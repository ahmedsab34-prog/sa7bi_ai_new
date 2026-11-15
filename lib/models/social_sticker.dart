
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

      if (decoded is! Map || decoded['version'] != 1) {
        return null;
      }

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

  static final List<Sa7biSticker> all =
      List<Sa7biSticker>.unmodifiable(
    <Sa7biSticker>[
      ..._makePack(
        packId: 'fun',
        packTitle: 'ضحك وهزار',
        palettes: const <List<int>>[
          [0xFFFFC857, 0xFFFF7B54],
          [0xFFFFA94D, 0xFFFF6B6B],
          [0xFFB197FC, 0xFF748FFC],
          [0xFFF783AC, 0xFFDA77F2],
          [0xFF74C0FC, 0xFF4DABF7],
        ],
        stickers: const <_StickerSeed>[
          _StickerSeed('laugh', '😂', 'ضحك للصبح', 'مش قادر أبطل ضحك'),
          _StickerSeed('lol', '🤣', 'وقعت من الضحك', 'ده أنا اتفصلت'),
          _StickerSeed('silly', '🤪', 'هزار رسمي', 'بهزر يا نجم'),
          _StickerSeed('oops', '🙈', 'مكسوف شوية', 'اعتبرني ما قلتش'),
          _StickerSeed('prank', '😎', 'داخل أروش', 'الروشنة وصلت'),
          _StickerSeed('facepalm', '🤦', 'يا نهار أبيض', 'إيه اللي أنا سمعته ده؟'),
          _StickerSeed('giggle', '🤭', 'ضحكة مستخبية', 'ضحكت من غير ما أحس'),
          _StickerSeed('tears_laugh', '😂😭', 'دموع الضحك', 'ضحك لحد الدموع'),
          _StickerSeed('tongue', '😛', 'لسان طويل', 'هزار على خفيف'),
          _StickerSeed('cool_glasses', '🕶️', 'الروش وصل', 'خليك في حالك يا نجم'),
          _StickerSeed('clown', '🤡', 'مهرج اللحظة', 'أنا اللي عملت كده؟'),
          _StickerSeed('monkey_hide', '🙊', 'مش سامع', 'أنا ماليش دعوة'),
          _StickerSeed('wink', '😉', 'غمزة صاحبي', 'فاهمني طبعًا'),
          _StickerSeed('grin', '😁', 'ابتسامة عريضة', 'الدنيا فل'),
          _StickerSeed('smirk', '😏', 'نظرة ثقة', 'عارف أنا بعمل إيه'),
          _StickerSeed('sweat_smile', '😅', 'عدت على خير', 'الحمد لله جت سليمة'),
          _StickerSeed('party', '🥳', 'يلا نحتفل', 'الفرحة مش سايعانا'),
          _StickerSeed('laugh_scream', '🤣🤣', 'انفجار ضحك', 'مش قادر أوقف'),
          _StickerSeed('goofy', '🥴', 'مش مركز', 'الدنيا لفت بيا'),
          _StickerSeed('wink_star', '🤩', 'نجم النجوم', 'يا سلام على الروقان'),
        ],
      ),
      ..._makePack(
        packId: 'feelings',
        packTitle: 'مشاعر',
        palettes: const <List<int>>[
          [0xFFFF8787, 0xFFE64980],
          [0xFFFF6B6B, 0xFFC92A2A],
          [0xFF91A7FF, 0xFF5C7CFA],
          [0xFFFFD8A8, 0xFFFF922B],
          [0xFFDAF5E8, 0xFF20C997],
        ],
        stickers: const <_StickerSeed>[
          _StickerSeed('love', '🥰', 'محبة صاحبي', 'إنت غالي عندي'),
          _StickerSeed('heart', '❤️', 'من القلب', 'كل الحب ليك'),
          _StickerSeed('miss', '🥹', 'وحشتني', 'فينك يا صاحبي؟'),
          _StickerSeed('sad', '😢', 'زعلان', 'محتاج كلمة حلوة'),
          _StickerSeed('hug', '🤗', 'حضن كبير', 'خد حضن يا بطل'),
          _StickerSeed('blush', '☺️', 'كسوف جميل', 'كسفتني يا صاحبي'),
          _StickerSeed('kiss', '😘', 'بوسة ليك', 'خد أحلى بوسة'),
          _StickerSeed('heart_eyes', '😍', 'عيون قلب', 'إيه الجمال ده؟'),
          _StickerSeed('hearts', '💞', 'حب في حب', 'قلبي كله ليك'),
          _StickerSeed('broken_heart', '💔', 'قلبي واجعني', 'يا رب تعدي على خير'),
          _StickerSeed('comfort', '🫂', 'أنا معاك', 'مش هسيبك لوحدك'),
          _StickerSeed('cry_loud', '😭', 'دموعي نازلة', 'محتاج حضن'),
          _StickerSeed('angry', '😡', 'متضايق', 'أنا مش مبسوط'),
          _StickerSeed('steam', '😤', 'مكتوم', 'أعصابي تعبت'),
          _StickerSeed('lonely', '🥺', 'محتاجك', 'طمني عليك'),
          _StickerSeed('shy', '😊', 'مكسوف', 'مش عارف أقول إيه'),
          _StickerSeed('sparkle_love', '💖', 'حلو وجودك', 'وجودك مفرحني'),
          _StickerSeed('hand_heart', '🫶', 'قلب بإيدك', 'كل قلبي ليك'),
          _StickerSeed('calm', '😌', 'راحة بال', 'ربنا يريح قلبك'),
          _StickerSeed('burning_love', '❤️‍🔥', 'حب مولع', 'الحب كله هنا'),
        ],
      ),
      ..._makePack(
        packId: 'reactions',
        packTitle: 'ردود سريعة',
        palettes: const <List<int>>[
          [0xFF69DB7C, 0xFF2F9E44],
          [0xFF8CE99A, 0xFF37B24D],
          [0xFF74C0FC, 0xFF339AF0],
          [0xFFFFE066, 0xFFF08C00],
          [0xFFB197FC, 0xFF6741D9],
        ],
        stickers: const <_StickerSeed>[
          _StickerSeed('ok', '👌', 'تمام', 'تمام يا كبير'),
          _StickerSeed('yes', '✅', 'موافق', 'اتفقنا'),
          _StickerSeed('no', '🙅', 'لأ', 'مش المرة دي'),
          _StickerSeed('wow', '🤩', 'واو', 'إبداع يا صاحبي'),
          _StickerSeed('thinking', '🤔', 'بفكر', 'خليني أفكر'),
          _StickerSeed('clap', '👏', 'تصفيق', 'برافو عليك'),
          _StickerSeed('fire', '🔥', 'جامد جدًا', 'إنت مولعها'),
          _StickerSeed('suspect', '🤨', 'بصراحة؟', 'إنت متأكد؟'),
          _StickerSeed('shush', '🤫', 'سر بينا', 'ما تقولش لحد'),
          _StickerSeed('sleep', '😴', 'نعسان', 'تصبح على خير'),
          _StickerSeed('sick', '🤒', 'مش قادر', 'محتاج أرتاح'),
          _StickerSeed('thinking_hard', '🧐', 'بدقق', 'خليني أتأكد'),
          _StickerSeed('shrug', '🤷', 'مش عارف', 'معرفش والله'),
          _StickerSeed('eyes', '👀', 'شايفك', 'أنا متابع'),
          _StickerSeed('hundred', '💯', 'مية مية', 'كلام مظبوط'),
          _StickerSeed('check', '☑️', 'تم التنفيذ', 'خلصنا يا بطل'),
          _StickerSeed('cross', '❌', 'مش موافق', 'لأ مش كده'),
          _StickerSeed('wave', '👋', 'سلام سريع', 'أشوفك على خير'),
          _StickerSeed('star_eyes', '🤩', 'مبهور', 'مش طبيعي'),
          _StickerSeed('pray', '🙏', 'يا رب', 'ربنا يسهل'),
        ],
      ),
      ..._makePack(
        packId: 'support',
        packTitle: 'تشجيع ودعم',
        palettes: const <List<int>>[
          [0xFFFFE066, 0xFFF08C00],
          [0xFF8CE99A, 0xFF2B8A3E],
          [0xFF74C0FC, 0xFF4263EB],
          [0xFFB197FC, 0xFF7048E8],
          [0xFF96F2D7, 0xFF20C997],
        ],
        stickers: const <_StickerSeed>[
          _StickerSeed('champ', '🏆', 'بطل', 'إنت قدها'),
          _StickerSeed('strong', '💪', 'قوي', 'كمل يا وحش'),
          _StickerSeed('star', '🌟', 'نجم', 'منور الدنيا'),
          _StickerSeed('rocket', '🚀', 'انطلق', 'المستقبل ليك'),
          _StickerSeed('medal', '🥇', 'المركز الأول', 'تستاهل الذهب'),
          _StickerSeed('crown', '👑', 'ملك', 'إنت الملك'),
          _StickerSeed('diamond', '💎', 'ماسي', 'قيمة كبيرة'),
          _StickerSeed('muscle_plus', '🏋️', 'قوة وعزيمة', 'كل يوم أقوى'),
          _StickerSeed('brain', '🧠', 'دماغ عالية', 'تفكير ممتاز'),
          _StickerSeed('genius', '🤓', 'عبقري', 'فكرة عبقرية'),
          _StickerSeed('books', '📚', 'اتعلم', 'العلم نور'),
          _StickerSeed('target', '🎯', 'في الهدف', 'جبتها صح'),
          _StickerSeed('bulb', '💡', 'فكرة جديدة', 'عاش التفكير'),
          _StickerSeed('trophy', '🏅', 'فخور بيك', 'إنجاز عظيم'),
          _StickerSeed('fist_bump', '🤜🤛', 'إيد واحدة', 'إحنا فريق واحد'),
          _StickerSeed('handshake', '🤝', 'اتفاق رجالة', 'كلمتنا واحدة'),
          _StickerSeed('proud', '✨', 'فخور بيك', 'مستواك بيتحسن'),
          _StickerSeed('money', '🤑', 'كسبان', 'رزق واسع يا رب'),
          _StickerSeed('fireworks', '🎆', 'نجاح', 'الفرحة كبيرة'),
          _StickerSeed('finish', '🏁', 'وصلت', 'كملت للآخر'),
        ],
      ),
      ..._makePack(
        packId: 'greetings',
        packTitle: 'تحيات',
        palettes: const <List<int>>[
          [0xFF96F2D7, 0xFF20C997],
          [0xFFFFE066, 0xFFFF922B],
          [0xFF748FFC, 0xFF364FC7],
          [0xFFFFD8A8, 0xFFF06595],
          [0xFFB2F2BB, 0xFF40C057],
        ],
        stickers: const <_StickerSeed>[
          _StickerSeed('hello', '👋', 'أهلًا', 'يا ميت أهلا'),
          _StickerSeed('morning', '☀️', 'صباح الخير', 'صباحك جميل'),
          _StickerSeed('night', '🌙', 'تصبح على خير', 'ليلة هادية عليك'),
          _StickerSeed('thanks', '🙏', 'شكرًا', 'متشكر يا صاحبي'),
          _StickerSeed('welcome', '🤗', 'نورت', 'البيت بيتك'),
          _StickerSeed('sunrise', '🌅', 'صباح النور', 'يومك كله خير'),
          _StickerSeed('evening', '🌃', 'مساء الخير', 'مساءك سعيد'),
          _StickerSeed('bye', '🙋', 'سلام', 'أشوفك قريب'),
          _StickerSeed('hi_five', '🙌', 'تحياتي', 'أهلا بصاحبي'),
          _StickerSeed('hello_hands', '👐', 'أهلًا وسهلًا', 'نورت مكانك'),
          _StickerSeed('weekend', '🏖️', 'إجازة سعيدة', 'استمتع بوقتك'),
          _StickerSeed('friday', '🕌', 'جمعة مباركة', 'ربنا يجعلها جمعة خير'),
          _StickerSeed('congrats', '🎉', 'مبروك', 'فرحتلك من قلبي'),
          _StickerSeed('birthday', '🎂', 'كل سنة وانت طيب', 'سنة حلوة عليك'),
          _StickerSeed('new_year', '🎊', 'سنة سعيدة', 'كل سنة وانت بخير'),
          _StickerSeed('coffee', '☕', 'قهوة الصباح', 'قهوتك جاهزة'),
          _StickerSeed('tea', '🫖', 'كوباية شاي', 'تعالى نروق'),
          _StickerSeed('rose', '🌹', 'وردة ليك', 'تستاهل كل خير'),
          _StickerSeed('peace', '✌️', 'سلام ومحبة', 'المحبة تجمعنا'),
          _StickerSeed('blessing', '🤲', 'دعوة حلوة', 'ربنا يسعد أيامك'),
        ],
      ),
    ],
  );

  static List<Sa7biSticker> _makePack({
    required String packId,
    required String packTitle,
    required List<_StickerSeed> stickers,
    required List<List<int>> palettes,
  }) {
    return List<Sa7biSticker>.generate(
      stickers.length,
      (index) {
        final seed = stickers[index];
        final palette = palettes[index % palettes.length];

        return Sa7biSticker(
          id: seed.id,
          packId: packId,
          packTitle: packTitle,
          emoji: seed.emoji,
          title: seed.title,
          caption: seed.caption,
          startColor: palette[0],
          endColor: palette[1],
        );
      },
      growable: false,
    );
  }

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

class _StickerSeed {
  const _StickerSeed(
    this.id,
    this.emoji,
    this.title,
    this.caption,
  );

  final String id;
  final String emoji;
  final String title;
  final String caption;
}
