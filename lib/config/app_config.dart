/// الإعدادات العامة لتطبيق صاحبي AI.
///
/// هذا الملف مخصص للإعدادات العامة غير السرية.
/// لا تضع هنا أي API Keys أو كلمات مرور أو Secrets.
class AppConfig {
  AppConfig._();

  // ============================================================
  // APP
  // ============================================================

  static const String appName = 'صاحبي AI';

  static const String appNameEnglish = 'Sa7bi AI';

  static const String packageName =
      'com.example.sa7bi_ai_new';

  static const String appVersion = '1.0.0';

  // ============================================================
  // BACKEND
  // ============================================================

  /// Cloudflare Worker الخاص بتطبيق صاحبي AI.
  ///
  /// مهم:
  /// لا يوجد أي OpenAI API Key داخل التطبيق.
  /// المفتاح محفوظ كـSecret داخل Cloudflare Worker.
  static const String backendBaseUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  /// فحص الاتصال الأساسي بالـWorker.
  static const String backendHealthEndpoint =
      '$backendBaseUrl/health';

  /// المحادثة.
  static const String aiChatEndpoint =
      '$backendBaseUrl/v1/chat';

  /// إنشاء الصور.
  static const String imageGenerationEndpoint =
      '$backendBaseUrl/v1/image';

  /// الأخبار.
  static const String newsEndpoint =
      '$backendBaseUrl/v1/news';

  /// المقاطع القصيرة.
  static const String shortsEndpoint =
      '$backendBaseUrl/v1/shorts';

  /// البحث الصوتي.
  static const String audioSearchEndpoint =
      '$backendBaseUrl/v1/audio/search-v4';

  /// بيانات القرآن.
  static const String quranEndpoint =
      '$backendBaseUrl/v1/audio/quran';

  /// دول الراديو.
  static const String radioCountriesEndpoint =
      '$backendBaseUrl/v1/radio/countries';

  /// محطات الراديو.
  static const String radioStationsEndpoint =
      '$backendBaseUrl/v1/radio/stations';

  /// رابط تحميل التطبيق.
  static const String downloadEndpoint =
      '$backendBaseUrl/download';

  // ============================================================
  // NETWORK LIMITS
  // ============================================================

  /// أقصى عدد محاولات لطلبات الـBackend.
  static const int maximumNetworkAttempts = 3;

  /// مهلة الاتصال الأولية.
  static const int networkTimeoutSeconds = 45;

  /// مهلة المحادثة.
  static const int chatTimeoutSeconds = 90;

  /// مهلة تحليل الصور.
  static const int imageTimeoutSeconds = 120;

  // ============================================================
  // CHAT
  // ============================================================

  /// أقصى عدد رسائل محفوظة محليًا في الشات.
  static const int maximumChatMessages = 80;

  /// أقصى عدد رسائل يتم إرسالها كسياق للـBackend.
  static const int maximumContextMessages = 8;

  /// أقصى طول للرسالة الواحدة.
  static const int maximumMessageCharacters = 12000;

  // ============================================================
  // NEWS
  // ============================================================

  /// بعد كل خمسة أخبار يظهر شريط المقاطع القصيرة.
  static const int newsBeforeShorts = 5;

  /// أقصى عدد أخبار نحاول عرضه.
  static const int maximumNewsItems = 30;

  /// أقصى عدد مقاطع قصيرة في الدفعة.
  static const int maximumShortsItems = 20;

  // ============================================================
  // MEDIA
  // ============================================================

  /// أقصى حجم للصورة التي يسمح التطبيق بإرسالها.
  static const int maximumImageSizeMb = 5;

  /// أقصى حجم منطقي للفيديو قبل المعالجة.
  static const int maximumVideoSizeMb = 50;

  /// عدد اللقطات المستخدمة لتحليل الفيديو.
  static const int maximumVideoFrames = 4;

  // ============================================================
  // AUDIO
  // ============================================================

  static const String audioChannelId =
      'com.sa7bi.ai.audio';

  static const String audioChannelName =
      'صاحبي AI - الصوت';

  // ============================================================
  // PROFILE
  // ============================================================

  static const String defaultUserName =
      'صاحبي';

  // ============================================================
  // FEATURES
  // ============================================================

  /// نظام الـCredits.
  static const bool creditsEnabled = true;

  /// إنشاء الصور.
  static const bool imageGenerationEnabled = true;

  /// تحليل الصور.
  static const bool imageAnalysisEnabled = true;

  /// تحليل الفيديو عن طريق لقطات.
  static const bool videoAnalysisEnabled = true;

  /// بوابة فضفضة / Khalasana.
  static const bool khalasanaEnabled = true;

  /// الأخبار.
  static const bool newsEnabled = true;

  /// المقاطع القصيرة.
  static const bool shortsEnabled = true;

  /// الصوت.
  static const bool audioEnabled = true;

  /// الراديو.
  static const bool radioEnabled = true;

  // ============================================================
  // SECURITY
  // ============================================================

  /// ممنوع وضع مفاتيح API داخل التطبيق.
  static const bool clientSideApiKeysAllowed = false;

  /// كل عمليات الذكاء الاصطناعي تمر عبر الـBackend.
  static const bool aiMustUseBackend = true;

  // ============================================================
  // URL HELPERS
  // ============================================================

  /// إنشاء رابط Backend من مسار.
  ///
  /// مثال:
  /// buildBackendUrl('/health')
  ///
  /// النتيجة:
  /// https://sa7bi-ai-new.ahmedsab34.workers.dev/health
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
