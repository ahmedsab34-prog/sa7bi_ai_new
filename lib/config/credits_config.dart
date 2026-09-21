/// إعدادات نظام الرصيد في صاحبي AI.
///
/// كل أسعار الاستخدام موجودة هنا في مكان واحد حتى لا نضطر
/// لتعديل ChatScreen أو أي شاشة أخرى كل مرة نغيّر فيها التكلفة.
///
/// لا يحتوي هذا الملف على أي مفاتيح سرية.
class CreditsConfig {
  CreditsConfig._();

  // ============================================================
  // الرصيد الابتدائي
  // ============================================================

  /// الرصيد الذي يحصل عليه المستخدم الجديد.
  static const int initialCredits = 100;

  // ============================================================
  // تكلفة استخدام الذكاء الاصطناعي
  // ============================================================

  /// تكلفة رسالة نصية عادية.
  static const int textMessageCost = 1;

  /// تكلفة تحليل صورة يرسلها المستخدم للذكاء الاصطناعي.
  static const int imageAnalysisCost = 3;

  /// تكلفة تحليل فيديو عندما يتم دعم التحليل الحقيقي من الـBackend.
  static const int videoAnalysisCost = 5;

  /// Speech-to-Text المحلي لا يحتاج حاليًا إلى طلب مدفوع من الـBackend.
  static const int speechToTextCost = 0;

  /// TTS المحلي لا يحتاج حاليًا إلى Credits.
  static const int textToSpeechCost = 0;

  // ============================================================
  // إنشاء الصور
  // ============================================================

  /// تكلفة إنشاء صورة بالذكاء الاصطناعي.
  static const int imageGenerationCost = 10;

  // ============================================================
  // مكافآت الإعلانات
  // ============================================================

  /// عدد الـCredits بعد مشاهدة إعلان مكافأة.
  static const int rewardedAdCredits = 10;

  /// الحد الأقصى لمرات مكافأة الإعلان يوميًا.
  static const int rewardedAdDailyLimit = 5;

  // ============================================================
  // الحماية المحلية
  // ============================================================

  /// الحد الأقصى المحلي للرصيد.
  ///
  /// الحماية النهائية للرصيد والاستخدام ستكون من الـBackend أيضًا.
  static const int maximumLocalCredits = 9999;

  // ============================================================
  // مساعدات الرصيد
  // ============================================================

  /// هل الرصيد الحالي يكفي للتكلفة؟
  static bool canAfford(
    int currentCredits,
    int cost,
  ) {
    if (cost <= 0) {
      return true;
    }

    return currentCredits >= cost;
  }

  /// خصم Credits بدون السماح برصيد سالب.
  static int subtract(
    int currentCredits,
    int cost,
  ) {
    if (cost <= 0) {
      return currentCredits;
    }

    final result = currentCredits - cost;

    if (result < 0) {
      return 0;
    }

    return result;
  }

  /// إضافة Credits مع احترام الحد الأقصى.
  static int add(
    int currentCredits,
    int amount,
  ) {
    if (amount <= 0) {
      return currentCredits;
    }

    final result = currentCredits + amount;

    if (result > maximumLocalCredits) {
      return maximumLocalCredits;
    }

    return result;
  }
}
