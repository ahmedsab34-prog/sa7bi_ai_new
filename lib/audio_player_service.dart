import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// ============================================================
/// Sa7bi AI Background Audio Handler
/// ============================================================
///
/// مسؤول عن:
/// - تشغيل الصوت داخل التطبيق
/// - تشغيل الصوت في الخلفية
/// - إشعار Android
/// - شاشة القفل
/// - Play / Pause / Stop
/// - Seek
/// - تشغيل روابط الإنترنت
/// - تشغيل ملفات الصوت من الهاتف
///
/// لا يتم إنشاء أكثر من AudioHandler واحد.
/// ============================================================

class Sa7biAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlaybackEvent>? _playbackSubscription;
  StreamSubscription<int?>? _indexSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  bool _initialized = false;
  Future<void>? _initializing;

  Sa7biAudioHandler() {
    _initializing = _initialize();
  }

  /// ------------------------------------------------------------
  /// Initialize audio engine
  /// ------------------------------------------------------------

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }

    final session = await AudioSession.instance;

    await session.configure(
      const AudioSessionConfiguration.music(),
    );

    _playbackSubscription =
        _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object error, StackTrace stackTrace) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState:
                AudioProcessingState.error,
          ),
        );
      },
    );

    _indexSubscription =
        _player.currentIndexStream.listen(
      (index) {
        if (index == null) {
          return;
        }

        final items = queue.value;

        if (index < 0 || index >= items.length) {
          return;
        }

        mediaItem.add(items[index]);
      },
    );

    _positionSubscription =
        _player.positionStream.listen(
      (position) {
        final current =
            playbackState.value;

        playbackState.add(
          current.copyWith(
            updatePosition: position,
            bufferedPosition:
                _player.bufferedPosition,
            speed: _player.speed,
          ),
        );
      },
    );

    _initialized = true;

    _broadcastState(
      _player.playbackEvent,
    );
  }

  Future<void> _ensureInitialized() async {
    final future = _initializing;

    if (future != null) {
      await future;
    }

    if (!_initialized) {
      _initializing = _initialize();

      try {
        await _initializing;
      } finally {
        _initializing = null;
      }
    }
  }

  /// ------------------------------------------------------------
  /// Convert just_audio state to audio_service state
  /// ------------------------------------------------------------

  void _broadcastState(
    PlaybackEvent event,
  ) {
    final processingState =
        const <ProcessingState,
            AudioProcessingState>{
      ProcessingState.idle:
          AudioProcessingState.idle,
      ProcessingState.loading:
          AudioProcessingState.loading,
      ProcessingState.buffering:
          AudioProcessingState.buffering,
      ProcessingState.ready:
          AudioProcessingState.ready,
      ProcessingState.completed:
          AudioProcessingState.completed,
    }[_player.processingState]!;

    final playing =
        _player.playing;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (playing)
            MediaControl.pause
          else
            MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices:
            const [0, 1],
        processingState:
            processingState,
        playing: playing,
        updatePosition:
            _player.position,
        bufferedPosition:
            _player.bufferedPosition,
        speed: _player.speed,
        queueIndex:
            event.currentIndex,
      ),
    );
  }

  /// ------------------------------------------------------------
  /// PLAY
  /// ------------------------------------------------------------

  @override
  Future<void> play() async {
    await _ensureInitialized();

    await _player.play();
  }

  /// ------------------------------------------------------------
  /// PAUSE
  /// ------------------------------------------------------------

  @override
  Future<void> pause() async {
    await _ensureInitialized();

    await _player.pause();
  }

  /// ------------------------------------------------------------
  /// STOP
  /// ------------------------------------------------------------

  @override
  Future<void> stop() async {
    await _ensureInitialized();

    await _player.stop();

    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        processingState:
            AudioProcessingState.idle,
        updatePosition:
            Duration.zero,
        bufferedPosition:
            Duration.zero,
      ),
    );

    await super.stop();
  }

  /// ------------------------------------------------------------
  /// SEEK
  /// ------------------------------------------------------------

  @override
  Future<void> seek(
    Duration position,
  ) async {
    await _ensureInitialized();

    await _player.seek(position);
  }

  /// ------------------------------------------------------------
  /// PLAY MEDIA ITEM
  /// ------------------------------------------------------------

  @override
  Future<void> playMediaItem(
    MediaItem item,
  ) async {
    await playUrl(
      url: item.id,
      title: item.title,
      artist:
          item.artist ?? 'صحبي AI',
    );
  }

  /// ------------------------------------------------------------
  /// PLAY URL
  /// ------------------------------------------------------------

  Future<void> playUrl({
    required String url,
    required String title,
    String? artist,
  }) async {
    await _ensureInitialized();

    final cleanUrl =
        url.trim();

    if (cleanUrl.isEmpty) {
      throw Exception(
        'رابط الصوت فارغ.',
      );
    }

    final item = MediaItem(
      id: cleanUrl,
      title: title.trim().isEmpty
          ? 'صوت من صحبي AI'
          : title.trim(),
      artist:
          artist ?? 'صحبي AI',
    );

    mediaItem.add(item);

    await _player.stop();

    await _player.setUrl(
      cleanUrl,
    );

    await _player.play();
  }

  /// ------------------------------------------------------------
  /// PLAY LOCAL FILE
  /// ------------------------------------------------------------

  Future<void> playLocalFile({
    required String path,
    required String title,
    String? artist,
  }) async {
    await _ensureInitialized();

    final cleanPath =
        path.trim();

    if (cleanPath.isEmpty) {
      throw Exception(
        'مسار ملف الصوت فارغ.',
      );
    }

    final file =
        File(cleanPath);

    if (!await file.exists()) {
      throw Exception(
        'ملف الصوت غير موجود.',
      );
    }

    final item = MediaItem(
      id: cleanPath,
      title: title.trim().isEmpty
          ? 'ملف صوتي'
          : title.trim(),
      artist:
          artist ?? 'من الهاتف',
    );

    mediaItem.add(item);

    await _player.stop();

    await _player.setFilePath(
      cleanPath,
    );

    await _player.play();
  }

  /// ------------------------------------------------------------
  /// SKIP FORWARD
  /// ------------------------------------------------------------

  @override
  Future<void> fastForward() async {
    await _ensureInitialized();

    final position =
        _player.position;

    final duration =
        _player.duration;

    if (duration == null) {
      return;
    }

    final target =
        position +
            const Duration(
              seconds: 10,
            );

    await _player.seek(
      target > duration
          ? duration
          : target,
    );
  }

  /// ------------------------------------------------------------
  /// SKIP BACKWARD
  /// ------------------------------------------------------------

  @override
  Future<void> rewind() async {
    await _ensureInitialized();

    final position =
        _player.position;

    final target =
        position -
            const Duration(
              seconds: 10,
            );

    await _player.seek(
      target < Duration.zero
          ? Duration.zero
          : target,
    );
  }

  /// ------------------------------------------------------------
  /// TASK REMOVED
  /// ------------------------------------------------------------

  @override
  Future<void> onTaskRemoved() async {
    // لا نوقف الصوت هنا.
    //
    // audio_service يعمل كـ foreground service
    // أثناء التشغيل، لذلك يظل الصوت قادرًا
    // على الاستمرار عند إزالة واجهة التطبيق
    // من التطبيقات الأخيرة.
  }

  /// ------------------------------------------------------------
  /// DISPOSE
  /// ------------------------------------------------------------

  Future<void> disposePlayer() async {
    await _playbackSubscription?.cancel();
    await _indexSubscription?.cancel();
    await _positionSubscription?.cancel();

    await _player.dispose();
  }
}

/// ============================================================
/// Sa7bi Audio Controller
/// ============================================================
///
/// نقطة الدخول الوحيدة للصوت داخل التطبيق.
///
/// main.dart يستخدم:
///
/// AudioController.initialize()
///
/// AudioCenterScreen يستخدم نفس الشيء.
///
/// لا يتم إنشاء AudioService مرتين.
/// ============================================================

class AudioController {
  static Sa7biAudioHandler? _handler;

  static Future<Sa7biAudioHandler>?
      _initializing;

  /// ------------------------------------------------------------
  /// INITIALIZE
  /// ------------------------------------------------------------

  static Future<Sa7biAudioHandler>
      initialize() async {
    if (_handler != null) {
      return _handler!;
    }

    final existing =
        _initializing;

    if (existing != null) {
      return existing;
    }

    final future =
        _createHandler();

    _initializing = future;

    try {
      final handler =
          await future;

      _handler = handler;

      return handler;
    } finally {
      _initializing = null;
    }
  }

  /// ------------------------------------------------------------
  /// CREATE HANDLER
  /// ------------------------------------------------------------

  static Future<Sa7biAudioHandler>
      _createHandler() async {
    final handler =
        await AudioService.init(
      builder:
          () => Sa7biAudioHandler(),
      config:
          const AudioServiceConfig(
        androidNotificationChannelId:
            'com.sa7bi.ai.audio',

        androidNotificationChannelName:
            'صحبي AI - الصوت',

        androidNotificationOngoing:
            true,

        // مهم جدًا لتجنب مشاكل إعادة تشغيل
        // الـ foreground service على Android.
        androidStopForegroundOnPause:
            false,

        androidNotificationIcon:
            'mipmap/ic_launcher',

        androidResumeOnClick:
            true,
      ),
    );

    return handler
        as Sa7biAudioHandler;
  }

  /// ------------------------------------------------------------
  /// GET HANDLER
  /// ------------------------------------------------------------

  static Sa7biAudioHandler?
      get handler => _handler;
}

/// ============================================================
/// Compatibility service
/// ============================================================
///
/// موجود فقط للحفاظ على أي كود قديم يستخدم
/// Sa7biAudioService.
/// ============================================================

class Sa7biAudioService {
  static Future<Sa7biAudioHandler>
      init() {
    return AudioController
        .initialize();
  }

  static Sa7biAudioHandler?
      get handler =>
          AudioController.handler;
}
