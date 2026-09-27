import 'dart:async';

import '../services/ads_service.dart';
import '../services/credits_service.dart';

/// مدير الإعلانات المكافِئة والـCredits في صاحبي AI.
///
/// IMPORTANT:
/// - التطبيق لا يمنح Credits بنفسه.
/// - onUserEarnedReward من AdMob ليس مصدر السلطة للرصيد.
/// - المكافأة الحقيقية تأتي من AdMob SSV → Cloudflare Worker.
/// - بعد مشاهدة الإعلان ننتظر تأكيد السيرفر ثم نعمل refresh للرصيد.
/// - إذا تأخر SSV، نظل نتحقق لفترة محدودة بدل إعطاء Credits وهمية.
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

  /// عملية التحقق الحالية من مكافأة SSV.
  Future<RewardedAdResult>? _pendingRewardVerification;

  /// آخر عداد Rewarded Ads معروف قبل عرض الإعلان.
  int? _rewardedAdsCountBeforeShow;

  /// أقصى مدة ننتظر خلالها وصول SSV.
  static const Duration _verificationTimeout =
      Duration(seconds: 30);

  /// الفاصل بين محاولات قراءة الرصيد.
  static const Duration _verificationInterval =
      Duration(seconds: 2);

  // ============================================================
  // GETTERS
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
  // INITIALIZATION
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
  // ELIGIBILITY
  // ============================================================

  /// هل المستخدم مؤهل لعرض إعلان مكافأة؟
  ///
  /// التحقق من الحد اليومي يتم من السيرفر.
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
  // PRELOAD
  // ============================================================

  /// تجهيز الإعلان مسبقًا.
  Future<bool> preloadRewardedAd() async {
    await _ensureInitialized();

    if (!await canShowRewarded()) {
      return false;
    }

    return _ads.loadRewarded();
  }

  // ============================================================
  // BEGIN
  // ============================================================

  /// بداية محاولة عرض إعلان.
  ///
  /// لا تمنح أي Credits.
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

    // ----------------------------------------------------------
    // نأخذ snapshot للعداد قبل الإعلان.
    //
    // بعد SSV نتأكد أن العداد زاد.
    // ----------------------------------------------------------

    await _credits.refresh();

    _rewardedAdsCountBeforeShow =
        _credits.rewardedAdsToday;

    _isShowing = true;

    return true;
  }

  // ============================================================
  // SHOW REWARDED
  // ============================================================

  /// عرض الإعلان المكافأة الحقيقي.
  ///
  /// النجاح النهائي لا يعتمد على onUserEarnedReward وحده.
  ///
  /// التسلسل:
  ///
  /// 1. المستخدم يشاهد الإعلان.
  /// 2. AdMob يطلق onUserEarnedReward.
  /// 3. AdMob يرسل SSV إلى Worker.
  /// 4. Worker يتحقق من Google signature.
  /// 5. Durable Object يضيف Credits.
  /// 6. التطبيق يقرأ الرصيد من السيرفر.
  /// 7. إذا زاد عداد المكافآت → نجاح.
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

    _pendingRewardVerification = null;

    try {
      final shown =
          await _ads.showRewarded(
        onRewardEarned: (amount) {
          // ----------------------------------------------------
          // مهم:
          //
          // لا نضيف Credits هنا.
          //
          // فقط نبدأ عملية انتظار تأكيد SSV.
          // ----------------------------------------------------

          _pendingRewardVerification =
              _verifyRewardFromServer(
            expectedRewardAmount: amount,
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
      // لو onUserEarnedReward لم يحدث:
      // الإعلان أُغلق بدون مكافأة.
      // --------------------------------------------------------

      final verification =
          _pendingRewardVerification;

      if (verification == null) {
        await cancelRewardedAd();

        return const RewardedAdResult.failure(
          'تم إغلاق الإعلان قبل الحصول على المكافأة.',
        );
      }

      // --------------------------------------------------------
      // ننتظر تأكيد SSV الحقيقي.
      // --------------------------------------------------------

      final result =
          await verification;

      _isShowing = false;
      _pendingRewardVerification = null;

      return result;
    } catch (_) {
      await cancelRewardedAd();

      return const RewardedAdResult.failure(
        'حصل خطأ أثناء تشغيل أو تأكيد مكافأة الإعلان.',
      );
    }
  }

  // ============================================================
  // SERVER VERIFICATION
  // ============================================================

  /// انتظار وصول مكافأة AdMob SSV إلى السيرفر.
  ///
  /// لا يوجد هنا أي endpoint لمنح Credits.
  ///
  /// نحن فقط نقرأ الرصيد من السيرفر وننتظر أن يتغير
  /// العداد اليومي بعد أن يقوم Google SSV بتأكيد المكافأة.
  Future<RewardedAdResult> _verifyRewardFromServer({
    required int expectedRewardAmount,
  }) async {
    final before =
        _rewardedAdsCountBeforeShow ??
            _credits.rewardedAdsToday;

    final started =
        DateTime.now();

    while (DateTime.now()
            .difference(started) <
        _verificationTimeout) {
      try {
        await _credits.refresh();

        final current =
            _credits.rewardedAdsToday;

        // ------------------------------------------------------
        // أهم شرط:
        //
        // لا نعتبر المكافأة ناجحة إلا إذا زاد عداد
        // الإعلانات المكافِئة القادم من السيرفر.
        // ------------------------------------------------------

        if (current > before) {
          return RewardedAdResult.success(
            rewardCredits:
                _credits.rewardedAdCredits,
            remainingCredits:
                _credits.credits,
            remainingAdsToday:
                _credits.remainingRewardedAdsToday,
          );
        }

        // ------------------------------------------------------
        // لو السيرفر أكد أننا وصلنا للحد اليومي بدون زيادة
        // فهذا يعني أن المكافأة الحالية لم تُقبل.
        // ------------------------------------------------------

        if (current >=
            _credits.rewardedAdDailyLimit) {
          return const RewardedAdResult.failure(
            'لم يتم تأكيد مكافأة الإعلان من السيرفر.',
          );
        }
      } catch (_) {
        // ------------------------------------------------------
        // فشل قراءة مؤقت.
        //
        // نستمر في المحاولة حتى انتهاء المهلة.
        // لا نمنح Credits محليًا.
        // ------------------------------------------------------
      }

      await Future<void>.delayed(
        _verificationInterval,
      );
    }

    // ----------------------------------------------------------
    // انتهت المهلة.
    //
    // لا نعطي المستخدم Credits من التطبيق.
    // يمكن للـSSV أن يصل متأخرًا، وعندها refresh لاحق
    // سيظهر الرصيد الصحيح.
    // ----------------------------------------------------------

    try {
      await _credits.refresh();
    } catch (_) {}

    final current =
        _credits.rewardedAdsToday;

    if (current > before) {
      return RewardedAdResult.success(
        rewardCredits:
            _credits.rewardedAdCredits,
        remainingCredits:
            _credits.credits,
        remainingAdsToday:
            _credits.remainingRewardedAdsToday,
      );
    }

    return RewardedAdResult.pending(
      rewardCredits:
          expectedRewardAmount > 0
              ? expectedRewardAmount
              : _credits.rewardedAdCredits,
      remainingCredits:
          _credits.credits,
      remainingAdsToday:
          _credits.remainingRewardedAdsToday,
    );
  }

  // ============================================================
  // LEGACY-SAFE COMPLETE
  // ============================================================

  /// توافق مع أي جزء قديم من التطبيق يستدعي completeReward().
  ///
  /// مهم:
  /// هذه الدالة لا تضيف Credits.
  ///
  /// إذا تم استدعاؤها أثناء مشاهدة Rewarded Ad،
  /// فهي تنتظر تأكيد SSV فقط.
  Future<RewardedAdResult> completeReward({
    int? rewardedAmount,
  }) async {
    await _ensureInitialized();

    final pending =
        _pendingRewardVerification;

    if (pending != null) {
      return pending;
    }

    return const RewardedAdResult.failure(
      'لم يتم بدء عملية تحقق من مكافأة الإعلان.',
    );
  }

  // ============================================================
  // CANCEL
  // ============================================================

  /// إلغاء حالة الإعلان بدون منح Credits.
  Future<void> cancelRewardedAd() async {
    _isShowing = false;
    _pendingRewardVerification = null;
    _rewardedAdsCountBeforeShow = null;
  }

  // ============================================================
  // RESET
  // ============================================================

  Future<void> reset() async {
    _isShowing = false;
    _pendingRewardVerification = null;
    _rewardedAdsCountBeforeShow = null;
  }
}

// ================================================================
// RESULT
// ================================================================

/// نتيجة عملية الإعلان المكافأة.
class RewardedAdResult {
  final bool success;

  /// true عندما الإعلان نجح لكن SSV لم يتأكد خلال المهلة.
  final bool pending;

  final String? error;

  /// عدد Credits المرتبط بالمكافأة.
  final int rewardCredits;

  /// إجمالي Credits الحالية من السيرفر.
  final int remainingCredits;

  /// عدد الإعلانات المتبقية اليوم.
  final int remainingAdsToday;

  const RewardedAdResult._({
    required this.success,
    required this.pending,
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
          pending: false,
          rewardCredits: rewardCredits,
          remainingCredits: remainingCredits,
          remainingAdsToday: remainingAdsToday,
        );

  const RewardedAdResult.pending({
    required int rewardCredits,
    required int remainingCredits,
    required int remainingAdsToday,
  }) : this._(
          success: false,
          pending: true,
          error:
              'تمت مشاهدة الإعلان، وجاري تأكيد المكافأة من السيرفر.',
          rewardCredits: rewardCredits,
          remainingCredits: remainingCredits,
          remainingAdsToday: remainingAdsToday,
        );

  const RewardedAdResult.failure(
    String message,
  ) : this._(
          success: false,
          pending: false,
          error: message,
        );
}
