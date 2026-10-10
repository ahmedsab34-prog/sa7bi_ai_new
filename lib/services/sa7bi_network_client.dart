
import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';

/// بوابة الشبكة الموحدة لتطبيق صاحبي AI.
///
/// سياسة الاتصال:
/// - Cronet على Android عند توفره، وإلا IOClient.
/// - محاولتان كحد أقصى لطلبات GET/HEAD على الخادم الأساسي.
/// - تجربة الخادم الاحتياطي بعد فشل الاتصال الأساسي.
/// - طلبات AI محددة بوجود Request ID وDevice ID.
/// - لا نعيد إرسال طلب AI بسبب Timeout لتجنب تكرار التنفيذ أو الخصم.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent = 'Sa7biAI-Mobile/1.0';

  static const Duration connectionTimeout =
      Duration(seconds: 20);

  /// مهلة كل محاولة عادية إلى الخادم الأساسي.
  static const Duration safeRequestTimeout =
      Duration(seconds: 15);

  /// مهلة الخادم الاحتياطي؛ أطول قليلًا للشبكات البطيئة.
  static const Duration fallbackRequestTimeout =
      Duration(seconds: 30);

  static const int maximumAttempts = 2;

  static http.Client? _client;
  static bool _usingCronet = false;

  static http.Client get client {
    return _client ??= _createClient();
  }

  static bool get isCronet => _usingCronet;

  static String get transportName => _usingCronet
      ? 'ANDROID_CRONET_WITH_WORKER_FAILOVER'
      : 'DART_IO_WITH_WORKER_FAILOVER';

  static bool get failoverEnabled => true;

  static http.Client factory() => client;

  static http.Client _createClient() {
    if (Platform.isAndroid) {
      try {
        final engine = CronetEngine.build(
          cacheMode: CacheMode.memory,
          cacheMaxSize: 2 * 1024 * 1024,
          userAgent: userAgent,
        );

        final cronetClient = CronetClient.fromCronetEngine(
          engine,
          closeEngine: true,
        );

        _usingCronet = true;

        return _Sa7biFailoverClient(
          primary: cronetClient,
          fallback: cronetClient,
        );
      } catch (_) {
        // إذا تعذر إنشاء Cronet، نستخدم IOClient.
        _usingCronet = false;
      }
    }

    final ioClient = _createIoClient();
    _usingCronet = false;

    return _Sa7biFailoverClient(
      primary: ioClient,
      fallback: ioClient,
    );
  }

  static http.Client _createIoClient() {
    final ioClient = HttpClient()
      ..userAgent = userAgent
      ..connectionTimeout = connectionTimeout;

    return IOClient(ioClient);
  }

  static void close() {
    final previous = _client;
    _client = null;

    try {
      previous?.close();
    } catch (_) {
      // لا نسمح لفشل الإغلاق بإسقاط التطبيق.
    }
  }
}

class _Sa7biFailoverClient extends http.BaseClient {
  _Sa7biFailoverClient({
    required this.primary,
    required this.fallback,
  });

  final http.Client primary;
  final http.Client fallback;

  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest original,
  ) async {
    if (_closed) {
      throw http.ClientException(
        'Network client is closed.',
        original.url,
      );
    }

    final method = original.method.toUpperCase();
    final host = original.url.host.toLowerCase();

    final isPrimaryBackend =
        host == AppConfig.backendPrimaryHost.toLowerCase();

    final canFallbackGet = isPrimaryBackend &&
        (method == 'GET' || method == 'HEAD');

    final canFallbackAi = isPrimaryBackend &&
        method == 'POST' &&
        _isIdentifiedAiRequest(original);

    // نجهز جسم الطلب مرة واحدة؛ لأن BaseRequest لا يمكن
    // إعادة finalize له بعد إرسال المحاولة الأولى.
    final bodyBytes = await original.finalize().toBytes();

    if (canFallbackGet) {
      Object? lastError;

      for (
        var attempt = 1;
        attempt <= Sa7biNetworkClient.maximumAttempts;
        attempt++
      ) {
        try {
          final request = _cloneRequest(
            original,
            original.url,
            bodyBytes,
          );

          return await primary
              .send(request)
              .timeout(
                Sa7biNetworkClient.safeRequestTimeout,
              );
        } on TimeoutException catch (error) {
          lastError = error;
        } on SocketException catch (error) {
          lastError = error;
        } on http.ClientException catch (error) {
          lastError = error;
        } on IOException catch (error) {
          lastError = error;
        }

        if (attempt < Sa7biNetworkClient.maximumAttempts) {
          await Future<void>.delayed(
            const Duration(seconds: 1),
          );
        }
      }

      try {
        return await _sendFallback(
          original,
          bodyBytes,
        );
      } catch (fallbackError) {
        throw http.ClientException(
          'فشل الاتصال بالخادم الأساسي بعد '
          '${Sa7biNetworkClient.maximumAttempts} محاولات. '
          'آخر خطأ أساسي: $lastError. '
          'خطأ الخادم الاحتياطي: $fallbackError',
          original.url,
        );
      }
    }

    try {
      final request = _cloneRequest(
        original,
        original.url,
        bodyBytes,
      );

      // لا نضيف مهلة قصيرة هنا على طلب AI؛ لأن خدمة AI
      // نفسها تحدد مهلة الطلب حسب نوع العملية.
      return await primary.send(request);
    } on SocketException {
      if (!canFallbackAi) rethrow;

      return _sendFallback(
        original,
        bodyBytes,
      );
    } on http.ClientException {
      if (!canFallbackAi) rethrow;

      return _sendFallback(
        original,
        bodyBytes,
      );
    } on IOException {
      if (!canFallbackAi) rethrow;

      return _sendFallback(
        original,
        bodyBytes,
      );
    }
  }

  bool _isIdentifiedAiRequest(
    http.BaseRequest request,
  ) {
    final path = request.url.path;

    final isAiEndpoint =
        path == '/v1/chat' ||
        path == '/v1/image';

    if (!isAiEndpoint) return false;

    String? headerValue(String name) {
      for (final entry in request.headers.entries) {
        if (entry.key.toLowerCase() == name) {
          return entry.value.trim();
        }
      }

      return null;
    }

    final requestId = headerValue('x-sa7bi-request-id');
    final deviceId = headerValue('x-sa7bi-device-id');

    return requestId != null &&
        requestId.isNotEmpty &&
        deviceId != null &&
        deviceId.isNotEmpty;
  }

  Future<http.StreamedResponse> _sendFallback(
    http.BaseRequest original,
    List<int> bodyBytes,
  ) async {
    if (_closed) {
      throw http.ClientException(
        'Network client is closed.',
        original.url,
      );
    }

    if (original.url.host.toLowerCase() !=
        AppConfig.backendPrimaryHost.toLowerCase()) {
      throw http.ClientException(
        'Fallback is only available for the primary Worker.',
        original.url,
      );
    }

    final fallbackBase = Uri.parse(
      AppConfig.backendFallbackBaseUrl,
    );

    final fallbackUri = original.url.replace(
      scheme: fallbackBase.scheme,
      host: fallbackBase.host,
      port: fallbackBase.hasPort ? fallbackBase.port : null,
    );

    final request = _cloneRequest(
      original,
      fallbackUri,
      bodyBytes,
    );

    final future = fallback.send(request);
    final method = original.method.toUpperCase();

    if (method == 'GET' || method == 'HEAD') {
      return future.timeout(
        Sa7biNetworkClient.fallbackRequestTimeout,
      );
    }

    // طلبات POST لا تُعاد بسبب Timeout.
    // قد يكون الخادم استلم الطلب وبدأ تنفيذه بالفعل.
    return future;
  }

  static http.Request _cloneRequest(
    http.BaseRequest original,
    Uri uri,
    List<int> bodyBytes,
  ) {
    final request = http.Request(
      original.method,
      uri,
    );

    request.headers.addAll(original.headers);
    request.headers.remove('content-length');
    request.headers.remove('host');

    request.followRedirects = original.followRedirects;
    request.maxRedirects = original.maxRedirects;
    request.persistentConnection = original.persistentConnection;
    request.bodyBytes = bodyBytes;

    return request;
  }

  @override
  void close() {
    if (_closed) return;

    _closed = true;

    try {
      primary.close();
    } catch (_) {
      // تجاهل خطأ الإغلاق.
    }

    if (!identical(primary, fallback)) {
      try {
        fallback.close();
      } catch (_) {
        // تجاهل خطأ الإغلاق.
      }
    }
  }
}
