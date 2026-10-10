
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';

/// بوابة الشبكة الموحدة لتطبيق صاحبي AI.
///
/// يستخدم التطبيق HttpClient القياسي بدل Cronet
/// لعزل مشكلات النقل على أجهزة Android.
///
/// طلبات GET وHEAD إلى الـWorker الأساسي يمكنها
/// استخدام الـWorker الاحتياطي عند فشل الاتصال.
///
/// طلبات POST لا يعاد إرسالها بسبب انتهاء المهلة.
/// يسمح بالمسار الاحتياطي لطلبات AI المحددة فقط
/// عند وجود معرف الطلب ومعرف الجهاز.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent = 'Sa7biAI-Mobile/1.0';

  static const Duration connectionTimeout =
      Duration(seconds: 20);

  static const Duration safeRequestTimeout =
      Duration(seconds: 12);

  static const Duration fallbackRequestTimeout =
      Duration(seconds: 35);

  static http.Client? _client;

  static http.Client get client {
    return _client ??= _createClient();
  }

  /// Cronet معطل في هذا الإصدار لعزل مسار النقل.
  static bool get isCronet => false;

  static String get transportName =>
      'DART_IO_WITH_WORKER_FAILOVER';

  static bool get failoverEnabled => true;

  /// Factory متوافقة مع http.runWithClient في main.dart.
  static http.Client factory() => client;

  static http.Client _createClient() {
    return _Sa7biFailoverClient(
      primary: _createIoClient(),
      fallback: _createIoClient(),
    );
  }

  static http.Client _createIoClient() {
    final ioClient = HttpClient()
      ..userAgent = userAgent
      ..connectionTimeout = connectionTimeout;

    return IOClient(ioClient);
  }

  /// يغلق النقل الحالي ويتيح إنشاء عميل جديد لاحقًا.
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
        host ==
        AppConfig.backendPrimaryHost.toLowerCase();

    final canFallbackGet =
        isPrimaryBackend &&
        (method == 'GET' || method == 'HEAD');

    final canFallbackAi =
        isPrimaryBackend &&
        method == 'POST' &&
        _isIdentifiedAiRequest(original);

    // تجهيز جسم الطلب مرة واحدة.
    // لا نعيد استخدام BaseRequest بعد finalize.
    final bodyBytes =
        await original.finalize().toBytes();

    try {
      final request = _cloneRequest(
        original,
        original.url,
        bodyBytes,
      );

      final responseFuture = primary.send(request);

      // مهلة النقل القصيرة مخصصة لـ GET وHEAD فقط.
      // لا نضيف مهلة عامة لطلبات AI.
      if (canFallbackGet) {
        return await responseFuture.timeout(
          Sa7biNetworkClient.safeRequestTimeout,
        );
      }

      return await responseFuture;
    } on TimeoutException {
      if (!canFallbackGet) {
        rethrow;
      }

      return _sendFallback(
        original,
        bodyBytes,
      );
    } on SocketException {
      if (!canFallbackGet && !canFallbackAi) {
        rethrow;
      }

      return _sendFallback(
        original,
        bodyBytes,
      );
    } on http.ClientException {
      if (!canFallbackGet && !canFallbackAi) {
        rethrow;
      }

      return _sendFallback(
        original,
        bodyBytes,
      );
    } on IOException {
      if (!canFallbackGet && !canFallbackAi) {
        rethrow;
      }

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

    if (!isAiEndpoint) {
      return false;
    }

    String? headerValue(String name) {
      for (final entry in request.headers.entries) {
        if (entry.key.toLowerCase() == name) {
          return entry.value.trim();
        }
      }

      return null;
    }

    final requestId =
        headerValue('x-sa7bi-request-id');

    final deviceId =
        headerValue('x-sa7bi-device-id');

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

    // لا نغيّر وجهة الخدمات الخارجية.
    // الاستبدال مسموح للـWorker الأساسي فقط.
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
      port: fallbackBase.hasPort
          ? fallbackBase.port
          : null,
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

    // لا نضيف مهلة جديدة إلى POST.
    // المهلة الأصلية يجب أن تظل تحت تحكم خدمة AI.
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

    // نترك مكتبة HTTP تحسب القيم المناسبة للوجهة الجديدة.
    request.headers.remove('content-length');
    request.headers.remove('host');

    request.followRedirects = original.followRedirects;
    request.maxRedirects = original.maxRedirects;
    request.persistentConnection =
        original.persistentConnection;

    request.bodyBytes = bodyBytes;

    return request;
  }

  @override
  void close() {
    if (_closed) {
      return;
    }

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
