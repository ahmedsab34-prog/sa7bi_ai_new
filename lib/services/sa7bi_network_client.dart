import 'dart:async';
import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/app_config.dart';

/// بوابة الشبكة الموحدة لتطبيق صاحبي AI.
///
/// Android: Cronet مع مسار احتياطي IO.
/// المنصات الأخرى: IO.
/// لا تتم إعادة محاولات POST تلقائيًا لتجنب تكرار
/// الطلبات المدفوعة أو تكرار العمليات على الخادم.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent = 'Sa7biAI-Mobile/1.0';
  static const int cacheSizeBytes = 2 * 1024 * 1024;

  static const Duration failoverTimeout =
      Duration(seconds: 8);

  static const Duration connectionTimeout =
      Duration(seconds: 30);

  static http.Client? _client;
  static http.Client? _transportClient;
  static bool _isCronet = false;
  static bool _isResetting = false;

  /// عميل واجهة ثابت لا يصبح مغلقًا نهائيًا عند إعادة التهيئة.
  static http.Client get client =>
      _client ??= _RecoveringClient();

  static bool get isCronet => _isCronet;

  static String get transportName => _isCronet
      ? 'CRONET_ANDROID_WITH_IO_FAILOVER'
      : 'DART_IO_WITH_FAILOVER';

  static bool get failoverEnabled => true;

  /// يستخدمه http.runWithClient في main.dart.
  static http.Client factory() => client;

  static http.Client _getTransportClient() =>
      _transportClient ??= _createClient();

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
        // استمرار التشغيل باستخدام IO إذا تعذر إنشاء Cronet.
      }
    }

    _isCronet = false;
    return _createIoClient();
  }

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

    return CronetClient.fromCronetEngine(
      engine,
      closeEngine: true,
    );
  }

  static http.Client _createIoClient() {
    final ioClient = HttpClient()
      ..userAgent = userAgent
      ..connectionTimeout = connectionTimeout;

    return IOClient(ioClient);
  }

  /// إعادة إنشاء عميل النقل فقط، دون إبطال عميل الواجهة.
  static void _resetTransport() {
    if (_isResetting) return;

    _isResetting = true;
    final previous = _transportClient;

    _transportClient = null;
    _isCronet = false;

    try {
      previous?.close();
    } catch (_) {
      // فشل الإغلاق لا يمنع محاولة إنشاء اتصال جديد.
    } finally {
      _isResetting = false;
    }
  }

  /// يحافظ على توافق الواجهة مع الاستدعاءات الموجودة.
  static void close() {
    _resetTransport();
  }

  static Future<http.StreamedResponse> _send(
    http.BaseRequest original,
  ) async {
    final method = original.method.toUpperCase();
    final canRetry = method == 'GET' || method == 'HEAD';

    // قراءة الجسم مرة واحدة قبل إنشاء أي نسخ من الطلب.
    final bodyBytes = await original.finalize().toBytes();

    try {
      final request = _cloneRequest(original, bodyBytes);
      return await _getTransportClient().send(request);
    } on http.ClientException {
      _resetTransport();
      if (!canRetry) rethrow;
      return _retrySafeRequest(original, bodyBytes);
    } on SocketException {
      _resetTransport();
      if (!canRetry) rethrow;
      return _retrySafeRequest(original, bodyBytes);
    } on TimeoutException {
      _resetTransport();
      if (!canRetry) rethrow;
      return _retrySafeRequest(original, bodyBytes);
    } on IOException {
      _resetTransport();
      if (!canRetry) rethrow;
      return _retrySafeRequest(original, bodyBytes);
    }
  }

  static Future<http.StreamedResponse> _retrySafeRequest(
    http.BaseRequest original,
    List<int> bodyBytes,
  ) {
    final request = _cloneRequest(original, bodyBytes);
    return _getTransportClient().send(request);
  }

  static http.Request _cloneRequest(
    http.BaseRequest original,
    List<int> bodyBytes,
  ) {
    final request = http.Request(
      original.method,
      original.url,
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

/// واجهة مستقرة؛ استدعاء close يعيد تهيئة النقل فقط.
/// لا تحتفظ الواجهة بحالة closed دائمة.
class _RecoveringClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request,
  ) {
    return Sa7biNetworkClient._send(request);
  }

  @override
  void close() {
    Sa7biNetworkClient._resetTransport();
  }
}

/// يجرّب Cronet أولًا، ثم IO للطلبات الآمنة فقط.
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
    final uri = request.url;
    final isPrimaryBackend =
        uri.host == AppConfig.backendPrimaryHost;

    final method = request.method.toUpperCase();
    final canRetry = method == 'GET' || method == 'HEAD';
    final bodyBytes = await request.finalize().toBytes();

    final primaryRequest =
        Sa7biNetworkClient._cloneRequest(
      request,
      bodyBytes,
    );

    try {
      return await primary
          .send(primaryRequest)
          .timeout(fallbackTimeout);
    } on TimeoutException {
      if (!canRetry) rethrow;
      return _sendFallback(
        request,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
      );
    } on SocketException {
      if (!canRetry) rethrow;
      return _sendFallback(
        request,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
      );
    } on http.ClientException {
      if (!canRetry) rethrow;
      return _sendFallback(
        request,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
      );
    } on IOException {
      if (!canRetry) rethrow;
      return _sendFallback(
        request,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
      );
    }
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

    final fallbackRequest =
        Sa7biNetworkClient._cloneRequest(
      original,
      bodyBytes,
    );

    // الحفاظ على المسار والاستعلام مع تغيير المضيف فقط.
    final request = http.Request(
      fallbackRequest.method,
      fallbackUri,
    )
      ..headers.addAll(fallbackRequest.headers)
      ..followRedirects = fallbackRequest.followRedirects
      ..maxRedirects = fallbackRequest.maxRedirects
      ..persistentConnection =
          fallbackRequest.persistentConnection
      ..bodyBytes = bodyBytes;

    return fallback.send(request);
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
