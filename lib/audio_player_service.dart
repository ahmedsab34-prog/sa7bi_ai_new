import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class Sa7biAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  Sa7biAudioHandler() {
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final session = await AudioSession.instance;

      await session.configure(
        const AudioSessionConfiguration.music(),
      );

      _player.playbackEventStream.listen(
        (_) {
          _broadcastState();
        },
        onError: (
          Object error,
          StackTrace stackTrace,
        ) {
          // خطأ في مصدر الصوت لا يجب أن يغلق التطبيق.
        },
      );

      _player.durationStream.listen(
        (duration) {
          if (duration == null) {
            return;
          }

          final current = mediaItem.value;

          if (current != null) {
            mediaItem.add(
              current.copyWith(
                duration: duration,
              ),
            );
          }
        },
      );

      _player.sequenceStateStream.listen(
        (sequenceState) {
          final items = sequenceState.effectiveSequence
              .map(
                (source) => source.tag,
              )
              .whereType<MediaItem>()
              .toList();

          queue.add(items);

          final int? index =
              sequenceState.currentIndex;

          if (index != null &&
              index >= 0 &&
              index < items.length) {
            mediaItem.add(
              items[index],
            );
          }

          _broadcastState();
        },
      );

      _player.processingStateStream.listen(
        (_) {
          _broadcastState();
        },
      );

      _player.playerStateStream.listen(
        (_) {
          _broadcastState();
        },
      );
    } catch (_) {
      // لا نسمح بفشل تهيئة الصوت بإغلاق التطبيق.
    }
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
    playbackState.add(
      playbackState.value.copyWith(
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
          2,
        ],
        processingState:
            _processingState(),
        playing: _player.playing,
        updatePosition:
            _player.position,
        bufferedPosition:
            _player.bufferedPosition,
        speed: _player.speed,
        queueIndex:
            _player.currentIndex,
      ),
    );
  }

  Future<void> playUrl({
    required String url,
    required String title,
    String? artist,
    String? album,
    String? artUri,
  }) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(cleanUrl);

    if (uri == null ||
        (!uri.hasScheme ||
            (uri.scheme != 'http' &&
                uri.scheme != 'https'))) {
      throw const FormatException(
        'رابط الصوت غير صالح.',
      );
    }

    final item = MediaItem(
      id: cleanUrl,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri == null
          ? null
          : Uri.tryParse(artUri),
    );

    await _loadSingleSource(
      AudioSource.uri(
        uri,
        tag: item,
      ),
    );
  }

  Future<void> playLocalFile({
    required String path,
    required String title,
    String? artist,
    String? album,
  }) async {
    final cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      throw const FormatException(
        'مسار الملف غير صالح.',
      );
    }

    final item = MediaItem(
      id: cleanPath,
      title: title,
      artist: artist,
      album: album,
    );

    await _loadSingleSource(
      AudioSource.file(
        cleanPath,
        tag: item,
      ),
    );
  }

  Future<void> _loadSingleSource(
    AudioSource source,
  ) async {
    await _player.setAudioSource(
      source,
      preload: true,
    );

    await _player.play();
  }

  Future<void> playQueue(
    List<MediaItem> items,
  ) async {
    if (items.isEmpty) {
      return;
    }

    final sources = <AudioSource>[];

    for (final item in items) {
      final uri = Uri.tryParse(
        item.id,
      );

      if (uri == null) {
        continue;
      }

      if (uri.scheme == 'http' ||
          uri.scheme == 'https') {
        sources.add(
          AudioSource.uri(
            uri,
            tag: item,
          ),
        );
      } else if (uri.scheme == 'file') {
        sources.add(
          AudioSource.file(
            uri.toFilePath(),
            tag: item,
          ),
        );
      }
    }

    if (sources.isEmpty) {
      return;
    }

    await _player.setAudioSources(
      sources,
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
    await super.stop();
  }

  @override
  Future<void> seek(
    Duration position,
  ) async {
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
    }
  }

  @override
  Future<void> skipToQueueItem(
    int index,
  ) async {
    final length =
        _player.sequence.length;

    if (index < 0 ||
        index >= length) {
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
        await _player.setLoopMode(
          LoopMode.off,
        );
        break;

      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(
          LoopMode.one,
        );
        break;

      case AudioServiceRepeatMode.all:
        await _player.setLoopMode(
          LoopMode.all,
        );
        break;

      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(
          LoopMode.all,
        );
        break;
    }
  }

  @override
  Future<void> setShuffleMode(
    AudioServiceShuffleMode shuffleMode,
  ) async {
    switch (shuffleMode) {
      case AudioServiceShuffleMode.none:
        await _player.setShuffleModeEnabled(
          false,
        );
        break;

      case AudioServiceShuffleMode.all:
        await _player.setShuffleModeEnabled(
          true,
        );
        break;

      case AudioServiceShuffleMode.group:
        await _player.setShuffleModeEnabled(
          true,
        );
        break;
    }
  }

  @override
  Future<void> customAction(
    String name, [
    dynamic arguments,
  ]) async {
    if (name == 'setVolume') {
      final value = arguments is num
          ? arguments.toDouble()
          : 1.0;

      await _player.setVolume(
        value.clamp(0.0, 1.0).toDouble(),
      );
    }
  }
}

class AudioController {
  AudioController._();

  static Sa7biAudioHandler? _handler;

  static Future<Sa7biAudioHandler> init() async {
    final existing = _handler;

    if (existing != null) {
      return existing;
    }

    _handler = await AudioService.init(
      builder: () => Sa7biAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'sa7bi_ai_audio',
        androidNotificationChannelName:
            'صحبي AI Audio',
        androidNotificationChannelDescription:
            'تشغيل الصوت في الخلفية',

        // متوافق مع audio_service 0.18.19.
        // نترك androidNotificationOngoing على
        // القيمة الافتراضية false لأن الجمع بين
        // ongoing:true و stopForegroundOnPause:false
        // ممنوع في هذا الإصدار.
        androidStopForegroundOnPause:
            false,

        androidShowNotificationBadge:
            true,

        notificationColor:
            Color(0xFF151923),
      ),
    );

    return _handler!;
  }

  // توافق مع الملفات الحالية التي تستعمل
  // AudioController.initialize().
  static Future<Sa7biAudioHandler>
      initialize() async {
    return init();
  }

  static Sa7biAudioHandler? get handler =>
      _handler;
}
