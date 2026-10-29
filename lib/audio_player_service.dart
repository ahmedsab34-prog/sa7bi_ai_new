import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// مشغّل الصوت المركزي لتطبيق صاحبي AI.
///
/// كل المصادر الصوتية تمر من هنا حتى تظل جلسة الصوت
/// واحدة أثناء التنقل بين أقسام التطبيق أو تصغيره.
///
/// مهم:
/// لا ننتظر Future الخاصة بـ _player.play() داخل
/// طابور العمليات؛ لأن Future التشغيل قد تظل معلقة
/// حتى نهاية المقطع أو إيقافه مؤقتًا.
class Sa7biAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer(
    handleInterruptions: false,
  );

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<AudioInterruptionEvent>?
      _interruptionSubscription;
  StreamSubscription<ProcessingState>? _processingSubscription;
  StreamSubscription<SequenceState?>? _sequenceSubscription;

  Future<void>? _initializationFuture;

  bool _initialized = false;
  bool _disposed = false;

  Future<void> _operationTail = Future<void>.value();

  bool _interruptionActive = false;
  bool _resumeAfterInterruption = false;
  bool _wasDucked = false;

  bool _microphoneCaptureActive = false;
  bool _resumeAfterMicrophone = false;

  Sa7biAudioHandler() {
    _initializationFuture = _initialize();
  }

  // ============================================================
  // SERIALIZED OPERATIONS
  // ============================================================

  Future<T> _runExclusive<T>(
    Future<T> Function() operation,
  ) {
    final previous = _operationTail;

    final next = previous
        .catchError((_) {})
        .then<T>((_) => operation());

    _operationTail = next.then<void>(
      (_) {},
      onError: (_) {},
    );

    return next;
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initialize() async {
    if (_initialized || _disposed) {
      return;
    }

    try {
      final session = await AudioSession.instance;

      await session.configure(
        const AudioSessionConfiguration.music(),
      );

      _interruptionSubscription =
          session.interruptionEventStream.listen(
        (event) {
          unawaited(_handleInterruption(event));
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Audio interruption stream error: $error');
          debugPrintStack(stackTrace: stackTrace);
        },
      );

      _playerStateSubscription =
          _player.playerStateStream.listen(
        (_) => _broadcastState(),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Audio player state error: $error');
        },
      );

      _positionSubscription =
          _player.positionStream.listen(
        (_) => _broadcastState(),
      );

      _durationSubscription =
          _player.durationStream.listen(
        (_) {
          _updateCurrentMediaItemDuration();
          _broadcastState();
        },
      );

      _processingSubscription =
          _player.processingStateStream.listen(
        (state) {
          if (state == ProcessingState.completed) {
            _broadcastState();
          }
        },
      );

      _sequenceSubscription =
          _player.sequenceStateStream.listen(
        (sequence) {
          _updateCurrentMediaItem(sequence);
          _broadcastState();
        },
      );

      _initialized = true;
      _broadcastState();
    } catch (error, stackTrace) {
      _initialized = false;

      debugPrint(
        'Sa7biAudioHandler initialization failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _ensureInitialized() async {
    if (_disposed) {
      throw StateError('Audio handler has been disposed');
    }

    final pending = _initializationFuture;

    if (pending != null) {
      await pending;

      if (_initialized) {
        return;
      }
    }

    _initializationFuture = _initialize();
    await _initializationFuture;

    if (!_initialized) {
      throw StateError(
        'Audio handler initialization failed',
      );
    }
  }

  // ============================================================
  // PLAYBACK STATE
  // ============================================================

  PlaybackState _buildPlaybackState() {
    final processingState = _player.processingState;

    final AudioProcessingState audioProcessingState;

    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        audioProcessingState = AudioProcessingState.completed;
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
      androidCompactActionIndices: const <int>[0, 1, 2],
      processingState: audioProcessingState,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    );
  }

  void _broadcastState() {
    if (_disposed) {
      return;
    }

    playbackState.add(_buildPlaybackState());
  }

  void _updateCurrentMediaItem(
    SequenceState? sequence,
  ) {
    if (sequence == null || _disposed) {
      return;
    }

    final index = sequence.currentIndex;
    final items = queue.value;

    if (index < 0 || index >= items.length) {
      return;
    }

    final item = items[index];
    final duration = _player.duration;

    mediaItem.add(
      duration != null && item.duration != duration
          ? item.copyWith(duration: duration)
          : item,
    );
  }

  void _updateCurrentMediaItemDuration() {
    if (_disposed) {
      return;
    }

    final currentIndex = _player.currentIndex;

    if (currentIndex == null) {
      return;
    }

    final items = queue.value;

    if (currentIndex < 0 || currentIndex >= items.length) {
      return;
    }

    final item = items[currentIndex];
    final duration = _player.duration;

    if (duration == null || item.duration == duration) {
      return;
    }

    mediaItem.add(item.copyWith(duration: duration));
  }

  bool get _hasPlayableItem {
    return !_disposed &&
        queue.value.isNotEmpty &&
        mediaItem.value != null;
  }

  // ============================================================
  // NON-BLOCKING PLAY
  // ============================================================

  /// يبدأ التشغيل دون حجز طابور العمليات حتى نهاية المقطع.
  void _startPlayback(String contextLabel) {
    if (_disposed || !_hasPlayableItem) {
      return;
    }

    if (_interruptionActive) {
      _resumeAfterInterruption = true;
      return;
    }

    if (_microphoneCaptureActive) {
      _resumeAfterMicrophone = true;
      return;
    }

    unawaited(
      _player.play().then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('$contextLabel failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          _broadcastState();
        },
      ),
    );

    _broadcastState();
  }

  // ============================================================
  // PHONE CALLS / AUDIO INTERRUPTIONS
  // ============================================================

  Future<void> _handleInterruption(
    AudioInterruptionEvent event,
  ) async {
    try {
      if (_disposed) {
        return;
      }

      if (event.begin) {
        _interruptionActive = true;

        if (event.type == AudioInterruptionType.duck) {
          if (_player.playing) {
            _resumeAfterInterruption = true;
            _wasDucked = true;

            await _player.setVolume(0.35);
          } else if (_microphoneCaptureActive &&
              _resumeAfterMicrophone) {
            _resumeAfterInterruption = true;
          }

          _broadcastState();
          return;
        }

        _resumeAfterInterruption =
            _player.playing ||
            (_microphoneCaptureActive &&
                _resumeAfterMicrophone) ||
            _resumeAfterInterruption;

        _wasDucked = false;

        if (_player.playing) {
          await _player.pause();
        }

        _broadcastState();
        return;
      }

      // انتهت المقاطعة الخارجية.
      _interruptionActive = false;

      if (_wasDucked) {
        _wasDucked = false;
        await _player.setVolume(1.0);
      }

      final shouldResume =
          _resumeAfterInterruption ||
          (_microphoneCaptureActive &&
              _resumeAfterMicrophone);

      _resumeAfterInterruption = false;

      // لو الميكروفون لا يزال يعمل، نؤجل الاستئناف
      // إلى أن تنتهي جلسة التقاط الصوت أيضًا.
      if (_microphoneCaptureActive) {
        _resumeAfterMicrophone = shouldResume;
        _broadcastState();
        return;
      }

      if (shouldResume &&
          _hasPlayableItem &&
          !_player.playing &&
          _player.processingState != ProcessingState.completed) {
        _startPlayback('Resume after audio interruption');
      }

      _resumeAfterMicrophone = false;
      _broadcastState();
    } catch (error, stackTrace) {
      debugPrint('Audio interruption error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ============================================================
  // MICROPHONE / VOICE INPUT
  // ============================================================

  /// يناديها التعرف على الكلام قبل فتح الميكروفون.
  ///
  /// لا نستأنف صوتًا كان متوقفًا يدويًا قبل الميكروفون.
  Future<void> beginMicrophoneCapture() async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      if (_microphoneCaptureActive) {
        return;
      }

      _resumeAfterMicrophone =
          _player.playing ||
          (_interruptionActive &&
              _resumeAfterInterruption);

      _microphoneCaptureActive = true;

      if (_player.playing) {
        await _player.pause();
      }

      _broadcastState();
    });
  }

  /// يناديها التعرف على الكلام عند إيقاف الميكروفون.
  Future<void> endMicrophoneCapture() async {
    if (_disposed) {
      return;
    }

    await _ensureInitialized();

    return _runExclusive<void>(() async {
      if (!_microphoneCaptureActive) {
        return;
      }

      _microphoneCaptureActive = false;

      final shouldResume =
          _resumeAfterMicrophone ||
          _resumeAfterInterruption;

      _resumeAfterMicrophone = false;

      if (_interruptionActive) {
        _resumeAfterInterruption = shouldResume;
        _broadcastState();
        return;
      }

      if (shouldResume &&
          _hasPlayableItem &&
          !_player.playing &&
          _player.processingState != ProcessingState.completed) {
        _startPlayback('Resume after microphone capture');
      }

      _broadcastState();
    });
  }

  // ============================================================
  // AUDIO SOURCE
  // ============================================================

  AudioSource _audioSourceForItem(MediaItem item) {
    final id = item.id.trim();

    if (id.isEmpty) {
      throw Exception('Audio URL/path is empty');
    }

    if (id.startsWith('http://') ||
        id.startsWith('https://')) {
      return AudioSource.uri(
        Uri.parse(id),
        tag: item,
      );
    }

    return AudioSource.file(
      id,
      tag: item,
    );
  }

  Future<void> _setQueueSource({
    required List<MediaItem> items,
    required int initialIndex,
    bool autoplay = false,
  }) async {
    if (items.isEmpty || _disposed) {
      return;
    }

    final safeIndex =
        initialIndex.clamp(0, items.length - 1).toInt();

    try {
      await _player.stop();
    } catch (error) {
      debugPrint('Audio stop before queue reset: $error');
    }

    final children = items
        .map(_audioSourceForItem)
        .toList();

    final source = ConcatenatingAudioSource(
      children: children,
      useLazyPreparation: true,
    );

    queue.add(List<MediaItem>.unmodifiable(items));

    await _player.setAudioSource(
      source,
      initialIndex: safeIndex,
      initialPosition: Duration.zero,
    );

    if (_disposed) {
      return;
    }

    mediaItem.add(items[safeIndex]);
    _broadcastState();

    if (autoplay) {
      _startPlayback('Autoplay queue source');
    }
  }

  // ============================================================
  // AUDIO SERVICE CONTROLS
  // ============================================================

  @override
  Future<void> play() async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      if (_disposed) {
        return;
      }

      try {
        if (_microphoneCaptureActive) {
          _resumeAfterMicrophone = true;
          _resumeAfterInterruption = false;
          return;
        }

        if (_interruptionActive) {
          _resumeAfterInterruption = true;
          return;
        }

        if (!_hasPlayableItem) {
          return;
        }

        _resumeAfterInterruption = false;

        // إعادة المقطع من البداية إذا انتهى.
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }

        _startPlayback('Audio play');
      } catch (error, stackTrace) {
        debugPrint('Audio play failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> pause() async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      try {
        // الضغط اليدوي على إيقاف مؤقت يلغي الاستئناف التلقائي.
        _resumeAfterMicrophone = false;
        _resumeAfterInterruption = false;

        await _player.pause();
        _broadcastState();
      } catch (error, stackTrace) {
        debugPrint('Audio pause failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> stop() async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      try {
        _resumeAfterMicrophone = false;
        _resumeAfterInterruption = false;
        _wasDucked = false;

        await _player.setVolume(1.0);
        await _player.stop();

        _broadcastState();
        await super.stop();
      } catch (error, stackTrace) {
        debugPrint('Audio stop failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> seek(Duration position) async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      try {
        await _player.seek(position);
        _broadcastState();
      } catch (error, stackTrace) {
        debugPrint('Audio seek failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> skipToNext() async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      try {
        final items = queue.value;

        if (items.isEmpty) {
          return;
        }

        final currentIndex = _player.currentIndex ?? 0;

        if (currentIndex + 1 >= items.length) {
          return;
        }

        await _player.seekToNext();
        _startPlayback('Audio next');
      } catch (error, stackTrace) {
        debugPrint('Audio next failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> skipToPrevious() async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      try {
        final items = queue.value;

        if (items.isEmpty) {
          return;
        }

        final currentIndex = _player.currentIndex ?? 0;

        if (currentIndex > 0) {
          await _player.seekToPrevious();
          _startPlayback('Audio previous');
        } else {
          await _player.seek(Duration.zero);
          _startPlayback('Replay first queue item');
        }
      } catch (error, stackTrace) {
        debugPrint('Audio previous failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      try {
        final items = queue.value;

        if (index < 0 || index >= items.length) {
          return;
        }

        await _player.seek(
          Duration.zero,
          index: index,
        );

        _startPlayback('Audio queue selection');
      } catch (error, stackTrace) {
        debugPrint('Audio queue selection failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> fastForward() async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      try {
        final target =
            _player.position + const Duration(seconds: 15);

        final duration = _player.duration;

        await _player.seek(
          duration != null && target > duration
              ? duration
              : target,
        );

        _broadcastState();
      } catch (error, stackTrace) {
        debugPrint('Audio fast-forward failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> rewind() async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      try {
        final target =
            _player.position - const Duration(seconds: 15);

        await _player.seek(
          target.isNegative ? Duration.zero : target,
        );

        _broadcastState();
      } catch (error, stackTrace) {
        debugPrint('Audio rewind failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    await _ensureInitialized();

    if (item.id.trim().isEmpty) {
      throw Exception('Audio URL/path is empty');
    }

    return _runExclusive<void>(() async {
      try {
        _resumeAfterInterruption = false;

        await _setQueueSource(
          items: <MediaItem>[item],
          initialIndex: 0,
          autoplay: true,
        );
      } catch (error, stackTrace) {
        debugPrint('Audio media item failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    await _ensureInitialized();

    if (item.id.trim().isEmpty) {
      return;
    }

    return _runExclusive<void>(() async {
      final oldQueue = List<MediaItem>.from(queue.value);
      final wasPlaying = _player.playing;
      final currentIndex = _player.currentIndex ?? 0;
      final currentPosition = _player.position;

      final newQueue = <MediaItem>[
        ...oldQueue,
        item,
      ];

      try {
        await _setQueueSource(
          items: newQueue,
          initialIndex: oldQueue.isEmpty ? 0 : currentIndex,
          autoplay: wasPlaying,
        );

        if (oldQueue.isNotEmpty &&
            currentIndex >= 0 &&
            currentIndex < oldQueue.length &&
            currentPosition > Duration.zero) {
          await _player.seek(
            currentPosition,
            index: currentIndex,
          );
        }
      } catch (error, stackTrace) {
        debugPrint('Adding audio queue item failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> addQueueItems(List<MediaItem> items) async {
    await _ensureInitialized();

    final validItems = items
        .where((item) => item.id.trim().isNotEmpty)
        .toList();

    if (validItems.isEmpty) {
      return;
    }

    return _runExclusive<void>(() async {
      final oldQueue = List<MediaItem>.from(queue.value);
      final wasPlaying = _player.playing;
      final currentIndex = _player.currentIndex ?? 0;
      final currentPosition = _player.position;

      final newQueue = <MediaItem>[
        ...oldQueue,
        ...validItems,
      ];

      try {
        await _setQueueSource(
          items: newQueue,
          initialIndex: oldQueue.isEmpty ? 0 : currentIndex,
          autoplay: wasPlaying,
        );

        if (oldQueue.isNotEmpty &&
            currentIndex >= 0 &&
            currentIndex < oldQueue.length &&
            currentPosition > Duration.zero) {
          await _player.seek(
            currentPosition,
            index: currentIndex,
          );
        }
      } catch (error, stackTrace) {
        debugPrint('Adding audio queue items failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    await _ensureInitialized();

    return _runExclusive<void>(() async {
      final oldQueue = List<MediaItem>.from(queue.value);

      if (index < 0 || index >= oldQueue.length) {
        return;
      }

      final currentIndex = _player.currentIndex ?? 0;
      final currentPosition = _player.position;
      final wasPlaying = _player.playing;

      oldQueue.removeAt(index);

      if (oldQueue.isEmpty) {
        await _player.stop();
        queue.add(const <MediaItem>[]);
        mediaItem.add(null);
        _broadcastState();
        return;
      }

      final newIndex = index < currentIndex
          ? currentIndex - 1
          : currentIndex.clamp(0, oldQueue.length - 1).toInt();

      try {
        await _setQueueSource(
          items: oldQueue,
          initialIndex: newIndex,
          autoplay: wasPlaying,
        );

        if (index != currentIndex &&
            currentPosition > Duration.zero) {
          await _player.seek(
            currentPosition,
            index: newIndex,
          );
        }
      } catch (error, stackTrace) {
        debugPrint('Removing audio queue item failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _broadcastState();
        rethrow;
      }
    });
  }

  // ============================================================
  // PUBLIC HELPERS
  // ============================================================

  Future<void> playUrl({
    required String url,
    String title = 'صوت من صاحبي AI',
    String? artist,
    String? album,
    Uri? artUri,
  }) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      throw Exception('Audio URL is empty');
    }

    await playMediaItem(
      MediaItem(
        id: cleanUrl,
        title: title,
        artist: artist ?? 'صاحبي AI',
        album: album ?? 'صاحبي AI',
        artUri: artUri,
      ),
    );
  }

  Future<void> playLocalFile({
    required String path,
    String title = 'ملف صوتي',
    String? artist,
  }) async {
    await _ensureInitialized();

    final cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      throw Exception('Audio file path is empty');
    }

    final file = File(cleanPath);

    if (!await file.exists()) {
      throw Exception('Audio file does not exist');
    }

    await playMediaItem(
      MediaItem(
        id: cleanPath,
        title: title,
        artist: artist ?? 'صاحبي AI',
        album: 'ملفات صوتية',
      ),
    );
  }

  Future<void> setSpeed(double speed) async {
    if (speed <= 0) {
      return;
    }

    await _ensureInitialized();

    return _runExclusive<void>(() async {
      await _player.setSpeed(speed);
      _broadcastState();
    });
  }

  Future<void> setVolume(double volume) async {
    await _ensureInitialized();

    final safeVolume = volume.clamp(0.0, 1.0).toDouble();

    return _runExclusive<void>(() async {
      await _player.setVolume(safeVolume);
      _broadcastState();
    });
  }

  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get isPlaying => _player.playing;
  ProcessingState get processingState => _player.processingState;
  bool get isInterruptionActive => _interruptionActive;
  bool get isMicrophoneCaptureActive => _microphoneCaptureActive;

  @override
  Future<void> onTaskRemoved() async {
    // لا نوقف الصوت لمجرد إزالة التطبيق من شاشة التطبيقات الأخيرة.
    // Android AudioService يتولى استمرار جلسة التشغيل بالخلفية.
  }

  Future<void> disposeHandler() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _processingSubscription?.cancel();
    await _sequenceSubscription?.cancel();
    await _interruptionSubscription?.cancel();

    try {
      await _player.stop();
    } catch (error) {
      debugPrint('Audio stop during dispose failed: $error');
    }

    await _player.dispose();
  }
}

// ============================================================
// AUDIO CONTROLLER
// ============================================================

class AudioController {
  AudioController._();

  static Sa7biAudioHandler? _handler;
  static bool _initialized = false;

  static final ValueNotifier<bool> isPlayingNotifier =
      ValueNotifier<bool>(false);

  static ValueNotifier<bool> get isPlaying => isPlayingNotifier;

  static final ValueNotifier<Duration> position =
      ValueNotifier<Duration>(Duration.zero);

  static final ValueNotifier<Duration?> duration =
      ValueNotifier<Duration?>(null);

  static Stream<PlaybackState> get playbackStateStream {
    final currentHandler = _handler;

    if (currentHandler != null) {
      return currentHandler.playbackState;
    }

    return const Stream<PlaybackState>.empty();
  }

  static StreamSubscription<PlaybackState>?
      _playbackSubscription;

  static Future<Sa7biAudioHandler>? _initializationFuture;

  static Future<Sa7biAudioHandler> initialize() {
    final currentHandler = _handler;

    if (currentHandler != null && _initialized) {
      return Future<Sa7biAudioHandler>.value(currentHandler);
    }

    final pending = _initializationFuture;

    if (pending != null) {
      return pending;
    }

    final future = _initializeInternal();
    _initializationFuture = future;

    return future;
  }

  static Future<Sa7biAudioHandler> _initializeInternal() async {
    try {
      final handler = await AudioService.init(
        builder: () => Sa7biAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.sa7bi.ai.audio',
          androidNotificationChannelName: 'صاحبي AI - الصوت',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationIcon: 'drawable/ic_audio_notification',
        ),
      );

      _handler = handler;
      _initialized = true;

      await _playbackSubscription?.cancel();

      _playbackSubscription =
          handler.playbackState.listen((state) {
        isPlayingNotifier.value = state.playing;
        position.value = state.updatePosition;

        final item = handler.mediaItem.value;

        if (item?.duration != null) {
          duration.value = item!.duration;
        } else {
          duration.value = handler.duration;
        }
      });

      return handler;
    } catch (error, stackTrace) {
      _handler = null;
      _initialized = false;

      debugPrint(
        'AudioController initialization failed: $error',
      );
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } finally {
      _initializationFuture = null;
    }
  }

  static Future<void> playUrl({
    required String url,
    String title = 'صوت من صاحبي AI',
    String? artist,
    String? album,
    Uri? artUri,
  }) async {
    final handler = await initialize();

    await handler.playUrl(
      url: url,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
    );
  }

  static Future<void> playLocalFile({
    required String path,
    String title = 'ملف صوتي',
    String? artist,
  }) async {
    final handler = await initialize();

    await handler.playLocalFile(
      path: path,
      title: title,
      artist: artist,
    );
  }

  static Future<void> play() async {
    final handler = await initialize();
    await handler.play();
  }

  static Future<void> pause() async {
    final handler = await initialize();
    await handler.pause();
  }

  static Future<void> stop() async {
    final handler = await initialize();
    await handler.stop();
  }

  static Future<void> seek(Duration position) async {
    final handler = await initialize();
    await handler.seek(position);
  }

  static Future<void> fastForward() async {
    final handler = await initialize();
    await handler.fastForward();
  }

  static Future<void> rewind() async {
    final handler = await initialize();
    await handler.rewind();
  }

  static Future<void> next() async {
    final handler = await initialize();
    await handler.skipToNext();
  }

  static Future<void> previous() async {
    final handler = await initialize();
    await handler.skipToPrevious();
  }

  static Future<void> setSpeed(double speed) async {
    final handler = await initialize();
    await handler.setSpeed(speed);
  }

  static Future<void> setVolume(double volume) async {
    final handler = await initialize();
    await handler.setVolume(volume);
  }

  /// لا ننشئ مشغّلًا جديدًا لمجرد فتح الميكروفون.
  /// إذا لم يكن هناك مشغّل نشط، فلا توجد موسيقى تحتاج الإيقاف.
  static Future<void> beginMicrophoneCapture() async {
    final currentHandler = _handler;

    if (currentHandler == null) {
      return;
    }

    await currentHandler.beginMicrophoneCapture();
  }

  static Future<void> endMicrophoneCapture() async {
    final currentHandler = _handler;

    if (currentHandler == null) {
      return;
    }

    await currentHandler.endMicrophoneCapture();
  }

  static Sa7biAudioHandler? get handler => _handler;
}

// ============================================================
// BACKWARD-COMPATIBLE WRAPPER
// ============================================================

class Sa7biAudioService {
  Sa7biAudioService._();

  static Future<Sa7biAudioHandler> initialize() {
    return AudioController.initialize();
  }

  static Future<void> playUrl({
    required String url,
    String title = 'صوت من صاحبي AI',
    String? artist,
    String? album,
    Uri? artUri,
  }) {
    return AudioController.playUrl(
      url: url,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
    );
  }

  static Future<void> playLocalFile({
    required String path,
    String title = 'ملف صوتي',
    String? artist,
  }) {
    return AudioController.playLocalFile(
      path: path,
      title: title,
      artist: artist,
    );
  }

  static Future<void> play() => AudioController.play();
  static Future<void> pause() => AudioController.pause();
  static Future<void> stop() => AudioController.stop();

  static Future<void> seek(Duration position) {
    return AudioController.seek(position);
  }
}
