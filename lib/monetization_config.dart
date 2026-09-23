class MonetizationConfig {
  MonetizationConfig._();

  // ============================================================
  // APP DOWNLOAD
  // ============================================================

  static const String appDownloadUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev/download';

  // ============================================================
  // AFFILIATE / SHOPPING LINKS
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
  // MONETIZATION SWITCHES
  // ============================================================

  /// تشغيل روابط التسوق والـ Affiliate.
  static const bool affiliateEnabled = true;

  /// تشغيل AdMob.
  static const bool admobEnabled = true;

  // ============================================================
  // HOME ADS
  // ============================================================

  /// إظهار بانر AdMob في الصفحة الرئيسية.
  static const bool homeBannerEnabled = true;

  /// السماح بإعلانات Interstitial.
  static const bool interstitialEnabled = true;

  /// السماح بالإعلانات المدفوعة Rewarded.
  static const bool rewardedAdsEnabled = true;

  // ============================================================
  // AFFILIATE CAROUSEL
  // ============================================================

  /// إظهار شريط التسوق الأفقي في الصفحة الرئيسية.
  static const bool affiliateCarouselEnabled = true;

  /// عنوان قسم التسوق.
  static const String affiliateCarouselTitle =
      'تسوق من صاحبي';

  /// وصف قصير أسفل العنوان.
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
  // CREDIT / MONETIZATION SETTINGS
  // ============================================================

  static const int rewardedCredits =
      5;
}
