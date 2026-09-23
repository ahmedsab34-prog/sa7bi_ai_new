import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// ---------------------------------------------------------------------------
/// Sa7bi AI Audio Handler
/// ---------------------------------------------------------------------------
/// مسؤول عن:
/// - تشغيل الصوت في الخلفية.
/// - التحكم من شاشة القفل والإشعارات.
/// - Play / Pause / Stop.
/// - Seek.
/// - Next / Previous.
/// - Fast Forward / Rewind.
/// - تشغيل روابط الإنترنت.
/// - تشغيل الملفات المحلية.
/// - التعامل مع المكالمات/المقاطعات الصوتية.
/// ---------------------------------------------------------------------------
class Sa7biAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;

  bool _initialized = false;

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
          session.interruptionEventStream.listen((event) {
        if (event.begin) {
          if (event.type == AudioInterruptionType.duck) {
            _player.setVolume(0.35);
          } else {
            pause();
          }
        } else {
          _player.setVolume(1.0);
        }
      });

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

      _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          _broadcastState();

          final currentQueue = queue.value;
          if (currentQueue.length > 1) {
            final currentIndex = _player.currentIndex ?? 0;

            if (currentIndex + 1 < currentQueue.length) {
              skipToQueueItem(currentIndex + 1);
            }
          }
        }
      });

      _player.becomingNoisyEventStream.listen((_) {
        pause();
      });

      _broadcastState();
    } catch (_) {
      // الصوت يظل قابلاً للاستخدام حتى لو تعذر إعداد AudioSession.
    }
  }

  PlaybackState _buildPlaybackState() {
    final processingState = _player.processingState;

    AudioProcessingState audioProcessingState;

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

    return PlaybackState(
      controls: <MediaControl>[
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const <MediaAction>{
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const <int>[
        0,
        1,
        2,
      ],
      processingState: audioProcessingState,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    );
  }

  void _broadcastState() {
    playbackState.add(_buildPlaybackState());
  }

  // ---------------------------------------------------------------------------
  // Play
  // ---------------------------------------------------------------------------

  @override
  Future<void> play() async {
    await _initialize();

    try {
      await _player.play();
      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Pause
  // ---------------------------------------------------------------------------

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Stop
  // ---------------------------------------------------------------------------

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      _broadcastState();

      await super.stop();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Seek
  // ---------------------------------------------------------------------------

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Skip Next
  // ---------------------------------------------------------------------------

  @override
  Future<void> skipToNext() async {
    try {
      final currentQueue = queue.value;

      if (currentQueue.isEmpty) {
        return;
      }

      final currentIndex = _player.currentIndex ?? 0;

      if (currentIndex + 1 < currentQueue.length) {
        await _player.seekToNext();
        await _player.play();
      }

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Skip Previous
  // ---------------------------------------------------------------------------

  @override
  Future<void> skipToPrevious() async {
    try {
      final currentQueue = queue.value;

      if (currentQueue.isEmpty) {
        return;
      }

      final currentIndex = _player.currentIndex ?? 0;

      if (currentIndex > 0) {
        await _player.seekToPrevious();
        await _player.play();
      } else {
        await _player.seek(Duration.zero);
      }

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Fast Forward
  // ---------------------------------------------------------------------------

  @override
  Future<void> fastForward() async {
    try {
      final current = _player.position;
      final duration = _player.duration;

      final target = current + const Duration(seconds: 15);

      if (duration != null && target > duration) {
        await _player.seek(duration);
      } else {
        await _player.seek(target);
      }

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Rewind
  // ---------------------------------------------------------------------------

  @override
  Future<void> rewind() async {
    try {
      final current = _player.position;
      final target = current - const Duration(seconds: 15);

      await _player.seek(
        target.isNegative ? Duration.zero : target,
      );

      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Play MediaItem
  // ---------------------------------------------------------------------------
  // مهم:
  // استخدمنا اسم item بدل mediaItem حتى لا يحصل shadowing مع
  // BaseAudioHandler.mediaItem.
  // ---------------------------------------------------------------------------

  @override
  Future<void> playMediaItem(MediaItem item) async {
    await _initialize();

    try {
      mediaItem.add(item);
      queue.add(<MediaItem>[item]);

      final cleanUrl = item.id.trim();

      if (cleanUrl.isEmpty) {
        throw Exception('Audio URL is empty');
      }

      await _player.setUrl(cleanUrl);
      await _player.play();

      _broadcastState();
    } catch (_) {
      _broadcastState();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Queue
  // ---------------------------------------------------------------------------

  @override
  Future<void> addQueueItem(MediaItem item) async {
    final updatedQueue = List<MediaItem>.from(queue.value);

    updatedQueue.add(item);

    queue.add(updatedQueue);

    if (_player.audioSource == null) {
      mediaItem.add(item);

      final cleanUrl = item.id.trim();

      if (cleanUrl.isNotEmpty) {
        await _player.setUrl(cleanUrl);
      }

      _broadcastState();
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> items) async {
    if (items.isEmpty) {
      return;
    }

    final updatedQueue = List<MediaItem>.from(queue.value);
    updatedQueue.addAll(items);

    queue.add(updatedQueue);

    if (_player.audioSource == null) {
      final first = items.first;
      mediaItem.add(first);

      final cleanUrl = first.id.trim();

      if (cleanUrl.isNotEmpty) {
        await _player.setUrl(cleanUrl);
      }
    }

    _broadcastState();
  }

  // ---------------------------------------------------------------------------
  // Remove Queue Item
  // ---------------------------------------------------------------------------

  @override
  Future<void> removeQueueItemAt(int index) async {
    final updatedQueue = List<MediaItem>.from(queue.value);

    if (index < 0 || index >= updatedQueue.length) {
      return;
    }

    updatedQueue.removeAt(index);
    queue.add(updatedQueue);

    _broadcastState();
  }

  // ---------------------------------------------------------------------------
  // Play URL
  // ---------------------------------------------------------------------------

  Future<void> playUrl(
    String url, {
    String title = 'صوت من صاحبي AI',
    String? artist,
    String? album,
    String? artUri,
  }) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      throw Exception('Audio URL is empty');
    }

    final item = MediaItem(
      id: cleanUrl,
      title: title,
      artist: artist ?? 'صاحبي AI',
      album: album ?? 'صاحبي AI',
      artUri: artUri == null || artUri.trim().isEmpty
          ? null
          : Uri.tryParse(artUri),
    );

    await playMediaItem(item);
  }

  // ---------------------------------------------------------------------------
  // Play Local File
  // ---------------------------------------------------------------------------

  Future<void> playLocalFile(
    String path, {
    String title = 'ملف صوتي',
    String? artist,
  }) async {
    final cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      throw Exception('Audio file path is empty');
    }

    final file = File(cleanPath);

    if (!await file.exists()) {
      throw Exception('Audio file does not exist');
    }

    final item = MediaItem(
      id: cleanPath,
      title: title,
      artist: artist ?? 'صاحبي AI',
      album: 'ملفات صوتية',
    );

    try {
      mediaItem.add(item);
      queue.add(<MediaItem>[item]);

      await _player.setFilePath(cleanPath);
      await _player.play();

      _broadcastState();
    } catch (_) {
      _broadcastState();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Speed
  // ---------------------------------------------------------------------------

  Future<void> setSpeed(double speed) async {
    if (speed <= 0) {
      return;
    }

    try {
      await _player.setSpeed(speed);
      _broadcastState();
    } catch (_) {
      _broadcastState();
    }
  }

  // ---------------------------------------------------------------------------
  // Volume
  // ---------------------------------------------------------------------------

  Future<void> setVolume(double volume) async {
    final safeVolume = volume.clamp(0.0, 1.0);

    try {
      await _player.setVolume(safeVolume);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Current information
  // ---------------------------------------------------------------------------

  Duration get position => _player.position;

  Duration? get duration => _player.duration;

  bool get isPlaying => _player.playing;

  ProcessingState get processingState => _player.processingState;

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  Future<void> disposeHandler() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _interruptionSubscription?.cancel();

    await _player.dispose();
  }

  @override
  Future<void> onTaskRemoved() async {
    // لا نوقف الصوت هنا.
    // المطلوب أن يستمر التشغيل في الخلفية بعد خروج التطبيق من الشاشة.
  }
}

/// ---------------------------------------------------------------------------
/// AudioController
/// ---------------------------------------------------------------------------
/// واجهة بسيطة تستخدمها شاشات التطبيق بدل التعامل مباشرة مع AudioHandler.
/// ---------------------------------------------------------------------------
class AudioController {
  AudioController._();

  static Sa7biAudioHandler? _handler;
  static bool _initialized = false;

  static final ValueNotifier<bool> isPlaying =
      ValueNotifier<bool>(false);

  static final ValueNotifier<Duration> position =
      ValueNotifier<Duration>(Duration.zero);

  static final ValueNotifier<Duration?> duration =
      ValueNotifier<Duration?>(null);

  static StreamSubscription<PlaybackState>? _playbackSubscription;

  static Future<Sa7biAudioHandler> initialize() async {
    if (_handler != null && _initialized) {
      return _handler!;
    }

    final handler = await AudioService.init(
      builder: () => Sa7biAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.example.sa7bi_ai_new.audio',
        androidNotificationChannelName:
            'صاحبي AI - الصوت',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
        androidNotificationIcon:
            'mipmap/ic_launcher',
        notificationColorized: true,
        notificationClickStartsActivity: true,
      ),
    );

    _handler = handler;
    _initialized = true;

    await _playbackSubscription?.cancel();

    _playbackSubscription =
        handler.playbackState.listen((state) {
      isPlaying.value = state.playing;
      position.value = state.updatePosition;

      final currentItem = handler.mediaItem.value;

      if (currentItem != null) {
        final currentDuration = currentItem.duration;

        duration.value = currentDuration ??
            (state.processingState == AudioProcessingState.ready
                ? handlerDuration(handler)
                : null);
      } else {
        duration.value = handlerDuration(handler);
      }
    });

    return handler;
  }

  static Duration? handlerDuration(
    Sa7biAudioHandler handler,
  ) {
    return handler.duration;
  }

  static Future<void> playUrl(
    String url, {
    String title = 'صوت من صاحبي AI',
    String? artist,
    String? album,
    String? artUri,
  }) async {
    final handler = await initialize();

    await handler.playUrl(
      url,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
    );
  }

  static Future<void> playLocalFile(
    String path, {
    String title = 'ملف صوتي',
    String? artist,
  }) async {
    final handler = await initialize();

    await handler.playLocalFile(
      path,
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

  static Sa7biAudioHandler? get handler => _handler;
}

/// ---------------------------------------------------------------------------
/// Backward-compatible wrapper
/// ---------------------------------------------------------------------------
/// لو أي ملف قديم في المشروع ما زال يستدعي Sa7biAudioService، يظل شغالًا.
/// ---------------------------------------------------------------------------
class Sa7biAudioService {
  Sa7biAudioService._();

  static Future<Sa7biAudioHandler> initialize() {
    return AudioController.initialize();
  }

  static Future<void> playUrl(
    String url, {
    String title = 'صوت من صاحبي AI',
    String? artist,
    String? album,
    String? artUri,
  }) {
    return AudioController.playUrl(
      url,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
    );
  }

  static Future<void> playLocalFile(
    String path, {
    String title = 'ملف صوتي',
    String? artist,
  }) {
    return AudioController.playLocalFile(
      path,
      title: title,
      artist: artist,
    );
  }

  static Future<void> play() {
    return AudioController.play();
  }

  static Future<void> pause() {
    return AudioController.pause();
  }

  static Future<void> stop() {
    return AudioController.stop();
  }

  static Future<void> seek(Duration position) {
    return AudioController.seek(position);
  }
}
