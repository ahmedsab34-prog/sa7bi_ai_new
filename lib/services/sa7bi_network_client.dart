import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';

/// بوابة الشبكة الموحدة لتطبيق صاحبي AI.
///
/// Android:
///   Cronet
///      ↓ عند فشل GET/HEAD
///   IO fallback
///
/// قواعد مهمة:
/// - لا يوجد IP ثابت.
/// - لا يوجد Socket.connect.
/// - لا يوجد إجبار IPv4 أو IPv6.
/// - لا توجد مفاتيح API داخل التطبيق.
/// - يظل عميل الواجهة ثابتًا حتى عند إعادة إنشاء النقل.
/// - لا تعاد طلبات POST المدفوعة تلقائيًا.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent = 'Sa7biAI-Mobile/1.0';

  static const int cacheSizeBytes = 2 * 1024 * 1024;

  static const Duration failoverTimeout =
      Duration(seconds: 8);

  static const Duration connectionTimeout =
      Duration(seconds: 30);

  /// عميل الواجهة الذي تستخدمه خدمات التطبيق.
  ///
  /// لا نعيد استبداله عند تعطل اتصال داخلي؛ بل يعيد
  /// توجيه الطلبات إلى عميل النقل الحالي.
  static http.Client? _client;

  /// عميل النقل الفعلي، ويمكن إعادة إنشائه.
  static http.Client? _transportClient;

  static bool _isCronet = false;

  static bool _isResetting = false;

  /// عميل الشبكة الموحد.
  static http.Client get client {
    return _client ??= _RecoveringClient();
  }

  /// هل يستخدم التطبيق Cronet؟
  static bool get isCronet => _isCronet;

  /// اسم وسيلة الاتصال المستخدمة.
  static String get transportName {
    if (_isCronet) {
      return 'CRONET_ANDROID_WITH_IO_FAILOVER';
    }

    return 'DART_IO_WITH_FAILOVER';
  }

  /// هل مسار الاتصال الاحتياطي مفعّل؟
  static bool get failoverEnabled => true;

  /// يستخدمه http.runWithClient.
  ///
  /// يعيد عميل الواجهة الثابت، لا عميل النقل الداخلي.
  static http.Client factory() => client;

  // ============================================================
  // إنشاء عميل النقل
  // ============================================================

  static http.Client _getTransportClient() {
    return _transportClient ??= _createClient();
  }

  static http.Client _createClient() {
    final primary = _createPrimaryClient();
    final fallback = _createIoClient();

    return _FailoverClient(
      primary: primary,
      fallback: fallback,
      fallbackTimeout: failoverTimeout,
    );
  }

  static http.Client _createPrimaryClient() {
    if (Platform.isAndroid) {
      try {
        final client = _createCronetClient();
        _isCronet = true;
        return client;
      } catch (_) {
        // إذا تعذر إنشاء Cronet، نستخدم IO.
      }
    }

    _isCronet = false;
    return _createIoClient();
  }

  // ============================================================
  // Cronet على Android
  // ============================================================

  static http.Client _createCronetClient() {
    final engine = CronetEngine.build(
      cacheMode: CacheMode.memory,
      cacheMaxSize: cacheSizeBytes,
      userAgent: userAgent,
      enableHttp2: true,
      enableQuic: true,
      enableBrotli: true,
      useBuiltInDnsResolver: false,
      enableStaleDns: true,
      useStaleOnNameNotResolved: true,
      allowCrossNetworkUsage: true,
    );

    try {
      return CronetClient.fromCronetEngine(
        engine,
        closeEngine: true,
      );
    } catch (_) {
      engine.shutdown();
      rethrow;
    }
  }

  // ============================================================
  // Dart IO
  // ============================================================

  static http.Client _createIoClient() {
    final ioClient = HttpClient()
      ..userAgent = userAgent
      ..connectionTimeout = connectionTimeout;

    return IOClient(ioClient);
  }

  // ============================================================
  // إعادة تهيئة النقل
  // ============================================================

  /// يتخلص من عميل النقل المعطل فقط.
  ///
  /// لا يغلق عميل الواجهة الثابت؛ لذلك تظل مراجع
  /// http.runWithClient صالحة بعد إعادة التهيئة.
  static void _resetTransport() {
    if (_isResetting) {
      return;
    }

    _isResetting = true;

    final previous = _transportClient;
    _transportClient = null;
    _isCronet = false;

    try {
      previous?.close();
    } catch (_) {
      // لا نسمح لفشل الإغلاق بمنع إنشاء عميل جديد.
    } finally {
      _isResetting = false;
    }
  }

  /// يسمح لبقية التطبيق بطلب إعادة تهيئة الاتصال.
  ///
  /// لا يستبدل عميل الواجهة الذي تحتفظ به zone.
  static void close() {
    _resetTransport();
  }

  // ============================================================
  // إرسال الطلب مع الاسترداد
  // ============================================================

  static Future<http.StreamedResponse> _send(
    http.BaseRequest original,
  ) async {
    // نقرأ جسم الطلب مرة واحدة وننشئ نسخة مستقلة.
    final bodyBytes = await original.finalize().toBytes();

    final method = original.method.toUpperCase();
    final canRetry = method == 'GET' || method == 'HEAD';

    final firstRequest = _cloneRequest(
      original,
      bodyBytes,
      original.url,
    );

    try {
      return await _getTransportClient().send(firstRequest);
    } on http.ClientException {
      _resetTransport();

      if (!canRetry) {
        rethrow;
      }

      return _retrySafeRequest(
        original,
        bodyBytes,
      );
    } on SocketException {
      _resetTransport();

      if (!canRetry) {
        rethrow;
      }

      return _retrySafeRequest(
        original,
        bodyBytes,
      );
    } on TimeoutException {
      _resetTransport();

      if (!canRetry) {
        rethrow;
      }

      return _retrySafeRequest(
        original,
        bodyBytes,
      );
    } on IOException {
      _resetTransport();

      if (!canRetry) {
        rethrow;
      }

      return _retrySafeRequest(
        original,
        bodyBytes,
      );
    }
  }

  static Future<http.StreamedResponse> _retrySafeRequest(
    http.BaseRequest original,
    List<int> bodyBytes,
  ) async {
    final retryRequest = _cloneRequest(
      original,
      bodyBytes,
      original.url,
    );

    // محاولة واحدة فقط بعد إعادة إنشاء النقل.
    return _getTransportClient().send(retryRequest);
  }

  static http.Request _cloneRequest(
    http.BaseRequest original,
    List<int> bodyBytes,
    Uri destinationUri,
  ) {
    final request = http.Request(
      original.method,
      destinationUri,
    );

    request.headers.addAll(original.headers);
    request.headers.remove('content-length');
    request.headers.remove('host');

    request.followRedirects = original.followRedirects;
    request.maxRedirects = original.maxRedirects;
    request.persistentConnection =
        original.persistentConnection;

    request.bodyBytes = bodyBytes;

    return request;
  }
}

// ================================================================
// عميل واجهة ثابت
// ================================================================

class _RecoveringClient extends http.BaseClient {
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request,
  ) async {
    if (_closed) {
      throw http.ClientException(
        'Network facade is closed.',
        request.url,
      );
    }

    return Sa7biNetworkClient._send(request);
  }

  @override
  void close() {
    // لا نغلق عميل النقل من خلال عميل الواجهة.
    // إعادة التهيئة تتم عن طريق Sa7biNetworkClient.close().
    _closed = true;
    Sa7biNetworkClient._resetTransport();
  }
}

// ================================================================
// عميل النقل الأساسي والاحتياطي
// ================================================================

class _FailoverClient extends http.BaseClient {
  final http.Client primary;
  final http.Client fallback;
  final Duration fallbackTimeout;

  _FailoverClient({
    required this.primary,
    required this.fallback,
    required this.fallbackTimeout,
  });

  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request,
  ) async {
    final originalUri = request.url;

    final isPrimaryBackend =
        originalUri.host == AppConfig.backendPrimaryHost;

    final bodyBytes = await request.finalize().toBytes();

    final primaryRequest = Sa7biNetworkClient._cloneRequest(
      request,
      bodyBytes,
      originalUri,
    );

    try {
      return await primary
          .send(primaryRequest)
          .timeout(fallbackTimeout);
    } on TimeoutException {
      if (!_canRetrySafely(request)) {
        rethrow;
      }

      return _sendFallback(
        request,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
      );
    } on SocketException {
      if (!_canRetrySafely(request)) {
        rethrow;
      }

      return _sendFallback(
        request,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
      );
    } on http.ClientException {
      if (!_canRetrySafely(request)) {
        rethrow;
      }

      return _sendFallback(
        request,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
      );
    } on IOException {
      if (!_canRetrySafely(request)) {
        rethrow;
      }

      return _sendFallback(
        request,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
      );
    }
  }

  bool _canRetrySafely(http.BaseRequest request) {
    final method = request.method.toUpperCase();
    return method == 'GET' || method == 'HEAD';
  }

  Future<http.StreamedResponse> _sendFallback(
    http.BaseRequest original,
    List<int> bodyBytes, {
    required bool isPrimaryBackend,
  }) {
    final fallbackUri = isPrimaryBackend
        ? _replaceBackendHost(
            original.url,
            AppConfig.backendFallbackBaseUrl,
          )
        : original.url;

    final fallbackRequest = Sa7biNetworkClient._cloneRequest(
      original,
      bodyBytes,
      fallbackUri,
    );

    return fallback.send(fallbackRequest);
  }

  static Uri _replaceBackendHost(
    Uri originalUri,
    String destinationBaseUrl,
  ) {
    final destination = Uri.parse(destinationBaseUrl);

    return originalUri.replace(
      scheme: destination.scheme,
      host: destination.host,
      port: destination.hasPort ? destination.port : null,
    );
  }

  @override
  void close() {
    primary.close();

    if (!identical(primary, fallback)) {
      fallback.close();
    }
  }
}
