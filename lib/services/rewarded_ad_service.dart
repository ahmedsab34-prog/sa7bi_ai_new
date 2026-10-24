
import 'dart:async';

import 'ads_service.dart';
import 'credits_service.dart';

/// مدير الإعلانات المكافِئة والـCredits في صاحبي AI.
///
/// التطبيق لا يمنح Credits بنفسه.
/// onUserEarnedReward ليس إثباتًا على وصول الرصيد.
/// المكافأة الحقيقية تأتي من AdMob SSV ثم Cloudflare Worker.
/// بعد مشاهدة الإعلان ننتظر تأكيد السيرفر.
class RewardedAdService {
  RewardedAdService._();

  static final RewardedAdService instance =
      RewardedAdService._();

  final AdsService _ads = AdsService.instance;
  final CreditsService _credits = CreditsService.instance;

  bool _initialized = false;
  bool _isShowing = false;

  Future<RewardedAdResult>? _pendingRewardVerification;

  int? _rewardedAdsCountBeforeShow;

  static const Duration _verificationTimeout =
      Duration(seconds: 30);

  static const Duration _verificationInterval =
      Duration(seconds: 2);

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isShowing => _isShowing;

  int get rewardCredits => _ads.rewardedCredits;

  int get dailyLimit => _ads.rewardedDailyLimit;

  int get remainingToday =>
      _credits.remainingRewardedAdsToday;

  bool get isAdLoaded => _ads.isRewardedLoaded;

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

  /// فحص أهلية عرض إعلان المكافأة.
  ///
  /// يجب أن يكون آخر فحص للرصيد ناجحًا من السيرفر.
  Future<bool> canShowRewarded() async {
    await _ensureInitialized();

    if (_isShowing) {
      return false;
    }

    final canClaim =
        await _credits.canClaimRewardedAd();

    if (!canClaim || !_credits.hasValidServerBalance) {
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

  /// بداية محاولة عرض الإعلان.
  ///
  /// لا تمنح هذه الدالة أي Credits.
  Future<bool> beginRewardedAd() async {
    await _ensureInitialized();

    if (_isShowing) {
      return false;
    }

    final canShow = await canShowRewarded();

    if (!canShow) {
      return false;
    }

    // تحديث الرصيد قبل تسجيل العداد المرجعي.
    await _credits.refresh();

    if (!_credits.hasValidServerBalance) {
      return false;
    }

    _rewardedAdsCountBeforeShow =
        _credits.rewardedAdsToday;

    _isShowing = true;

    return true;
  }

  // ============================================================
  // SHOW REWARDED
  // ============================================================

  /// عرض إعلان المكافأة وانتظار تأكيد السيرفر.
  ///
  /// التسلسل:
  /// 1. المستخدم يشاهد الإعلان.
  /// 2. AdMob يطلق onUserEarnedReward.
  /// 3. Google يرسل SSV إلى Worker.
  /// 4. Worker يتحقق من التوقيع.
  /// 5. Durable Object يسجل المكافأة.
  /// 6. التطبيق يعيد قراءة الرصيد من السيرفر.
  Future<RewardedAdResult> showRewardedAd() async {
    await _ensureInitialized();

    if (_isShowing) {
      return const RewardedAdResult.failure(
        'يوجد إعلان مكافأة قيد التشغيل بالفعل.',
      );
    }

    final canStart = await beginRewardedAd();

    if (!canStart) {
      return const RewardedAdResult.failure(
        'الإعلان المكافأة غير متاح حاليًا أو وصلت للحد اليومي.',
      );
    }

    _pendingRewardVerification = null;

    try {
      final shown = await _ads.showRewarded(
        onRewardEarned: (amount) {
          // لا نضيف رصيدًا محليًا.
          // نبدأ فقط انتظار تأكيد SSV.
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

      final verification = _pendingRewardVerification;

      if (verification == null) {
        await cancelRewardedAd();

        return const RewardedAdResult.failure(
          'تم إغلاق الإعلان قبل الحصول على المكافأة.',
        );
      }

      final result = await verification;

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

  /// انتظار تأكيد المكافأة من السيرفر.
  ///
  /// لا يوجد هنا endpoint يمنح Credits.
  /// نجاح التحقق يتطلب قراءة ناجحة من السيرفر
  /// وزيادة العداد اليومي مقارنة بما قبل الإعلان.
  Future<RewardedAdResult> _verifyRewardFromServer({
    required int expectedRewardAmount,
  }) async {
    final before =
        _rewardedAdsCountBeforeShow ??
            _credits.rewardedAdsToday;

    final started = DateTime.now();

    while (DateTime.now().difference(started) <
        _verificationTimeout) {
      await _credits.refresh();

      // refresh قد يعيد Cache قديمًا عند فشل الاتصال.
      // لا نستخدم هذه القيمة لإثبات المكافأة.
      if (_credits.hasValidServerBalance) {
        final current = _credits.rewardedAdsToday;

        if (current > before) {
          return RewardedAdResult.success(
            rewardCredits: _credits.rewardedAdCredits,
            remainingCredits: _credits.credits,
            remainingAdsToday:
                _credits.remainingRewardedAdsToday,
          );
        }

        if (current >= _credits.rewardedAdDailyLimit) {
          return const RewardedAdResult.failure(
            'لم يتم تأكيد مكافأة الإعلان من السيرفر.',
          );
        }
      }

      await Future<void>.delayed(
        _verificationInterval,
      );
    }

    // محاولة أخيرة بعد انتهاء المهلة.
    await _credits.refresh();

    final current = _credits.rewardedAdsToday;

    if (_credits.hasValidServerBalance &&
        current > before) {
      return RewardedAdResult.success(
        rewardCredits: _credits.rewardedAdCredits,
        remainingCredits: _credits.credits,
        remainingAdsToday:
            _credits.remainingRewardedAdsToday,
      );
    }

    // لا نعلن النجاح ولا نضيف Credits محليًا.
    // قد يصل تأكيد SSV متأخرًا؛ يمكن تحديث الرصيد لاحقًا.
    return RewardedAdResult.pending(
      rewardCredits: expectedRewardAmount > 0
          ? expectedRewardAmount
          : _credits.rewardedAdCredits,
      remainingCredits: _credits.credits,
      remainingAdsToday:
          _credits.remainingRewardedAdsToday,
    );
  }

  // ============================================================
  // LEGACY-SAFE COMPLETE
  // ============================================================

  /// توافق مع الأجزاء القديمة التي تستدعي completeReward().
  ///
  /// لا تمنح هذه الدالة أي Credits.
  Future<RewardedAdResult> completeReward({
    int? rewardedAmount,
  }) async {
    await _ensureInitialized();

    final pending = _pendingRewardVerification;

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

  /// إلغاء حالة الإعلان دون منح Credits.
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

  /// الإعلان شوهد، لكن تأكيد السيرفر لم يكتمل بعد.
  final bool pending;

  final String? error;

  /// عدد Credits المرتبط بالمكافأة.
  final int rewardCredits;

  /// إجمالي Credits الحالية حسب آخر قراءة.
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
