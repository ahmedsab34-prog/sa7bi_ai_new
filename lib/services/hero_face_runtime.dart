import 'dart:async';

import 'package:flutter/foundation.dart';

/// التعبيرات التي يستطيع التطبيق طلبها من مجسم HERO.
enum HeroExpression {
  neutral,
  smile,
  sad,
  surprise,
  angry,
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

/// جسر موحد بين الصوت وواجهة مجسم HERO.
///
/// لا يحرك هذا الملف صورة أو وجهًا بديلًا. يرسل أسماء حركات إلى عارض GLB
/// فقط عندما تكون الحركات موجودة فعلًا داخل الملف.
class HeroFaceRuntime {
  HeroFaceRuntime._();

  static final HeroFaceRuntime instance = HeroFaceRuntime._();

  static const Map<HeroExpression, String> expressionAnimationNames = {
    HeroExpression.smile: 'HERO_FACE_SMILE',
    HeroExpression.sad: 'HERO_FACE_SAD',
    HeroExpression.surprise: 'HERO_FACE_SURPRISE',
    HeroExpression.angry: 'HERO_FACE_ANGRY',
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

  static Set<String> get requiredFaceAnimationNames => {
        ...expressionAnimationNames.values,
        ...requiredVisemeAnimationNames,
      };

  final StreamController<HeroFaceCommand> _commands =
      StreamController<HeroFaceCommand>.broadcast(sync: true);

  final ValueNotifier<Set<String>> _availableAnimations =
      ValueNotifier<Set<String>>(<String>{});

  int _revision = 0;
  HeroFaceCommand? _lastCommand;

  Stream<HeroFaceCommand> get commands => _commands.stream;

  ValueListenable<Set<String>> get availableAnimations =>
      _availableAnimations;

  HeroFaceCommand? get lastCommand => _lastCommand;

  bool get isFaceRigAvailable =>
      requiredFaceAnimationNames.every(_availableAnimations.value.contains);

  bool hasAnimation(String name) =>
      _availableAnimations.value.contains(name);

  void reportAvailableAnimations(Iterable<String> names) {
    _availableAnimations.value = Set<String>.unmodifiable(
      names.where((name) => name.trim().isNotEmpty),
    );
  }

  void onSpeechStarted() {
    resetFace();
  }

  /// flutter_tts يرسل حدود الكلمات، لا حدود الفونيمات الدقيقة.
  /// نختار شكل فم تقريبيًا لكل كلمة إلى أن يتوفر مصدر توقيت للفونيمات.
  void onSpeechWord(String word) {
    final clean = word.trim();
    if (clean.isEmpty) return;

    final viseme = visemeForWord(clean);
    _emit(
      type: HeroFaceCommandType.viseme,
      animationName: 'HERO_VISEME_$viseme',
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
      loop: expression != HeroExpression.blink,
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

    if (!_commands.isClosed) {
      _commands.add(command);
    }
  }

  /// تحويل تقريبي للحرف الأول من الكلمة إلى Viseme.
  /// القيم متوافقة مع أسماء أهداف الوجه المحددة في مواصفات HERO.
  static String visemeForWord(String word) {
    final clean = word.trim();
    if (clean.isEmpty) return 'sil';

    final first = clean.runes.first;

    switch (first) {
      // إغلاق الشفتين: ب، م
      case 0x0628:
      case 0x0645:
        return 'PP';

      // الشفة مع الأسنان: ف
      case 0x0641:
        return 'FF';

      // اللسان بين الأسنان: ث، ذ، ظ
      case 0x062B:
      case 0x0630:
      case 0x0638:
        return 'TH';

      // مخارج د/ت/ط
      case 0x062F:
      case 0x062A:
      case 0x0637:
        return 'DD';

      // مؤخرة اللسان: ك، ق، خ
      case 0x0643:
      case 0x0642:
      case 0x062E:
        return 'kk';

      // أصوات الشين والجيم
      case 0x0634:
      case 0x062C:
        return 'CH';

      // الصفير: س، ص، ز
      case 0x0633:
      case 0x0635:
      case 0x0632:
        return 'SS';

      case 0x0646:
        return 'nn';

      case 0x0631:
      case 0x0644:
        return 'RR';

      // الفتح
      case 0x0627:
      case 0x0623:
      case 0x0625:
      case 0x0622:
        return 'aa';

      case 0x064A:
      case 0x0649:
        return 'I';

      case 0x0648:
        return 'U';
    }

    // دعم الكلمات الإنجليزية عند استخدام صوت غير عربي.
    final lower = clean.toLowerCase();
    final latin = lower.codeUnitAt(0);

    if (latin == 0x70 || latin == 0x62 || latin == 0x6D) return 'PP';
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
