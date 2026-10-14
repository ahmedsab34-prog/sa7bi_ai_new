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
///
/// مهم:
/// - client عميل دائم للخدمات التي تستخدمه مباشرة.
/// - factory ينشئ عميلًا مستقلًا لكل طلب Zone.
/// - لا تعِد العميل الدائم من factory لأن http.get/http.post
///   قد يغلقان عميل Zone بعد انتهاء الطلب.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent = 'Sa7biAI-Mobile/1.0';

  static const Duration connectionTimeout =
      Duration(seconds: 20);

  static const Duration safeRequestTimeout =
      Duration(seconds: 15);

  static const Duration fallbackRequestTimeout =
      Duration(seconds: 30);

  static const int maximumAttempts = 2;

  static http.Client? _client;
  static bool _usingCronet = false;
  static bool _initialized = false;

  /// عميل دائم للخدمات التي تستدعي Sa7biNetworkClient.client مباشرة.
  ///
  /// لا يُستخدم هذا العميل كعميل Zone لدوال http المساعدة.
  static http.Client get client {
    if (_client == null) {
      _client = _createClient();
      _initialized = true;
      _logInitialization();
    }

    return _client!;
  }

  static bool get isCronet => _usingCronet;

  static String get transportName => _usingCronet
      ? 'ANDROID_CRONET_WITH_WORKER_FAILOVER'
      : 'DART_IO_WITH_WORKER_FAILOVER';

  static bool get failoverEnabled => true;

  static bool get isInitialized => _initialized;

  /// عميل مستقل لكل استدعاء من http.runWithClient.
  ///
  /// لا تستخدم _client هنا؛ دوال http.get/http.post
  /// قد تغلق العميل الذي ترجعه هذه الدالة بعد انتهاء الطلب.
  static http.Client factory() => _createClient();

  static http.Client _createClient() {
    http.Client? primary;
    http.Client? fallback;

    try {
      if (Platform.isAndroid) {
        try {
          final engine = CronetEngine.build(
            cacheMode: CacheMode.memory,
            cacheMaxSize: 2 * 1024 * 1024,
            userAgent: userAgent,
          );

          primary = CronetClient.fromCronetEngine(
            engine,
            closeEngine: true,
          );

          _usingCronet = true;

          fallback = _createIoClient();

          return _Sa7biFailoverClient(
            primary: primary,
            fallback: fallback,
          );
        } catch (_) {
          _usingCronet = false;

          // لو فشل إنشاء Cronet بعد إنشاء أحد العملاء،
          // نغلق الموارد الجزئية قبل إنشاء عملاء IO.
          try {
            primary?.close();
          } catch (_) {}

          try {
            fallback?.close();
          } catch (_) {}

          primary = null;
          fallback = null;
        }
      }

      primary = _createIoClient();
      fallback = _createIoClient();

      return _Sa7biFailoverClient(
        primary: primary,
        fallback: fallback,
      );
    } catch (error) {
      try {
        primary?.close();
      } catch (_) {}

      try {
        fallback?.close();
      } catch (_) {}

      throw StateError(
        'Failed to initialize Sa7biNetworkClient: $error',
      );
    }
  }

  static http.Client _createIoClient() {
    final ioClient = HttpClient()
      ..userAgent = userAgent
      ..connectionTimeout = connectionTimeout;

    return IOClient(ioClient);
  }

  static void _logInitialization() {
    final message = 'Sa7biNetworkClient initialized: '
        'transport=$transportName, '
        'failoverEnabled=$failoverEnabled';

    // يمكن تفعيل السطر التالي عند الحاجة إلى التشخيص:
    // debugPrint(message);
    assert(message.isNotEmpty);
  }

  /// يغلق العميل الدائم فقط.
  ///
  /// عملاء Zone مستقلة، وكل طلب مسؤول عن إغلاق عميله.
  static void close() {
    final previous = _client;

    _client = null;
    _initialized = false;

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

    // نقرأ جسم الطلب مرة واحدة حتى نستطيع إنشاء نسخة جديدة
    // لكل محاولة دون إعادة finalize للطلب الأصلي.
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

      // لا نفرض مهلة قصيرة على طلب AI هنا.
      // خدمة AI تحدد المهلة المناسبة لنوع العملية.
      return await primary.send(request);
    } on TimeoutException {
      // لا نكرر طلب AI عند انتهاء المهلة؛ فقد يكون الخادم
      // قد بدأ التنفيذ بالفعل.
      rethrow;
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

    // لا نكرر POST عند Timeout لتجنب تنفيذ عملية AI مرتين.
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

    // نترك مكتبة HTTP تضبط هذين الرأسين حسب الطلب الجديد.
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
