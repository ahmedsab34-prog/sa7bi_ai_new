import 'package:flutter/material.dart';

/// مسؤول عن تحديد مظهر المحادثة حسب موضوع الكلام.
///
/// لا يقوم بتغيير واجهة ChatScreen مباشرة.
/// هو فقط يحدد الثيم المناسب، بحيث نقدر لاحقًا نخلي:
/// - الخلفية تتغير
/// - لون الفقاعات يتغير
/// - أيقونة الذكاء الاصطناعي تتغير
/// - الإضاءة والحركة تتغير
///
/// وكل ده بدون تكرار الكود داخل ChatScreen.
class ChatThemeService {
  ChatThemeService._();

  // ============================================================
  // الثيمات الأساسية
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

  static ChatThemeData detectFromText(
    String text, {
    String serviceKey = 'general',
  }) {
    final value = text.trim().toLowerCase();

    if (value.isEmpty) {
      return forService(serviceKey);
    }

    // خلصانة تظل ديناميكية، حتى لو الموضوع تغير داخلها.
    if (serviceKey == 'khalasana') {
      return _detectDynamicTopic(value);
    }

    // لو المستخدم داخل خدمة معينة، نحافظ على هوية الخدمة.
    if (serviceKey != 'general') {
      return forService(serviceKey);
    }

    return _detectDynamicTopic(value);
  }

  static ChatThemeData _detectDynamicTopic(String text) {
    if (_containsAny(text, <String>[
      'طبخ',
      'اكل',
      'أكل',
      'مطبخ',
      'وصفة',
      'وصفات',
      'كشري',
      'مكرونة',
      'رز',
      'فراخ',
      'لحمة',
    ])) {
      return kitchen();
    }

    if (_containsAny(text, <String>[
      'بيع',
      'شراء',
      'تجارة',
      'مشروع',
      'متجر',
      'محل',
      'زبون',
      'عميل',
      'سعر',
      'مبيعات',
      'تسويق',
    ])) {
      return merchant();
    }

    if (_containsAny(text, <String>[
      'صيدلية',
      'دواء',
      'أدوية',
      'علاج',
      'فيتامين',
      'أعشاب',
      'عشبة',
      'صيدلي',
    ])) {
      return pharmacy();
    }

    if (_containsAny(text, <String>[
      'كهرباء',
      'سباكة',
      'سباك',
      'نجار',
      'تصليح',
      'صيانة',
      'تكييف',
      'غسالة',
      'ثلاجة',
      'كمبيوتر',
      'موبايل',
    ])) {
      return tradesperson();
    }

    if (_containsAny(text, <String>[
      'صلاة',
      'قرآن',
      'قران',
      'ذكر',
      'أذكار',
      'اذكار',
      'دعاء',
      'دعاء',
      'مسجد',
      'عبادة',
      'رمضان',
    ])) {
      return worship();
    }

    if (_containsAny(text, <String>[
      'شراء',
      'اشتري',
      'أشتري',
      'منتج',
      'منتجات',
      'أمازون',
      'امازون',
      'جوميا',
      'نون',
      'سلة',
      'مقاس',
    ])) {
      return shopping();
    }

    if (_containsAny(text, <String>[
      'فيسبوك',
      'انستجرام',
      'انستغرام',
      'واتساب',
      'تيليجرام',
      'اصحاب',
      'أصحاب',
      'صديق',
      'صداقة',
      'سوشيال',
    ])) {
      return social();
    }

    if (_containsAny(text, <String>[
      'متضايق',
      'مضايق',
      'زعلان',
      'حزين',
      'فضفضة',
      'فضفضه',
      'مش مبسوط',
      'تعبان نفسيًا',
      'تعبان نفسيا',
      'مشكلة شخصية',
    ])) {
      return venting();
    }

    if (_containsAny(text, <String>[
      'رياضة',
      'رياضه',
      'كرة',
      'كورة',
      'جيم',
      'تمرين',
      'تمارين',
      'مباراة',
      'ماتش',
      'هواية',
      'هوايات',
    ])) {
      return hobbiesSports();
    }

    if (_containsAny(text, <String>[
      'بودكاست',
      'بود كاست',
      'تسجيل',
      'مايك',
      'صوت',
      'حلقة',
      'حلقات',
      'محتوى صوتي',
    ])) {
      return podcasts();
    }

    return khalasana();
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
