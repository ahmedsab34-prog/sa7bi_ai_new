import 'package:flutter/material.dart';

/// مسؤول عن تحديد مظهر المحادثة حسب موضوع الكلام.
///
/// المسؤولية هنا هي بيانات الثيم فقط:
/// - ألوان الخلفية.
/// - ألوان الفقاعات.
/// - لون الإضاءة.
/// - أيقونة AI.
/// - الحالة البصرية للمحادثة.
///
/// في خلصانة AI يمكن للثيم أن يتغير تلقائيًا
/// حسب موضوع الحوار الحالي، بدون تغيير شعار صاحبي AI.
class ChatThemeService {
  ChatThemeService._();

  // ============================================================
  // الثيم العام
  // ============================================================

  static ChatThemeData general() {
    return const ChatThemeData(
      id: 'general',
      name: 'عام',
      primary: Color(0xFF7C5CFF),
      secondary: Color(0xFF36D1DC),
      glow: Color(0xFF9C7BFF),
      backgroundTop: Color(0xFF080B18),
      backgroundBottom: Color(0xFF11152A),
      userBubble: Color(0xFF27345C),
      aiBubble: Color(0xFF171D34),
      aiIcon: Icons.auto_awesome_rounded,
      mood: ChatMood.normal,
    );
  }

  // ============================================================
  // خلصانة AI
  // ============================================================

  static ChatThemeData khalasana() {
    return const ChatThemeData(
      id: 'khalasana',
      name: 'خلصانة AI',
      primary: Color(0xFFFFD76A),
      secondary: Color(0xFF63E6FF),
      glow: Color(0xFF8B6CFF),
      backgroundTop: Color(0xFF050710),
      backgroundBottom: Color(0xFF10152A),
      userBubble: Color(0xFF26334D),
      aiBubble: Color(0xFF151B2D),
      aiIcon: Icons.auto_awesome_rounded,
      mood: ChatMood.dynamic,
    );
  }

  // ============================================================
  // المطبخ
  // ============================================================

  static ChatThemeData kitchen() {
    return const ChatThemeData(
      id: 'kitchen',
      name: 'المطبخ',
      primary: Color(0xFFFF9F43),
      secondary: Color(0xFFFFD166),
      glow: Color(0xFFFF6B35),
      backgroundTop: Color(0xFF17100A),
      backgroundBottom: Color(0xFF24170D),
      userBubble: Color(0xFF4A2D18),
      aiBubble: Color(0xFF2A1B10),
      aiIcon: Icons.restaurant_rounded,
      mood: ChatMood.warm,
    );
  }

  // ============================================================
  // التجارة
  // ============================================================

  static ChatThemeData merchant() {
    return const ChatThemeData(
      id: 'merchant',
      name: 'التجارة',
      primary: Color(0xFF35D07F),
      secondary: Color(0xFF6EE7B7),
      glow: Color(0xFF00B894),
      backgroundTop: Color(0xFF07150F),
      backgroundBottom: Color(0xFF0D241A),
      userBubble: Color(0xFF174B36),
      aiBubble: Color(0xFF10281E),
      aiIcon: Icons.storefront_rounded,
      mood: ChatMood.business,
    );
  }

  // ============================================================
  // الصحة والصيدلية
  // ============================================================

  static ChatThemeData pharmacy() {
    return const ChatThemeData(
      id: 'pharmacy',
      name: 'الصحة والصيدلية',
      primary: Color(0xFF55D6BE),
      secondary: Color(0xFF74B9FF),
      glow: Color(0xFF00CEC9),
      backgroundTop: Color(0xFF071416),
      backgroundBottom: Color(0xFF0C2225),
      userBubble: Color(0xFF16464A),
      aiBubble: Color(0xFF102A2D),
      aiIcon: Icons.local_pharmacy_rounded,
      mood: ChatMood.calm,
    );
  }

  // ============================================================
  // الصيانة والحرف
  // ============================================================

  static ChatThemeData tradesperson() {
    return const ChatThemeData(
      id: 'tradesperson',
      name: 'الصيانة والحرف',
      primary: Color(0xFFFFB84D),
      secondary: Color(0xFFB8C0FF),
      glow: Color(0xFFFF8C42),
      backgroundTop: Color(0xFF15120C),
      backgroundBottom: Color(0xFF252016),
      userBubble: Color(0xFF49361C),
      aiBubble: Color(0xFF2A2115),
      aiIcon: Icons.build_rounded,
      mood: ChatMood.technical,
    );
  }

  // ============================================================
  // العبادة
  // ============================================================

  static ChatThemeData worship() {
    return const ChatThemeData(
      id: 'worship',
      name: 'العبادة',
      primary: Color(0xFFD6B36A),
      secondary: Color(0xFF7ED6A5),
      glow: Color(0xFFC8A951),
      backgroundTop: Color(0xFF0C110D),
      backgroundBottom: Color(0xFF152017),
      userBubble: Color(0xFF29402F),
      aiBubble: Color(0xFF18271D),
      aiIcon: Icons.mosque_rounded,
      mood: ChatMood.calm,
    );
  }

  // ============================================================
  // التسوق
  // ============================================================

  static ChatThemeData shopping() {
    return const ChatThemeData(
      id: 'shopping',
      name: 'التسوق',
      primary: Color(0xFFFF5FA2),
      secondary: Color(0xFF8B7CFF),
      glow: Color(0xFFFF79B0),
      backgroundTop: Color(0xFF160A15),
      backgroundBottom: Color(0xFF24102A),
      userBubble: Color(0xFF4A1E46),
      aiBubble: Color(0xFF2C1630),
      aiIcon: Icons.shopping_bag_rounded,
      mood: ChatMood.shopping,
    );
  }

  // ============================================================
  // التواصل الاجتماعي
  // ============================================================

  static ChatThemeData social() {
    return const ChatThemeData(
      id: 'social',
      name: 'التواصل',
      primary: Color(0xFF5B8CFF),
      secondary: Color(0xFFB06CFF),
      glow: Color(0xFF6C63FF),
      backgroundTop: Color(0xFF090D1A),
      backgroundBottom: Color(0xFF17112B),
      userBubble: Color(0xFF263A68),
      aiBubble: Color(0xFF1C1934),
      aiIcon: Icons.people_alt_rounded,
      mood: ChatMood.social,
    );
  }

  // ============================================================
  // فضفضة
  // ============================================================

  static ChatThemeData venting() {
    return const ChatThemeData(
      id: 'venting',
      name: 'فضفضة',
      primary: Color(0xFFB388FF),
      secondary: Color(0xFF80CBC4),
      glow: Color(0xFF9575CD),
      backgroundTop: Color(0xFF0D0B17),
      backgroundBottom: Color(0xFF1A1425),
      userBubble: Color(0xFF3A2C51),
      aiBubble: Color(0xFF251C34),
      aiIcon: Icons.favorite_rounded,
      mood: ChatMood.emotional,
    );
  }

  // ============================================================
  // الهوايات والرياضة
  // ============================================================

  static ChatThemeData hobbiesSports() {
    return const ChatThemeData(
      id: 'hobbies_sports',
      name: 'الهوايات والرياضة',
      primary: Color(0xFF00D2FF),
      secondary: Color(0xFF3A7BD5),
      glow: Color(0xFF00E5FF),
      backgroundTop: Color(0xFF06121A),
      backgroundBottom: Color(0xFF0B2032),
      userBubble: Color(0xFF12415C),
      aiBubble: Color(0xFF0D293D),
      aiIcon: Icons.sports_soccer_rounded,
      mood: ChatMood.energetic,
    );
  }

  // ============================================================
  // البودكاست
  // ============================================================

  static ChatThemeData podcasts() {
    return const ChatThemeData(
      id: 'podcasts',
      name: 'البودكاست',
      primary: Color(0xFFFF6B9D),
      secondary: Color(0xFFFFB86C),
      glow: Color(0xFFFF4D88),
      backgroundTop: Color(0xFF160A12),
      backgroundBottom: Color(0xFF28131E),
      userBubble: Color(0xFF4B2036),
      aiBubble: Color(0xFF2C1724),
      aiIcon: Icons.mic_rounded,
      mood: ChatMood.media,
    );
  }

  // ============================================================
  // اختيار الثيم من مفتاح الخدمة
  // ============================================================

  static ChatThemeData forService(String serviceKey) {
    switch (serviceKey.trim().toLowerCase()) {
      case 'khalasana':
        return khalasana();

      case 'kitchen':
        return kitchen();

      case 'merchant':
        return merchant();

      case 'pharmacy':
        return pharmacy();

      case 'tradesperson':
        return tradesperson();

      case 'worship':
        return worship();

      case 'shopping':
        return shopping();

      case 'social':
        return social();

      case 'venting':
        return venting();

      case 'hobbies_sports':
        return hobbiesSports();

      case 'podcasts':
        return podcasts();

      default:
        return general();
    }
  }

  // ============================================================
  // اكتشاف موضوع المحادثة
  // ============================================================

  /// يحدد الثيم المناسب للنص الحالي.
  ///
  /// داخل الخدمات المتخصصة نحافظ على هوية الخدمة.
  /// داخل خلصانة AI نسمح للموضوع بالتغير.
  /// داخل المحادثة العامة يمكن أيضًا اكتشاف الموضوع.
  static ChatThemeData detectFromText(
    String text, {
    String serviceKey = 'general',
  }) {
    final value = _normalizeArabic(text);

    if (value.isEmpty) {
      return forService(serviceKey);
    }

    final normalizedServiceKey =
        serviceKey.trim().toLowerCase();

    // خلصانة AI هي المحادثة الديناميكية الرئيسية.
    if (normalizedServiceKey == 'khalasana') {
      return _detectDynamicTopic(value);
    }

    // الخدمات المتخصصة تحافظ على هويتها.
    if (normalizedServiceKey != 'general') {
      return forService(normalizedServiceKey);
    }

    return _detectDynamicTopic(value);
  }

  /// اكتشاف الموضوع داخل المحادثة الديناميكية.
  ///
  /// ترتيب القواعد مهم:
  /// نضع الموضوعات الأكثر تحديدًا قبل الكلمات العامة
  /// حتى لا يتم تصنيف "شراء منتج" كتجارة قبل التسوق.
  static ChatThemeData _detectDynamicTopic(String text) {
    // ----------------------------------------------------------
    // التسوق
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'شراء',
      'اشتري',
      'اشتري',
      'اشتري',
      'منتج',
      'منتجات',
      'اماوزن',
      'امازون',
      'جوميا',
      'نون',
      'سله',
      'سلة',
      'مقاس',
      'سعر المنتج',
      'عايز اشتري',
      'عاوزه اشتري',
      'عاوز اشتري',
      'محتاج اشتري',
      'فين اشتري',
      'منين اشتري',
    ])) {
      return shopping();
    }

    // ----------------------------------------------------------
    // المطبخ
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'طبخ',
      'اكل',
      'مطبخ',
      'وصفه',
      'وصفات',
      'كشري',
      'مكرونه',
      'رز',
      'فراخ',
      'لحمه',
      'طعام',
      'وجبه',
      'وجبات',
    ])) {
      return kitchen();
    }

    // ----------------------------------------------------------
    // الصيانة والحرف
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'كهرباء',
      'سباكه',
      'سباك',
      'نجار',
      'تصليح',
      'صيانه',
      'تكييف',
      'غساله',
      'ثلاجه',
      'كمبيوتر',
      'موبايل',
      'شاشه',
      'بوتجاز',
      'سخان',
    ])) {
      return tradesperson();
    }

    // ----------------------------------------------------------
    // الصحة والصيدلية
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'صيدليه',
      'دواء',
      'ادويه',
      'علاج',
      'فيتامين',
      'اعشاب',
      'عشبه',
      'صيدلي',
      'جرعه',
      'اعراض',
      'مرض',
    ])) {
      return pharmacy();
    }

    // ----------------------------------------------------------
    // العبادة
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'صلاه',
      'قران',
      'ذكر',
      'اذكار',
      'دعاء',
      'مسجد',
      'عباده',
      'رمضان',
      'صيام',
      'زكاه',
    ])) {
      return worship();
    }

    // ----------------------------------------------------------
    // فضفضة
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'متضايق',
      'مضايق',
      'زعلان',
      'حزين',
      'فضفضه',
      'فضفضه',
      'مش مبسوط',
      'تعبان نفسيا',
      'مشكله شخصيه',
      'حاسس بضيق',
      'مخنوق',
      'مخنوقه',
    ])) {
      return venting();
    }

    // ----------------------------------------------------------
    // الهوايات والرياضة
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'رياضه',
      'كره',
      'كوره',
      'جيم',
      'تمرين',
      'تمارين',
      'مباراه',
      'ماتش',
      'هوايه',
      'هوايات',
      'جري',
      'كمال اجسام',
    ])) {
      return hobbiesSports();
    }

    // ----------------------------------------------------------
    // البودكاست والصوت
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'بودكاست',
      'بود كاست',
      'تسجيل',
      'مايك',
      'حلقه',
      'حلقات',
      'محتوى صوتي',
      'محتوي صوتي',
    ])) {
      return podcasts();
    }

    // ----------------------------------------------------------
    // التواصل الاجتماعي
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'فيسبوك',
      'انستجرام',
      'انستغرام',
      'واتساب',
      'تيليجرام',
      'اصحاب',
      'صديق',
      'صداقه',
      'سوشيال',
      'ريلز',
      'تيك توك',
    ])) {
      return social();
    }

    // ----------------------------------------------------------
    // التجارة والمشروعات
    // ----------------------------------------------------------

    if (_containsAny(text, <String>[
      'بيع',
      'بيع منتجات',
      'تجاره',
      'مشروع',
      'متجر',
      'محل',
      'زبون',
      'عميل',
      'مبيعات',
      'تسويق',
      'براند',
      'هامش ربح',
      'ارباح',
    ])) {
      return merchant();
    }

    // لا يوجد موضوع واضح:
    // نرجع إلى الهوية الخاصة بخلصانة AI.
    return khalasana();
  }

  /// تطبيع بسيط للنص العربي لتقليل اختلافات الكتابة.
  ///
  /// لا يغير معنى النص؛ فقط يساعد على مطابقة الكلمات:
  /// أ / إ / آ -> ا
  /// ة -> ه
  /// ى -> ي
  /// يزيل التشكيل.
  static String _normalizeArabic(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _containsAny(
    String text,
    List<String> words,
  ) {
    for (final word in words) {
      if (text.contains(word)) {
        return true;
      }
    }

    return false;
  }
}

/// الحالة البصرية للمحادثة.
enum ChatMood {
  normal,
  dynamic,
  warm,
  business,
  calm,
  technical,
  shopping,
  social,
  emotional,
  energetic,
  media,
}

/// بيانات ثيم المحادثة.
class ChatThemeData {
  final String id;
  final String name;

  final Color primary;
  final Color secondary;
  final Color glow;

  final Color backgroundTop;
  final Color backgroundBottom;

  final Color userBubble;
  final Color aiBubble;

  final IconData aiIcon;

  final ChatMood mood;

  const ChatThemeData({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.glow,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.userBubble,
    required this.aiBubble,
    required this.aiIcon,
    required this.mood,
  });
}

ده التعديل الوحيد في الخطوة دي. بعد لصقه، ما تعملش أي ملف تاني دلوقتي؛ الخطوة التالية هنراجع "chat_dynamic_background.dart" لأنه هو اللي بيحوّل بيانات الثيم دي إلى خلفية متحركة فعلية.
