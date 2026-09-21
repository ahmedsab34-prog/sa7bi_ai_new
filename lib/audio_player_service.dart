import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// خدمة الصوت الأساسية لتطبيق صاحبي AI.
///
/// مسؤولة عن:
/// - تشغيل الصوت من الإنترنت.
/// - تشغيل الملفات المحلية.
/// - التشغيل في الخلفية.
/// - إشعار Android.
/// - أزرار التشغيل والإيقاف.
/// - التحكم من شاشة القفل.
/// - استمرار الصوت أثناء التنقل داخل التطبيق.
/// - إيقاف الصوت عند إغلاق التطبيق بالكامل حسب سلوك Android.
class Sa7biAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  Sa7biAudioHandler() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final session = await AudioSession.instance;

      await session.configure(
        const AudioSessionConfiguration.music(),
      );

      _playerStateSubscription =
          _player.playerStateStream.listen((_) {
        _broadcastState();
      });

      _positionSubscription =
          _player.positionStream.listen((_) {
        _broadcastState();
      });

      _durationSubscription =
          _player.durationStream.listen((_) {
        _broadcastState();
      });

      _broadcastState();
    } catch (_) {
      // لا نوقف التطبيق إذا فشل إعداد جلسة الصوت.
    }
  }

  void _broadcastState() {
    final processingState = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

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
        androidCompactActionIndices: const [0, 1, 2],
        processingState: processingState,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
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
    }
  }

  @override
  Future<void> fastForward() async {
    final current = _player.position;
    final duration = _player.duration ?? Duration.zero;

    var target = current + const Duration(seconds: 10);

    if (duration > Duration.zero && target > duration) {
      target = duration;
    }

    await _player.seek(target);
  }

  @override
  Future<void> rewind() async {
    var target =
        _player.position - const Duration(seconds: 10);

    if (target < Duration.zero) {
      target = Duration.zero;
    }

    await _player.seek(target);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    await _player.setUrl(mediaItem.id);

    this.mediaItem.add(mediaItem);
    queue.add([mediaItem]);

    await _player.play();
  }

  /// تشغيل رابط صوت مباشر.
  Future<void> playUrl({
    required String url,
    String title = 'صحبي AI',
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      throw ArgumentError('Audio URL is empty');
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
  }

  /// تشغيل ملف صوت موجود على الهاتف.
  Future<void> playLocalFile({
    required String path,
    String title = 'صحبي AI',
    String? artist,
    String? album,
  }) async {
    final cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      throw ArgumentError('Audio file path is empty');
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
  }

  bool get isPlaying => _player.playing;

  Duration get position => _player.position;

  Duration? get duration => _player.duration;

  @override
  Future<void> onTaskRemoved() async {
    // نحافظ على السلوك الحالي:
    // لا نوقف الصوت بمجرد إزالة التطبيق من شاشة التطبيقات الأخيرة.
  }

  Future<void> disposePlayer() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();

    await _player.dispose();
  }
}

/// مدير الصوت الرئيسي للتطبيق.
class AudioController {
  AudioController._();

  static Sa7biAudioHandler? _handler;
  static bool _initialized = false;
  static Future<Sa7biAudioHandler>? _initializing;

  /// الـ AudioHandler الحالي.
  static Sa7biAudioHandler? get handler => _handler;

  /// Stream حالة التشغيل.
  ///
  /// يستخدمه:
  /// - AudioCenterScreen
  /// - MiniAudioPlayer
  /// - أي واجهة تحتاج معرفة هل الصوت يعمل أم متوقف.
  static Stream<PlaybackState> get playbackStateStream {
    final currentHandler = _handler;

    if (currentHandler == null) {
      return const Stream<PlaybackState>.empty();
    }

    return currentHandler.playbackState;
  }

  /// تهيئة نظام الصوت مرة واحدة فقط.
  static Future<Sa7biAudioHandler> initialize() async {
    if (_initialized && _handler != null) {
      return _handler!;
    }

    if (_initializing != null) {
      return _initializing!;
    }

    _initializing = _createHandler();

    try {
      final result = await _initializing!;
      return result;
    } finally {
      _initializing = null;
    }
  }

  static Future<Sa7biAudioHandler> _createHandler() async {
    try {
      _handler = await AudioService.init(
        builder: () => Sa7biAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'com.sa7bi.ai.audio',
          androidNotificationChannelName:
              'صحبي AI - الصوت',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
          androidNotificationIcon:
              'drawable/app_icon',
          androidResumeOnClick: true,
        ),
      );

      _initialized = true;

      return _handler!;
    } catch (_) {
      _handler = null;
      _initialized = false;
      rethrow;
    }
  }

  static Future<void> playUrl({
    required String url,
    String title = 'صحبي AI',
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) async {
    final audioHandler = await initialize();

    await audioHandler.playUrl(
      url: url,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );
  }

  static Future<void> playLocalFile({
    required String path,
    String title = 'صحبي AI',
    String? artist,
    String? album,
  }) async {
    final audioHandler = await initialize();

    await audioHandler.playLocalFile(
      path: path,
      title: title,
      artist: artist,
      album: album,
    );
  }

  static Future<void> pause() async {
    await _handler?.pause();
  }

  static Future<void> play() async {
    await _handler?.play();
  }

  static Future<void> stop() async {
    await _handler?.stop();
  }

  static Future<void> seek(Duration position) async {
    await _handler?.seek(position);
  }
}

/// توافق مع أي كود قديم يستخدم Sa7biAudioService.
class Sa7biAudioService {
  Sa7biAudioService._();

  static final Sa7biAudioService instance =
      Sa7biAudioService._();

  Future<Sa7biAudioHandler> initialize() {
    return AudioController.initialize();
  }

  Future<void> playUrl({
    required String url,
    String title = 'صحبي AI',
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
    String title = 'صحبي AI',
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

  Future<void> seek(Duration position) {
    return AudioController.seek(position);
  }
}
