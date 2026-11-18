
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../lib/services/audio_focus_coordinator.dart';

void main() {
  group('AudioFocusCoordinator', () {
    test('stops all registered speech engines independently', () async {
      final ownerA = Object();
      final ownerB = Object();
      final events = <String>[];

      AudioFocusCoordinator.registerSpeechController(
        ownerA,
        () async {
          events.add('engine-a');
          throw StateError('simulated TTS failure');
        },
      );

      AudioFocusCoordinator.registerSpeechController(
        ownerB,
        () async {
          events.add('engine-b');
        },
      );

      addTearDown(() {
        AudioFocusCoordinator.unregisterSpeechController(ownerA);
        AudioFocusCoordinator.unregisterSpeechController(ownerB);
      });

      await AudioFocusCoordinator.stopAllSpeech();

      expect(events, ['engine-a', 'engine-b']);
    });

    test('stops speech and media before starting new speech', () async {
      final owner = Object();
      final events = <String>[];

      AudioFocusCoordinator.registerSpeechController(
        owner,
        () async {
          events.add('stop-old-speech');
        },
      );

      addTearDown(
        () => AudioFocusCoordinator.unregisterSpeechController(owner),
      );

      await AudioFocusCoordinator.runWithSpeechFocus<void>(
        stopMediaPlayback: () async {
          events.add('stop-media');
        },
        startSpeech: () async {
          events.add('start-new-speech');
        },
      );

      expect(
        events,
        [
          'stop-old-speech',
          'stop-media',
          'start-new-speech',
        ],
      );
    });

    test('does not start speech when media playback cannot stop', () async {
      final owner = Object();
      var speechStarted = false;

      AudioFocusCoordinator.registerSpeechController(
        owner,
        () async {},
      );

      addTearDown(
        () => AudioFocusCoordinator.unregisterSpeechController(owner),
      );

      await expectLater(
        AudioFocusCoordinator.runWithSpeechFocus<void>(
          stopMediaPlayback: () async {
            throw StateError('media stop failed');
          },
          startSpeech: () async {
            speechStarted = true;
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(speechStarted, isFalse);
    });

    test('serializes overlapping speech focus operations', () async {
      final releaseFirst = Completer<void>();
      final firstStarted = Completer<void>();
      final events = <String>[];

      final first = AudioFocusCoordinator.runWithSpeechFocus<void>(
        stopMediaPlayback: () async {
          events.add('stop-media-1');
        },
        startSpeech: () async {
          events.add('start-1');
          firstStarted.complete();
          await releaseFirst.future;
        },
      );

      await firstStarted.future;

      final second = AudioFocusCoordinator.runWithSpeechFocus<void>(
        stopMediaPlayback: () async {
          events.add('stop-media-2');
        },
        startSpeech: () async {
          events.add('start-2');
        },
      );

      expect(events, ['stop-media-1', 'start-1']);

      releaseFirst.complete();

      await Future.wait([first, second]);

      expect(
        events,
        [
          'stop-media-1',
          'start-1',
          'stop-media-2',
          'start-2',
        ],
      );
    });
  });
}
