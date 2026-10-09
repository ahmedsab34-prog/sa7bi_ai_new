
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
/// مهم:
/// - لا يوجد IP ثابت.
/// - لا يوجد Socket.connect.
/// - لا يوجد إجبار IPv4 أو IPv6.
/// - لا توجد API Keys.
/// - كل خدمات package:http تستفيد من نفس البوابة.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent = 'Sa7biAI-Mobile/1.0';

  static const int cacheSizeBytes = 2 * 1024 * 1024;

  static const Duration failoverTimeout =
      Duration(seconds: 8);

  static http.Client? _client;
  static http.Client? _fallbackClient;

  static bool _isCronet = false;

  static http.Client get client {
    final existing = _client;

    if (existing != null) {
      return existing;
    }

    final created = _createClient();
    _client = created;

    return created;
  }

  static bool get isCronet => _isCronet;

  static String get transportName {
    if (_isCronet) {
      return 'CRONET_ANDROID_WITH_IO_FAILOVER';
    }

    return 'DART_IO_FALLBACK';
  }

  static bool get failoverEnabled => true;

  static http.Client factory() => client;

  // ============================================================
  // CLIENT CREATION
  // ============================================================

  static http.Client _createClient() {
    if (Platform.isAndroid) {
      final primary = _createCronetClient();

      // مسار نقل مستقل عن Cronet.
      // إذا تعذر اتصال Cronet، نجرب Dart IO.
      final fallback = _createIoClient();

      _fallbackClient = fallback;
      _isCronet = true;

      return _FailoverClient(
        primary: primary,
        fallback: fallback,
        fallbackTimeout: failoverTimeout,
      );
    }

    _isCronet = false;

    final primary = _createIoClient();
    final fallback = _createIoClient();

    _fallbackClient = fallback;

    return _FailoverClient(
      primary: primary,
      fallback: fallback,
      fallbackTimeout: failoverTimeout,
    );
  }

  // ============================================================
  // CRONET PRIMARY
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
  // DART IO TRANSPORT
  // ============================================================

  static http.Client _createIoClient() {
    final ioClient = HttpClient()
      ..userAgent = userAgent
      ..connectionTimeout = const Duration(seconds: 30);

    return IOClient(ioClient);
  }

  // ============================================================
  // CLOSE
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
// FAILOVER CLIENT
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
    final bodyBytes =
        await request.finalize().toBytes();

    final primaryRequest = _cloneRequest(
      request,
      bodyBytes,
      AppConfig.backendBaseUrl,
    );

    try {
      return await primary
          .send(primaryRequest)
          .timeout(fallbackTimeout);
    } on TimeoutException {
      return _sendFallback(request, bodyBytes);
    } on SocketException {
      return _sendFallback(request, bodyBytes);
    } on http.ClientException {
      return _sendFallback(request, bodyBytes);
    } on IOException {
      return _sendFallback(request, bodyBytes);
    }
  }

  Future<http.StreamedResponse> _sendFallback(
    http.BaseRequest original,
    List<int> bodyBytes,
  ) async {
    final fallbackRequest = _cloneRequest(
      original,
      bodyBytes,
      AppConfig.backendFallbackBaseUrl,
    );

    return fallback.send(fallbackRequest);
  }

  static http.Request _cloneRequest(
    http.BaseRequest original,
    List<int> bodyBytes,
    String baseUrl,
  ) {
    final base = Uri.parse(baseUrl);

    final uri =
        original.url.host == AppConfig.backendPrimaryHost
            ? original.url.replace(
                scheme: base.scheme,
                host: base.host,
                port: base.hasPort ? base.port : null,
              )
            : original.url;

    final request = http.Request(
      original.method,
      uri,
    );

    request.headers.addAll(original.headers);
    request.headers.remove('content-length');

    request.followRedirects = original.followRedirects;
    request.maxRedirects = original.maxRedirects;
    request.persistentConnection =
        original.persistentConnection;
    request.bodyBytes = bodyBytes;

    return request;
  }
}
