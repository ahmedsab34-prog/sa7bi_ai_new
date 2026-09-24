/// الإعدادات العامة لتطبيق صاحبي AI.
///
/// هذا الملف مخصص للإعدادات العامة غير السرية.
/// لا تضع هنا أي API Keys أو كلمات مرور أو Secrets.
class AppConfig {
  AppConfig._();

  // ============================================================
  // معلومات التطبيق
  // ============================================================

  static const String appName = 'صاحبي AI';

  static const String appNameEnglish = 'Sa7bi AI';

  static const String packageName =
      'com.example.sa7bi_ai_new';

  static const String appVersion = '1.0.0';

  // ============================================================
  // Backend
  // ============================================================

  /// عنوان الـCloudflare Worker الخاص بالتطبيق.
  ///
  /// مفتاح OpenAI لا يوجد هنا ولا داخل التطبيق.
  /// المفتاح محفوظ في Cloudflare Secret.
  static const String backendBaseUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  /// Endpoint المحادثة مع الذكاء الاصطناعي.
  static const String aiChatEndpoint =
      '$backendBaseUrl/v1/chat';

  /// Endpoint إنشاء الصور.
  static const String imageGenerationEndpoint =
      '$backendBaseUrl/v1/image';

  /// Endpoint الأخبار.
  static const String newsEndpoint =
      '$backendBaseUrl/v1/news';

  /// Endpoint المقاطع القصيرة.
  static const String shortsEndpoint =
      '$backendBaseUrl/v1/shorts';

  /// رابط تحميل التطبيق للمشاركة.
  static const String downloadEndpoint =
      '$backendBaseUrl/download';

  // ============================================================
  // General limits
  // ============================================================

  /// أقصى عدد رسائل يتم الاحتفاظ بها في تاريخ كل شات.
  static const int maximumChatMessages = 80;

  /// أقصى عدد عناصر يمكن عرضه في بعض القوائم الطويلة.
  static const int maximumListItems = 100;

  /// مدة انتظار طلبات الـBackend بالثواني.
  static const int networkTimeoutSeconds = 45;

  /// مدة انتظار أطول لعمليات إنشاء الصور.
  static const int imageTimeoutSeconds = 90;

  // ============================================================
  // Home
  // ============================================================

  /// عدد الأخبار قبل ظهور شريط الـShorts.
  static const int newsBeforeShorts = 5;

  /// عدد الأخبار التي نحاول عرضها في الصفحة الرئيسية.
  static const int maximumNewsItems = 30;

  /// عدد المقاطع القصيرة التي يمكن تحميلها في الدفعة.
  static const int maximumShortsItems = 20;

  // ============================================================
  // Chat
  // ============================================================

  /// عدد الرسائل التي نرسلها كسياق مختصر للـBackend.
  ///
  /// لا يعني ذلك حذف التاريخ المحلي.
  /// التاريخ المحلي يظل محفوظًا للمستخدم.
  static const int maximumContextMessages = 20;

  /// أقصى طول تقريبي للنص المرسل في رسالة واحدة.
  static const int maximumMessageCharacters = 12000;

  // ============================================================
  // Media
  // ============================================================

  /// أقصى حجم منطقي للصورة قبل إرسالها للـBackend بالـMB.
  static const int maximumImageSizeMb = 10;

  /// أقصى حجم منطقي للفيديو بالـMB.
  static const int maximumVideoSizeMb = 50;

  /// أقصى عدد لقطات يتم استخراجها من الفيديو للتحليل.
  static const int maximumVideoFrames = 4;

  // ============================================================
  // Audio
  // ============================================================

  /// اسم قناة الصوت في Android.
  static const String audioChannelId =
      'com.sa7bi.ai.audio';

  static const String audioChannelName =
      'صحبي AI - الصوت';

  // ============================================================
  // Profile
  // ============================================================

  /// اسم افتراضي للمستخدم عند عدم اختيار اسم.
  static const String defaultUserName =
      'صاحبي';

  // ============================================================
  // Feature flags
  // ============================================================

  /// تشغيل نظام Credits.
  static const bool creditsEnabled = true;

  /// السماح بإنشاء الصور.
  static const bool imageGenerationEnabled = true;

  /// السماح بتحليل الصور.
  static const bool imageAnalysisEnabled = true;

  /// تشغيل تحليل الفيديو.
  ///
  /// التحليل يتم عن طريق استخراج لقطات من الفيديو
  /// ثم إرسال هذه اللقطات للذكاء الاصطناعي.
  static const bool videoAnalysisEnabled = true;

  /// تشغيل Khalasana.
  static const bool khalasanaEnabled = true;

  /// تشغيل الأخبار.
  static const bool newsEnabled = true;

  /// تشغيل المقاطع القصيرة.
  static const bool shortsEnabled = true;

  /// تشغيل الصوت.
  static const bool audioEnabled = true;

  // ============================================================
  // Safety / networking
  // ============================================================

  /// عدم السماح للواجهة بإرسال API Keys مباشرة.
  static const bool clientSideApiKeysAllowed = false;

  /// كل طلبات الذكاء الاصطناعي تمر عبر الـBackend.
  static const bool aiMustUseBackend = true;

  // ============================================================
  // Helpers
  // ============================================================

  /// تكوين رابط Endpoint مع مسار إضافي.
  static String buildBackendUrl(
    String path,
  ) {
    final cleaned = path.trim();

    if (cleaned.isEmpty) {
      return backendBaseUrl;
    }

    if (cleaned.startsWith('/')) {
      return '$backendBaseUrl$cleaned';
    }

    return '$backendBaseUrl/$cleaned';
  }
}
