import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/credits_config.dart';

/// خدمة الإعلانات المركزية في صاحبي AI.
///
/// مسؤوليتها:
/// - تهيئة AdMob.
/// - Banner Ads.
/// - Interstitial Ads.
/// - Rewarded Ads.
/// - عداد الـInterstitial.
/// - حالة Banner من الإعدادات.
///
/// ملاحظات مهمة:
/// - لا يتم عرض أي إعلان تلقائيًا عند تشغيل التطبيق.
/// - فشل الإعلان لا يجب أن يغلق التطبيق.
/// - Rewarded لا تعتبر مكتملة إلا بعد onUserEarnedReward.
/// - الـAd IDs الحالية هي IDs الإنتاج الخاصة بالتطبيق.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  // ============================================================
  // AdMob Production IDs
  // ============================================================

  static const String appId =
      'ca-app-pub-9077658292229374~9135705635';

  static const String bannerAdUnitId =
      'ca-app-pub-9077658292229374/1672148581';

  static const String interstitialAdUnitId =
      'ca-app-pub-9077658292229374/9768287146';

  static const String rewardedAdUnitId =
      'ca-app-pub-9077658292229374/4621745555';

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

  bool _adMobInitialized = false;

  bool _bannerEnabled = true;

  int _interstitialCounter = 0;

  BannerAd? _bannerAd;

  InterstitialAd? _interstitialAd;

  RewardedAd? _rewardedAd;

  bool _isLoadingInterstitial = false;

  bool _isLoadingRewarded = false;

  // ============================================================
  // Getters
  // ============================================================

  bool get isInitialized => _initialized;

  bool get isAdMobInitialized => _adMobInitialized;

  bool get bannerEnabled => _bannerEnabled;

  int get interstitialCounter => _interstitialCounter;

  BannerAd? get bannerAd => _bannerAd;

  bool get isBannerLoaded => _bannerAd != null;

  bool get isInterstitialLoaded => _interstitialAd != null;

  bool get isRewardedLoaded => _rewardedAd != null;

  int get rewardedCredits =>
      CreditsConfig.rewardedAdCredits;

  int get rewardedDailyLimit =>
      CreditsConfig.rewardedAdDailyLimit;

  // ============================================================
  // Initialization
  // ============================================================

  /// تهيئة التخزين وAdMob.
  ///
  /// لا يتم عرض أي إعلان هنا.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
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

      try {
        await MobileAds.instance.initialize();
        _adMobInitialized = true;
      } catch (_) {
        // فشل AdMob لا يمنع تشغيل التطبيق.
        _adMobInitialized = false;
      }

      _initialized = true;
    } catch (_) {
      // حتى لو حدث خطأ في SharedPreferences،
      // لا نسمح لخدمة الإعلانات بإيقاف التطبيق.
      _initialized = true;
      _adMobInitialized = false;
    }
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
  Future<bool> shouldShowBanner() async {
    await _ensureInitialized();

    return _bannerEnabled && _adMobInitialized;
  }

  /// تشغيل/إيقاف الـBanner من إعدادات التطبيق.
  Future<void> setBannerEnabled(
    bool enabled,
  ) async {
    await _ensureInitialized();

    _bannerEnabled = enabled;

    try {
      await _preferences?.setBool(
        _bannerEnabledKey,
        enabled,
      );
    } catch (_) {
      // لا نوقف التطبيق بسبب خطأ تخزين إعداد الإعلان.
    }

    if (!enabled) {
      disposeBanner();
    }
  }

  /// تحميل Banner Ad.
  ///
  /// يتم استدعاؤها من الشاشة التي تريد عرض الـBanner فيها.
  Future<BannerAd?> loadBanner({
    AdSize adSize = AdSize.banner,
  }) async {
    await _ensureInitialized();

    if (!_adMobInitialized ||
        !_bannerEnabled) {
      return null;
    }

    disposeBanner();

    final completer =
        Completer<BannerAd?>();

    late final BannerAd banner;

    banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) {
            completer.complete(
              ad as BannerAd,
            );
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      ),
    );

    try {
      await banner.load();

      if (!completer.isCompleted) {
        completer.complete(banner);
      }
    } catch (_) {
      banner.dispose();

      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    final loadedBanner =
        await completer.future;

    if (loadedBanner != null) {
      _bannerAd = loadedBanner;
    }

    return loadedBanner;
  }

  /// تنظيف Banner فقط.
  void disposeBanner() {
    try {
      _bannerAd?.dispose();
    } catch (_) {}

    _bannerAd = null;
  }

  // ============================================================
  // Interstitial
  // ============================================================

  /// تسجيل فرصة لعرض Interstitial.
  ///
  /// لا يعرض الإعلان بنفسه.
  ///
  /// مثال:
  /// بعد كل 5 عمليات مناسبة:
  /// true → أصبح مسموحًا بمحاولة عرض الإعلان.
  Future<bool> registerInterstitialOpportunity({
    int every = 5,
  }) async {
    await _ensureInitialized();

    if (every <= 0) {
      return false;
    }

    _interstitialCounter++;

    try {
      await _preferences?.setInt(
        _interstitialCounterKey,
        _interstitialCounter,
      );
    } catch (_) {}

    if (_interstitialCounter < every) {
      return false;
    }

    _interstitialCounter = 0;

    try {
      await _preferences?.setInt(
        _interstitialCounterKey,
        0,
      );
    } catch (_) {}

    return true;
  }

  /// إعادة عداد Interstitial.
  Future<void> resetInterstitialCounter() async {
    await _ensureInitialized();

    _interstitialCounter = 0;

    try {
      await _preferences?.setInt(
        _interstitialCounterKey,
        0,
      );
    } catch (_) {}
  }

  /// تحميل Interstitial.
  Future<bool> loadInterstitial() async {
    await _ensureInitialized();

    if (!_adMobInitialized ||
        _isLoadingInterstitial) {
      return _interstitialAd != null;
    }

    if (_interstitialAd != null) {
      return true;
    }

    _isLoadingInterstitial = true;

    final completer =
        Completer<bool>();

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback:
            InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;

            ad.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent:
                  (ad) {
                ad.dispose();
                _interstitialAd = null;

                // تحميل الإعلان التالي مسبقًا.
                unawaited(
                  loadInterstitial(),
                );
              },
              onAdFailedToShowFullScreenContent:
                  (ad, error) {
                ad.dispose();
                _interstitialAd = null;

                unawaited(
                  loadInterstitial(),
                );
              },
            );

            if (!completer.isCompleted) {
              completer.complete(true);
            }
          },
          onAdFailedToLoad: (error) {
            _interstitialAd = null;

            if (!completer.isCompleted) {
              completer.complete(false);
            }
          },
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    } finally {
      _isLoadingInterstitial = false;
    }

    return completer.future;
  }

  /// عرض Interstitial إذا كان محمّلًا.
  ///
  /// ترجع true إذا تم بدء محاولة العرض.
  Future<bool> showInterstitial() async {
    await _ensureInitialized();

    if (!_adMobInitialized) {
      return false;
    }

    final ad = _interstitialAd;

    if (ad == null) {
      await loadInterstitial();
      return false;
    }

    _interstitialAd = null;

    try {
      ad.show();
      return true;
    } catch (_) {
      try {
        ad.dispose();
      } catch (_) {}

      unawaited(
        loadInterstitial(),
      );

      return false;
    }
  }

  // ============================================================
  // Rewarded Ads
  // ============================================================

  /// هل يمكن منطقيًا استخدام Rewarded Credits؟
  ///
  /// هذه لا تعني أن إعلان AdMob محمّل.
  Future<bool> canGiveRewardedCredits() async {
    await _ensureInitialized();

    return CreditsServiceAvailability.canReward;
  }

  /// عدد الـCredits الخاصة بالإعلان.
  Future<int> getRewardAmount() async {
    await _ensureInitialized();

    return CreditsConfig.rewardedAdCredits;
  }

  /// تحميل Rewarded Ad.
  Future<bool> loadRewarded() async {
    await _ensureInitialized();

    if (!_adMobInitialized ||
        _isLoadingRewarded) {
      return _rewardedAd != null;
    }

    if (_rewardedAd != null) {
      return true;
    }

    _isLoadingRewarded = true;

    final completer =
        Completer<bool>();

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback:
            RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;

            if (!completer.isCompleted) {
              completer.complete(true);
            }
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;

            if (!completer.isCompleted) {
              completer.complete(false);
            }
          },
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    } finally {
      _isLoadingRewarded = false;
    }

    return completer.future;
  }

  /// عرض Rewarded Ad.
  ///
  /// النتيجة:
  /// - true = المستخدم حصل فعلًا على Reward.
  /// - false = الإعلان لم يُعرض أو لم تكتمل المكافأة.
  ///
  /// مهم:
  /// لا يتم إعطاء Credits إلا داخل
  /// onUserEarnedReward.
  Future<bool> showRewarded({
    void Function(int amount)? onRewardEarned,
  }) async {
    await _ensureInitialized();

    if (!_adMobInitialized ||
        !CreditsServiceAvailability.canReward) {
      return false;
    }

    RewardedAd? ad = _rewardedAd;

    if (ad == null) {
      final loaded =
          await loadRewarded();

      if (!loaded) {
        return false;
      }

      ad = _rewardedAd;
    }

    if (ad == null) {
      return false;
    }

    _rewardedAd = null;

    final completer =
        Completer<bool>();

    bool rewardEarned = false;

    ad.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();

        if (!completer.isCompleted) {
          completer.complete(
            rewardEarned,
          );
        }

        unawaited(
          loadRewarded(),
        );
      },
      onAdFailedToShowFullScreenContent:
          (ad, error) {
        ad.dispose();

        if (!completer.isCompleted) {
          completer.complete(false);
        }

        unawaited(
          loadRewarded(),
        );
      },
    );

    try {
      ad.show(
        onUserEarnedReward:
            (ad, reward) {
          rewardEarned = true;

          final amount =
              reward.amount.toInt();

          if (onRewardEarned != null) {
            onRewardEarned(
              amount > 0
                  ? amount
                  : CreditsConfig
                      .rewardedAdCredits,
            );
          }
        },
      );
    } catch (_) {
      try {
        ad.dispose();
      } catch (_) {}

      if (!completer.isCompleted) {
        completer.complete(false);
      }

      unawaited(
        loadRewarded(),
      );
    }

    return completer.future;
  }

  // ============================================================
  // General cleanup
  // ============================================================

  Future<void> dispose() async {
    disposeBanner();

    try {
      _interstitialAd?.dispose();
    } catch (_) {}

    try {
      _rewardedAd?.dispose();
    } catch (_) {}

    _interstitialAd = null;
    _rewardedAd = null;
  }
}

/// حالة مستقلة تسمح لباقي النظام بمعرفة هل يمكن إعطاء
/// Rewarded Credits بدون ربط كل الملفات مباشرة بـAdMob.
class CreditsServiceAvailability {
  CreditsServiceAvailability._();

  static bool canReward = true;
}
