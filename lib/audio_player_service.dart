import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// خدمة الصوت الأساسية لتطبيق صاحبي AI.
///
/// تحافظ على:
/// - Background playback
/// - Lock-screen controls
/// - استمرار الصوت عند الخروج من التطبيق
/// - Mini player
/// - استئناف التشغيل
///
/// وتضيف:
/// - Audio Focus
/// - إيقاف الصوت تلقائيًا عند المكالمات/استخدام الميكروفون
/// - استئناف الصوت تلقائيًا بعد انتهاء المقاطعة
/// - إيقاف الصوت عند فصل السماعة
class Sa7biAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  Sa7biAudioHandler()
      : _player = AudioPlayer(
          // نحن ندير المقاطعات بأنفسنا.
          handleInterruptions: false,
        ) {
    _initialize();
  }

  final AudioPlayer _player;

  AudioSession? _audioSession;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  StreamSubscription<AudioInterruptionEvent>?
      _interruptionSubscription;

  StreamSubscription<void>?
      _becomingNoisySubscription;

  bool _pausedByInterruption = false;
  bool _disposed = false;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initialize() async {
    try {
      final session = await AudioSession.instance;

      if (_disposed) {
        return;
      }

      _audioSession = session;

      await session.configure(
        const AudioSessionConfiguration.music(),
      );

      // --------------------------------------------------------
      // Audio interruptions
      //
      // مثال:
      // WhatsApp call
      // Phone call
      // Voice recording
      // Google Assistant
      // أي تطبيق آخر يحصل على Audio Focus
      // --------------------------------------------------------

      _interruptionSubscription =
          session.interruptionEventStream.listen(
        _handleAudioInterruption,
      );

      // --------------------------------------------------------
      // Headphones / Bluetooth disconnected
      // --------------------------------------------------------

      _becomingNoisySubscription =
          session.becomingNoisyEventStream.listen(
        (_) async {
          if (_disposed) {
            return;
          }

          if (_player.playing) {
            await _player.pause();
            _broadcastState();
          }
        },
      );

      // --------------------------------------------------------
      // Player streams
      // --------------------------------------------------------

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
          _broadcastState();
        },
      );

      _broadcastState();
    } catch (error) {
      debugPrint(
        'Sa7biAudioHandler initialization error: $error',
      );
    }
  }

  // ============================================================
  // AUDIO INTERRUPTION
  // ============================================================

  Future<void> _handleAudioInterruption(
    AudioInterruptionEvent event,
  ) async {
    if (_disposed) {
      return;
    }

    try {
      if (event.begin) {
        // ------------------------------------------------------
        // أي مقاطعة تبدأ:
        //
        // نوقف صوت صاحبي إذا كان يعمل.
        //
        // نحتفظ بعلامة خاصة حتى نعرف هل نعيده أم لا.
        // ------------------------------------------------------

        if (_player.playing) {
          _pausedByInterruption = true;

          await _player.pause();

          _broadcastState();
        }

        return;
      }

      // --------------------------------------------------------
      // المقاطعة انتهت.
      //
      // نعيد الصوت فقط إذا كان التطبيق هو الذي أوقفه
      // بسبب المقاطعة.
      // --------------------------------------------------------

      if (_pausedByInterruption) {
        _pausedByInterruption = false;

        if (!_disposed) {
          await _player.play();
          _broadcastState();
        }
      }
    } catch (error) {
      debugPrint(
        'Audio interruption handling error: $error',
      );
    }
  }

  // ============================================================
  // PLAYBACK STATE
  // ============================================================

  void _broadcastState() {
    if (_disposed) {
      return;
    }

    final playing = _player.playing;

    AudioController._updatePlayingState(
      playing,
    );

    final processingState =
        switch (_player.processingState) {
      ProcessingState.idle =>
        AudioProcessingState.idle,
      ProcessingState.loading =>
        AudioProcessingState.loading,
      ProcessingState.buffering =>
        AudioProcessingState.buffering,
      ProcessingState.ready =>
        AudioProcessingState.ready,
      ProcessingState.completed =>
        AudioProcessingState.completed,
    };

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing)
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
        processingState: processingState,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition:
            _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  // ============================================================
  // AUDIO SERVICE CONTROLS
  // ============================================================

  @override
  Future<void> play() async {
    if (_disposed) {
      return;
    }

    try {
      await _player.play();
      _broadcastState();
    } catch (error) {
      debugPrint(
        'Audio play error: $error',
      );
    }
  }

  @override
  Future<void> pause() async {
    if (_disposed) {
      return;
    }

    try {
      await _player.pause();

      _pausedByInterruption = false;

      _broadcastState();
    } catch (error) {
      debugPrint(
        'Audio pause error: $error',
      );
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) {
      return;
    }

    try {
      _pausedByInterruption = false;

      await _player.stop();

      AudioController._updatePlayingState(
        false,
      );

      await super.stop();
    } catch (error) {
      debugPrint(
        'Audio stop error: $error',
      );
    }
  }

  @override
  Future<void> seek(
    Duration position,
  ) async {
    if (_disposed) {
      return;
    }

    try {
      await _player.seek(position);
      _broadcastState();
    } catch (error) {
      debugPrint(
        'Audio seek error: $error',
      );
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_disposed) {
      return;
    }

    try {
      if (_player.hasNext) {
        await _player.seekToNext();
        _broadcastState();
      }
    } catch (error) {
      debugPrint(
        'Audio next error: $error',
      );
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_disposed) {
      return;
    }

    try {
      if (_player.hasPrevious) {
        await _player.seekToPrevious();
        _broadcastState();
      }
    } catch (error) {
      debugPrint(
        'Audio previous error: $error',
      );
    }
  }

  @override
  Future<void> fastForward() async {
    if (_disposed) {
      return;
    }

    try {
      final current = _player.position;
      final duration =
          _player.duration ?? Duration.zero;

      var target =
          current + const Duration(seconds: 10);

      if (duration > Duration.zero &&
          target > duration) {
        target = duration;
      }

      await _player.seek(target);
      _broadcastState();
    } catch (error) {
      debugPrint(
        'Audio fast-forward error: $error',
      );
    }
  }

  @override
  Future<void> rewind() async {
    if (_disposed) {
      return;
    }

    try {
      var target =
          _player.position -
          const Duration(seconds: 10);

      if (target < Duration.zero) {
        target = Duration.zero;
      }

      await _player.seek(target);
      _broadcastState();
    } catch (error) {
      debugPrint(
        'Audio rewind error: $error',
      );
    }
  }

  // ============================================================
  // MEDIA ITEM
  // ============================================================

  @override
  Future<void> playMediaItem(
    MediaItem mediaItem,
  ) async {
    final cleanUrl =
        mediaItem.id.trim();

    if (cleanUrl.isEmpty) {
      throw ArgumentError(
        'Audio URL is empty',
      );
    }

    if (_disposed) {
      throw StateError(
        'Audio handler is disposed',
      );
    }

    mediaItem.add(mediaItem);
    queue.add([mediaItem]);

    await _player.setUrl(cleanUrl);
    await _player.play();

    _broadcastState();
  }

  // ============================================================
  // PLAY URL
  // ============================================================

  Future<void> playUrl({
    required String url,
    String title = 'صاحبي AI',
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      throw ArgumentError(
        'Audio URL is empty',
      );
    }

    if (_disposed) {
      throw StateError(
        'Audio handler is disposed',
      );
    }

    final item = MediaItem(
      id: cleanUrl,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );

    mediaItem.add(item);
    queue.add([item]);

    await _player.setUrl(cleanUrl);
    await _player.play();

    _broadcastState();
  }

  // ============================================================
  // LOCAL FILE
  // ============================================================

  Future<void> playLocalFile({
    required String path,
    String title = 'صاحبي AI',
    String? artist,
    String? album,
  }) async {
    final cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      throw ArgumentError(
        'Audio file path is empty',
      );
    }

    if (_disposed) {
      throw StateError(
        'Audio handler is disposed',
      );
    }

    final item = MediaItem(
      id: cleanPath,
      title: title,
      artist: artist,
      album: album,
    );

    mediaItem.add(item);
    queue.add([item]);

    await _player.setFilePath(cleanPath);
    await _player.play();

    _broadcastState();
  }

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isPlaying =>
      _player.playing;

  Duration get position =>
      _player.position;

  Duration? get duration =>
      _player.duration;

  // ============================================================
  // BACKGROUND
  // ============================================================

  @override
  Future<void> onTaskRemoved() async {
    // مهم جدًا:
    //
    // لا نوقف الصوت عندما يزيل المستخدم التطبيق
    // من قائمة التطبيقات الأخيرة.
    //
    // وبالتالي يستمر التشغيل في الخلفية.
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> disposePlayer() async {
    if (_disposed) {
      return;
    }

    _disposed = true;

    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();

    _playerStateSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;
    _interruptionSubscription = null;
    _becomingNoisySubscription = null;

    _pausedByInterruption = false;

    AudioController._updatePlayingState(
      false,
    );

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

  static Future<Sa7biAudioHandler>?
      _initializing;

  static final ValueNotifier<
      Sa7biAudioHandler?>
      handlerNotifier =
      ValueNotifier<Sa7biAudioHandler?>(
    null,
  );

  static final ValueNotifier<bool>
      isPlayingNotifier =
      ValueNotifier<bool>(false);

  // ============================================================
  // GETTERS
  // ============================================================

  static Sa7biAudioHandler? get handler =>
      _handler;

  static bool get isInitialized =>
      _initialized &&
      _handler != null;

  static Stream<PlaybackState>
      get playbackStateStream {
    final currentHandler = _handler;

    if (currentHandler == null) {
      return const Stream<
          PlaybackState>.empty();
    }

    return currentHandler.playbackState;
  }

  // ============================================================
  // STATE
  // ============================================================

  static void _updatePlayingState(
    bool playing,
  ) {
    if (isPlayingNotifier.value !=
        playing) {
      isPlayingNotifier.value =
          playing;
    }
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  static Future<Sa7biAudioHandler>
      initialize() async {
    if (_initialized &&
        _handler != null) {
      return _handler!;
    }

    final currentInitializing =
        _initializing;

    if (currentInitializing != null) {
      return currentInitializing;
    }

    final future =
        _createHandler();

    _initializing = future;

    try {
      return await future;
    } finally {
      if (identical(
        _initializing,
        future,
      )) {
        _initializing = null;
      }
    }
  }

  static Future<Sa7biAudioHandler>
      _createHandler() async {
    try {
      final createdHandler =
          await AudioService.init(
        builder: () =>
            Sa7biAudioHandler(),
        config:
            const AudioServiceConfig(
          androidNotificationChannelId:
              'com.sa7bi.ai.audio',
          androidNotificationChannelName:
              'صاحبي AI - الصوت',
          androidNotificationOngoing:
              false,
          androidStopForegroundOnPause:
              false,
          androidNotificationIcon:
              'drawable/app_icon',
          androidResumeOnClick:
              true,
        ),
      );

      _handler = createdHandler;

      _initialized = true;

      handlerNotifier.value =
          createdHandler;

      _updatePlayingState(
        createdHandler.isPlaying,
      );

      return createdHandler;
    } catch (_) {
      _handler = null;

      _initialized = false;

      handlerNotifier.value = null;

      _updatePlayingState(false);

      rethrow;
    }
  }

  // ============================================================
  // PLAY URL
  // ============================================================

  static Future<void> playUrl({
    required String url,
    String title = 'صاحبي AI',
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) async {
    final audioHandler =
        await initialize();

    await audioHandler.playUrl(
      url: url,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );
  }

  // ============================================================
  // LOCAL FILE
  // ============================================================

  static Future<void> playLocalFile({
    required String path,
    String title = 'صاحبي AI',
    String? artist,
    String? album,
  }) async {
    final audioHandler =
        await initialize();

    await audioHandler.playLocalFile(
      path: path,
      title: title,
      artist: artist,
      album: album,
    );
  }

  // ============================================================
  // PAUSE
  // ============================================================

  static Future<void> pause() async {
    await _handler?.pause();

    _updatePlayingState(false);
  }

  // ============================================================
  // PLAY
  // ============================================================

  static Future<void> play() async {
    await _handler?.play();

    if (_handler != null) {
      _updatePlayingState(
        _handler!.isPlaying,
      );
    }
  }

  // ============================================================
  // STOP
  // ============================================================

  static Future<void> stop() async {
    await _handler?.stop();

    _updatePlayingState(false);
  }

  // ============================================================
  // SEEK
  // ============================================================

  static Future<void> seek(
    Duration position,
  ) async {
    await _handler?.seek(position);
  }
}

// ============================================================
// BACKWARD COMPATIBILITY
// ============================================================

class Sa7biAudioService {
  Sa7biAudioService._();

  static final Sa7biAudioService instance =
      Sa7biAudioService._();

  Future<Sa7biAudioHandler> initialize() {
    return AudioController.initialize();
  }

  Future<void> playUrl({
    required String url,
    String title = 'صاحبي AI',
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) {
    return AudioController.playUrl(
      url: url,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );
  }

  Future<void> playLocalFile({
    required String path,
    String title = 'صاحبي AI',
    String? artist,
    String? album,
  }) {
    return AudioController.playLocalFile(
      path: path,
      title: title,
      artist: artist,
      album: album,
    );
  }

  Future<void> pause() {
    return AudioController.pause();
  }

  Future<void> play() {
    return AudioController.play();
  }

  Future<void> stop() {
    return AudioController.stop();
  }

  Future<void> seek(
    Duration position,
  ) {
    return AudioController.seek(position);
  }
}
