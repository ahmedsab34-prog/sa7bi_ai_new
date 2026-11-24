import 'package:flutter_test/flutter_test.dart';

import '../lib/services/audio_volume_ducker.dart';

void main() {
  group('AudioVolumeDucker', () {
    test('keeps the initial user volume', () {
      final ducker = AudioVolumeDucker(
        initialVolume: 0.7,
      );

      expect(ducker.userVolume, 0.7);
      expect(ducker.effectiveVolume, 0.7);
      expect(ducker.isDucked, isFalse);
    });

    test('reduces volume temporarily and restores it', () {
      final ducker = AudioVolumeDucker(
        initialVolume: 0.8,
        duckFactor: 0.35,
      );

      expect(ducker.beginDuck(), closeTo(0.28, 0.000001));
      expect(ducker.isDucked, isTrue);
      expect(ducker.userVolume, 0.8);

      expect(ducker.endDuck(), 0.8);
      expect(ducker.isDucked, isFalse);
      expect(ducker.userVolume, 0.8);
    });

    test('preserves volume changes made during ducking', () {
      final ducker = AudioVolumeDucker(
        initialVolume: 0.8,
        duckFactor: 0.35,
      );

      ducker.beginDuck();

      expect(
        ducker.setUserVolume(0.6),
        closeTo(0.21, 0.000001),
      );

      expect(ducker.userVolume, 0.6);
      expect(ducker.isDucked, isTrue);

      expect(ducker.endDuck(), 0.6);
      expect(ducker.userVolume, 0.6);
    });

    test('clamps user volume to the supported range', () {
      final ducker = AudioVolumeDucker();

      expect(ducker.setUserVolume(-1.0), 0.0);
      expect(ducker.userVolume, 0.0);

      expect(ducker.setUserVolume(2.0), 1.0);
      expect(ducker.userVolume, 1.0);
    });

    test('supports mute while ducking', () {
      final ducker = AudioVolumeDucker(
        initialVolume: 0.5,
      );

      expect(ducker.beginDuck(), closeTo(0.175, 0.000001));
      expect(ducker.setUserVolume(0.0), 0.0);
      expect(ducker.endDuck(), 0.0);
      expect(ducker.userVolume, 0.0);
    });

    test('repeated duck and restore calls are safe', () {
      final ducker = AudioVolumeDucker(
        initialVolume: 0.65,
      );

      ducker.beginDuck();
      ducker.beginDuck();

      expect(ducker.effectiveVolume, closeTo(0.2275, 0.000001));

      ducker.endDuck();
      ducker.endDuck();

      expect(ducker.effectiveVolume, 0.65);
      expect(ducker.isDucked, isFalse);
    });

    test('rejects non-finite volume values', () {
      final ducker = AudioVolumeDucker();

      expect(
        () => ducker.setUserVolume(double.nan),
        throwsArgumentError,
      );

      expect(
        () => ducker.setUserVolume(double.infinity),
        throwsArgumentError,
      );
    });

    test('rejects an invalid duck factor', () {
      expect(
        () => AudioVolumeDucker(duckFactor: -0.1),
        throwsArgumentError,
      );

      expect(
        () => AudioVolumeDucker(duckFactor: 1.1),
        throwsArgumentError,
      );
    });
  });
}
