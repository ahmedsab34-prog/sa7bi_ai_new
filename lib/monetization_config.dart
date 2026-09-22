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

  /// Affiliate links are enabled.
  static const bool affiliateEnabled = true;

  /// AdMob is enabled.
  ///
  /// Actual AdMob initialization and loading are handled by
  /// AdsService.
  static const bool admobEnabled = true;

  // ============================================================
  // GENERAL SETTINGS
  // ============================================================

  /// Show the main banner on the Home screen.
  static const bool homeBannerEnabled = true;

  /// Allow interstitial ads where appropriate.
  static const bool interstitialEnabled = true;

  /// Allow rewarded ads for earning credits.
  static const bool rewardedAdsEnabled = true;
}
