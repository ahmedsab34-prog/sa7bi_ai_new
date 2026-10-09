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
///      ↓
///   Primary Worker
///      ↓ عند فشل الاتصال فقط
///   Fallback Worker باستخدام IOClient
///
/// قواعد مهمة:
/// - لا يوجد IP ثابت.
/// - لا يوجد Socket.connect.
/// - لا يوجد إجبار IPv4 أو IPv6.
/// - لا توجد مفاتيح API داخل التطبيق.
/// - خدمات package:http تستخدم بوابة الشبكة الموحدة.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent = 'Sa7biAI-Mobile/1.0';

  static const int cacheSizeBytes = 2 * 1024 * 1024;

  static const Duration failoverTimeout =
      Duration(seconds: 8);

  static http.Client? _client;
  static http.Client? _fallbackClient;

  static bool _isCronet = false;

  /// عميل الشبكة الموحد.
  static http.Client get client {
    final existing = _client;

    if (existing != null) {
      return existing;
    }

    final created = _createClient();
    _client = created;

    return created;
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
  static http.Client factory() => client;

  // ============================================================
  // إنشاء العملاء
  // ============================================================

  static http.Client _createClient() {
    final primary = _createPrimaryClient();
    final fallback = _createIoClient();

    _fallbackClient = fallback;

    return _FailoverClient(
      primary: primary,
      fallback: fallback,
      fallbackTimeout: failoverTimeout,
    );
  }

  static http.Client _createPrimaryClient() {
    if (Platform.isAndroid) {
      _isCronet = true;
      return _createCronetClient();
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

    return CronetClient.fromCronetEngine(
      engine,
      closeEngine: true,
    );
  }

  // ============================================================
  // Dart IO — مسار اتصال مستقل
  // ============================================================

  static http.Client _createIoClient() {
    final ioClient = HttpClient()
      ..userAgent = userAgent
      ..connectionTimeout = const Duration(seconds: 30);

    return IOClient(ioClient);
  }

  // ============================================================
  // إغلاق الاتصال
  // ============================================================

  static void close() {
    final existing = _client;
    final fallback = _fallbackClient;

    _client = null;
    _fallbackClient = null;
    _isCronet = false;

    if (existing != null) {
      existing.close();
    }

    if (fallback != null &&
        !identical(fallback, existing)) {
      fallback.close();
    }
  }
}

// ================================================================
// عميل الاتصال الأساسي والاحتياطي
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

    // لا نغيّر وجهة أي طلب خارج الخادم الأساسي المحدد.
    final isPrimaryBackend =
        originalUri.host == AppConfig.backendPrimaryHost;

    // نحفظ بيانات الطلب حتى نستطيع إنشاء نسخة مستقلة
    // عند الحاجة إلى مسار احتياطي.
    final bodyBytes = await request.finalize().toBytes();

    final primaryRequest = _cloneRequest(
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

  /// نسمح بإعادة المحاولة التلقائية للطلبات الآمنة فقط.
  ///
  /// لا نعيد POST تلقائيًا؛ فقد يكون الخادم نفّذ الطلب
  /// بالفعل قبل انقطاع الاتصال، وإعادته قد تكرر العملية
  /// أو استهلاك الرصيد.
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

    final fallbackRequest = _cloneRequest(
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

  @override
  void close() {
    primary.close();
    fallback.close();
  }
}
