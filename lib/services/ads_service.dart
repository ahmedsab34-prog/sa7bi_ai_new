import 'package:shared_preferences/shared_preferences.dart';

import '../config/credits_config.dart';

/// خدمة الإعلانات في صاحبي AI.
///
/// هذه الطبقة هي المكان الموحد لكل ما يتعلق بالإعلانات:
/// - Banner
/// - Interstitial
/// - Rewarded
///
/// حاليًا لا تعتمد على google_mobile_ads حتى لا نضيف dependency
/// جديدة أثناء مرحلة بناء البنية الأساسية.
///
/// عند تفعيل AdMob لاحقًا، سنضع كود الشبكة هنا بدل توزيعه
/// داخل ChatScreen وmain.dart وباقي الشاشات.
///
/// بهذه الطريقة لن نحتاج لإعادة تصميم التطبيق عند إضافة الإعلانات.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  // ============================================================
  // Storage
  // ============================================================

  static const String _interstitialCounterKey =
      'sa7bi_interstitial_counter';

  static const String _bannerEnabledKey =
      'sa7bi_banner_enabled';

  // ============================================================
  // State
  // ============================================================

  SharedPreferences? _preferences;

  bool _initialized = false;

  int _interstitialCounter = 0;

  bool _bannerEnabled = true;

  // ============================================================
  // Getters
  // ============================================================

  bool get isInitialized => _initialized;

  bool get bannerEnabled => _bannerEnabled;

  int get interstitialCounter =>
      _interstitialCounter;

  // ============================================================
  // Initialization
  // ============================================================

  /// تهيئة خدمة الإعلانات.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _preferences =
        await SharedPreferences.getInstance();

    _interstitialCounter =
        _preferences!.getInt(
              _interstitialCounterKey,
            ) ??
            0;

    _bannerEnabled =
        _preferences!.getBool(
              _bannerEnabledKey,
            ) ??
            true;

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ============================================================
  // Banner
  // ============================================================

  /// هل الـBanner مسموح بالظهور؟
  ///
  /// لاحقًا سيتم ربطها بحالة AdMob الفعلية.
  Future<bool> shouldShowBanner() async {
    await _ensureInitialized();

    return _bannerEnabled;
  }

  /// تشغيل/إيقاف ظهور الـBanner من إعدادات التطبيق.
  Future<void> setBannerEnabled(
    bool enabled,
  ) async {
    await _ensureInitialized();

    _bannerEnabled = enabled;

    await _preferences!.setBool(
      _bannerEnabledKey,
      enabled,
    );
  }

  // ============================================================
  // Interstitial
  // ============================================================

  /// تسجيل عملية يمكن بعدها إظهار Interstitial.
  ///
  /// القيمة المرجعة تحدد هل وصلنا للنقطة التي يُسمح فيها
  /// بعرض إعلان بيني.
  ///
  /// لا تعرض الإعلان من داخل هذه الدالة.
  /// هي فقط تدير التوقيت والمنطق.
  Future<bool> registerInterstitialOpportunity({
    int every = 5,
  }) async {
    await _ensureInitialized();

    if (every <= 0) {
      return false;
    }

    _interstitialCounter++;

    await _preferences!.setInt(
      _interstitialCounterKey,
      _interstitialCounter,
    );

    if (_interstitialCounter < every) {
      return false;
    }

    _interstitialCounter = 0;

    await _preferences!.setInt(
      _interstitialCounterKey,
      0,
    );

    return true;
  }

  /// إعادة عداد الإعلانات البينية.
  Future<void> resetInterstitialCounter() async {
    await _ensureInitialized();

    _interstitialCounter = 0;

    await _preferences!.setInt(
      _interstitialCounterKey,
      0,
    );
  }

  // ============================================================
  // Rewarded Ads
  // ============================================================

  /// هل مكافأة الإعلان متاحة منطقيًا؟
  ///
  /// هذه الدالة لا تعني أن إعلان AdMob تم تحميله.
  /// هي فقط تتحقق من إمكانية إعطاء المكافأة حسب إعدادات Credits.
  Future<bool> canGiveRewardedCredits() async {
    await _ensureInitialized();

    return CreditsServiceAvailability.canReward;
  }

  /// عدد الـCredits الذي سيحصل عليه المستخدم بعد إعلان مكافأة.
  int get rewardedCredits {
    return CreditsConfig.rewardedAdCredits;
  }

  /// الحد اليومي للإعلانات المكافِئة.
  int get rewardedDailyLimit {
    return CreditsConfig.rewardedAdDailyLimit;
  }

  /// تسجيل نجاح مشاهدة إعلان مكافأة.
  ///
  /// لا تقوم هذه الدالة بإضافة الرصيد بنفسها.
  /// إضافة الرصيد يجب أن تمر عبر CreditsService بعد التأكد
  /// من أن شبكة الإعلانات أعادت reward فعلية.
  Future<int> getRewardAmount() async {
    await _ensureInitialized();

    return CreditsConfig.rewardedAdCredits;
  }

  // ============================================================
  // Ad lifecycle placeholders
  // ============================================================

  /// تحميل Banner.
  ///
  /// سيُنفذ فعليًا بعد إضافة google_mobile_ads.
  Future<void> loadBanner() async {
    await _ensureInitialized();

    // يتم تفعيل التحميل الفعلي هنا في مرحلة AdMob.
  }

  /// تحميل Interstitial.
  Future<void> loadInterstitial() async {
    await _ensureInitialized();

    // يتم تفعيل التحميل الفعلي هنا في مرحلة AdMob.
  }

  /// تحميل Rewarded Ad.
  Future<void> loadRewarded() async {
    await _ensureInitialized();

    // يتم تفعيل التحميل الفعلي هنا في مرحلة AdMob.
  }

  /// إخفاء/تنظيف موارد الإعلانات.
  Future<void> dispose() async {
    // لا توجد حاليًا كائنات AdMob تحتاج إلى التخلص منها.
    //
    // عند تفعيل google_mobile_ads سيتم تنظيف:
    // BannerAd
    // InterstitialAd
    // RewardedAd
  }
}

/// حالة بسيطة لتحديد إمكانية استخدام Rewarded Ads.
///
/// تم فصلها عن شبكة الإعلانات نفسها حتى لا يصبح التطبيق
/// مرتبطًا بمكتبة AdMob في كل مكان.
class CreditsServiceAvailability {
  CreditsServiceAvailability._();

  static bool canReward = true;
}
