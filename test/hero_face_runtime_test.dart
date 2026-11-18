import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/hero_face_runtime.dart';

void main() {
  group('HERO animation contract', () {
    test('declares six expression names and fifteen visemes', () {
      expect(
        HeroFaceRuntime.expressionAnimationNames.values,
        containsAll({
          'HERO_FACE_SMILE',
          'HERO_FACE_SAD',
          'HERO_FACE_SURPRISE',
          'HERO_FACE_ANGRY',
          'HERO_FACE_WINK',
          'HERO_FACE_BLINK',
        }),
      );
      expect(HeroFaceRuntime.expressionAnimationNames, hasLength(6));
      expect(HeroFaceRuntime.requiredVisemeAnimationNames, hasLength(15));
      expect(
        HeroFaceRuntime.requiredVisemeAnimationNames,
        containsAll({
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
        }),
      );
      expect(HeroFaceRuntime.requiredFaceAnimationNames, hasLength(21));
    });

    test('maps common Arabic starting sounds to their visemes', () {
      expect(HeroFaceRuntime.visemeForWord('مرحبا'), 'PP');
      expect(HeroFaceRuntime.visemeForWord('فكرة'), 'FF');
      expect(HeroFaceRuntime.visemeForWord('ثلاثة'), 'TH');
      expect(HeroFaceRuntime.visemeForWord('تبدأ'), 'DD');
      expect(HeroFaceRuntime.visemeForWord('كلمة'), 'kk');
      expect(HeroFaceRuntime.visemeForWord('شمس'), 'CH');
      expect(HeroFaceRuntime.visemeForWord('سلام'), 'SS');
      expect(HeroFaceRuntime.visemeForWord('نور'), 'nn');
      expect(HeroFaceRuntime.visemeForWord('رائع'), 'RR');
      expect(HeroFaceRuntime.visemeForWord('أهلاً'), 'aa');
      expect(HeroFaceRuntime.visemeForWord('يوم'), 'I');
      expect(HeroFaceRuntime.visemeForWord('وقت'), 'U');
    });

    test('ignores Arabic diacritics and tatweel', () {
      expect(HeroFaceRuntime.visemeForWord('مُحَمَّد'), 'PP');
      expect(HeroFaceRuntime.visemeForWord('ـفكرة'), 'FF');
      expect(HeroFaceRuntime.visemeForWord('َ'), 'sil');
    });

    test('maps English combinations before individual letters', () {
      expect(HeroFaceRuntime.visemeForWord('throne'), 'TH');
      expect(HeroFaceRuntime.visemeForWord('show'), 'CH');
      expect(HeroFaceRuntime.visemeForWord('phone'), 'FF');
      expect(HeroFaceRuntime.visemeForWord('red'), 'RR');
      expect(HeroFaceRuntime.visemeForWord('open'), 'O');
      expect(HeroFaceRuntime.visemeForWord(''), 'sil');
    });
  });

  group('HERO runtime and 3D Lite status', () {
    late HeroFaceRuntime runtime;

    setUp(() {
      runtime = HeroFaceRuntime.instance;
      runtime.reportAvailableAnimations(const {
        'Hero_Idle',
        'Hero_Welcome',
        'Hero_Power',
      });
      runtime.onSpeechFinished();
    });

    test('publishes expression commands and updates the Lite mood', () async {
      final events = <HeroFaceCommand>[];
      final subscription = runtime.commands.listen(events.add);

      runtime.playExpression(HeroExpression.smile);
      expect(runtime.liteStatus.value.expression, HeroExpression.smile);

      runtime.playExpression(HeroExpression.neutral);
      await subscription.cancel();

      expect(events, hasLength(2));
      expect(events.first.type, HeroFaceCommandType.expression);
      expect(events.first.animationName, 'HERO_FACE_SMILE');
      expect(events.first.loop, isTrue);
      expect(events.last.type, HeroFaceCommandType.reset);
      expect(runtime.liteStatus.value.expression, HeroExpression.neutral);
    });

    test('keeps wink and blink as one-shot compatibility commands', () async {
      final events = <HeroFaceCommand>[];
      final subscription = runtime.commands.listen(events.add);

      runtime.playExpression(HeroExpression.wink);
      runtime.playExpression(HeroExpression.blink);
      await subscription.cancel();

      expect(events, hasLength(2));
      expect(events[0].animationName, 'HERO_FACE_WINK');
      expect(events[1].animationName, 'HERO_FACE_BLINK');
      expect(events.every((event) => !event.loop), isTrue);
    });

    test('publishes viseme events and updates the speaking indicator', () async {
      final events = <HeroFaceCommand>[];
      final subscription = runtime.commands.listen(events.add);

      runtime.onSpeechStarted();
      expect(runtime.liteStatus.value.isSpeaking, isTrue);

      runtime.onSpeechWord('سلام');
      expect(runtime.liteStatus.value.isSpeaking, isTrue);
      expect(runtime.liteStatus.value.activeViseme, 'SS');

      runtime.onSpeechFinished();
      await subscription.cancel();

      expect(events, hasLength(3));
      expect(events[0].type, HeroFaceCommandType.reset);
      expect(events[1].type, HeroFaceCommandType.viseme);
      expect(events[1].animationName, 'HERO_VISEME_SS');
      expect(events[2].type, HeroFaceCommandType.reset);
      expect(runtime.liteStatus.value.isSpeaking, isFalse);
      expect(runtime.liteStatus.value.activeViseme, 'sil');
    });

    test('does not require a face rig for the Lite status to work', () {
      expect(runtime.hasAnimation('Hero_Idle'), isTrue);
      expect(runtime.isFaceRigAvailable, isFalse);

      runtime.onSpeechStarted();
      runtime.onSpeechWord('مرحبا');

      expect(runtime.liteStatus.value.isSpeaking, isTrue);
      expect(runtime.liteStatus.value.activeViseme, 'PP');
      expect(runtime.isFaceRigAvailable, isFalse);
    });

    test('reports actual available animations without assuming facial clips', () {
      expect(runtime.isFaceRigAvailable, isFalse);
      expect(runtime.missingRequiredAnimations, isNotEmpty);

      runtime.reportAvailableAnimations({
        ...HeroFaceRuntime.requiredFaceAnimationNames,
        'Hero_Idle',
        'Hero_Welcome',
        'Hero_Power',
      });

      expect(runtime.isFaceRigAvailable, isTrue);
      expect(runtime.missingRequiredAnimations, isEmpty);
    });
  });
}
