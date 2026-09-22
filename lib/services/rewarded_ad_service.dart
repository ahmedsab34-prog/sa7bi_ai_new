import '../services/ads_service.dart';
import '../services/credits_service.dart';

/// مدير الإعلانات المكافِئة والـCredits في صاحبي AI.
///
/// المسؤول عن:
/// - التحقق من أهلية المستخدم.
/// - التحقق من الحد اليومي.
/// - بدء حالة الإعلان.
/// - عرض Rewarded Ad الحقيقي.
/// - إضافة Credits فقط بعد callback حقيقي من AdMob.
/// - إلغاء العملية عند الخطأ أو عدم إكمال الإعلان.
///
/// مهم جدًا:
/// مجرد فتح الإعلان لا يمنح Credits.
/// المكافأة لا تُسجل إلا بعد onUserEarnedReward.
class RewardedAdService {
  RewardedAdService._();

  static final RewardedAdService instance =
      RewardedAdService._();

  final AdsService _ads =
      AdsService.instance;

  final CreditsService _credits =
      CreditsService.instance;

  bool _initialized = false;
  bool _isShowing = false;

  // ============================================================
  // Getters
  // ============================================================

  bool get isShowing => _isShowing;

  int get rewardCredits =>
      _ads.rewardedCredits;

  int get dailyLimit =>
      _ads.rewardedDailyLimit;

  int get remainingToday =>
      _credits.remainingRewardedAdsToday;

  bool get isAdLoaded =>
      _ads.isRewardedLoaded;

  // ============================================================
  // Initialization
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _ads.initialize();
    await _credits.initialize();

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ============================================================
  // Eligibility
  // ============================================================

  /// هل المستخدم مؤهل للحصول على Rewarded Ad؟
  ///
  /// التحقق هنا يشمل:
  /// - عدم وجود إعلان آخر قيد العرض.
  /// - عدم تجاوز الحد اليومي.
  /// - السماح بالمكافآت.
  ///
  /// لا يعني ذلك أن الإعلان نفسه محمّل.
  Future<bool> canShowRewarded() async {
    await _ensureInitialized();

    if (_isShowing) {
      return false;
    }

    final canClaim =
        await _credits.canClaimRewardedAd();

    if (!canClaim) {
      return false;
    }

    return _ads.canGiveRewardedCredits();
  }

  // ============================================================
  // Loading
  // ============================================================

  /// تجهيز الإعلان المكافأة مسبقًا.
  ///
  /// ترجع true إذا كان الإعلان متاحًا/تم تحميله.
  Future<bool> preloadRewardedAd() async {
    await _ensureInitialized();

    if (!await canShowRewarded()) {
      return false;
    }

    return _ads.loadRewarded();
  }

  // ============================================================
  // Begin
  // ============================================================

  /// بداية محاولة عرض الإعلان.
  ///
  /// لا تضيف أي Credits.
  ///
  /// تستخدم قبل استدعاء [showRewardedAd].
  Future<bool> beginRewardedAd() async {
    await _ensureInitialized();

    if (_isShowing) {
      return false;
    }

    final canShow =
        await canShowRewarded();

    if (!canShow) {
      return false;
    }

    _isShowing = true;

    return true;
  }

  // ============================================================
  // Show real AdMob Rewarded Ad
  // ============================================================

  /// عرض الإعلان المكافأة الحقيقي.
  ///
  /// هذه هي الدالة الرئيسية التي ستستخدمها واجهة التطبيق.
  ///
  /// النتيجة:
  /// - success = true إذا حصل المستخدم فعلًا على المكافأة.
  /// - success = false إذا لم تكتمل المكافأة.
  ///
  /// يمكن تمرير callback اختياري بعد إضافة الـCredits بنجاح.
  Future<RewardedAdResult> showRewardedAd() async {
    await _ensureInitialized();

    if (_isShowing) {
      return const RewardedAdResult.failure(
        'يوجد إعلان مكافأة قيد التشغيل بالفعل.',
      );
    }

    final canStart =
        await beginRewardedAd();

    if (!canStart) {
      return const RewardedAdResult.failure(
        'الإعلان المكافأة غير متاح حاليًا أو وصلت للحد اليومي.',
      );
    }

    try {
      RewardedAdResult? completedResult;

      final shown =
          await _ads.showRewarded(
        onRewardEarned: (amount) async {
          // ----------------------------------------------------
          // مهم جدًا:
          //
          // هذا callback يتم استدعاؤه فقط بعد أن تؤكد AdMob
          // أن المستخدم حصل على Reward.
          //
          // هنا فقط نطلب إضافة Credits.
          // ----------------------------------------------------

          completedResult =
              await completeReward(
            rewardedAmount: amount,
          );
        },
      );

      if (!shown) {
        await cancelRewardedAd();

        return const RewardedAdResult.failure(
          'تعذر تشغيل الإعلان المكافأة حاليًا.',
        );
      }

      // --------------------------------------------------------
      // showRewarded ينتظر حتى إغلاق الإعلان.
      //
      // إذا حصل المستخدم على Reward سيكون
      // completedResult موجودًا.
      // --------------------------------------------------------

      if (completedResult != null) {
        return completedResult!;
      }

      // الإعلان أُغلق بدون Reward.
      await cancelRewardedAd();

      return const RewardedAdResult.failure(
        'تم إغلاق الإعلان قبل الحصول على المكافأة.',
      );
    } catch (_) {
      await cancelRewardedAd();

      return const RewardedAdResult.failure(
        'حصل خطأ أثناء تشغيل الإعلان.',
      );
    }
  }

  // ============================================================
  // Complete Reward
  // ============================================================

  /// تسجيل مشاهدة إعلان مكافأة ناجحة.
  ///
  /// هذه هي النقطة الوحيدة التي تمنح Credits.
  ///
  /// يجب استدعاؤها فقط من callback:
  /// onUserEarnedReward
  Future<RewardedAdResult> completeReward({
    int? rewardedAmount,
  }) async {
    await _ensureInitialized();

    if (!_isShowing) {
      return const RewardedAdResult.failure(
        'لا توجد مشاهدة إعلان مكافأة قيد التنفيذ.',
      );
    }

    try {
      // --------------------------------------------------------
      // فحص الحد اليومي مرة أخرى قبل إضافة المكافأة.
      // --------------------------------------------------------

      final canClaim =
          await _credits.canClaimRewardedAd();

      if (!canClaim) {
        _isShowing = false;

        return const RewardedAdResult.failure(
          'وصلت للحد اليومي للإعلانات المكافِئة.',
        );
      }

      // --------------------------------------------------------
      // إضافة المكافأة عن طريق CreditsService.
      // --------------------------------------------------------

      final claimed =
          await _credits.claimRewardedAd();

      _isShowing = false;

      if (!claimed) {
        return const RewardedAdResult.failure(
          'تعذر إضافة مكافأة الإعلان.',
        );
      }

      // --------------------------------------------------------
      // نستخدم قيمة Credits الخاصة بالتطبيق،
      // وليس قيمة عشوائية ترسلها شبكة الإعلان.
      // --------------------------------------------------------

      final actualReward =
          _ads.rewardedCredits;

      return RewardedAdResult.success(
        rewardCredits: actualReward,
        remainingCredits: _credits.credits,
        remainingAdsToday:
            _credits.remainingRewardedAdsToday,
      );
    } catch (_) {
      _isShowing = false;

      return const RewardedAdResult.failure(
        'حصل خطأ أثناء تسجيل مكافأة الإعلان.',
      );
    }
  }

  // ============================================================
  // Cancel
  // ============================================================

  /// إلغاء حالة الإعلان بدون مكافأة.
  ///
  /// تستخدم عندما:
  /// - الإعلان فشل في التشغيل.
  /// - المستخدم أغلق الإعلان بدون Reward.
  /// - حدث خطأ.
  Future<void> cancelRewardedAd() async {
    _isShowing = false;
  }

  // ============================================================
  // Reset
  // ============================================================

  /// إعادة ضبط الحالة عند مغادرة الشاشة.
  Future<void> reset() async {
    _isShowing = false;
  }
}

/// نتيجة عملية الإعلان المكافأة.
class RewardedAdResult {
  final bool success;
  final String? error;

  /// عدد Credits التي تمت إضافتها.
  final int rewardCredits;

  /// إجمالي Credits المتبقية للمستخدم.
  final int remainingCredits;

  /// عدد الإعلانات المكافِئة المتبقية اليوم.
  final int remainingAdsToday;

  const RewardedAdResult._({
    required this.success,
    this.error,
    this.rewardCredits = 0,
    this.remainingCredits = 0,
    this.remainingAdsToday = 0,
  });

  const RewardedAdResult.success({
    required int rewardCredits,
    required int remainingCredits,
    required int remainingAdsToday,
  }) : this._(
          success: true,
          rewardCredits: rewardCredits,
          remainingCredits: remainingCredits,
          remainingAdsToday: remainingAdsToday,
        );

  const RewardedAdResult.failure(
    String message,
  ) : this._(
          success: false,
          error: message,
        );
}
