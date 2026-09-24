import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/credits_config.dart';

/// خدمة الإعلانات المركزية في صاحبي AI.
///
/// المسؤوليات:
/// - تهيئة AdMob مرة واحدة بأمان.
/// - Banner Ads.
/// - Interstitial Ads.
/// - Rewarded Ads.
/// - حفظ عداد الـInterstitial.
/// - حفظ حالة الـBanner.
///
/// ملاحظات:
/// - لا يتم عرض إعلان تلقائي عند فتح التطبيق.
/// - فشل الإعلان لا يمنع التطبيق من العمل.
/// - Rewarded لا تُعتبر ناجحة إلا بعد onUserEarnedReward.
/// - Banner لا يُعتبر جاهزًا إلا بعد onAdLoaded.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  // ============================================================
  // ADMOB PRODUCTION IDS
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
  // STORAGE KEYS
  // ============================================================

  static const String _interstitialCounterKey =
      'sa7bi_interstitial_counter';

  static const String _bannerEnabledKey =
      'sa7bi_banner_enabled';

  // ============================================================
  // STATE
  // ============================================================

  SharedPreferences? _preferences;

  bool _initialized = false;
  bool _adMobInitialized = false;

  bool _bannerEnabled = true;

  int _interstitialCounter = 0;

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  bool _isLoadingBanner = false;
  bool _isLoadingInterstitial = false;
  bool _isLoadingRewarded = false;

  /// يمنع تشغيل تهيئة AdMob أكثر من مرة في نفس الوقت.
  Future<void>? _initializationFuture;

  // ============================================================
  // GETTERS
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
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() {
    final existing = _initializationFuture;

    if (existing != null) {
      return existing;
    }

    final future = _initializeInternal();

    _initializationFuture = future;

    return future;
  }

  Future<void> _initializeInternal() async {
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

      // ----------------------------------------------------------
      // AdMob
      // ----------------------------------------------------------

      try {
        await MobileAds.instance.initialize();

        _adMobInitialized = true;
      } catch (_) {
        _adMobInitialized = false;
      }

      _initialized = true;
    } catch (_) {
      _initialized = true;
      _adMobInitialized = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    await initialize();
  }

  // ============================================================
  // BANNER
  // ============================================================

  Future<bool> shouldShowBanner() async {
    await _ensureInitialized();

    return _bannerEnabled &&
        _adMobInitialized;
  }

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
    } catch (_) {}

    if (!enabled) {
      disposeBanner();
    }
  }

  /// تحميل Banner.
  ///
  /// لا يرجع الإعلان إلا بعد onAdLoaded.
  Future<BannerAd?> loadBanner({
    AdSize adSize = AdSize.banner,
  }) async {
    await _ensureInitialized();

    if (!_adMobInitialized ||
        !_bannerEnabled) {
      return null;
    }

    if (_bannerAd != null) {
      return _bannerAd;
    }

    if (_isLoadingBanner) {
      return null;
    }

    _isLoadingBanner = true;

    final completer =
        Completer<BannerAd?>();

    late final BannerAd banner;

    banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (ad is! BannerAd) {
            try {
              ad.dispose();
            } catch (_) {}

            if (!completer.isCompleted) {
              completer.complete(null);
            }

            return;
          }

          _bannerAd = ad;

          if (!completer.isCompleted) {
            completer.complete(ad);
          }
        },
        onAdFailedToLoad: (
          ad,
          error,
        ) {
          try {
            ad.dispose();
          } catch (_) {}

          _bannerAd = null;

          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {},
        onAdImpression: (ad) {},
      ),
    );

    try {
      await banner.load();
    } catch (_) {
      try {
        banner.dispose();
      } catch (_) {}

      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    BannerAd? result;

    try {
      result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
    } catch (_) {
      result = null;
    }

    if (result == null) {
      try {
        banner.dispose();
      } catch (_) {}

      if (identical(_bannerAd, banner)) {
        _bannerAd = null;
      }
    }

    _isLoadingBanner = false;

    return result;
  }

  void disposeBanner() {
    try {
      _bannerAd?.dispose();
    } catch (_) {}

    _bannerAd = null;
  }

  // ============================================================
  // INTERSTITIAL
  // ============================================================

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

  Future<bool> loadInterstitial() async {
    await _ensureInitialized();

    if (!_adMobInitialized) {
      return false;
    }

    if (_interstitialAd != null) {
      return true;
    }

    if (_isLoadingInterstitial) {
      return false;
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
    }

    _isLoadingInterstitial = false;

    try {
      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

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
  // REWARDED
  // ============================================================

  Future<bool> canGiveRewardedCredits() async {
    await _ensureInitialized();

    return CreditsServiceAvailability.canReward;
  }

  Future<int> getRewardAmount() async {
    await _ensureInitialized();

    return CreditsConfig.rewardedAdCredits;
  }

  Future<bool> loadRewarded() async {
    await _ensureInitialized();

    if (!_adMobInitialized) {
      return false;
    }

    if (_rewardedAd != null) {
      return true;
    }

    if (_isLoadingRewarded) {
      return false;
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
    }

    _isLoadingRewarded = false;

    try {
      return await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> showRewarded({
    void Function(int amount)?
        onRewardEarned,
  }) async {
    await _ensureInitialized();

    if (!_adMobInitialized ||
        !CreditsServiceAvailability.canReward) {
      return false;
    }

    RewardedAd? ad = _rewardedAd;

    if (ad == null) {
      final loaded = await loadRewarded();

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
      onAdDismissedFullScreenContent:
          (ad) {
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

          final safeAmount =
              amount > 0
                  ? amount
                  : CreditsConfig
                      .rewardedAdCredits;

          if (onRewardEarned != null) {
            onRewardEarned(
              safeAmount,
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
  // CLEANUP
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

/// حالة مستقلة لمعرفة هل يمكن إعطاء
/// Rewarded Credits.
class CreditsServiceAvailability {
  CreditsServiceAvailability._();

  static bool canReward = true;
}
