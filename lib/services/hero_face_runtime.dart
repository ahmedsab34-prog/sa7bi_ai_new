import 'dart:async';

import 'package:flutter/foundation.dart';

/// تعبيرات الوجه المطلوبة لشخصية HERO الواحدة.
/// neutral هو وضع الراحة ولا يحتاج إلى Animation Clip منفصل.
enum HeroExpression {
  neutral,
  smile,
  sad,
  surprise,
  angry,
  wink,
  blink,
}

enum HeroFaceCommandType {
  reset,
  expression,
  viseme,
}

@immutable
class HeroFaceCommand {
  const HeroFaceCommand({
    required this.revision,
    required this.type,
    this.animationName,
    this.loop = false,
  });

  /// رقم متزايد لتمييز الأمر الأحدث عن أي أمر قديم متأخر.
  final int revision;
  final HeroFaceCommandType type;
  final String? animationName;
  final bool loop;
}

/// الجسر الموحد بين أحداث الصوت وحركات الوجه المضمّنة داخل ملف HERO GLB.
///
/// هذا الملف لا يرسم وجهًا بديلًا ولا يغيّر صورة الشخصية. هو يرسل أسماء
/// Animation Clips إلى Model Viewer فقط؛ لذلك لا تظهر حركة حقيقية إلا بعد
/// تضمين الـClips المطلوبة داخل assets/3d/sa7bi_hero.glb.
class HeroFaceRuntime {
  HeroFaceRuntime._();

  static final HeroFaceRuntime instance = HeroFaceRuntime._();

  /// أسماء ثابتة يجب أن تطابق أسماء الـAnimations داخل ملف GLB حرفيًا.
  static const Map<HeroExpression, String> expressionAnimationNames = {
    HeroExpression.smile: 'HERO_FACE_SMILE',
    HeroExpression.sad: 'HERO_FACE_SAD',
    HeroExpression.surprise: 'HERO_FACE_SURPRISE',
    HeroExpression.angry: 'HERO_FACE_ANGRY',
    HeroExpression.wink: 'HERO_FACE_WINK',
    HeroExpression.blink: 'HERO_FACE_BLINK',
  };

  /// Visemes الخمسة عشر المتفق عليها بين Blender وFlutter.
  static const Set<String> requiredVisemeAnimationNames = {
    'HERO_VISEME_sil',
    'HERO_VISEME_PP',
    'HERO_VISEME_FF',
    'HERO_VISEME_TH',
    'HERO_VISEME_DD',
    'HERO_VISEME_kk',
    'HERO_VISEME_CH',
    'HERO_VISEME_SS',
    'HERO_VISEME_nn',
    'HERO_VISEME_RR',
    'HERO_VISEME_aa',
    'HERO_VISEME_E',
    'HERO_VISEME_I',
    'HERO_VISEME_O',
    'HERO_VISEME_U',
  };

  /// ست حركات وجه فعلية: ابتسامة، حزن، دهشة، غضب، غمزة، ورمشة.
  /// الوضع الطبيعي Neutral هو وضع الأوزان صفر ويُنفّذ بأمر reset.
  static Set<String> get requiredFaceAnimationNames =>
      Set<String>.unmodifiable({
        ...expressionAnimationNames.values,
        ...requiredVisemeAnimationNames,
      });

  final StreamController<HeroFaceCommand> _commands =
      StreamController<HeroFaceCommand>.broadcast(sync: true);

  final ValueNotifier<Set<String>> _availableAnimations =
      ValueNotifier<Set<String>>(const <String>{});

  int _revision = 0;
  HeroFaceCommand? _lastCommand;

  Stream<HeroFaceCommand> get commands => _commands.stream;

  ValueListenable<Set<String>> get availableAnimations =>
      _availableAnimations;

  HeroFaceCommand? get lastCommand => _lastCommand;

  bool get isFaceRigAvailable =>
      requiredFaceAnimationNames.every(_availableAnimations.value.contains);

  bool hasAnimation(String name) => _availableAnimations.value.contains(name);

  Set<String> get missingRequiredAnimations =>
      Set<String>.unmodifiable(
        requiredFaceAnimationNames.difference(_availableAnimations.value),
      );

  void reportAvailableAnimations(Iterable<String> names) {
    _availableAnimations.value = Set<String>.unmodifiable(
      names.where((name) => name.trim().isNotEmpty),
    );
  }

  /// بداية الكلام تعيد الوجه إلى وضع الراحة قبل أول حركة فم.
  void onSpeechStarted() {
    resetFace();
  }

  /// Flutter TTS يرسل حدود الكلمات، وليس توقيت كل فونيم على حدة.
  /// لذلك هذا اختيار Viseme تقريبي للكلمة، وليس Lip Sync فونيميًا دقيقًا.
  void onSpeechWord(String word) {
    final viseme = visemeForWord(word);
    final animationName = 'HERO_VISEME_$viseme';
    if (!requiredVisemeAnimationNames.contains(animationName)) return;

    _emit(
      type: HeroFaceCommandType.viseme,
      animationName: animationName,
    );
  }

  void onSpeechFinished() {
    resetFace();
  }

  void playExpression(HeroExpression expression) {
    if (expression == HeroExpression.neutral) {
      resetFace();
      return;
    }

    final animationName = expressionAnimationNames[expression];
    if (animationName == null) return;

    _emit(
      type: HeroFaceCommandType.expression,
      animationName: animationName,
      // الابتسامة والحزن والدهشة والغضب حالات مستمرة حتى اختيار غيرها.
      // الغمزة والرمشة حركتان قصيرتان لمرة واحدة.
      loop: expression != HeroExpression.wink &&
          expression != HeroExpression.blink,
    );
  }

  void resetFace() {
    _emit(type: HeroFaceCommandType.reset);
  }

  void _emit({
    required HeroFaceCommandType type,
    String? animationName,
    bool loop = false,
  }) {
    final command = HeroFaceCommand(
      revision: ++_revision,
      type: type,
      animationName: animationName,
      loop: loop,
    );

    _lastCommand = command;
    if (!_commands.isClosed) _commands.add(command);
  }

  /// يحذف التشكيل والتطويل قبل تحليل أول حرف عربي.
  static String _normalizeWord(String word) {
    final withoutMarks = word.runes.where((rune) {
      final isArabicMark =
          (rune >= 0x064B && rune <= 0x065F) || rune == 0x0670;
      return !isArabicMark && rune != 0x0640;
    });
    return String.fromCharCodes(withoutMarks).trim();
  }

  /// تحويل تقريبي لصوت بداية الكلمة إلى Viseme متوافق مع مواصفات HERO.
  /// لا يحل محل مصدر phoneme timing حقيقي عند توفره.
  static String visemeForWord(String word) {
    final clean = _normalizeWord(word);
    if (clean.isEmpty) return 'sil';

    final lower = clean.toLowerCase();

    // التركيبات الإنجليزية المركبة تُفحص قبل الحرف الأول.
    if (lower.startsWith('th')) return 'TH';
    if (lower.startsWith('ch') || lower.startsWith('sh')) return 'CH';
    if (lower.startsWith('ph')) return 'FF';

    final first = clean.runes.first;
    switch (first) {
      // إغلاق الشفتين.
      case 0x0628: // ب
      case 0x0645: // م
      case 0x067E: // پ
        return 'PP';

      // الشفة السفلى مع الأسنان.
      case 0x0641: // ف
      case 0x06A4: // ڤ
        return 'FF';

      // اللسان بين الأسنان.
      case 0x062B: // ث
      case 0x0630: // ذ
      case 0x0638: // ظ
        return 'TH';

      // طرف اللسان عند الأسنان/اللثة.
      case 0x062A: // ت
      case 0x062F: // د
      case 0x0637: // ط
      case 0x0636: // ض
        return 'DD';

      // مؤخرة اللسان.
      case 0x0643: // ك
      case 0x0642: // ق
      case 0x062E: // خ
      case 0x063A: // غ
        return 'kk';

      // أصوات الشين والجيم.
      case 0x0634: // ش
      case 0x062C: // ج
      case 0x0686: // چ
        return 'CH';

      // أصوات الصفير.
      case 0x0633: // س
      case 0x0635: // ص
      case 0x0632: // ز
        return 'SS';

      case 0x0646: // ن
        return 'nn';

      case 0x0631: // ر
      case 0x0644: // ل
        return 'RR';

      // فتح الفم.
      case 0x0627: // ا
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0639: // ع
      case 0x062D: // ح
      case 0x0647: // ه
      case 0x0629: // ة
        return 'aa';

      case 0x064A: // ي
      case 0x0649: // ى
      case 0x0626: // ئ
        return 'I';

      case 0x0648: // و
      case 0x0624: // ؤ
        return 'U';
    }

    // دعم الإنجليزية عند استخدام TTS بلغة غير العربية.
    final latin = lower.codeUnitAt(0);
    if (latin == 0x70 || latin == 0x62 || latin == 0x6D) return 'PP'; // p b m
    if (latin == 0x66 || latin == 0x76) return 'FF'; // f v
    if (latin == 0x74 || latin == 0x64) return 'DD'; // t d
    if (latin == 0x6B || latin == 0x67 || latin == 0x71) return 'kk'; // k g q
    if (latin == 0x63 || latin == 0x6A) return 'CH'; // c j
    if (latin == 0x73 || latin == 0x7A) return 'SS'; // s z
    if (latin == 0x6E) return 'nn'; // n
    if (latin == 0x72 || latin == 0x6C) return 'RR'; // r l
    if (latin == 0x61) return 'aa'; // a
    if (latin == 0x65) return 'E'; // e
    if (latin == 0x69 || latin == 0x79) return 'I'; // i y
    if (latin == 0x6F) return 'O'; // o
    if (latin == 0x75 || latin == 0x77) return 'U'; // u w

    return 'sil';
  }
}
