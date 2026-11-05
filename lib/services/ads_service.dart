
import 'dart:async';
import 'dart:convert';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/credits_config.dart';
import 'ai_request_service.dart';

/// خدمة الإعلانات المركزية في صاحبي AI.
///
/// المسؤوليات:
/// - تهيئة AdMob بأمان مع إمكانية إعادة المحاولة.
/// - إدارة Banner Ads وInterstitial Ads وRewarded Ads.
/// - إعداد AdMob Server-Side Verification.
/// - ربط مكافأة الإعلان بمعرف تثبيت التطبيق.
/// - عدم منح Credits من التطبيق مباشرة.
///
/// مصدر منح الرصيد هو Worker بعد تحقق Google SSV.
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  // ============================================================
  // ADMOB IDS
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

  /// يتغير كلما ألغينا تحميل Banner سابقًا.
  /// يمنع callback قديمًا من إعادة إعلان تم التخلص منه.
  int _bannerLoadGeneration = 0;

  /// يمنع تنفيذ التهيئة بالتوازي.
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
  // SAFE DISPOSAL
  // ============================================================

  void _safeDispose(Ad? ad) {
    if (ad == null) return;

    try {
      ad.dispose();
    } catch (_) {
      // لا نسمح لفشل التخلص من إعلان بإسقاط التطبيق.
    }
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() {
    if (_initialized && _adMobInitialized) {
      return Future<void>.value();
    }

    final existing = _initializationFuture;

    if (existing != null) {
      return existing;
    }

    late final Future<void> tracked;

    tracked = _initializeInternal().whenComplete(() {
      if (identical(_initializationFuture, tracked)) {
        _initializationFuture = null;
      }
    });

    _initializationFuture = tracked;

    return tracked;
  }

  Future<void> _initializeInternal() async {
    // تحميل إعدادات التطبيق مرة واحدة.
    try {
      if (_preferences == null) {
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
      }

      _initialized = true;
    } catch (_) {
      _initialized = false;
      _adMobInitialized = false;
      return;
    }

    // إذا فشلت تهيئة AdMob، تبقى قابلة لإعادة المحاولة.
    if (!_adMobInitialized) {
      try {
        await MobileAds.instance.initialize();
        _adMobInitialized = true;
      } catch (_) {
        _adMobInitialized = false;
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized || !_adMobInitialized) {
      await initialize();
    }
  }

  // ============================================================
  // BANNER
  // ============================================================

  Future<bool> shouldShowBanner() async {
    await _ensureInitialized();

    return _bannerEnabled && _adMobInitialized;
  }

  Future<void> setBannerEnabled(bool enabled) async {
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

  /// تحميل Banner وإرجاعه بعد onAdLoaded فقط.
  ///
  /// AdsService هي المالكة للإعلان.
  /// الشاشة التي تعرضه يجب أن تستدعي releaseBanner
  /// بدلًا من استدعاء dispose مباشرة.
  Future<BannerAd?> loadBanner({
    AdSize adSize = AdSize.banner,
  }) async {
    await _ensureInitialized();

    if (!_adMobInitialized || !_bannerEnabled) {
      return null;
    }

    if (_bannerAd != null) {
      return _bannerAd;
    }

    if (_isLoadingBanner) {
      return null;
    }

    _isLoadingBanner = true;

    final generation = ++_bannerLoadGeneration;

    final completer = Completer<BannerAd?>();

    late final BannerAd banner;

    banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (ad is! BannerAd) {
            _safeDispose(ad);

            if (!completer.isCompleted) {
              completer.complete(null);
            }

            return;
          }

          // تم إلغاء عملية التحميل أو تعطيل الإعلانات
          // أثناء انتظار استجابة AdMob.
          if (generation != _bannerLoadGeneration ||
              !_bannerEnabled ||
              !_adMobInitialized) {
            _safeDispose(ad);

            if (!completer.isCompleted) {
              completer.complete(null);
            }

            return;
          }

          final previous = _bannerAd;

          if (previous != null &&
              !identical(previous, ad)) {
            _safeDispose(previous);
          }

          _bannerAd = ad;

          if (!completer.isCompleted) {
            completer.complete(ad);
          }
        },
        onAdFailedToLoad: (ad, error) {
          if (generation == _bannerLoadGeneration) {
            if (identical(_bannerAd, ad)) {
              _bannerAd = null;
            }
          }

          _safeDispose(ad);

          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {},
        onAdImpression: (ad) {},
      ),
    );

    BannerAd? result;

    try {
      await banner.load();

      result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
    } catch (_) {
      result = null;
    }

    if (result == null) {
      // إلغاء صلاحية أي callback متأخر من نفس العملية.
      if (generation == _bannerLoadGeneration) {
        _bannerLoadGeneration++;

        if (identical(_bannerAd, banner)) {
          _bannerAd = null;
        }
      }

      _safeDispose(banner);
    }

    _isLoadingBanner = false;

    return result;
  }

  /// تحرير Banner من الشاشة التي كانت تعرضه.
  ///
  /// يمسح المرجع المركزي أيضًا حتى لا نعيد إعلانًا تم التخلص منه.
  void releaseBanner(BannerAd banner) {
    if (identical(_bannerAd, banner)) {
      _bannerAd = null;
      _bannerLoadGeneration++;
    }

    _safeDispose(banner);
  }

  /// التخلص من الإعلان الحالي وإلغاء صلاحية callbacks القديمة.
  void disposeBanner() {
    _bannerLoadGeneration++;

    final banner = _bannerAd;
    _bannerAd = null;

    _safeDispose(banner);
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

    final completer = Completer<bool>();

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;

            ad.fullScreenContentCallback =
                FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                _safeDispose(ad);

                if (identical(_interstitialAd, ad)) {
                  _interstitialAd = null;
                }

                unawaited(loadInterstitial());
              },
              onAdFailedToShowFullScreenContent: (
                ad,
                error,
              ) {
                _safeDispose(ad);

                if (identical(_interstitialAd, ad)) {
                  _interstitialAd = null;
                }

                unawaited(loadInterstitial());
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
      _safeDispose(ad);

      unawaited(loadInterstitial());

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

  /// ضبط SSV قبل السماح بعرض الإعلان.
  Future<bool> _configureRewardedSsv(
    RewardedAd ad,
  ) async {
    try {
      final deviceId =
          await AiRequestService.getDeviceId();

      if (deviceId.trim().isEmpty) {
        return false;
      }

      final customData = jsonEncode({
        'deviceId': deviceId,
        'source': 'sa7bi_rewarded_ad',
      });

      final options = ServerSideVerificationOptions(
        customData: customData,
      );

      await ad.setServerSideOptions(options);

      return true;
    } catch (_) {
      return false;
    }
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

    final completer = Completer<bool>();

    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            unawaited(
              _finishRewardedLoad(
                ad,
                completer,
              ),
            );
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _isLoadingRewarded = false;

            if (!completer.isCompleted) {
              completer.complete(false);
            }
          },
        ),
      );
    } catch (_) {
      _isLoadingRewarded = false;

      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    try {
      return await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          _isLoadingRewarded = false;
          return false;
        },
      );
    } catch (_) {
      _isLoadingRewarded = false;
      return false;
    }
  }

  Future<void> _finishRewardedLoad(
    RewardedAd ad,
    Completer<bool> completer,
  ) async {
    try {
      final ssvReady =
          await _configureRewardedSsv(ad);

      if (!ssvReady) {
        _safeDispose(ad);

        _rewardedAd = null;
        _isLoadingRewarded = false;

        if (!completer.isCompleted) {
          completer.complete(false);
        }

        return;
      }

      _rewardedAd = ad;
      _isLoadingRewarded = false;

      if (!completer.isCompleted) {
        completer.complete(true);
      }
    } catch (_) {
      _safeDispose(ad);

      _rewardedAd = null;
      _isLoadingRewarded = false;

      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }
  }

  /// عرض Rewarded Ad.
  ///
  /// callback المكافأة لا يضيف رصيدًا محليًا.
  /// Worker فقط يمنح الرصيد بعد Google SSV.
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

    final completer = Completer<bool>();

    bool rewardEarned = false;

    ad.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _safeDispose(ad);

        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }

        unawaited(loadRewarded());
      },
      onAdFailedToShowFullScreenContent: (
        ad,
        error,
      ) {
        _safeDispose(ad);

        if (!completer.isCompleted) {
          completer.complete(false);
        }

        unawaited(loadRewarded());
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          rewardEarned = true;

          final amount = reward.amount.toInt();

          final safeAmount = amount > 0
              ? amount
              : CreditsConfig.rewardedAdCredits;

          // إعلام الواجهة فقط.
          // لا يوجد تعديل محلي لرصيد المستخدم.
          onRewardEarned?.call(safeAmount);
        },
      );
    } catch (_) {
      _safeDispose(ad);

      if (!completer.isCompleted) {
        completer.complete(false);
      }

      unawaited(loadRewarded());
    }

    return completer.future;
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  Future<void> dispose() async {
    disposeBanner();

    final interstitial = _interstitialAd;
    final rewarded = _rewardedAd;

    _interstitialAd = null;
    _rewardedAd = null;

    _safeDispose(interstitial);
    _safeDispose(rewarded);
  }
}

/// حالة مستقلة لمعرفة هل يمكن عرض Rewarded Credits.
///
/// لا تمنح الرصيد؛ هي مجرد مفتاح تشغيل/إيقاف.
class CreditsServiceAvailability {
  CreditsServiceAvailability._();

  static bool canReward = true;
}
