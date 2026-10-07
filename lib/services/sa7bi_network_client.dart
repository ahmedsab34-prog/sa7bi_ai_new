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
///   Fallback Worker
///
/// مهم:
/// - لا يوجد IP ثابت.
/// - لا يوجد Socket.connect.
/// - لا يوجد connectionFactory.
/// - لا يوجد إجبار IPv4 أو IPv6.
/// - لا توجد API Keys.
/// - الـFallback لا يملك AI أو Credits مستقلة.
/// - كل خدمات package:http تستفيد من نفس البوابة.
///
/// main.dart يستخدم:
///
/// http.runWithClient(
///   () => runApp(...),
///   Sa7biNetworkClient.factory,
/// );
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent =
      'Sa7biAI-Mobile/1.0';

  static const int cacheSizeBytes =
      2 * 1024 * 1024;

  /// مهلة الانتقال من الـPrimary إلى الـFallback.
  ///
  /// هذه ليست مهلة التطبيق الكاملة.
  /// الهدف فقط ألا ننتظر وقتًا طويلًا قبل تجربة المسار البديل.
  static const Duration failoverTimeout =
      Duration(seconds: 8);

  static http.Client? _client;

  static http.Client? _fallbackClient;

  static bool _isCronet = false;

  // ============================================================
  // PUBLIC CLIENT
  // ============================================================

  /// العميل الموحد الذي يستخدمه التطبيق كله.
  static http.Client get client {
    final existing = _client;

    if (existing != null) {
      return existing;
    }

    final created = _createClient();

    _client = created;

    return created;
  }

  /// هل Cronet مستخدم؟
  static bool get isCronet =>
      _isCronet;

  /// اسم طبقة النقل الحالية.
  ///
  /// نحافظ على الاسم القديم حتى لا نكسر شاشة التشخيص.
  static String get transportName {
    if (_isCronet) {
      return 'CRONET_ANDROID';
    }

    return 'DART_IO_FALLBACK';
  }

  /// هل الـFailover مفعل؟
  static bool get failoverEnabled =>
      true;

  /// Factory المستخدمة مع package:http.
  static http.Client factory() {
    return client;
  }

  // ============================================================
  // CLIENT CREATION
  // ============================================================

  static http.Client _createClient() {
    if (Platform.isAndroid) {
      final primary =
          _createCronetClient();

      final fallback =
          _createCronetClient();

      _fallbackClient =
          fallback;

      _isCronet = true;

      return _FailoverClient(
        primary: primary,
        fallback: fallback,
        fallbackTimeout:
            failoverTimeout,
      );
    }

    _isCronet = false;

    final primary =
        _createIoClient();

    final fallback =
        _createIoClient();

    _fallbackClient =
        fallback;

    return _FailoverClient(
      primary: primary,
      fallback: fallback,
      fallbackTimeout:
          failoverTimeout,
    );
  }

  // ============================================================
  // CRONET
  // ============================================================

  static http.Client _createCronetClient() {
    final engine = CronetEngine.build(
      cacheMode:
          CacheMode.memory,
      cacheMaxSize:
          cacheSizeBytes,
      userAgent:
          userAgent,

      enableHttp2: true,
      enableQuic: true,
      enableBrotli: true,

      useBuiltInDnsResolver:
          false,

      enableStaleDns: true,
      useStaleOnNameNotResolved:
          true,

      allowCrossNetworkUsage:
          true,
    );

    return CronetClient.fromCronetEngine(
      engine,
      closeEngine: true,
    );
  }

  // ============================================================
  // DART IO FALLBACK
  // ============================================================

  static http.Client _createIoClient() {
    final ioClient =
        HttpClient()
          ..userAgent =
              userAgent
          ..connectionTimeout =
              const Duration(
            seconds: 30,
          );

    return IOClient(
      ioClient,
    );
  }

  // ============================================================
  // CLOSE
  // ============================================================

  /// إغلاق العميل عند الحاجة.
  ///
  /// لا يتم استدعاؤه أثناء تشغيل التطبيق الطبيعي.
  /// موجود للاختبارات وإدارة lifecycle.
  static void close() {
    final existing =
        _client;

    final fallback =
        _fallbackClient;

    _client = null;
    _fallbackClient = null;
    _isCronet = false;

    if (existing != null) {
      existing.close();
    }

    if (fallback != null &&
        !identical(
          fallback,
          existing,
        )) {
      fallback.close();
    }
  }
}

// ================================================================
// FAILOVER CLIENT
// ================================================================

/// Client داخلي يمرر الطلب أولًا إلى الـWorker الأساسي.
///
/// إذا فشل الاتصال نفسه أو انتهت مهلة الاتصال القصيرة،
/// يعيد الطلب إلى الـFallback Worker.
///
/// مهم جدًا:
/// - لا يتحول إلى fallback بسبب HTTP 400/401/403/404/409/500.
/// - الـHTTP response يعني أن الخادم تم الوصول إليه.
/// - الـFallback مخصص لفشل transport فقط.
/// - نفس body وheaders وrequest ID يتم تمريرها للطلب الثاني.
///
/// بذلك لا نعيد طلبات AI لمجرد أن الخادم رجع خطأ منطقي.
class _FailoverClient
    extends http.BaseClient {
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
    final bodyBytes =
        await request
            .finalize()
            .toBytes();

    final primaryRequest =
        _cloneRequest(
      request,
      bodyBytes,
      AppConfig.backendBaseUrl,
    );

    try {
      return await primary
          .send(
            primaryRequest,
          )
          .timeout(
        fallbackTimeout,
      );
    } on TimeoutException {
      return _sendFallback(
        request,
        bodyBytes,
      );
    } on SocketException {
      return _sendFallback(
        request,
        bodyBytes,
      );
    } on http.ClientException {
      return _sendFallback(
        request,
        bodyBytes,
      );
    } on IOException {
      return _sendFallback(
        request,
        bodyBytes,
      );
    }
  }

  Future<http.StreamedResponse>
      _sendFallback(
    http.BaseRequest original,
    List<int> bodyBytes,
  ) async {
    final fallbackUri =
        _buildFallbackUri(
      original.url,
    );

    final fallbackRequest =
        _cloneRequest(
      original,
      bodyBytes,
      AppConfig.backendFallbackBaseUrl,
    );

    final response =
        await fallback
            .send(
              fallbackRequest,
            );

    return response;
  }

  static http.Request _cloneRequest(
    http.BaseRequest original,
    List<int> bodyBytes,
    String baseUrl,
  ) {
    final fallbackBase =
        Uri.parse(
      baseUrl,
    );

    final uri =
        original.url.host ==
                AppConfig.backendPrimaryHost
            ? original.url.replace(
                scheme:
                    fallbackBase.scheme,
                host:
                    fallbackBase.host,
                port:
                    fallbackBase.hasPort
                        ? fallbackBase.port
                        : null,
              )
            : original.url;

    final request =
        http.Request(
      original.method,
      uri,
    );

    request.headers.addAll(
      original.headers,
    );

    request.headers.remove(
      'content-length',
    );

    request.followRedirects =
        original.followRedirects;

    request.maxRedirects =
        original.maxRedirects;

    request.persistentConnection =
        original.persistentConnection;

    request.bodyBytes =
        bodyBytes;

    return request;
  }

  static Uri _buildFallbackUri(
    Uri original,
  ) {
    final fallback =
        Uri.parse(
      AppConfig.backendFallbackBaseUrl,
    );

    return original.host ==
            AppConfig.backendPrimaryHost
        ? original.replace(
            scheme:
                fallback.scheme,
            host:
                fallback.host,
            port:
                fallback.hasPort
                    ? fallback.port
                    : null,
          )
        : original;
  }
}
