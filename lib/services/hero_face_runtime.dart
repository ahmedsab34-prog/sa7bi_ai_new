import 'dart:async';

import 'package:flutter/foundation.dart';

/// حالات التفاعل المرئية لشخصية HERO في وضع 3D Lite.
/// هذه الحالات تغيّر واجهة التفاعل حول المجسم، ولا تحرّك شبكة الوجه نفسها.
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

  final int revision;
  final HeroFaceCommandType type;
  final String? animationName;
  final bool loop;
}

/// حالة عرض خفيفة تستهلكها واجهة HERO 3D Lite.
/// activeViseme رمز صوتي تقريبي للكلمة الحالية، وليس حركة فم داخل GLB.
/// activeWord هو نص الكلمة التي أرسلها محرك TTS في آخر تحديث.
@immutable
class HeroLiteStatus {
  const HeroLiteStatus({
    this.isSpeaking = false,
    this.activeViseme = 'sil',
    this.activeWord = '',
    this.expression = HeroExpression.neutral,
    this.revision = 0,
  });

  final bool isSpeaking;
  final String activeViseme;
  final String activeWord;
  final HeroExpression expression;
  final int revision;
}

/// يجمع أوامر HERO القديمة مع حالة العرض الخفيفة.
///
/// في وضع 3D Lite نستخدم حركات الجسم الموجودة في GLB، ونزامن مؤشرًا بصريًا
/// حول المجسم مع حدود الكلمات التي يرسلها TTS. لا نفترض وجود Face Rig أو
/// Morph Targets أو Animation Clips للوجه داخل ملف المجسم الحالي.
class HeroFaceRuntime {
  HeroFaceRuntime._();

  static final HeroFaceRuntime instance = HeroFaceRuntime._();

  static const Map<HeroExpression, String> expressionAnimationNames = {
    HeroExpression.smile: 'HERO_FACE_SMILE',
    HeroExpression.sad: 'HERO_FACE_SAD',
    HeroExpression.surprise: 'HERO_FACE_SURPRISE',
    HeroExpression.angry: 'HERO_FACE_ANGRY',
    HeroExpression.wink: 'HERO_FACE_WINK',
    HeroExpression.blink: 'HERO_FACE_BLINK',
  };

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

  /// أسماء توافقية محفوظة للمرحلة المستقبلية التي قد تضيف تحريك وجه حقيقيًا.
  /// عدم وجودها داخل GLB لا يمنع تشغيل وضع 3D Lite.
  static Set<String> get requiredFaceAnimationNames =>
      Set<String>.unmodifiable({
        ...expressionAnimationNames.values,
        ...requiredVisemeAnimationNames,
      });

  final StreamController<HeroFaceCommand> _commands =
      StreamController<HeroFaceCommand>.broadcast(sync: true);

  final ValueNotifier<Set<String>> _availableAnimations =
      ValueNotifier<Set<String>>(const <String>{});

  final ValueNotifier<HeroLiteStatus> _liteStatus =
      ValueNotifier<HeroLiteStatus>(const HeroLiteStatus());

  int _revision = 0;
  HeroFaceCommand? _lastCommand;

  Stream<HeroFaceCommand> get commands => _commands.stream;

  ValueListenable<Set<String>> get availableAnimations =>
      _availableAnimations;

  ValueListenable<HeroLiteStatus> get liteStatus => _liteStatus;

  HeroFaceCommand? get lastCommand => _lastCommand;

  bool get isFaceRigAvailable =>
      requiredFaceAnimationNames.every(_availableAnimations.value.contains);

  bool hasAnimation(String name) => _availableAnimations.value.contains(name);

  Set<String> get missingRequiredAnimations => Set<String>.unmodifiable(
        requiredFaceAnimationNames.difference(_availableAnimations.value),
      );

  void reportAvailableAnimations(Iterable<String> names) {
    _availableAnimations.value = Set<String>.unmodifiable(
      names.where((name) => name.trim().isNotEmpty),
    );
  }

  void onSpeechStarted() {
    _updateLiteStatus(
      isSpeaking: true,
      activeViseme: 'sil',
      activeWord: '',
      expression: HeroExpression.neutral,
    );
    resetFace();
  }

  /// يستقبل حدود الكلمات من TTS ويحدّث الكلمة والرمز الصوتي مع كل كلمة.
  ///
  /// في 3D Lite تتحول هذه البيانات إلى مؤشر مرئي حول المجسم،
  /// وليست تحريكًا فعليًا للفم داخل ملف GLB.
  void onSpeechWord(String word) {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return;

    final viseme = visemeForWord(cleanWord);
    final animationName = 'HERO_VISEME_$viseme';

    if (!requiredVisemeAnimationNames.contains(animationName)) return;

    _updateLiteStatus(
      isSpeaking: true,
      activeViseme: viseme,
      activeWord: cleanWord,
    );

    _emit(
      type: HeroFaceCommandType.viseme,
      animationName: animationName,
    );
  }

  void onSpeechFinished() {
    _updateLiteStatus(
      isSpeaking: false,
      activeViseme: 'sil',
      activeWord: '',
      expression: HeroExpression.neutral,
    );
    resetFace();
  }

  /// في 3D Lite يغيّر هذا الاختيار رمز/لون/هالة التفاعل في الواجهة.
  /// لا يدّعي تعديل ملامح الوجه داخل المجسم.
  void playExpression(HeroExpression expression) {
    if (expression == HeroExpression.neutral) {
      _updateLiteStatus(expression: HeroExpression.neutral);
      resetFace();
      return;
    }

    _updateLiteStatus(expression: expression);

    final animationName = expressionAnimationNames[expression];
    if (animationName == null) return;

    _emit(
      type: HeroFaceCommandType.expression,
      animationName: animationName,
      loop: expression != HeroExpression.wink &&
          expression != HeroExpression.blink,
    );
  }

  void resetFace() {
    _updateLiteStatus(
      activeViseme: 'sil',
      expression: HeroExpression.neutral,
    );
    _emit(type: HeroFaceCommandType.reset);
  }

  void _updateLiteStatus({
    bool? isSpeaking,
    String? activeViseme,
    String? activeWord,
    HeroExpression? expression,
  }) {
    final previous = _liteStatus.value;

    _liteStatus.value = HeroLiteStatus(
      isSpeaking: isSpeaking ?? previous.isSpeaking,
      activeViseme: activeViseme ?? previous.activeViseme,
      activeWord: activeWord ?? previous.activeWord,
      expression: expression ?? previous.expression,
      revision: previous.revision + 1,
    );
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

  static String _normalizeWord(String word) {
    final withoutMarks = word.runes.where((rune) {
      final isArabicMark =
          (rune >= 0x064B && rune <= 0x065F) || rune == 0x0670;
      return !isArabicMark && rune != 0x0640;
    });

    return String.fromCharCodes(withoutMarks).trim();
  }

  /// يحوّل بداية الكلمة إلى Viseme تقريبي للعربية والإنجليزية.
  static String visemeForWord(String word) {
    final clean = _normalizeWord(word);
    if (clean.isEmpty) return 'sil';

    final lower = clean.toLowerCase();

    if (lower.startsWith('th')) return 'TH';
    if (lower.startsWith('ch') || lower.startsWith('sh')) return 'CH';
    if (lower.startsWith('ph')) return 'FF';

    final first = clean.runes.first;

    switch (first) {
      case 0x0628: // ب
      case 0x0645: // م
      case 0x067E: // پ
        return 'PP';

      case 0x0641: // ف
      case 0x06A4: // ڤ
        return 'FF';

      case 0x062B: // ث
      case 0x0630: // ذ
      case 0x0638: // ظ
        return 'TH';

      case 0x062A: // ت
      case 0x062F: // د
      case 0x0637: // ط
      case 0x0636: // ض
        return 'DD';

      case 0x0643: // ك
      case 0x0642: // ق
      case 0x062E: // خ
      case 0x063A: // غ
        return 'kk';

      case 0x0634: // ش
      case 0x062C: // ج
      case 0x0686: // چ
        return 'CH';

      case 0x0633: // س
      case 0x0635: // ص
      case 0x0632: // ز
        return 'SS';

      case 0x0646: // ن
        return 'nn';

      case 0x0631: // ر
      case 0x0644: // ل
        return 'RR';

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

    final latin = lower.codeUnitAt(0);

    if (latin == 0x70 || latin == 0x62 || latin == 0x6D) {
      return 'PP';
    }
    if (latin == 0x66 || latin == 0x76) return 'FF';
    if (latin == 0x74 || latin == 0x64) return 'DD';
    if (latin == 0x6B || latin == 0x67 || latin == 0x71) return 'kk';
    if (latin == 0x63 || latin == 0x6A) return 'CH';
    if (latin == 0x73 || latin == 0x7A) return 'SS';
    if (latin == 0x6E) return 'nn';
    if (latin == 0x72 || latin == 0x6C) return 'RR';
    if (latin == 0x61) return 'aa';
    if (latin == 0x65) return 'E';
    if (latin == 0x69 || latin == 0x79) return 'I';
    if (latin == 0x6F) return 'O';
    if (latin == 0x75 || latin == 0x77) return 'U';

    return 'sil';
  }
}
