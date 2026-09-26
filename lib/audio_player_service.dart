// ignore_for_file: unused_field

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
/// - شاشة القفل والإشعار.
/// - تشغيل الإنترنت والملفات المحلية.
/// - Queue حقيقي متعدد المقاطع.
/// - الانتقال التلقائي للمقطع التالي.
/// - Next / Previous.
/// - Seek / Fast Forward / Rewind.
/// - التعامل مع المكالمات والمقاطعات.
/// - استكمال التشغيل بعد انتهاء المقاطعة.
/// - حماية تبديل المصادر من العمليات المتزامنة.
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
  StreamSubscription<SequenceState?>? _sequenceSubscription;

  Future<void>? _initializationFuture;

  bool _initialized = false;
  bool _disposed = false;

  // =========================================================================
  // SERIALIZED PLAYER OPERATIONS
  // =========================================================================

  Future<void> _operationTail = Future<void>.value();

  Future<T> _runExclusive<T>(
    Future<T> Function() operation,
  ) {
    final previous = _operationTail;

    final next = previous
        .catchError(
          (_) {},
        )
        .then<T>(
          (_) => operation(),
        );

    _operationTail = next.then<void>(
      (_) {},
      onError: (_) {},
    );

    return next;
  }

  // =========================================================================
  // INTERRUPTION STATE
  // =========================================================================

  bool _interruptionActive = false;
  bool _resumeAfterInterruption = false;
  bool _wasDucked = false;

  // =========================================================================
  // QUEUE STATE
  // =========================================================================

  ConcatenatingAudioSource? _queueSource;

  bool _rebuildingQueue = false;

  Sa7biAudioHandler() {
    _initializationFuture = _initialize();
  }

  // =========================================================================
  // INITIALIZE
  // =========================================================================

  Future<void> _initialize() async {
    if (_initialized || _disposed) {
      return;
    }

    try {
      final session =
          await AudioSession.instance;

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
          _player.playerStateStream.listen(
        (_) {
          _broadcastState();
        },
      );

      _positionSubscription =
          _player.positionStream.listen(
        (_) {
          _broadcastState();
        },
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
        (state) async {
          if (state ==
              ProcessingState.completed) {
            _broadcastState();
          }
        },
      );

      _sequenceSubscription =
          _player.sequenceStateStream.listen(
        (sequence) {
          _updateCurrentMediaItem(
            sequence,
          );
          _broadcastState();
        },
      );

      _initialized = true;

      _broadcastState();
    } catch (_) {
      _initialized = true;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_disposed) {
      throw StateError(
        'Audio handler has been disposed',
      );
    }

    final future =
        _initializationFuture;

    if (future != null) {
      await future;
      return;
    }

    _initializationFuture =
        _initialize();

    await _initializationFuture;
  }

  // =========================================================================
  // INTERRUPTION
  // =========================================================================

  Future<void> _handleInterruption(
    AudioInterruptionEvent event,
  ) async {
    try {
      if (_disposed) {
        return;
      }

      if (event.begin) {
        _interruptionActive = true;

        if (event.type ==
            AudioInterruptionType.duck) {
          if (_player.playing) {
            _resumeAfterInterruption = true;
            _wasDucked = true;

            await _player.setVolume(
              0.35,
            );
          } else {
            _resumeAfterInterruption =
                false;
            _wasDucked = false;
          }

          _broadcastState();
          return;
        }

        _resumeAfterInterruption =
            _player.playing;

        _wasDucked = false;

        if (_player.playing) {
          await _player.pause();
        }

        _broadcastState();
        return;
      }

      _interruptionActive = false;

      if (_wasDucked) {
        _wasDucked = false;

        await _player.setVolume(
          1.0,
        );

        if (_resumeAfterInterruption &&
            !_player.playing &&
            _player.processingState !=
                ProcessingState.completed) {
          try {
            await _player.play();
          } catch (_) {}
        }

        _resumeAfterInterruption =
            false;

        _broadcastState();
        return;
      }

      await _player.setVolume(
        1.0,
      );

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
    } catch (_) {}
  }

  // =========================================================================
  // PLAYBACK STATE
  // =========================================================================

  PlaybackState _buildPlaybackState() {
    final processingState =
        _player.processingState;

    AudioProcessingState
        audioProcessingState;

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

    final controls =
        <MediaControl>[
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
          const <int>[
        0,
        1,
        2,
      ],
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
    if (_disposed) {
      return;
    }

    playbackState.add(
      _buildPlaybackState(),
    );
  }

  // =========================================================================
  // MEDIA ITEM / QUEUE SYNC
  // =========================================================================

  void _updateCurrentMediaItem(
    SequenceState? sequence,
  ) {
    if (sequence == null ||
        _disposed) {
      return;
    }

    final index =
        sequence.currentIndex;

    final items =
        queue.value;

    if (index < 0 ||
        index >= items.length) {
      return;
    }

    final item =
        items[index];

    final duration =
        _player.duration;

    if (duration != null &&
        item.duration != duration) {
      mediaItem.add(
        item.copyWith(
          duration: duration,
        ),
      );
    } else {
      mediaItem.add(
        item,
      );
    }
  }

  void _updateCurrentMediaItemDuration() {
    if (_disposed) {
      return;
    }

    final currentIndex =
        _player.currentIndex;

    if (currentIndex == null) {
      return;
    }

    final items =
        queue.value;

    if (currentIndex < 0 ||
        currentIndex >=
            items.length) {
      return;
    }

    final item =
        items[currentIndex];

    final duration =
        _player.duration;

    if (duration == null) {
      return;
    }

    if (item.duration ==
        duration) {
      return;
    }

    mediaItem.add(
      item.copyWith(
        duration: duration,
      ),
    );
  }

  // =========================================================================
  // BUILD AUDIO SOURCE
  // =========================================================================

  AudioSource _audioSourceForItem(
    MediaItem item,
  ) {
    final id =
        item.id.trim();

    if (id.isEmpty) {
      throw Exception(
        'Audio URL/path is empty',
      );
    }

    if (id.startsWith(
          'http://',
        ) ||
        id.startsWith(
          'https://',
        )) {
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

  // =========================================================================
  // SET QUEUE SOURCE - INTERNAL
  // =========================================================================

  Future<void> _setQueueSource({
    required List<MediaItem> items,
    required int initialIndex,
    bool autoplay = false,
  }) async {
    if (items.isEmpty ||
        _disposed) {
      return;
    }

    final safeIndex =
        initialIndex.clamp(
      0,
      items.length - 1,
    );

    _rebuildingQueue = true;

    try {
      try {
        await _player.stop();
      } catch (_) {}

      _queueSource = null;

      final children =
          items.map(
        _audioSourceForItem,
      ).toList();

      final source =
          ConcatenatingAudioSource(
        children: children,
        useLazyPreparation: true,
      );

      queue.add(
        List<MediaItem>.unmodifiable(
          items,
        ),
      );

      _queueSource = source;

      await _player.setAudioSource(
        source,
        initialIndex:
            safeIndex,
        initialPosition:
            Duration.zero,
      );

      if (_disposed) {
        return;
      }

      mediaItem.add(
        items[safeIndex],
      );

      if (autoplay &&
          !_interruptionActive &&
          !_disposed) {
        await _player.play();
      }
    } finally {
      _rebuildingQueue = false;
    }

    _broadcastState();
  }

  // =========================================================================
  // PLAY
  // =========================================================================

  @override
  Future<void> play() async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        if (_disposed) {
          return;
        }

        try {
          _resumeAfterInterruption =
              false;

          await _player.play();

          _broadcastState();
        } catch (_) {
          _broadcastState();
        }
      },
    );
  }

  // =========================================================================
  // PAUSE
  // =========================================================================

  @override
  Future<void> pause() async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        try {
          if (_interruptionActive) {
            _resumeAfterInterruption =
                false;
          }

          await _player.pause();

          _broadcastState();
        } catch (_) {
          _broadcastState();
        }
      },
    );
  }

  // =========================================================================
  // STOP
  // =========================================================================

  @override
  Future<void> stop() async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        try {
          _resumeAfterInterruption =
              false;

          _interruptionActive =
              false;

          _wasDucked = false;

          await _player.stop();

          _broadcastState();

          await super.stop();
        } catch (_) {
          _broadcastState();
        }
      },
    );
  }

  // =========================================================================
  // SEEK
  // =========================================================================

  @override
  Future<void> seek(
    Duration position,
  ) async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        try {
          await _player.seek(
            position,
          );

          _broadcastState();
        } catch (_) {
          _broadcastState();
        }
      },
    );
  }

  // =========================================================================
  // NEXT
  // =========================================================================

  @override
  Future<void> skipToNext() async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        try {
          final items =
              queue.value;

          if (items.isEmpty) {
            return;
          }

          final currentIndex =
              _player.currentIndex ??
                  0;

          if (currentIndex + 1 >=
              items.length) {
            return;
          }

          await _player
              .seekToNext();

          await _player.play();

          _broadcastState();
        } catch (_) {
          _broadcastState();
        }
      },
    );
  }

  // =========================================================================
  // PREVIOUS
  // =========================================================================

  @override
  Future<void>
      skipToPrevious() async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        try {
          final items =
              queue.value;

          if (items.isEmpty) {
            return;
          }

          final currentIndex =
              _player.currentIndex ??
                  0;

          if (currentIndex > 0) {
            await _player
                .seekToPrevious();

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
      },
    );
  }

  // =========================================================================
  // SKIP TO SPECIFIC QUEUE ITEM
  // =========================================================================

  @override
  Future<void> skipToQueueItem(
    int index,
  ) async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        try {
          final items =
              queue.value;

          if (index < 0 ||
              index >=
                  items.length) {
            return;
          }

          await _player.seek(
            Duration.zero,
            index: index,
          );

          await _player.play();

          _broadcastState();
        } catch (_) {
          _broadcastState();
        }
      },
    );
  }

  // =========================================================================
  // FAST FORWARD
  // =========================================================================

  @override
  Future<void> fastForward() async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
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
            await _player.seek(
              duration,
            );
          } else {
            await _player.seek(
              target,
            );
          }

          _broadcastState();
        } catch (_) {
          _broadcastState();
        }
      },
    );
  }

  // =========================================================================
  // REWIND
  // =========================================================================

  @override
  Future<void> rewind() async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
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
      },
    );
  }

  // =========================================================================
  // PLAY MEDIA ITEM
  // =========================================================================

  @override
  Future<void> playMediaItem(
    MediaItem item,
  ) async {
    await _ensureInitialized();

    final cleanId =
        item.id.trim();

    if (cleanId.isEmpty) {
      throw Exception(
        'Audio URL/path is empty',
      );
    }

    return _runExclusive<void>(
      () async {
        try {
          _resumeAfterInterruption =
              false;

          await _setQueueSource(
            items: <MediaItem>[
              item,
            ],
            initialIndex: 0,
            autoplay: true,
          );
        } catch (_) {
          _broadcastState();
          rethrow;
        }
      },
    );
  }

  // =========================================================================
  // ADD QUEUE ITEM
  // =========================================================================

  @override
  Future<void> addQueueItem(
    MediaItem item,
  ) async {
    await _ensureInitialized();

    if (item.id.trim().isEmpty) {
      return;
    }

    return _runExclusive<void>(
      () async {
        final oldQueue =
            List<MediaItem>.from(
          queue.value,
        );

        final wasPlaying =
            _player.playing;

        final currentIndex =
            _player.currentIndex ??
                0;

        final currentPosition =
            _player.position;

        final newQueue =
            <MediaItem>[
          ...oldQueue,
          item,
        ];

        try {
          await _setQueueSource(
            items: newQueue,
            initialIndex:
                oldQueue.isEmpty
                    ? 0
                    : currentIndex,
            autoplay:
                wasPlaying,
          );

          if (oldQueue.isNotEmpty &&
              currentIndex >= 0 &&
              currentIndex <
                  oldQueue.length &&
              currentPosition >
                  Duration.zero) {
            try {
              await _player.seek(
                currentPosition,
                index:
                    currentIndex,
              );
            } catch (_) {}
          }
        } catch (_) {
          _broadcastState();
          rethrow;
        }
      },
    );
  }

  // =========================================================================
  // ADD QUEUE ITEMS
  // =========================================================================

  @override
  Future<void> addQueueItems(
    List<MediaItem> items,
  ) async {
    await _ensureInitialized();

    if (items.isEmpty) {
      return;
    }

    final validItems =
        items
            .where(
              (item) =>
                  item.id.trim()
                      .isNotEmpty,
            )
            .toList();

    if (validItems.isEmpty) {
      return;
    }

    return _runExclusive<void>(
      () async {
        final oldQueue =
            List<MediaItem>.from(
          queue.value,
        );

        final wasPlaying =
            _player.playing;

        final currentIndex =
            _player.currentIndex ??
                0;

        final currentPosition =
            _player.position;

        final newQueue =
            <MediaItem>[
          ...oldQueue,
          ...validItems,
        ];

        try {
          await _setQueueSource(
            items: newQueue,
            initialIndex:
                oldQueue.isEmpty
                    ? 0
                    : currentIndex,
            autoplay:
                wasPlaying,
          );

          if (oldQueue.isNotEmpty &&
              currentIndex >= 0 &&
              currentIndex <
                  oldQueue.length &&
              currentPosition >
                  Duration.zero) {
            try {
              await _player.seek(
                currentPosition,
                index:
                    currentIndex,
              );
            } catch (_) {}
          }
        } catch (_) {
          _broadcastState();
          rethrow;
        }
      },
    );
  }

  // =========================================================================
  // REMOVE QUEUE ITEM
  // =========================================================================

  @override
  Future<void> removeQueueItemAt(
    int index,
  ) async {
    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        final oldQueue =
            List<MediaItem>.from(
          queue.value,
        );

        if (index < 0 ||
            index >=
                oldQueue.length) {
          return;
        }

        final currentIndex =
            _player.currentIndex ??
                0;

        final currentPosition =
            _player.position;

        final wasPlaying =
            _player.playing;

        oldQueue.removeAt(
          index,
        );

        if (oldQueue.isEmpty) {
          try {
            await _player.stop();
          } catch (_) {}

          _queueSource = null;

          queue.add(
            const <MediaItem>[],
          );

          mediaItem.add(null);

          _broadcastState();
          return;
        }

        int newIndex;

        if (index <
            currentIndex) {
          newIndex =
              currentIndex - 1;
        } else {
          newIndex =
              currentIndex.clamp(
            0,
            oldQueue.length - 1,
          );
        }

        try {
          await _setQueueSource(
            items: oldQueue,
            initialIndex:
                newIndex,
            autoplay:
                wasPlaying,
          );

          if (index !=
                  currentIndex &&
              newIndex >= 0 &&
              newIndex <
                  oldQueue.length &&
              currentPosition >
                  Duration.zero) {
            try {
              await _player.seek(
                currentPosition,
                index:
                    newIndex,
              );
            } catch (_) {}
          }
        } catch (_) {
          _broadcastState();
          rethrow;
        }
      },
    );
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

    await playMediaItem(
      item,
    );
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
    await _ensureInitialized();

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

    return _runExclusive<void>(
      () async {
        try {
          _resumeAfterInterruption =
              false;

          await _setQueueSource(
            items: <MediaItem>[
              item,
            ],
            initialIndex: 0,
            autoplay: true,
          );
        } catch (_) {
          _broadcastState();
          rethrow;
        }
      },
    );
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

    await _ensureInitialized();

    return _runExclusive<void>(
      () async {
        try {
          await _player.setSpeed(
            speed,
          );

          _broadcastState();
        } catch (_) {
          _broadcastState();
        }
      },
    );
  }

  // =========================================================================
  // VOLUME
  // =========================================================================

  Future<void> setVolume(
    double volume,
  ) async {
    await _ensureInitialized();

    final safeVolume =
        volume.clamp(
      0.0,
      1.0,
    );

    return _runExclusive<void>(
      () async {
        try {
          await _player.setVolume(
            safeVolume,
          );
        } catch (_) {}
      },
    );
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
  // ON TASK REMOVED
  // =========================================================================

  @override
  Future<void> onTaskRemoved() async {
    // لا نوقف الصوت عند إزالة التطبيق
    // من شاشة التطبيقات الأخيرة.
  }

  // =========================================================================
  // DISPOSE
  // =========================================================================

  Future<void> disposeHandler() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _playerStateSubscription
        ?.cancel();

    await _positionSubscription
        ?.cancel();

    await _durationSubscription
        ?.cancel();

    await _processingSubscription
        ?.cancel();

    await _sequenceSubscription
        ?.cancel();

    await _interruptionSubscription
        ?.cancel();

    try {
      await _player.stop();
    } catch (_) {}

    await _player.dispose();
  }
}

/// ===========================================================================
/// AudioController
/// ===========================================================================

class AudioController {
  AudioController._();

  static Sa7biAudioHandler? _handler;

  static bool _initialized =
      false;

  static final ValueNotifier<bool>
      isPlayingNotifier =
      ValueNotifier<bool>(
    false,
  );

  static ValueNotifier<bool>
      get isPlaying =>
          isPlayingNotifier;

  static final ValueNotifier<
          Duration>
      position =
      ValueNotifier<Duration>(
    Duration.zero,
  );

  static final ValueNotifier<
          Duration?>
      duration =
      ValueNotifier<Duration?>(
    null,
  );

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

  static Future<void>
      _initializationFuture =
      Future<void>.value();

  // =========================================================================
  // INITIALIZE
  // =========================================================================

  static Future<
          Sa7biAudioHandler>
      initialize() async {
    if (_handler != null &&
        _initialized) {
      return _handler!;
    }

    await _initializationFuture;

    if (_handler != null &&
        _initialized) {
      return _handler!;
    }

    final completer =
        Completer<void>();

    _initializationFuture =
        completer.future;

    try {
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
          handler.playbackState
              .listen(
        (state) {
          isPlayingNotifier
              .value =
              state.playing;

          position.value =
              state.updatePosition;

          final item =
              handler.mediaItem.value;

          if (item != null &&
              item.duration !=
                  null) {
            duration.value =
                item.duration;
          } else {
            duration.value =
                handler.duration;
          }
        },
      );

      completer.complete();

      return handler;
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(
          error,
          stackTrace,
        );
      }

      rethrow;
    } finally {
      if (completer.isCompleted) {
        // لا شيء.
      }
    }
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

  static Future<void> playLocalFile({
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
          Sa7biAudioHandler>
      initialize() {
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
        .seek(
      position,
    );
  }
}
