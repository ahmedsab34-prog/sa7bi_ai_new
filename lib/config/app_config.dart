/// الإعدادات العامة لتطبيق صاحبي AI.
///
/// هذا الملف مخصص للإعدادات العامة غير السرية.
/// ممنوع وضع أي API Keys أو كلمات مرور أو Secrets هنا.
///
/// معلومات الإصدار يتم حقنها أثناء GitHub Actions:
/// - SA7BI_APP_VERSION
/// - SA7BI_BUILD_NUMBER
/// - SA7BI_COMMIT_SHA
class AppConfig {
  AppConfig._();

  // ============================================================
  // APP
  // ============================================================

  static const String appName = 'صاحبي AI';

  static const String appNameEnglish = 'Sa7bi AI';

  static const String packageName =
      'com.example.sa7bi_ai_new';

  /// رقم الإصدار الذي يظهر للمستخدم.
  ///
  /// GitHub Actions يحقن القيمة الحقيقية أثناء البناء.
  static const String appVersion =
      String.fromEnvironment(
    'SA7BI_APP_VERSION',
    defaultValue: '1.0.1',
  );

  /// رقم Build الحقيقي الخاص بـGitHub Actions.
  static const String buildNumber =
      String.fromEnvironment(
    'SA7BI_BUILD_NUMBER',
    defaultValue: '0',
  );

  /// Commit الذي بُني منه الـAPK.
  static const String commitSha =
      String.fromEnvironment(
    'SA7BI_COMMIT_SHA',
    defaultValue: 'unknown',
  );

  /// هوية النسخة كاملة.
  static String get buildIdentity =>
      '$appVersion+$buildNumber ($commitSha)';

  // ============================================================
  // BACKEND
  // ============================================================

  /// الـWorker الأساسي.
  ///
  /// هذا يظل المصدر الرئيسي لكل خدمات التطبيق.
  static const String backendBaseUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  /// Worker احتياطي Stateless.
  ///
  /// لا يملك قاعدة بيانات أو Credits مستقلة.
  /// وظيفته فقط تمرير الطلب إلى الـWorker الأساسي.
  ///
  /// الهدف منه معالجة حالات فشل الوصول إلى hostname الأساسي
  /// من بعض الشبكات.
  static const String backendFallbackBaseUrl =
      'https://sa7bi-ai-new-fallback.ahmedsab34.workers.dev';

  /// اسم الـhost الأساسي.
  static const String backendPrimaryHost =
      'sa7bi-ai-new.ahmedsab34.workers.dev';

  /// اسم الـhost الاحتياطي.
  static const String backendFallbackHost =
      'sa7bi-ai-new-fallback.ahmedsab34.workers.dev';

  static const String backendHealthEndpoint =
      '$backendBaseUrl/health';

  static const String aiChatEndpoint =
      '$backendBaseUrl/v1/chat';

  static const String imageGenerationEndpoint =
      '$backendBaseUrl/v1/image';

  static const String newsEndpoint =
      '$backendBaseUrl/v1/news';

  static const String shortsEndpoint =
      '$backendBaseUrl/v1/shorts';

  static const String audioSearchEndpoint =
      '$backendBaseUrl/v1/audio/search-v4';

  static const String quranEndpoint =
      '$backendBaseUrl/v1/audio/quran';

  static const String radioCountriesEndpoint =
      '$backendBaseUrl/v1/radio/countries';

  static const String radioStationsEndpoint =
      '$backendBaseUrl/v1/radio/stations';

  /// هذا الرابط هو بوابة تنزيل الـAPK الحقيقي.
  static const String downloadEndpoint =
      '$backendBaseUrl/download';

  static const String monetizationEndpoint =
      '$backendBaseUrl/v1/monetization';

  // ============================================================
  // NETWORK LIMITS
  // ============================================================

  /// عدد محاولات الطلب على مستوى الخدمات التي تستخدم
  /// هذا الإعداد.
  static const int maximumNetworkAttempts = 3;

  static const int networkTimeoutSeconds = 45;

  static const int chatTimeoutSeconds = 90;

  static const int imageTimeoutSeconds = 120;

  // ============================================================
  // CHAT
  // ============================================================

  static const int maximumChatMessages = 80;

  static const int maximumContextMessages = 8;

  static const int maximumMessageCharacters = 12000;

  // ============================================================
  // NEWS
  // ============================================================

  static const int newsBeforeShorts = 5;

  static const int maximumNewsItems = 30;

  static const int maximumShortsItems = 20;

  // ============================================================
  // MEDIA
  // ============================================================

  static const int maximumImageSizeMb = 5;

  static const int maximumVideoSizeMb = 50;

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

  static const bool creditsEnabled = true;

  static const bool imageGenerationEnabled = true;

  static const bool imageAnalysisEnabled = true;

  static const bool videoAnalysisEnabled = true;

  static const bool khalasanaEnabled = true;

  static const bool newsEnabled = true;

  static const bool shortsEnabled = true;

  static const bool audioEnabled = true;

  static const bool radioEnabled = true;

  // ============================================================
  // SECURITY
  // ============================================================

  static const bool clientSideApiKeysAllowed = false;

  static const bool aiMustUseBackend = true;

  // ============================================================
  // URL HELPERS
  // ============================================================

  /// يبني رابطًا على الـWorker الأساسي.
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

  /// يبني رابطًا على الـWorker الاحتياطي.
  static String buildFallbackBackendUrl(
    String path,
  ) {
    final cleaned = path.trim();

    if (cleaned.isEmpty) {
      return backendFallbackBaseUrl;
    }

    if (cleaned.startsWith('/')) {
      return '$backendFallbackBaseUrl$cleaned';
    }

    return '$backendFallbackBaseUrl/$cleaned';
  }
}
