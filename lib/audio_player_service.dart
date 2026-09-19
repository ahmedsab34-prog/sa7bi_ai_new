import 'dart:async';
import 'dart:io';

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
        _broadcastState();

        final index = event.currentIndex;

        if (index != null &&
            index >= 0 &&
            index < queue.value.length) {
          final item = queue.value[index];

          if (mediaItem.value?.id != item.id) {
            mediaItem.add(
              item.copyWith(
                duration: _player.duration ?? item.duration,
              ),
            );
          } else if (_player.duration != null &&
              mediaItem.value?.duration != _player.duration) {
            mediaItem.add(
              item.copyWith(
                duration: _player.duration,
              ),
            );
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );

    _player.durationStream.listen((duration) {
      final current = mediaItem.value;

      if (current != null && duration != null) {
        mediaItem.add(
          current.copyWith(
            duration: duration,
          ),
        );
      }
    });

    _player.sequenceStateStream.listen((sequenceState) {
      final sequence = sequenceState.sequence;

      final items = <MediaItem>[];

      for (final source in sequence) {
        final tag = source.tag;

        if (tag is MediaItem) {
          items.add(tag);
        }
      }

      if (items.isNotEmpty) {
        queue.add(items);

        final currentIndex = sequenceState.currentIndex;

        if (currentIndex >= 0 &&
            currentIndex < items.length) {
          mediaItem.add(items[currentIndex]);
        }
      }
    });

    _player.errorStream.listen((error) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: error.message,
        ),
      );
    });
  }

  AudioProcessingState _processingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;

      case ProcessingState.loading:
        return AudioProcessingState.loading;

      case ProcessingState.buffering:
        return AudioProcessingState.buffering;

      case ProcessingState.ready:
        return AudioProcessingState.ready;

      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _broadcastState() {
    final event = _player.playbackEvent;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing)
            MediaControl.pause
          else
            MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [
          0,
          1,
          3,
        ],
        processingState: _processingState(),
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  Future<void> playUrl({
    required String url,
    required String title,
    String artist = 'صاحبي AI',
    String album = 'صاحبي AI',
    String? artUrl,
  }) async {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      throw const FormatException(
        'رابط الصوت غير صحيح',
      );
    }

    final item = MediaItem(
      id: url,
      title: title,
      artist: artist,
      album: album,
      artUri: artUrl == null
          ? null
          : Uri.tryParse(artUrl),
    );

    await _loadSingleSource(
      AudioSource.uri(
        uri,
        tag: item,
      ),
      item,
    );
  }

  Future<void> playLocalFile({
    required String path,
    required String title,
    String artist = 'من الهاتف',
  }) async {
    final file = File(path);

    if (!await file.exists()) {
      throw const FileSystemException(
        'الملف غير موجود',
      );
    }

    final item = MediaItem(
      id: path,
      title: title,
      artist: artist,
      album: 'ملفات الهاتف',
    );

    await _loadSingleSource(
      AudioSource.file(
        path,
        tag: item,
      ),
      item,
    );
  }

  Future<void> _loadSingleSource(
    AudioSource source,
    MediaItem item,
  ) async {
    await _player.stop();

    queue.add([item]);
    mediaItem.add(item);

    await _player.setAudioSource(
      source,
      preload: true,
    );

    await _player.play();
  }

  Future<void> playQueue(
    List<MediaItem> items,
  ) async {
    if (items.isEmpty) return;

    final sources = items.map((item) {
      final uri = Uri.tryParse(item.id);

      if (uri == null) {
        return AudioSource.file(
          item.id,
          tag: item,
        );
      }

      return AudioSource.uri(
        uri,
        tag: item,
      );
    }).toList();

    final source = ConcatenatingAudioSource(
      children: sources,
      useLazyPreparation: true,
    );

    queue.add(items);
    mediaItem.add(items.first);

    await _player.stop();

    await _player.setAudioSource(
      source,
      initialIndex: 0,
      preload: true,
    );

    await _player.play();
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

    mediaItem.add(null);
    queue.add([]);

    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 ||
        index >= queue.value.length) {
      return;
    }

    await _player.seek(
      Duration.zero,
      index: index,
    );
  }

  @override
  Future<void> setRepeatMode(
    AudioServiceRepeatMode repeatMode,
  ) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;

      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;

      case AudioServiceRepeatMode.group:
      case AudioServiceRepeatMode.all:
        await _player.setLoopMode(LoopMode.all);
        break;
    }

    playbackState.add(
      playbackState.value.copyWith(
        repeatMode: repeatMode,
      ),
    );
  }

  @override
  Future<void> setShuffleMode(
    AudioServiceShuffleMode shuffleMode,
  ) async {
    final enabled =
        shuffleMode == AudioServiceShuffleMode.all ||
            shuffleMode == AudioServiceShuffleMode.group;

    await _player.setShuffleModeEnabled(enabled);

    playbackState.add(
      playbackState.value.copyWith(
        shuffleMode: shuffleMode,
      ),
    );
  }

  @override
  Future customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'setVolume') {
      final value =
          (extras?['volume'] as num?)?.toDouble();

      if (value != null) {
        await _player.setVolume(
          value.clamp(0.0, 1.0),
        );
      }
    }

    if (name == 'setSpeed') {
      final value =
          (extras?['speed'] as num?)?.toDouble();

      if (value != null && value > 0) {
        await _player.setSpeed(value);
      }
    }

    return null;
  }

  Future<void> disposePlayer() async {
    await _player.dispose();
  }
}

class AudioController {
  static AudioHandler? _handler;
  static Future<AudioHandler>? _initializing;

  static AudioHandler? get handler => _handler;

  static Future<AudioHandler> initialize() {
    if (_handler != null) {
      return Future.value(_handler!);
    }

    if (_initializing != null) {
      return _initializing!;
    }

    _initializing = _initializeInternal();

    return _initializing!;
  }

  static Future<AudioHandler> _initializeInternal() async {
    final handler =
        await AudioService.init<Sa7biAudioHandler>(
      builder: () => Sa7biAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.example.sa7bi_ai_new.audio',
        androidNotificationChannelName:
            'صاحبي AI - الصوت',
        androidNotificationChannelDescription:
            'تشغيل القرآن والأذكار والموسيقى والبودكاست والراديو',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        androidNotificationClickStartsActivity: true,
        androidShowNotificationBadge: false,
      ),
    );

    _handler = handler;

    return handler;
  }

  static Sa7biAudioHandler? get sa7biHandler {
    final value = _handler;

    if (value is Sa7biAudioHandler) {
      return value;
    }

    return null;
  }
}
