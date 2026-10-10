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
///      ↓ عند تعذر الاتصال
///   Worker احتياطي + IO
///
/// المنصات الأخرى:
///   IO
///
/// قواعد الأمان:
/// - لا توجد عناوين IP ثابتة أو تغييرات DNS قسرية.
/// - لا توجد مفاتيح API داخل التطبيق.
/// - لا تتم إعادة POST تلقائيًا لمجرد انتهاء المهلة.
/// - يسمح بالمسار الاحتياطي لطلبات AI المحددة التي تحمل
///   معرف طلب ثابتًا داخل المحاولة نفسها.
/// - لا يتم استبدال عميل الواجهة عند إعادة تهيئة النقل.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent = 'Sa7biAI-Mobile/1.0';

  static const int cacheSizeBytes = 2 * 1024 * 1024;

  /// مهلة تجربة المسار الأساسي لطلبات GET وHEAD.
  static const Duration safeRequestTimeout =
      Duration(seconds: 12);

  /// أقصى انتظار للمسار الاحتياطي لطلبات GET وHEAD.
  static const Duration fallbackRequestTimeout =
      Duration(seconds: 35);

  static const Duration connectionTimeout =
      Duration(seconds: 30);

  static http.Client? _client;
  static http.Client? _transportClient;

  static bool _isCronet = false;
  static bool _isResetting = false;

  /// عميل واجهة ثابت.
  static http.Client get client =>
      _client ??= _RecoveringClient();

  static bool get isCronet => _isCronet;

  static String get transportName => _isCronet
      ? 'CRONET_ANDROID_WITH_IO_FAILOVER'
      : 'DART_IO_WITH_IO_FALLBACK';

  static bool get failoverEnabled => true;

  /// متوافق مع http.runWithClient في main.dart.
  static http.Client factory() => client;

  static http.Client _getTransportClient() =>
      _transportClient ??= _createClient();

  static http.Client _createClient() {
    final primary = _createPrimaryClient();
    final fallback = _createIoClient();

    return _FailoverClient(
      primary: primary,
      fallback: fallback,
      fallbackTimeout: safeRequestTimeout,
      fallbackRequestTimeout: fallbackRequestTimeout,
    );
  }

  static http.Client _createPrimaryClient() {
    if (Platform.isAndroid) {
      try {
        final client = _createCronetClient();
        _isCronet = true;
        return client;
      } catch (_) {
        // استمرار العمل باستخدام IO إذا تعذر إنشاء Cronet.
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

  /// إعادة تهيئة عميل النقل فقط.
  static void _resetTransport() {
    if (_isResetting) return;

    _isResetting = true;

    final previous = _transportClient;

    _transportClient = null;
    _isCronet = false;

    try {
      previous?.close();
    } catch (_) {
      // تجاهل فشل الإغلاق.
    } finally {
      _isResetting = false;
    }
  }

  /// يحافظ على توافق الواجهة الحالية.
  static void close() {
    _resetTransport();
  }

  static Future<http.StreamedResponse> _send(
    http.BaseRequest original,
  ) async {
    final method = original.method.toUpperCase();

    final canRetry =
        method == 'GET' || method == 'HEAD';

    // تجهيز جسم الطلب مرة واحدة فقط.
    final bodyBytes = await original.finalize().toBytes();

    try {
      final request = _cloneRequest(
        original,
        bodyBytes,
      );

      return await _getTransportClient().send(request);
    } on http.ClientException {
      _resetTransport();

      if (!canRetry) rethrow;

      return _retrySafeRequest(
        original,
        bodyBytes,
      );
    } on SocketException {
      _resetTransport();

      if (!canRetry) rethrow;

      return _retrySafeRequest(
        original,
        bodyBytes,
      );
    } on TimeoutException {
      _resetTransport();

      if (!canRetry) rethrow;

      return _retrySafeRequest(
        original,
        bodyBytes,
      );
    } on IOException {
      _resetTransport();

      if (!canRetry) rethrow;

      return _retrySafeRequest(
        original,
        bodyBytes,
      );
    }
  }

  static Future<http.StreamedResponse> _retrySafeRequest(
    http.BaseRequest original,
    List<int> bodyBytes,
  ) {
    final request = _cloneRequest(
      original,
      bodyBytes,
    );

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

/// عميل واجهة ثابت لا يصبح مغلقًا نهائيًا.
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

/// عميل نقل أساسي مع مسار احتياطي مستقل.
class _FailoverClient extends http.BaseClient {
  final http.Client primary;
  final http.Client fallback;

  final Duration fallbackTimeout;
  final Duration fallbackRequestTimeout;

  _FailoverClient({
    required this.primary,
    required this.fallback,
    required this.fallbackTimeout,
    required this.fallbackRequestTimeout,
  });

  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest original,
  ) async {
    final method = original.method.toUpperCase();

    final canRetry =
        method == 'GET' || method == 'HEAD';

    final bodyBytes =
        await original.finalize().toBytes();

    final uri = original.url;

    final isPrimaryBackend =
        uri.host.toLowerCase() ==
        AppConfig.backendPrimaryHost.toLowerCase();

    final canFallbackAI =
        isPrimaryBackend &&
        _isIdempotentAIRequest(original);

    final primaryRequest =
        Sa7biNetworkClient._cloneRequest(
      original,
      bodyBytes,
    );

    try {
      final primaryFuture =
          primary.send(primaryRequest);

      // لا نفرض مهلة 12 ثانية على طلب AI قد يستغرق
      // وقتًا أطول بسبب ضعف الشبكة أو زمن الاستجابة.
      //
      // مهلة الشات أو الصور المحددة في الخدمة هي المرجع.
      if (canRetry) {
        return await primaryFuture.timeout(
          fallbackTimeout,
        );
      }

      return await primaryFuture;
    } on TimeoutException {
      // إعادة GET/HEAD آمنة نسبيًا.
      // لا نكرر POST بسبب انتهاء المهلة؛ ربما وصل للخادم.
      if (!canRetry) rethrow;

      return _sendFallback(
        original,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
        canRetry: true,
      );
    } on SocketException {
      if (!canRetry && !canFallbackAI) rethrow;

      return _sendFallback(
        original,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
        canRetry: canRetry,
      );
    } on http.ClientException {
      if (!canRetry && !canFallbackAI) rethrow;

      return _sendFallback(
        original,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
        canRetry: canRetry,
      );
    } on IOException {
      if (!canRetry && !canFallbackAI) rethrow;

      return _sendFallback(
        original,
        bodyBytes,
        isPrimaryBackend: isPrimaryBackend,
        canRetry: canRetry,
      );
    }
  }

  /// يسمح بالمسار الاحتياطي فقط لطلبات AI المعروفة
  /// التي تحمل X-Sa7bi-Request-Id.
  ///
  /// هذا لا يجعل إعادة POST آمنة في جميع الظروف؛
  /// يجب أن يظل الخادم مسؤولًا عن منع تكرار العمليات.
  bool _isIdempotentAIRequest(
    http.BaseRequest request,
  ) {
    final path = request.url.path;

    final isAIEndpoint =
        path == '/v1/chat' ||
        path == '/v1/image';

    if (!isAIEndpoint) return false;

    final hasRequestId =
        request.headers.entries.any(
      (entry) =>
          entry.key.toLowerCase() ==
              'x-sa7bi-request-id' &&
          entry.value.trim().isNotEmpty,
    );

    final hasDeviceId =
        request.headers.entries.any(
      (entry) =>
          entry.key.toLowerCase() ==
              'x-sa7bi-device-id' &&
          entry.value.trim().isNotEmpty,
    );

    return hasRequestId && hasDeviceId;
  }

  Future<http.StreamedResponse> _sendFallback(
    http.BaseRequest original,
    List<int> bodyBytes, {
    required bool isPrimaryBackend,
    required bool canRetry,
  }) {
    // لا نغير عناوين الخدمات الخارجية.
    // نستبدل عنوان Worker الأساسي فقط.
    final fallbackUri = isPrimaryBackend
        ? _replaceBackendHost(
            original.url,
            AppConfig.backendFallbackBaseUrl,
          )
        : original.url;

    final request =
        Sa7biNetworkClient._cloneRequest(
      original,
      bodyBytes,
    );

    final fallbackRequest = http.Request(
      request.method,
      fallbackUri,
    )
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection =
          request.persistentConnection
      ..bodyBytes = bodyBytes;

    final future = fallback.send(fallbackRequest);

    // مهلة المسار الاحتياطي القصيرة مخصصة لطلبات GET/HEAD.
    // لا نضيف مهلة جديدة إلى POST؛ الخدمة تحدد مهلتها.
    if (canRetry) {
      return future.timeout(
        fallbackRequestTimeout,
      );
    }

    return future;
  }

  static Uri _replaceBackendHost(
    Uri originalUri,
    String destinationBaseUrl,
  ) {
    final destination = Uri.parse(
      destinationBaseUrl,
    );

    return originalUri.replace(
      scheme: destination.scheme,
      host: destination.host,
      port: destination.hasPort
          ? destination.port
          : null,
    );
  }

  @override
  void close() {
    try {
      primary.close();
    } catch (_) {
      // تجاهل فشل الإغلاق.
    }

    if (!identical(primary, fallback)) {
      try {
        fallback.close();
      } catch (_) {
        // تجاهل فشل الإغلاق.
      }
    }
  }
}
