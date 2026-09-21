import 'package:shared_preferences/shared_preferences.dart';

import '../config/credits_config.dart';

/// خدمة إدارة Credits الخاصة بالمستخدم.
///
/// مسؤوليتها حاليًا:
/// - إنشاء الرصيد لأول مرة.
/// - حفظ الرصيد بعد إغلاق التطبيق.
/// - قراءة الرصيد.
/// - خصم تكلفة الاستخدام.
/// - إضافة Credits.
/// - تسجيل عدد مكافآت الإعلانات اليومية.
/// - منع الرصيد من النزول تحت الصفر.
///
/// ملاحظة مهمة:
/// هذه طبقة محلية لواجهة التطبيق وتجربة المستخدم.
/// الحماية النهائية من التلاعب بالرصيد والاستخدام يجب أن تكون
/// من الـBackend قبل الإطلاق التجاري الكامل.
class CreditsService {
  CreditsService._();

  static final CreditsService instance = CreditsService._();

  static const String _creditsKey = 'sa7bi_user_credits';
  static const String _rewardedCountKey = 'sa7bi_rewarded_ads_count';
  static const String _rewardedDateKey = 'sa7bi_rewarded_ads_date';

  SharedPreferences? _preferences;

  int _credits = 0;
  int _rewardedAdsToday = 0;
  String _rewardedAdsDate = '';

  bool _initialized = false;

  /// الرصيد الحالي.
  int get credits => _credits;

  /// عدد الإعلانات المكافِئة التي شاهدها المستخدم اليوم.
  int get rewardedAdsToday => _rewardedAdsToday;

  /// هل الخدمة تم تهيئتها؟
  bool get isInitialized => _initialized;

  /// تهيئة الخدمة وقراءة البيانات المحفوظة.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _preferences = await SharedPreferences.getInstance();

    final prefs = _preferences!;

    final savedCredits = prefs.getInt(_creditsKey);

    if (savedCredits == null) {
      _credits = CreditsConfig.initialCredits;

      await prefs.setInt(
        _creditsKey,
        _credits,
      );
    } else {
      _credits = _sanitizeCredits(savedCredits);
    }

    _rewardedAdsToday = prefs.getInt(
          _rewardedCountKey,
        ) ??
        0;

    _rewardedAdsDate = prefs.getString(
          _rewardedDateKey,
        ) ??
        '';

    await _resetRewardedCounterIfNewDay();

    _initialized = true;
  }

  /// التأكد من أن الخدمة جاهزة قبل أي عملية.
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// قراءة الرصيد من التخزين مرة أخرى.
  Future<int> refresh() async {
    await _ensureInitialized();

    final prefs = _preferences!;

    final savedCredits = prefs.getInt(_creditsKey);

    if (savedCredits != null) {
      _credits = _sanitizeCredits(savedCredits);
    }

    await _resetRewardedCounterIfNewDay();

    return _credits;
  }

  /// هل يوجد رصيد كافٍ لتكلفة معينة؟
  Future<bool> canAfford(int cost) async {
    await _ensureInitialized();

    return CreditsConfig.canAfford(
      _credits,
      cost,
    );
  }

  /// خصم تكلفة من الرصيد.
  ///
  /// ترجع true إذا تم الخصم بنجاح.
  /// ترجع false إذا لم يكن هناك رصيد كافٍ.
  Future<bool> spend(int cost) async {
    await _ensureInitialized();

    if (cost <= 0) {
      return true;
    }

    if (!CreditsConfig.canAfford(
      _credits,
      cost,
    )) {
      return false;
    }

    _credits = CreditsConfig.subtract(
      _credits,
      cost,
    );

    await _saveCredits();

    return true;
  }

  /// إضافة Credits للمستخدم.
  ///
  /// تستخدم لاحقًا للمكافآت، العروض، الاشتراكات أو أي مصدر آخر.
  Future<int> add(int amount) async {
    await _ensureInitialized();

    if (amount <= 0) {
      return _credits;
    }

    _credits = CreditsConfig.add(
      _credits,
      amount,
    );

    await _saveCredits();

    return _credits;
  }

  /// إعادة ضبط الرصيد إلى الرصيد الابتدائي.
  ///
  /// هذه الدالة للاستخدام الداخلي/الاختبارات فقط،
  /// وليست زرًا ظاهرًا للمستخدم.
  Future<void> resetToInitial() async {
    await _ensureInitialized();

    _credits = CreditsConfig.initialCredits;

    await _saveCredits();
  }

  /// عدد الإعلانات المكافِئة التي يمكن للمستخدم مشاهدتها اليوم.
  int get remainingRewardedAdsToday {
    final remaining =
        CreditsConfig.rewardedAdDailyLimit - _rewardedAdsToday;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }

  /// هل يمكن منح مكافأة إعلان الآن؟
  Future<bool> canClaimRewardedAd() async {
    await _ensureInitialized();

    await _resetRewardedCounterIfNewDay();

    return _rewardedAdsToday <
        CreditsConfig.rewardedAdDailyLimit;
  }

  /// تسجيل مشاهدة إعلان مكافأة وإضافة الـCredits.
  ///
  /// لا تستدعي هذه الدالة مباشرة من واجهة الإعلان قبل التأكد
  /// من نجاح مشاهدة الإعلان فعليًا.
  ///
  /// ترجع true إذا تم تسجيل المكافأة.
  Future<bool> claimRewardedAd() async {
    await _ensureInitialized();

    await _resetRewardedCounterIfNewDay();

    if (_rewardedAdsToday >=
        CreditsConfig.rewardedAdDailyLimit) {
      return false;
    }

    _rewardedAdsToday++;

    await _saveRewardedState();

    await add(
      CreditsConfig.rewardedAdCredits,
    );

    return true;
  }

  /// مسح بيانات Credits المحلية.
  ///
  /// لا نستخدمها في الواجهة العادية.
  /// مفيدة للاختبار أثناء التطوير.
  Future<void> clearLocalData() async {
    await _ensureInitialized();

    final prefs = _preferences!;

    await prefs.remove(_creditsKey);
    await prefs.remove(_rewardedCountKey);
    await prefs.remove(_rewardedDateKey);

    _credits = CreditsConfig.initialCredits;
    _rewardedAdsToday = 0;
    _rewardedAdsDate = _todayKey();

    await prefs.setInt(
      _creditsKey,
      _credits,
    );

    await prefs.setInt(
      _rewardedCountKey,
      _rewardedAdsToday,
    );

    await prefs.setString(
      _rewardedDateKey,
      _rewardedAdsDate,
    );
  }

  // ============================================================
  // Private helpers
  // ============================================================

  int _sanitizeCredits(int value) {
    if (value < 0) {
      return 0;
    }

    if (value > CreditsConfig.maximumLocalCredits) {
      return CreditsConfig.maximumLocalCredits;
    }

    return value;
  }

  Future<void> _saveCredits() async {
    final prefs = _preferences;

    if (prefs == null) {
      return;
    }

    await prefs.setInt(
      _creditsKey,
      _credits,
    );
  }

  Future<void> _saveRewardedState() async {
    final prefs = _preferences;

    if (prefs == null) {
      return;
    }

    await prefs.setInt(
      _rewardedCountKey,
      _rewardedAdsToday,
    );

    await prefs.setString(
      _rewardedDateKey,
      _rewardedAdsDate,
    );
  }

  Future<void> _resetRewardedCounterIfNewDay() async {
    final today = _todayKey();

    if (_rewardedAdsDate == today) {
      return;
    }

    _rewardedAdsDate = today;
    _rewardedAdsToday = 0;

    await _saveRewardedState();
  }

  String _todayKey() {
    final now = DateTime.now();

    final month =
        now.month.toString().padLeft(2, '0');

    final day =
        now.day.toString().padLeft(2, '0');

    return '${now.year}-$month-$day';
  }
}
