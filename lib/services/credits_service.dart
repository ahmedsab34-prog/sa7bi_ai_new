import 'package:shared_preferences/shared_preferences.dart';

import '../config/credits_config.dart';
import 'ai_request_service.dart';

/// خدمة عرض ومزامنة Credits الخاصة بالمستخدم.
///
/// IMPORTANT:
/// الرصيد الحقيقي موجود على Cloudflare Durable Object.
/// SharedPreferences هنا مجرد Cache لآخر رصيد معروف، وليس مصدر سلطة.
///
/// العمليات الحساسة مثل:
/// - خصم Credits من طلب AI
/// - حجز الرصيد
/// - تثبيت الخصم بعد نجاح الطلب
///
/// تتم من خلال الـBackend وليس من هنا.
class CreditsService {
  CreditsService._();

  static final CreditsService instance =
      CreditsService._();

  // ============================================================
  // LOCAL CACHE KEYS
  // ============================================================

  static const String _creditsKey =
      'sa7bi_user_credits_cache';

  static const String _rewardedCountKey =
      'sa7bi_rewarded_ads_count_cache';

  static const String _rewardedLimitKey =
      'sa7bi_rewarded_ads_limit_cache';

  static const String _rewardedCreditsKey =
      'sa7bi_rewarded_ads_credits_cache';

  static const String _lastSyncKey =
      'sa7bi_credits_last_sync';

  SharedPreferences? _preferences;

  int _credits = 0;

  int _rewardedAdsToday = 0;

  int _rewardedAdsDailyLimit =
      CreditsConfig.rewardedAdDailyLimit;

  int _rewardedAdCredits =
      CreditsConfig.rewardedAdCredits;

  bool _initialized = false;

  bool _serverAvailable = false;

  String? _lastError;

  DateTime? _lastSync;

  // ============================================================
  // GETTERS
  // ============================================================

  /// آخر رصيد معروف من السيرفر.
  ///
  /// إذا لم تتم المزامنة بعد، يكون هذا Cache محليًا فقط.
  int get credits => _credits;

  /// عدد الإعلانات المكافِئة المستخدمة اليوم حسب آخر مزامنة.
  int get rewardedAdsToday =>
      _rewardedAdsToday;

  /// الحد اليومي للإعلانات حسب السيرفر.
  int get rewardedAdDailyLimit =>
      _rewardedAdsDailyLimit;

  /// عدد Credits التي يمنحها الإعلان حسب السيرفر.
  int get rewardedAdCredits =>
      _rewardedAdCredits;

  /// عدد الإعلانات المتبقية اليوم.
  int get remainingRewardedAdsToday {
    final remaining =
        _rewardedAdsDailyLimit -
            _rewardedAdsToday;

    return remaining < 0
        ? 0
        : remaining;
  }

  /// هل تم تشغيل الخدمة؟
  bool get isInitialized =>
      _initialized;

  /// هل آخر اتصال بالسيرفر نجح؟
  bool get isServerAvailable =>
      _serverAvailable;

  /// آخر خطأ حصل أثناء المزامنة.
  String? get lastError =>
      _lastError;

  /// وقت آخر مزامنة ناجحة.
  DateTime? get lastSync =>
      _lastSync;

  /// هل يوجد رصيد كافٍ محليًا للعرض فقط؟
  ///
  /// لا تستخدم هذه الدالة للسماح بتنفيذ طلب AI.
  /// القرار النهائي يكون في الـBackend.
  bool get hasCredits =>
      _credits > 0;

  // ============================================================
  // INITIALIZE
  // ============================================================

  /// تهيئة الخدمة وقراءة آخر Cache.
  ///
  /// بعد قراءة الـCache نحاول فورًا مزامنة الرصيد
  /// من السيرفر.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _preferences =
        await SharedPreferences.getInstance();

    _loadLocalCache();

    _initialized = true;

    // مزامنة أولية.
    //
    // لا نفشل تشغيل التطبيق إذا كان السيرفر
    // غير متاح مؤقتًا.
    try {
      await refresh();
    } catch (_) {
      _serverAvailable = false;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ============================================================
  // REFRESH FROM SERVER
  // ============================================================

  /// يجلب الرصيد الحقيقي من Cloudflare.
  ///
  /// هذه هي العملية الأساسية لتحديث واجهة المستخدم.
  Future<int> refresh() async {
    await _ensureInitialized();

    try {
      final result =
          await AiRequestService.getCredits();

      _credits =
          _sanitizeCredits(
        result.balance,
      );

      _rewardedAdsToday =
          _sanitizeRewardedCount(
        result.dailyRewardedAds,
      );

      if (result.dailyRewardedAdsLimit >
          0) {
        _rewardedAdsDailyLimit =
            result.dailyRewardedAdsLimit;
      }

      if (result.rewardedAdCredits >
          0) {
        _rewardedAdCredits =
            result.rewardedAdCredits;
      }

      _serverAvailable = true;
      _lastError = null;
      _lastSync = DateTime.now();

      await _saveLocalCache();

      return _credits;
    } on AiRequestException catch (error) {
      _serverAvailable = false;
      _lastError = error.message;

      // لا نمسح الرصيد المحلي.
      //
      // نستخدم آخر قيمة معروفة للعرض فقط.
      return _credits;
    } catch (error) {
      _serverAvailable = false;
      _lastError = error.toString();

      return _credits;
    }
  }

  // ============================================================
  // CAN AFFORD
  // ============================================================

  /// فحص محلي للعرض فقط.
  ///
  /// لا يعتبر تصريحًا بتنفيذ الطلب.
  /// الـBackend يعيد التحقق من الرصيد لحظة تنفيذ AI.
  Future<bool> canAfford(
    int cost,
  ) async {
    await _ensureInitialized();

    if (cost <= 0) {
      return true;
    }

    return _credits >= cost;
  }

  // ============================================================
  // SERVER CREDIT COSTS
  // ============================================================

  /// تكلفة الرسالة النصية.
  ///
  /// متوافقة مع CreditsConfig وBackend:
  /// text = 1
  int get textCost =>
      CreditsConfig.textMessageCost;

  /// تكلفة تحليل صورة.
  ///
  /// متوافقة مع CreditsConfig وBackend:
  /// image_analysis = 3
  int get imageAnalysisCost =>
      CreditsConfig.imageAnalysisCost;

  /// تكلفة تحليل فيديو.
  ///
  /// متوافقة مع CreditsConfig وBackend:
  /// video_analysis = 5
  int get videoAnalysisCost =>
      CreditsConfig.videoAnalysisCost;

  /// تكلفة إنشاء صورة.
  ///
  /// متوافقة مع CreditsConfig وBackend:
  /// image_generation = 10
  int get imageGenerationCost =>
      CreditsConfig.imageGenerationCost;

  /// تكلفة تعديل صورة.
  ///
  /// الـBackend يستخدم حاليًا نفس تكلفة إنشاء الصورة:
  /// image_edit = 10
  ///
  /// لا نضيف قيمة ثانية إلى CreditsConfig حتى لا
  /// يكون لدينا مصدران مختلفان للأسعار.
  int get imageEditCost =>
      CreditsConfig.imageGenerationCost;

  // ============================================================
  // SPEND
  // ============================================================

  /// لم يعد التطبيق يخصم الرصيد محليًا.
  ///
  /// الخصم الحقيقي يتم داخل Backend:
  ///
  /// reserve → AI → commit
  ///
  /// لذلك هذه الدالة موجودة فقط للتوافق مع أي كود قديم.
  ///
  /// لا تستخدمها لإدارة Credits الجديدة.
  Future<bool> spend(
    int cost,
  ) async {
    await _ensureInitialized();

    if (cost <= 0) {
      return true;
    }

    /*
     * لا نخصم محليًا.
     *
     * السبب:
     * لو خصمنا هنا ثم خصم الـBackend مرة أخرى
     * سيُخصم الرصيد مرتين.
     *
     * كذلك لو فشل AI فلن نتمكن من معرفة
     * الحالة الحقيقية من الواجهة وحدها.
     */

    await refresh();

    return _credits >= cost;
  }

  // ============================================================
  // ADD
  // ============================================================

  /// لم يعد مسموحًا بإضافة Credits مباشرة من التطبيق.
  ///
  /// المكافآت الحقيقية يجب أن تأتي من السيرفر بعد
  /// التحقق من مصدر المكافأة.
  ///
  /// هذه الدالة متروكة للتوافق مع الكود القديم فقط.
  Future<int> add(
    int amount,
  ) async {
    await _ensureInitialized();

    if (amount <= 0) {
      return _credits;
    }

    /*
     * ممنوع تعديل الرصيد محليًا.
     *
     * أي إضافة حقيقية يجب أن تتم في Backend.
     */
    await refresh();

    return _credits;
  }

  // ============================================================
  // REWARDED ADS
  // ============================================================

  /// هل يمكن للمستخدم طلب إعلان مكافأة؟
  ///
  /// هذا فحص للواجهة فقط.
  /// التحقق النهائي يحدث على السيرفر
  /// بعد إثبات مشاهدة الإعلان.
  Future<bool> canClaimRewardedAd() async {
    await _ensureInitialized();

    /*
     * نحاول تحديث البيانات أولًا حتى لا تعتمد الواجهة
     * على Cache قديم.
     */
    await refresh();

    return remainingRewardedAdsToday > 0;
  }

  /// تسجيل مكافأة إعلان.
  ///
  /// IMPORTANT:
  /// لا نضيف Credits محليًا هنا.
  ///
  /// نظام المكافآت الحقيقي يتم من خلال:
  ///
  /// AdMob → SSV → Cloudflare Worker → Durable Object
  ///
  /// لذلك هذه الدالة لا تمنح Credits بنفسها.
  Future<bool> claimRewardedAd() async {
    await _ensureInitialized();

    /*
     * لا يوجد هنا:
     *
     * _credits += 10
     *
     * لأن ذلك يسمح بالتلاعب بالرصيد من التطبيق.
     *
     * AdMob SSV هو المسؤول عن إثبات المشاهدة،
     * والـBackend هو المسؤول عن إضافة Credits.
     */

    await refresh();

    return false;
  }

  // ============================================================
  // SERVER STATUS
  // ============================================================

  /// يجبر التطبيق على إعادة قراءة الرصيد الحقيقي.
  Future<int> syncFromServer() async {
    return refresh();
  }

  /// هل آخر مزامنة من السيرفر ناجحة؟
  bool get hasValidServerBalance =>
      _serverAvailable;

  // ============================================================
  // LOCAL CACHE
  // ============================================================

  void _loadLocalCache() {
    final prefs =
        _preferences;

    if (prefs == null) {
      return;
    }

    _credits =
        _sanitizeCredits(
      prefs.getInt(
            _creditsKey,
          ) ??
          0,
    );

    _rewardedAdsToday =
        _sanitizeRewardedCount(
      prefs.getInt(
            _rewardedCountKey,
          ) ??
          0,
    );

    final savedLimit =
        prefs.getInt(
      _rewardedLimitKey,
    );

    if (savedLimit != null &&
        savedLimit > 0) {
      _rewardedAdsDailyLimit =
          savedLimit;
    }

    final savedReward =
        prefs.getInt(
      _rewardedCreditsKey,
    );

    if (savedReward != null &&
        savedReward > 0) {
      _rewardedAdCredits =
          savedReward;
    }

    final savedSync =
        prefs.getString(
      _lastSyncKey,
    );

    if (savedSync != null) {
      _lastSync =
          DateTime.tryParse(
        savedSync,
      );
    }
  }

  Future<void> _saveLocalCache() async {
    final prefs =
        _preferences;

    if (prefs == null) {
      return;
    }

    await prefs.setInt(
      _creditsKey,
      _credits,
    );

    await prefs.setInt(
      _rewardedCountKey,
      _rewardedAdsToday,
    );

    await prefs.setInt(
      _rewardedLimitKey,
      _rewardedAdsDailyLimit,
    );

    await prefs.setInt(
      _rewardedCreditsKey,
      _rewardedAdCredits,
    );

    if (_lastSync != null) {
      await prefs.setString(
        _lastSyncKey,
        _lastSync!.toIso8601String(),
      );
    }
  }

  // ============================================================
  // DEVELOPMENT / TESTING
  // ============================================================

  /// يمسح الـCache المحلي فقط.
  ///
  /// لا يمسح الرصيد الحقيقي من السيرفر.
  Future<void> clearLocalData() async {
    await _ensureInitialized();

    final prefs =
        _preferences;

    if (prefs == null) {
      return;
    }

    await prefs.remove(
      _creditsKey,
    );

    await prefs.remove(
      _rewardedCountKey,
    );

    await prefs.remove(
      _rewardedLimitKey,
    );

    await prefs.remove(
      _rewardedCreditsKey,
    );

    await prefs.remove(
      _lastSyncKey,
    );

    _credits = 0;
    _rewardedAdsToday = 0;
    _lastSync = null;
    _lastError = null;

    /*
     * مهم:
     * لا ننشئ 100 Credits هنا.
     *
     * الـ100 Credits الأولى يتم إنشاؤها
     * داخل Durable Object فقط.
     */

    await refresh();
  }

  /// دالة قديمة كانت تعيد الرصيد إلى البداية.
  ///
  /// لم تعد تغير السيرفر.
  /// موجودة فقط لمنع كسر أي كود قديم.
  Future<void> resetToInitial() async {
    await _ensureInitialized();

    await refresh();
  }

  // ============================================================
  // SANITIZATION
  // ============================================================

  int _sanitizeCredits(
    int value,
  ) {
    if (value < 0) {
      return 0;
    }

    /*
     * لا نستخدم maximumLocalCredits كحد أمني
     * للرصيد الحقيقي.
     *
     * هذا مجرد Cache للعرض.
     */
    if (value >
        CreditsConfig.maximumLocalCredits) {
      return CreditsConfig.maximumLocalCredits;
    }

    return value;
  }

  int _sanitizeRewardedCount(
    int value,
  ) {
    if (value < 0) {
      return 0;
    }

    if (value >
        _rewardedAdsDailyLimit) {
      return _rewardedAdsDailyLimit;
    }

    return value;
  }
}
