/// مفاتيح ثابتة للخدمات داخل تطبيق صاحبي AI.
///
/// مهم:
/// لا نعتمد على اسم الخدمة الظاهر للمستخدم في تخزين المحادثات،
/// لأن الاسم العربي أو تغييره ممكن يعمل تعارض بين سجلات المحادثات.
///
/// كل خدمة لها ID ثابت لا يتغير حتى لو تغير الاسم أو التصميم.
class ServiceKeys {
  ServiceKeys._();

  // ============================================================
  // المحادثة العامة
  // ============================================================

  static const String general = 'general';

  // ============================================================
  // خلصانة AI
  // ============================================================

  static const String khalasana = 'khalasana';

  // ============================================================
  // أقسام صاحبي AI
  // ============================================================

  static const String kitchen = 'kitchen';

  static const String merchant = 'merchant';

  static const String pharmacy = 'pharmacy';

  static const String tradesperson = 'tradesperson';

  static const String worship = 'worship';

  static const String shopping = 'shopping';

  static const String social = 'social';

  static const String venting = 'venting';

  static const String hobbiesSports = 'hobbies_sports';

  static const String podcasts = 'podcasts';

  // ============================================================
  // أدوات مستقبلية
  // ============================================================

  static const String imageGeneration = 'image_generation';

  static const String news = 'news';

  static const String shorts = 'shorts';

  static const String audio = 'audio';

  // ============================================================
  // التحقق من المفتاح
  // ============================================================

  static bool isValid(String key) {
    switch (key) {
      case general:
      case khalasana:
      case kitchen:
      case merchant:
      case pharmacy:
      case tradesperson:
      case worship:
      case shopping:
      case social:
      case venting:
      case hobbiesSports:
      case podcasts:
      case imageGeneration:
      case news:
      case shorts:
      case audio:
        return true;

      default:
        return false;
    }
  }

  // ============================================================
  // قائمة الخدمات التي لها محادثة مستقلة
  // ============================================================

  static const List<String> chatServices = <String>[
    general,
    khalasana,
    kitchen,
    merchant,
    pharmacy,
    tradesperson,
    worship,
    shopping,
    social,
    venting,
    hobbiesSports,
    podcasts,
  ];
}
