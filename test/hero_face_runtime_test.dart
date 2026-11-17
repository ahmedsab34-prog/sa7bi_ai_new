import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/hero_face_runtime.dart';

void main() {
  group('HERO face animation contract', () {
    test('declares the five expression clips and fifteen viseme clips', () {
      expect(
        HeroFaceRuntime.expressionAnimationNames.values,
        containsAll({
          'HERO_FACE_SMILE',
          'HERO_FACE_SAD',
          'HERO_FACE_SURPRISE',
          'HERO_FACE_ANGRY',
          'HERO_FACE_BLINK',
        }),
      );

      expect(HeroFaceRuntime.requiredVisemeAnimationNames, hasLength(15));
      expect(HeroFaceRuntime.requiredFaceAnimationNames, hasLength(20));
    });

    test('maps common Arabic starting sounds to their viseme clips', () {
      expect(HeroFaceRuntime.visemeForWord('مرحبا'), 'PP');
      expect(HeroFaceRuntime.visemeForWord('فكرة'), 'FF');
      expect(HeroFaceRuntime.visemeForWord('ثلاثة'), 'TH');
      expect(HeroFaceRuntime.visemeForWord('شمس'), 'CH');
      expect(HeroFaceRuntime.visemeForWord('سلام'), 'SS');
      expect(HeroFaceRuntime.visemeForWord('نور'), 'nn');
      expect(HeroFaceRuntime.visemeForWord('رائع'), 'RR');
      expect(HeroFaceRuntime.visemeForWord('أهلاً'), 'aa');
      expect(HeroFaceRuntime.visemeForWord('يوم'), 'I');
      expect(HeroFaceRuntime.visemeForWord('وقت'), 'U');
    });

    test('maps English starting sounds and handles empty input safely', () {
      expect(HeroFaceRuntime.visemeForWord('red'), 'RR');
      expect(HeroFaceRuntime.visemeForWord('open'), 'O');
      expect(HeroFaceRuntime.visemeForWord(''), 'sil');
    });
  });

  group('HERO face runtime events', () {
    test('publishes an expression and returns to the neutral rest pose', () async {
      final runtime = HeroFaceRuntime.instance;
      final events = <HeroFaceCommand>[];
      final subscription = runtime.commands.listen(events.add);

      runtime.playExpression(HeroExpression.smile);
      runtime.resetFace();

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(events, hasLength(2));
      expect(events.first.type, HeroFaceCommandType.expression);
      expect(events.first.animationName, 'HERO_FACE_SMILE');
      expect(events.first.loop, isTrue);
      expect(events.last.type, HeroFaceCommandType.reset);
    });

    test('reports the actual animations exposed by the loaded GLB', () {
      final runtime = HeroFaceRuntime.instance;
      runtime.reportAvailableAnimations({
        'Hero_Idle',
        'Hero_Welcome',
        'Hero_Power',
      });

      expect(runtime.hasAnimation('Hero_Idle'), isTrue);
      expect(runtime.isFaceRigAvailable, isFalse);
    });
  });
}
