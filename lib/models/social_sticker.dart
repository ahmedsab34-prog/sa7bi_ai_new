import 'dart:convert';

class Sa7biSticker {
  const Sa7biSticker({
    required this.id,
    required this.packId,
    required this.packTitle,
    required this.emoji,
    required this.title,
    required this.caption,
    required this.startColor,
    required this.endColor,
  });

  final String id;
  final String packId;
  final String packTitle;
  final String emoji;
  final String title;
  final String caption;
  final int startColor;
  final int endColor;

  static const String messagePrefix = 'sa7bi-sticker:v1:';

  String toMessageText() {
    final payload = jsonEncode(<String, dynamic>{
      'version': 1,
      'stickerId': id,
    });

    return '$messagePrefix${base64Url.encode(utf8.encode(payload))}';
  }

  static Sa7biSticker? tryParse(String value) {
    if (!value.startsWith(messagePrefix)) return null;

    try {
      final encoded = value.substring(messagePrefix.length);
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(encoded)),
      );

      if (decoded is! Map || decoded['version'] != 1) return null;

      final id = decoded['stickerId'];
      if (id is! String) return null;

      return Sa7biStickerCatalog.byId[id];
    } catch (_) {
      return null;
    }
  }
}

class Sa7biStickerCatalog {
  Sa7biStickerCatalog._();

  static const List<Sa7biSticker> all = <Sa7biSticker>[
    Sa7biSticker(
      id: 'laugh',
      packId: 'fun',
      packTitle: 'ضحك وهزار',
      emoji: '😂',
      title: 'ضحك للصبح',
      caption: 'مش قادر أبطل ضحك',
      startColor: 0xFFFFC857,
      endColor: 0xFFFF7B54,
    ),
    Sa7biSticker(
      id: 'lol',
      packId: 'fun',
      packTitle: 'ضحك وهزار',
      emoji: '🤣',
      title: 'وقعت من الضحك',
      caption: 'ده أنا اتفصلت',
      startColor: 0xFFFFA94D,
      endColor: 0xFFFF6B6B,
    ),
    Sa7biSticker(
      id: 'silly',
      packId: 'fun',
      packTitle: 'ضحك وهزار',
      emoji: '🤪',
      title: 'هزار رسمي',
      caption: 'بهزر يا نجم',
      startColor: 0xFFB197FC,
      endColor: 0xFF748FFC,
    ),
    Sa7biSticker(
      id: 'oops',
      packId: 'fun',
      packTitle: 'ضحك وهزار',
      emoji: '🙈',
      title: 'مكسوف شوية',
      caption: 'اعتبرني ما قلتش',
      startColor: 0xFFF783AC,
      endColor: 0xFFDA77F2,
    ),
    Sa7biSticker(
      id: 'prank',
      packId: 'fun',
      packTitle: 'ضحك وهزار',
      emoji: '😎',
      title: 'داخل أروش',
      caption: 'الروشنة وصلت',
      startColor: 0xFF74C0FC,
      endColor: 0xFF4DABF7,
    ),
    Sa7biSticker(
      id: 'facepalm',
      packId: 'fun',
      packTitle: 'ضحك وهزار',
      emoji: '🤦',
      title: 'يا نهار أبيض',
      caption: 'إيه اللي أنا سمعته ده؟',
      startColor: 0xFFFFD43B,
      endColor: 0FFF8C00,
    ),

    Sa7biSticker(
      id: 'love',
      packId: 'feelings',
      packTitle: 'مشاعر',
      emoji: '🥰',
      title: 'محبة صاحبي',
      caption: 'إنت غالي عندي',
      startColor: 0xFFFF8787,
      endColor: 0xFFE64980,
    ),
    Sa7biSticker(
      id: 'heart',
      packId: 'feelings',
      packTitle: 'مشاعر',
      emoji: '❤️',
      title: 'من القلب',
      caption: 'كل الحب ليك',
      startColor: 0xFFFF6B6B,
      endColor: 0xFFC92A2A,
    ),
    Sa7biSticker(
      id: 'miss',
      packId: 'feelings',
      packTitle: 'مشاعر',
      emoji: '🥹',
      title: 'وحشتني',
      caption: 'فينك يا صاحبي؟',
      startColor: 0xFF91A7FF,
      endColor: 0xFF5C7CFA,
    ),
    Sa7biSticker(
      id: 'sad',
      packId: 'feelings',
      packTitle: 'مشاعر',
      emoji: '😢',
      title: 'زعلان',
      caption: 'محتاج كلمة حلوة',
      startColor: 0xFF74C0FC,
      endColor: 0xFF339AF0,
    ),
    Sa7biSticker(
      id: 'hug',
      packId: 'feelings',
      packTitle: 'مشاعر',
      emoji: '🤗',
      title: 'حضن كبير',
      caption: 'خد حضن يا بطل',
      startColor: 0xFFFFD8A8,
      endColor: 0xFFFF922B,
    ),

    Sa7biSticker(
      id: 'ok',
      packId: 'reactions',
      packTitle: 'ردود سريعة',
      emoji: '👌',
      title: 'تمام',
      caption: 'تمام يا كبير',
      startColor: 0xFF69DB7C,
      endColor: 0xFF2F9E44,
    ),
    Sa7biSticker(
      id: 'yes',
      packId: 'reactions',
      packTitle: 'ردود سريعة',
      emoji: '✅',
      title: 'موافق',
      caption: 'اتفقنا',
      startColor: 0xFF8CE99A,
      endColor: 0xFF37B24D,
    ),
    Sa7biSticker(
      id: 'no',
      packId: 'reactions',
      packTitle: 'ردود سريعة',
      emoji: '🙅',
      title: 'لأ',
      caption: 'مش المرة دي',
      startColor: 0xFFFF8787,
      endColor: 0xFFE03131,
    ),
    Sa7biSticker(
      id: 'wow',
      packId: 'reactions',
      packTitle: 'ردود سريعة',
      emoji: '🤩',
      title: 'واو',
      caption: 'إبداع يا صاحبي',
      startColor: 0xFFFFE066,
      endColor: 0xFFF08C00,
    ),
    Sa7biSticker(
      id: 'thinking',
      packId: 'reactions',
      packTitle: 'ردود سريعة',
      emoji: '🤔',
      title: 'بفكر',
      caption: 'خليني أفكر',
      startColor: 0xFFA5D8FF,
      endColor: 0xFF4DABF7,
    ),

    Sa7biSticker(
      id: 'champ',
      packId: 'support',
      packTitle: 'تشجيع ودعم',
      emoji: '🏆',
      title: 'بطل',
      caption: 'إنت قدها',
      startColor: 0xFFFFE066,
      endColor: 0xFFF08C00,
    ),
    Sa7biSticker(
      id: 'strong',
      packId: 'support',
      packTitle: 'تشجيع ودعم',
      emoji: '💪',
      title: 'قوي',
      caption: 'كمل يا وحش',
      startColor: 0xFF8CE99A,
      endColor: 0xFF2B8A3E,
    ),
    Sa7biSticker(
      id: 'star',
      packId: 'support',
      packTitle: 'تشجيع ودعم',
      emoji: '🌟',
      title: 'نجم',
      caption: 'منور الدنيا',
      startColor: 0xFFFFE066,
      endColor: 0xFFFF922B,
    ),
    Sa7biSticker(
      id: 'rocket',
      packId: 'support',
      packTitle: 'تشجيع ودعم',
      emoji: '🚀',
      title: 'انطلق',
      caption: 'المستقبل ليك',
      startColor: 0xFF74C0FC,
      endColor: 0xFF4263EB,
    ),

    Sa7biSticker(
      id: 'hello',
      packId: 'greetings',
      packTitle: 'تحيات',
      emoji: '👋',
      title: 'أهلًا',
      caption: 'يا ميت أهلا',
      startColor: 0xFF96F2D7,
      endColor: 0xFF20C997,
    ),
    Sa7biSticker(
      id: 'morning',
      packId: 'greetings',
      packTitle: 'تحيات',
      emoji: '☀️',
      title: 'صباح الخير',
      caption: 'صباحك جميل',
      startColor: 0xFFFFE066,
      endColor: 0xFFFF922B,
    ),
    Sa7biSticker(
      id: 'night',
      packId: 'greetings',
      packTitle: 'تحيات',
      emoji: '🌙',
      title: 'تصبح على خير',
      caption: 'ليلة هادية عليك',
      startColor: 0xFF748FFC,
      endColor: 0xFF364FC7,
    ),
    Sa7biSticker(
      id: 'thanks',
      packId: 'greetings',
      packTitle: 'تحيات',
      emoji: '🙏',
      title: 'شكرًا',
      caption: 'متشكر يا صاحبي',
      startColor: 0xFFB2F2BB,
      endColor: 0xFF40C057,
    ),
  ];

  static final Map<String, Sa7biSticker> byId =
      <String, Sa7biSticker>{
    for (final sticker in all) sticker.id: sticker,
  };

  static List<String> get packTitles => all
      .map((sticker) => sticker.packTitle)
      .toSet()
      .toList(growable: false);

  static List<Sa7biSticker> forPack(String packTitle) {
    if (packTitle == 'الكل') return all;

    return all
        .where((sticker) => sticker.packTitle == packTitle)
        .toList(growable: false);
  }
}
