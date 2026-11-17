import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/hero_face_runtime.dart';

void main() {
  group('HERO face animation contract', () {
    test('declares the six reference expressions and fifteen visemes', () {
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
      expect(HeroFaceRuntime.requiredFaceAnimationNames, hasLength(21));
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

    test('ignores Arabic diacritics and long-vowel marks', () {
      expect(HeroFaceRuntime.visemeForWord('مُحَمَّد'), 'PP');
      expect(HeroFaceRuntime.visemeForWord('ـفكرة'), 'FF');
      expect(HeroFaceRuntime.visemeForWord('َ'), 'sil');
    });

    test('maps English combinations before single letters', () {
      expect(HeroFaceRuntime.visemeForWord('throne'), 'TH');
      expect(HeroFaceRuntime.visemeForWord('show'), 'CH');
      expect(HeroFaceRuntime.visemeForWord('phone'), 'FF');
      expect(HeroFaceRuntime.visemeForWord('red'), 'RR');
      expect(HeroFaceRuntime.visemeForWord('open'), 'O');
      expect(HeroFaceRuntime.visemeForWord(''), 'sil');
    });
  });

  group('HERO face runtime events', () {
    late HeroFaceRuntime runtime;

    setUp(() {
      runtime = HeroFaceRuntime.instance;
      runtime.reportAvailableAnimations(const {
        'Hero_Idle',
        'Hero_Welcome',
        'Hero_Power',
      });
    });

    test('publishes a smile and then returns to neutral', () async {
      final events = <HeroFaceCommand>[];
      final subscription = runtime.commands.listen(events.add);

      runtime.playExpression(HeroExpression.smile);
      runtime.playExpression(HeroExpression.neutral);

      await subscription.cancel();

      expect(events, hasLength(2));
      expect(events.first.type, HeroFaceCommandType.expression);
      expect(events.first.animationName, 'HERO_FACE_SMILE');
      expect(events.first.loop, isTrue);
      expect(events.last.type, HeroFaceCommandType.reset);
      expect(events.last.revision, greaterThan(events.first.revision));
    });

    test('plays wink and blink as one-shot movements', () async {
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

    test('publishes speech visemes using the shared stable names', () async {
      final events = <HeroFaceCommand>[];
      final subscription = runtime.commands.listen(events.add);

      runtime.onSpeechStarted();
      runtime.onSpeechWord('سلام');
      runtime.onSpeechFinished();

      await subscription.cancel();

      expect(events, hasLength(3));
      expect(events[0].type, HeroFaceCommandType.reset);
      expect(events[1].type, HeroFaceCommandType.viseme);
      expect(events[1].animationName, 'HERO_VISEME_SS');
      expect(events[2].type, HeroFaceCommandType.reset);
    });

    test('reports loaded animations instead of assuming a face rig exists', () {
      expect(runtime.hasAnimation('Hero_Idle'), isTrue);
      expect(runtime.isFaceRigAvailable, isFalse);
      expect(
        runtime.missingRequiredAnimations,
        contains('HERO_FACE_WINK'),
      );

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
