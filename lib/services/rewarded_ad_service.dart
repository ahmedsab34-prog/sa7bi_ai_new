import '../services/ads_service.dart';
import '../services/credits_service.dart';

/// مدير الإعلانات المكافِئة والـCredits.
///
/// مهم:
/// هذه الطبقة لا تعتبر مجرد فتح نافذة الإعلان مشاهدة ناجحة.
/// المكافأة لا تُضاف إلا عند استدعاء [completeReward].
///
/// عند تفعيل AdMob فعليًا، سيتم استدعاء:
/// - [canShowRewarded]
/// - ثم عرض الإعلان من AdsService.
/// - ثم [completeReward] فقط من callback نجاح الـReward.
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

  bool get isShowing => _isShowing;

  int get rewardCredits =>
      _ads.rewardedCredits;

  int get dailyLimit =>
      _ads.rewardedDailyLimit;

  int get remainingToday =>
      _credits.remainingRewardedAdsToday;

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

  /// هل المستخدم مؤهل للحصول على إعلان مكافأة؟
  ///
  /// هذا لا يعني أن إعلان الشبكة تم تحميله.
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

  /// بداية محاولة عرض الإعلان.
  ///
  /// لا تضيف أي Credits.
  ///
  /// ترجع false إذا كان المستخدم غير مؤهل.
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

  /// إنهاء محاولة الإعلان بدون مكافأة.
  ///
  /// تستخدم في:
  /// - إغلاق الإعلان بدون إكماله.
  /// - حدوث خطأ.
  /// - عدم وصول callback المكافأة.
  Future<void> cancelRewardedAd() async {
    _isShowing = false;
  }

  /// تسجيل مشاهدة إعلان مكافأة ناجحة.
  ///
  /// هذه هي النقطة الوحيدة التي تمنح Credits.
  ///
  /// يجب استدعاؤها فقط بعد callback حقيقي من شبكة الإعلان
  /// يؤكد حصول المستخدم على الـReward.
  Future<RewardedAdResult> completeReward() async {
    await _ensureInitialized();

    if (!_isShowing) {
      return const RewardedAdResult.failure(
        'لا توجد مشاهدة إعلان مكافأة قيد التنفيذ.',
      );
    }

    try {
      final canClaim =
          await _credits.canClaimRewardedAd();

      if (!canClaim) {
        _isShowing = false;

        return const RewardedAdResult.failure(
          'وصلت للحد اليومي للإعلانات المكافِئة.',
        );
      }

      final claimed =
          await _credits.claimRewardedAd();

      _isShowing = false;

      if (!claimed) {
        return const RewardedAdResult.failure(
          'تعذر إضافة مكافأة الإعلان.',
        );
      }

      return RewardedAdResult.success(
        rewardCredits: _ads.rewardedCredits,
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

  /// إلغاء الحالة الحالية عند مغادرة الشاشة.
  Future<void> reset() async {
    _isShowing = false;
  }
}

/// نتيجة مشاهدة الإعلان المكافأة.
class RewardedAdResult {
  final bool success;
  final String? error;
  final int rewardCredits;
  final int remainingCredits;
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
