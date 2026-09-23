import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// ===========================================================================
/// Sa7bi AI Audio Handler
/// ===========================================================================
/// مسؤول عن:
/// - تشغيل الصوت في الخلفية.
/// - التحكم من شاشة القفل والإشعارات.
/// - Play / Pause / Stop.
/// - Seek.
/// - Next / Previous.
/// - Fast Forward / Rewind.
/// - تشغيل روابط الإنترنت.
/// - تشغيل الملفات المحلية.
/// - التعامل مع المقاطعات الصوتية.
/// - إيقاف الصوت أثناء المكالمات والمقاطعات.
/// - استكمال التشغيل تلقائيًا بعد انتهاء المقاطعة إذا كان الصوت يعمل قبلها.
/// ===========================================================================

class Sa7biAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<AudioInterruptionEvent>?
      _interruptionSubscription;
  StreamSubscription<ProcessingState>? _processingSubscription;

  bool _initialized = false;

  // =========================================================================
  // INTERRUPTION STATE
  // =========================================================================

  /// هل توجد مقاطعة صوتية حاليًا؟
  bool _interruptionActive = false;

  /// هل كان الصوت يعمل قبل بداية المقاطعة؟
  bool _resumeAfterInterruption = false;

  /// هل كنا نخفض الصوت بسبب Duck؟
  bool _wasDucked = false;

  Sa7biAudioHandler() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    try {
      final session = await AudioSession.instance;

      await session.configure(
        const AudioSessionConfiguration.music(),
      );

      _interruptionSubscription =
          session.interruptionEventStream.listen(
        (event) async {
          await _handleInterruption(event);
        },
      );

      _playerStateSubscription =
          _player.playerStateStream.listen((state) {
        _broadcastState();
      });

      _positionSubscription =
          _player.positionStream.listen((position) {
        _broadcastState();
      });

      _durationSubscription =
          _player.durationStream.listen((duration) {
        _broadcastState();
      });

      _processingSubscription =
          _player.processingStateStream.listen(
        (state) async {
          if (state != ProcessingState.completed) {
            return;
          }

          _broadcastState();

          final currentQueue = queue.value;

          if (currentQueue.length <= 1) {
            return;
          }

          final currentIndex =
              _player.currentIndex ?? 0;

          if (currentIndex + 1 < currentQueue.length) {
            try {
              await skipToQueueItem(
                currentIndex + 1,
              );
            } catch (_) {}
          }
        },
      );

      // لا نستخدم becomingNoisyEventStream
      // لأنه غير موجود في إصدار just_audio الحالي.

      _broadcastState();
    } catch (_) {
      // الصوت يظل قابلاً للاستخدام حتى لو تعذر إعداد AudioSession.
    }
  }

  // =========================================================================
  // AUDIO INTERRUPTION
  // =========================================================================

  Future<void> _handleInterruption(
    AudioInterruptionEvent event,
  ) async {
    try {
      if (event.begin) {
        _interruptionActive = true;

        if (event.type == AudioInterruptionType.duck) {
          // لو الصوت شغال، نحفظ حالته ونخفض الصوت مؤقتًا.
          if (_player.playing) {
            _resumeAfterInterruption = true;
            _wasDucked = true;
            await _player.setVolume(0.35);
          } else {
            _resumeAfterInterruption = false;
            _wasDucked = false;
          }

          _broadcastState();
          return;
        }

        // مكالمة أو مقاطعة قوية:
        // نحفظ هل الصوت كان شغال قبل الإيقاف.
        _resumeAfterInterruption = _player.playing;
        _wasDucked = false;

        if (_player.playing) {
          // نستخدم pause مباشرة هنا بدل pause()
          // حتى لا نمسح حالة الاستكمال.
          await _player.pause();
        }

        _broadcastState();
        return;
      }

      // انتهت المقاطعة.
      _interruptionActive = false;

      if (_wasDucked) {
        _wasDucked = false;

        await _player.setVolume(1.0);

        // لو كان شغال قبل الـDuck، يرجع يكمل.
        if (_resumeAfterInterruption &&
            !_player.playing) {
          try {
            await _player.play();
          } catch (_) {}
        }

        _resumeAfterInterruption = false;
        _broadcastState();
        return;
      }

      await _player.setVolume(1.0);

      // استكمال التشغيل تلقائيًا بعد المكالمة
      // فقط إذا كان الصوت يعمل قبل المقاطعة.
      if (_resumeAfterInterruption &&
          !_player.playing &&
          _player.processingState !=
              ProcessingState.completed) {
        try {
          await _player.play();
        } catch (_) {}
      }

      _resumeAfterInterruption = false;

      _broadcastState();
    } catch (_) {
      // لا نسمح بخطأ المقاطعة بإغلاق التطبيق.
    }
  }

  PlaybackState _buildPlaybackState() {
    final processingState =
        _player.processingState;

    AudioProcessingState audioProcessingState;

    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState =
            AudioProcessingState.idle;
        break;

      case ProcessingState.loading:
        audioProcessingState =
            AudioProcessingState.loading;
        break;

      case ProcessingState.buffering:
        audioProcessingState =
            AudioProcessingState.buffering;
        break;

      case ProcessingState.ready:
        audioProcessingState =
            AudioProcessingState.ready;
        break;

      case ProcessingState.completed:
        audioProcessingState =
            AudioProcessingState.completed;
        break;
    }

    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      if (_player.playing)
        MediaControl.pause
      else
        MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
    ];

    return PlaybackState(
      controls: controls,
      systemActions: const <MediaAction>{
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices:
          const <int>[0, 1, 2],
      processingState:
          audioProcessingState,
      playing: _player.playing,
      updatePosition:
          _player.position,
      bufferedPosition:
          _player.bufferedPosition,
      speed: _player.speed,
      queueIndex:
          _player.currentIndex,
    );
  }

  void _broadcastState() {
    playbackState.add(
      _buildPlaybackState(),
    );
  }

  // =========================================================================
  // PLAY
  // =========================================================================

  @override
  Future<void> play() async {
    await _initialize();

    try {
      // تشغيل يدوي يعني أن المستخدم يريد الصوت شغالًا.
      _resumeAfterInterruption = false;

      await _player.play();

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // PAUSE
  // =========================================================================

  @override
  Future<void> pause() async {
    try {
      // لو المستخدم ضغط Pause بنفسه أثناء المقاطعة،
      // لا نعيد التشغيل تلقائيًا بعدها.
      if (_interruptionActive) {
        _resumeAfterInterruption = false;
      }

      await _player.pause();

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // STOP
  // =========================================================================

  @override
  Future<void> stop() async {
    try {
      _resumeAfterInterruption = false;
      _interruptionActive = false;
      _wasDucked = false;

      await _player.stop();

      _broadcastState();

      await super.stop();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // SEEK
  // =========================================================================

  @override
  Future<void> seek(
    Duration position,
  ) async {
    try {
      await _player.seek(position);
      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // NEXT
  // =========================================================================

  @override
  Future<void> skipToNext() async {
    try {
      final currentQueue =
          queue.value;

      if (currentQueue.isEmpty) {
        return;
      }

      final currentIndex =
          _player.currentIndex ?? 0;

      if (currentIndex + 1 <
          currentQueue.length) {
        await _player.seekToNext();
        await _player.play();
      }

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // PREVIOUS
  // =========================================================================

  @override
  Future<void> skipToPrevious() async {
    try {
      final currentQueue =
          queue.value;

      if (currentQueue.isEmpty) {
        return;
      }

      final currentIndex =
          _player.currentIndex ?? 0;

      if (currentIndex > 0) {
        await _player.seekToPrevious();
        await _player.play();
      } else {
        await _player.seek(
          Duration.zero,
        );
      }

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // FAST FORWARD
  // =========================================================================

  @override
  Future<void> fastForward() async {
    try {
      final current =
          _player.position;

      final duration =
          _player.duration;

      final target =
          current +
              const Duration(
                seconds: 15,
              );

      if (duration != null &&
          target > duration) {
        await _player.seek(duration);
      } else {
        await _player.seek(target);
      }

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // REWIND
  // =========================================================================

  @override
  Future<void> rewind() async {
    try {
      final current =
          _player.position;

      final target =
          current -
              const Duration(
                seconds: 15,
              );

      await _player.seek(
        target.isNegative
            ? Duration.zero
            : target,
      );

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // PLAY MEDIA ITEM
  // =========================================================================

  @override
  Future<void> playMediaItem(
    MediaItem item,
  ) async {
    await _initialize();

    try {
      _resumeAfterInterruption = false;

      mediaItem.add(item);

      queue.add(
        <MediaItem>[item],
      );

      final cleanUrl =
          item.id.trim();

      if (cleanUrl.isEmpty) {
        throw Exception(
          'Audio URL is empty',
        );
      }

      await _player.setUrl(
        cleanUrl,
      );

      await _player.play();

      _broadcastState();
    } catch (_) {
      _broadcastState();
      rethrow;
    }
  }

  // =========================================================================
  // QUEUE
  // =========================================================================

  @override
  Future<void> addQueueItem(
    MediaItem item,
  ) async {
    final updatedQueue =
        List<MediaItem>.from(
      queue.value,
    );

    updatedQueue.add(item);

    queue.add(updatedQueue);

    if (_player.audioSource ==
        null) {
      mediaItem.add(item);

      final cleanUrl =
          item.id.trim();

      if (cleanUrl.isNotEmpty) {
        await _player.setUrl(
          cleanUrl,
        );
      }

      _broadcastState();
    }
  }

  @override
  Future<void> addQueueItems(
    List<MediaItem> items,
  ) async {
    if (items.isEmpty) {
      return;
    }

    final updatedQueue =
        List<MediaItem>.from(
      queue.value,
    );

    updatedQueue.addAll(items);

    queue.add(updatedQueue);

    if (_player.audioSource ==
        null) {
      final first =
          items.first;

      mediaItem.add(first);

      final cleanUrl =
          first.id.trim();

      if (cleanUrl.isNotEmpty) {
        await _player.setUrl(
          cleanUrl,
        );
      }
    }

    _broadcastState();
  }

  @override
  Future<void> removeQueueItemAt(
    int index,
  ) async {
    final updatedQueue =
        List<MediaItem>.from(
      queue.value,
    );

    if (index < 0 ||
        index >=
            updatedQueue.length) {
      return;
    }

    updatedQueue.removeAt(index);

    queue.add(updatedQueue);

    _broadcastState();
  }

  // =========================================================================
  // PLAY URL
  // =========================================================================

  Future<void> playUrl({
    required String url,
    String title =
        'صوت من صاحبي AI',
    String? artist,
    String? album,
    Uri? artUri,
  }) async {
    final cleanUrl =
        url.trim();

    if (cleanUrl.isEmpty) {
      throw Exception(
        'Audio URL is empty',
      );
    }

    final item = MediaItem(
      id: cleanUrl,
      title: title,
      artist:
          artist ?? 'صاحبي AI',
      album:
          album ?? 'صاحبي AI',
      artUri: artUri,
    );

    await playMediaItem(item);
  }

  // =========================================================================
  // PLAY LOCAL FILE
  // =========================================================================

  Future<void> playLocalFile({
    required String path,
    String title =
        'ملف صوتي',
    String? artist,
  }) async {
    final cleanPath =
        path.trim();

    if (cleanPath.isEmpty) {
      throw Exception(
        'Audio file path is empty',
      );
    }

    final file =
        File(cleanPath);

    if (!await file.exists()) {
      throw Exception(
        'Audio file does not exist',
      );
    }

    final item = MediaItem(
      id: cleanPath,
      title: title,
      artist:
          artist ?? 'صاحبي AI',
      album:
          'ملفات صوتية',
    );

    try {
      _resumeAfterInterruption =
          false;

      mediaItem.add(item);

      queue.add(
        <MediaItem>[item],
      );

      await _player.setFilePath(
        cleanPath,
      );

      await _player.play();

      _broadcastState();
    } catch (_) {
      _broadcastState();
      rethrow;
    }
  }

  // =========================================================================
  // SPEED
  // =========================================================================

  Future<void> setSpeed(
    double speed,
  ) async {
    if (speed <= 0) {
      return;
    }

    try {
      await _player.setSpeed(
        speed,
      );

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // =========================================================================
  // VOLUME
  // =========================================================================

  Future<void> setVolume(
    double volume,
  ) async {
    final safeVolume =
        volume.clamp(
      0.0,
      1.0,
    );

    try {
      await _player.setVolume(
        safeVolume,
      );
    } catch (_) {}
  }

  // =========================================================================
  // CURRENT INFORMATION
  // =========================================================================

  Duration get position =>
      _player.position;

  Duration? get duration =>
      _player.duration;

  bool get isPlaying =>
      _player.playing;

  ProcessingState
      get processingState =>
          _player.processingState;

  // =========================================================================
  // DISPOSE
  // =========================================================================

  Future<void> disposeHandler() async {
    await _playerStateSubscription
        ?.cancel();

    await _positionSubscription
        ?.cancel();

    await _durationSubscription
        ?.cancel();

    await _processingSubscription
        ?.cancel();

    await _interruptionSubscription
        ?.cancel();

    await _player.dispose();
  }

  @override
  Future<void> onTaskRemoved() async {
    // لا نوقف الصوت هنا.
    // يسمح ذلك باستمرار تشغيل الصوت في الخلفية.
  }
}

/// ===========================================================================
/// AudioController
/// ===========================================================================

class AudioController {
  AudioController._();

  static Sa7biAudioHandler?
      _handler;

  static bool _initialized =
      false;

  // =========================================================================
  // PUBLIC NOTIFIERS
  // =========================================================================

  static final ValueNotifier<bool>
      isPlayingNotifier =
      ValueNotifier<bool>(false);

  static ValueNotifier<bool>
      get isPlaying =>
          isPlayingNotifier;

  static final ValueNotifier<
      Duration> position =
      ValueNotifier<Duration>(
    Duration.zero,
  );

  static final ValueNotifier<
      Duration?> duration =
      ValueNotifier<Duration?>(
    null,
  );

  // =========================================================================
  // PUBLIC PLAYBACK STREAM
  // =========================================================================

  static Stream<PlaybackState>
      get playbackStateStream {
    final handler =
        _handler;

    if (handler != null) {
      return handler.playbackState;
    }

    return const Stream<
        PlaybackState>.empty();
  }

  static StreamSubscription<
          PlaybackState>?
      _playbackSubscription;

  // =========================================================================
  // INITIALIZE
  // =========================================================================

  static Future<
      Sa7biAudioHandler> initialize() async {
    if (_handler != null &&
        _initialized) {
      return _handler!;
    }

    final handler =
        await AudioService.init(
      builder: () =>
          Sa7biAudioHandler(),
      config:
          const AudioServiceConfig(
        androidNotificationChannelId:
            'com.example.sa7bi_ai_new.audio',

        androidNotificationChannelName:
            'صاحبي AI - الصوت',

        androidNotificationOngoing:
            false,

        androidStopForegroundOnPause:
            false,

        androidNotificationIcon:
            'mipmap/ic_launcher',
      ),
    );

    _handler = handler;
    _initialized = true;

    await _playbackSubscription
        ?.cancel();

    _playbackSubscription =
        handler.playbackState.listen(
      (state) {
        isPlayingNotifier.value =
            state.playing;

        position.value =
            state.updatePosition;

        final item =
            handler.mediaItem.value;

        if (item != null &&
            item.duration != null) {
          duration.value =
              item.duration;
        } else {
          duration.value =
              handler.duration;
        }
      },
    );

    return handler;
  }

  // =========================================================================
  // PLAY URL
  // =========================================================================

  static Future<void> playUrl({
    required String url,
    String title =
        'صوت من صاحبي AI',
    String? artist,
    String? album,
    Uri? artUri,
  }) async {
    final handler =
        await initialize();

    await handler.playUrl(
      url: url,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
    );
  }

  // =========================================================================
  // PLAY LOCAL FILE
  // =========================================================================

  static Future<void>
      playLocalFile({
    required String path,
    String title =
        'ملف صوتي',
    String? artist,
  }) async {
    final handler =
        await initialize();

    await handler.playLocalFile(
      path: path,
      title: title,
      artist: artist,
    );
  }

  // =========================================================================
  // BASIC CONTROLS
  // =========================================================================

  static Future<void> play() async {
    final handler =
        await initialize();

    await handler.play();
  }

  static Future<void> pause() async {
    final handler =
        await initialize();

    await handler.pause();
  }

  static Future<void> stop() async {
    final handler =
        await initialize();

    await handler.stop();
  }

  static Future<void> seek(
    Duration position,
  ) async {
    final handler =
        await initialize();

    await handler.seek(
      position,
    );
  }

  static Future<void>
      fastForward() async {
    final handler =
        await initialize();

    await handler.fastForward();
  }

  static Future<void> rewind() async {
    final handler =
        await initialize();

    await handler.rewind();
  }

  static Future<void> next() async {
    final handler =
        await initialize();

    await handler.skipToNext();
  }

  static Future<void>
      previous() async {
    final handler =
        await initialize();

    await handler.skipToPrevious();
  }

  static Future<void> setSpeed(
    double speed,
  ) async {
    final handler =
        await initialize();

    await handler.setSpeed(
      speed,
    );
  }

  static Future<void> setVolume(
    double volume,
  ) async {
    final handler =
        await initialize();

    await handler.setVolume(
      volume,
    );
  }

  static Sa7biAudioHandler?
      get handler =>
          _handler;
}

/// ===========================================================================
/// Backward-Compatible Wrapper
/// ===========================================================================

class Sa7biAudioService {
  Sa7biAudioService._();

  static Future<
      Sa7biAudioHandler> initialize() {
    return AudioController
        .initialize();
  }

  static Future<void> playUrl({
    required String url,
    String title =
        'صوت من صاحبي AI',
    String? artist,
    String? album,
    Uri? artUri,
  }) {
    return AudioController
        .playUrl(
      url: url,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
    );
  }

  static Future<void>
      playLocalFile({
    required String path,
    String title =
        'ملف صوتي',
    String? artist,
  }) {
    return AudioController
        .playLocalFile(
      path: path,
      title: title,
      artist: artist,
    );
  }

  static Future<void> play() {
    return AudioController
        .play();
  }

  static Future<void> pause() {
    return AudioController
        .pause();
  }

  static Future<void> stop() {
    return AudioController
        .stop();
  }

  static Future<void> seek(
    Duration position,
  ) {
    return AudioController
        .seek(position);
  }
}
