import 'dart:io';

import 'package:cronet_http/cronet_http.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// بوابة الشبكة الموحدة لتطبيق صاحبي AI.
///
/// Android:
///   Cronet -> HTTPS -> Backend
///
/// المنطق الحالي للتطبيق لا يحتاج معرفة نوع HTTP client.
/// أي استخدام لـ package:http عبر:
///   http.get(...)
///   http.post(...)
///   Client()
/// داخل Zone التطبيق يمر من خلال هذا العميل.
///
/// الهدف:
/// - التخلص من مسار IOClient الافتراضي كمصدر وحيد للاتصال.
/// - استخدام Network Stack الخاص بـAndroid/Cronet.
/// - دعم HTTP/2 وHTTP/3/QUIC.
/// - إبقاء hostname الحقيقي وعدم استخدام Cloudflare IP مباشرة.
/// - عدم استخدام Socket.connect أو connectionFactory.
/// - عدم إجبار IPv4 أو IPv6.
/// - عدم وضع أي API key هنا.
class Sa7biNetworkClient {
  Sa7biNetworkClient._();

  static const String userAgent =
      'Sa7biAI-Mobile/1.0';

  static const int cacheSizeBytes =
      2 * 1024 * 1024;

  static http.Client? _client;

  static bool _isCronet = false;

  /// العميل الموحد.
  static http.Client get client {
    final existing = _client;

    if (existing != null) {
      return existing;
    }

    final created = _createClient();

    _client = created;

    return created;
  }

  /// هل التطبيق يعمل حاليًا باستخدام Cronet؟
  static bool get isCronet => _isCronet;

  /// اسم طبقة الشبكة المستخدمة.
  static String get transportName {
    if (_isCronet) {
      return 'CRONET_ANDROID';
    }

    return 'DART_IO_FALLBACK';
  }

  /// Factory تستخدم مع package:http runWithClient.
  ///
  /// مهم:
  /// نعيد نفس العميل حتى لا يتم إنشاء CronetEngine جديد
  /// لكل طلب.
  static http.Client factory() {
    return client;
  }

  /// إنشاء العميل.
  static http.Client _createClient() {
    if (Platform.isAndroid) {
      final engine = CronetEngine.build(
        cacheMode: CacheMode.memory,
        cacheMaxSize: cacheSizeBytes,
        userAgent: userAgent,

        // نستخدم HTTP/2 وQUIC المتاحين في Cronet.
        enableHttp2: true,
        enableQuic: true,

        // Brotli يقلل حجم بعض استجابات JSON.
        enableBrotli: true,

        // مهم:
        // في الإصدار الحديث من cronet_http يتم توفير
        // إعدادات DNS الخاصة بـCronet.
        //
        // إجبار Cronet على استخدام system resolver
        // يمنع بعض مشاكل DNS الداخلية مع QUIC.
        useBuiltInDnsResolver: false,

        // السماح بالاستفادة من DNS قديم عند حدوث مشكلة
        // مؤقتة في إعادة الحل.
        enableStaleDns: true,
        useStaleOnNameNotResolved: true,
        allowCrossNetworkUsage: true,
      );

      _isCronet = true;

      return CronetClient.fromCronetEngine(
        engine,
        closeEngine: true,
      );
    }

    // fallback للمنصات غير Android.
    _isCronet = false;

    final ioClient = HttpClient()
      ..userAgent = userAgent
      ..connectionTimeout =
          const Duration(seconds: 30);

    return IOClient(ioClient);
  }

  /// إغلاق العميل عند الحاجة.
  ///
  /// لا يتم استدعاؤه أثناء تشغيل التطبيق الطبيعي.
  /// موجود للاختبارات وإدارة lifecycle مستقبلًا.
  static void close() {
    final existing = _client;

    _client = null;

    if (existing != null) {
      existing.close();
    }

    _isCronet = false;
  }
}
