import 'dart:async';

import 'package:flutter/foundation.dart';

enum HeroExpression {
  smile,
  sad,
  surprise,
  angry,
  blink,
}

enum HeroFaceCommandType {
  expression,
  viseme,
  reset,
}

@immutable
class HeroFaceCommand {
  const HeroFaceCommand({
    required this.type,
    this.animationName,
    this.loop = false,
  });

  final HeroFaceCommandType type;
  final String? animationName;
  final bool loop;
}

class HeroFaceRuntime {
  HeroFaceRuntime._();

  static final HeroFaceRuntime instance = HeroFaceRuntime._();

  final StreamController<HeroFaceCommand> _commands =
      StreamController<HeroFaceCommand>.broadcast(sync: true);

  final ValueNotifier<Set<String>> _availableAnimations =
      ValueNotifier<Set<String>>(const <String>{});

  Stream<HeroFaceCommand> get commands => _commands.stream;

  ValueListenable<Set<String>> get availableAnimations =>
      _availableAnimations;

  HeroFaceCommand? _lastCommand;

  HeroFaceCommand? get lastCommand => _lastCommand;

  static const Map<HeroExpression, String> expressionAnimationNames = {
    HeroExpression.smile: 'Hero_Face_Smile',
    HeroExpression.sad: 'Hero_Face_Sad',
    HeroExpression.surprise: 'Hero_Face_Surprise',
    HeroExpression.angry: 'Hero_Face_Angry',
    HeroExpression.blink: 'Hero_Face_Blink',
  };

  static const Map<String, String> visemeAnimationNames = {
    'sil': 'Hero_Viseme_sil',
    'PP': 'Hero_Viseme_PP',
    'FF': 'Hero_Viseme_FF',
    'TH': 'Hero_Viseme_TH',
    'DD': 'Hero_Viseme_DD',
    'kk': 'Hero_Viseme_kk',
    'CH': 'Hero_Viseme_CH',
    'SS': 'Hero_Viseme_SS',
    'nn': 'Hero_Viseme_nn',
    'RR': 'Hero_Viseme_RR',
    'aa': 'Hero_Viseme_aa',
    'E': 'Hero_Viseme_E',
    'I': 'Hero_Viseme_I',
    'O': 'Hero_Viseme_O',
    'U': 'Hero_Viseme_U',
  };

  static final Set<String> requiredFaceAnimationNames =
      Set<String>.unmodifiable({
    ...expressionAnimationNames.values,
    ...visemeAnimationNames.values,
  });

  void reportAvailableAnimations(Iterable<String> animations) {
    _availableAnimations.value =
        Set<String>.unmodifiable(animations);
  }

  void playExpression(HeroExpression expression) {
    final animationName = expressionAnimationNames[expression];

    if (animationName == null) return;

    _publish(
      HeroFaceCommand(
        type: HeroFaceCommandType.expression,
        animationName: animationName,
        loop: expression != HeroExpression.blink,
      ),
    );
  }

  void resetFace() {
    _publish(
      const HeroFaceCommand(
        type: HeroFaceCommandType.reset,
      ),
    );
  }

  void onSpeechStarted() {
    _publishViseme('sil');
  }

  void onSpeechWord(String word) {
    final viseme = visemeForWord(word);
    _publishViseme(viseme);
  }

  void onSpeechFinished() {
    resetFace();
  }

  void _publishViseme(String viseme) {
    final animationName = visemeAnimationNames[viseme];

    if (animationName == null) return;

    _publish(
      HeroFaceCommand(
        type: HeroFaceCommandType.viseme,
        animationName: animationName,
        loop: true,
      ),
    );
  }

  void _publish(HeroFaceCommand command) {
    _lastCommand = command;

    if (!_commands.isClosed) {
      _commands.add(command);
    }
  }

  static String visemeForWord(String word) {
    final value = word.trim().toLowerCase();

    if (value.isEmpty) return 'sil';

    // English combinations must be checked before the first character.
    if (value.startsWith('th')) return 'TH';
    if (value.startsWith('ch') || value.startsWith('sh')) {
      return 'CH';
    }

    final first = String.fromCharCode(value.runes.first);

    switch (first) {
      // Closed lips.
      case 'ب':
      case 'م':
      case 'پ':
      case 'p':
      case 'b':
      case 'm':
        return 'PP';

      // Teeth and lower lip.
      case 'ف':
      case 'ڤ':
      case 'f':
      case 'v':
        return 'FF';

      // Tongue between or near the teeth.
      case 'ث':
      case 'ذ':
      case 'ظ':
        return 'TH';

      // Tongue touching the teeth ridge.
      case 'ت':
      case 'د':
      case 'ط':
      case 'ض':
      case 't':
      case 'd':
        return 'DD';

      // Back of the tongue.
      case 'ك':
      case 'ق':
      case 'خ':
      case 'غ':
      case 'k':
      case 'g':
      case 'q':
      case 'c':
        return 'kk';

      // Affricate and shushing sounds.
      case 'ش':
      case 'ج':
      case 'چ':
      case 'j':
        return 'CH';

      // Hissing sounds.
      case 'س':
      case 'ص':
      case 'ز':
      case 's':
      case 'z':
        return 'SS';

      case 'ن':
      case 'n':
        return 'nn';

      case 'ر':
      case 'r':
        return 'RR';

      // Open mouth.
      case 'ا':
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ع':
      case 'ح':
      case 'ه':
      case 'ة':
      case 'a':
        return 'aa';

      case 'e':
        return 'E';

      case 'ي':
      case 'ى':
      case 'ئ':
      case 'i':
      case 'y':
        return 'I';

      case 'o':
        return 'O';

      case 'و':
      case 'ؤ':
      case 'u':
      case 'w':
        return 'U';

      default:
        return 'aa';
    }
  }
}
