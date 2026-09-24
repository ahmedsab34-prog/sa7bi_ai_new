class MonetizationConfig {
  MonetizationConfig._();

  // ============================================================
  // APP DOWNLOAD
  // ============================================================

  static const String appDownloadUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev/download';

  // ============================================================
  // SHOPPING / AFFILIATE DESTINATIONS
  // ============================================================

  static const String amazonUrl =
      'https://www.amazon.eg/';

  static const String jumiaUrl =
      'https://www.jumia.com.eg/';

  static const String noonUrl =
      'https://www.noon.com/egypt-ar/';

  static const String facebookShopUrl =
      'https://www.facebook.com/marketplace/';

  // ============================================================
  // MASTER SWITCHES
  // ============================================================

  /// تشغيل قسم التسوق.
  static const bool affiliateEnabled = true;

  /// تشغيل AdMob بالكامل.
  static const bool admobEnabled = true;

  // ============================================================
  // HOME ADS
  // ============================================================

  /// إظهار بانر AdMob في الصفحة الرئيسية.
  static const bool homeBannerEnabled = true;

  /// السماح بإعلانات Interstitial.
  static const bool interstitialEnabled = true;

  /// السماح بإعلانات Rewarded.
  static const bool rewardedAdsEnabled = true;

  // ============================================================
  // AFFILIATE / SHOPPING CAROUSEL
  // ============================================================

  /// إظهار شريط المتاجر في الصفحة الرئيسية.
  static const bool affiliateCarouselEnabled = true;

  static const String affiliateCarouselTitle =
      'تسوق من صاحبي';

  static const String affiliateCarouselSubtitle =
      'اختار المتجر وافتحه مباشرة';

  // ============================================================
  // APP DOWNLOAD
  // ============================================================

  static const String downloadTitle =
      'حمّل صاحبي AI';

  static const String downloadSubtitle =
      'نسخة التطبيق الرسمية';

  // ============================================================
  // CREDITS / REWARDED ADS
  // ============================================================

  /// عدد الكريدت التي يحصل عليها المستخدم بعد
  /// إكمال إعلان Rewarded بنجاح.
  static const int rewardedCredits = 10;
