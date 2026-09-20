import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class Sa7biAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  Sa7biAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;

    await session.configure(
      const AudioSessionConfiguration.music(),
    );

    _player.playbackEventStream.listen(
      (event) {
        final processingState;

        switch (event.processingState) {
          case ProcessingState.idle:
            processingState = AudioProcessingState.idle;
            break;
          case ProcessingState.loading:
            processingState = AudioProcessingState.loading;
            break;
          case ProcessingState.buffering:
            processingState = AudioProcessingState.buffering;
            break;
          case ProcessingState.ready:
            processingState = AudioProcessingState.ready;
            break;
          case ProcessingState.completed:
            processingState = AudioProcessingState.completed;
            break;
        }

        final playing = _player.playing;

        playbackState.add(
          playbackState.value.copyWith(
            controls: [
              if (playing) MediaControl.pause else MediaControl.play,
              MediaControl.stop,
            ],
            systemActions: const {
              MediaAction.seek,
            },
            androidCompactActionIndices: const [0, 1],
            processingState: processingState,
            playing: playing,
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
            speed: _player.speed,
            queueIndex: _player.currentIndex,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
          ),
        );
      },
    );

    _player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= queue.value.length) {
        return;
      }

      mediaItem.add(queue.value[index]);
    });

    _player.positionStream.listen((position) {
      final current = playbackState.value;

      playbackState.add(
        current.copyWith(
          updatePosition: position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
        ),
      );
    });
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();

    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState: AudioProcessingState.idle,
        updatePosition: Duration.zero,
      ),
    );

    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    try {
      mediaItem.add(item);

      await _player.setUrl(item.id);

      await _player.play();
    } catch (e) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ),
      );
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    // Keep audio alive when the user removes the app from recent apps.
    // The Android foreground service handles continued playback.
  }

  Future<void> disposePlayer() async {
    await _player.dispose();
  }
}

class Sa7biAudioService {
  static AudioHandler? _handler;
  static Future<AudioHandler>? _initializing;

  static Future<AudioHandler> init() async {
    if (_handler != null) {
      return _handler!;
    }

    if (_initializing != null) {
      return _initializing!;
    }

    _initializing = _initialize();

    try {
      _handler = await _initializing!;
      return _handler!;
    } finally {
      _initializing = null;
    }
  }

  static Future<AudioHandler> _initialize() async {
    return AudioService.init(
      builder: () => Sa7biAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.sa7bi.ai.audio',
        androidNotificationChannelName: 'صحبي AI - الصوت',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  }

  static AudioHandler? get handler => _handler;
}
