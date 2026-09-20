import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// خدمة الصوت الأساسية للتطبيق.
///
/// مسؤولة عن:
/// - تشغيل الصوت من الإنترنت.
/// - تشغيل الملفات المحلية.
/// - التشغيل في الخلفية.
/// - إشعار Android.
/// - أزرار التشغيل والإيقاف والتقديم والترجيع.
/// - التحكم من شاشة القفل.
/// - استمرار الخدمة عند إزالة التطبيق من التطبيقات الأخيرة.
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

      _playerStateSubscription = _player.playerStateStream.listen(
        (_) => _broadcastState(),
      );

      _positionSubscription = _player.positionStream.listen(
        (_) => _broadcastState(),
      );

      _durationSubscription = _player.durationStream.listen(
        (_) => _broadcastState(),
      );
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
    try {
      await _player.setUrl(mediaItem.id);

      queue.add([mediaItem]);

      await _player.play();
    } catch (_) {
      rethrow;
    }
  }

  /// تشغيل رابط صوت مباشر.
  Future<void> playUrl(
    String url, {
    String title = 'صحبي AI',
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) async {
    final item = MediaItem(
      id: url,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );

    mediaItem.add(item);
    queue.add([item]);

    await _player.setUrl(url);
    await _player.play();
  }

  /// تشغيل ملف صوت موجود على الهاتف.
  Future<void> playLocalFile(
    String path, {
    String title = 'صحبي AI',
    String? artist,
    String? album,
  }) async {
    final item = MediaItem(
      id: path,
      title: title,
      artist: artist,
      album: album,
    );

    mediaItem.add(item);
    queue.add([item]);

    await _player.setFilePath(path);
    await _player.play();
  }

  /// هل الصوت يعمل حاليًا؟
  bool get isPlaying => _player.playing;

  /// موضع التشغيل الحالي.
  Duration get position => _player.position;

  /// مدة الملف الحالي.
  Duration? get duration => _player.duration;

  @override
  Future<void> onTaskRemoved() async {
    // لا نوقف الصوت عند إزالة التطبيق من التطبيقات الأخيرة.
    // يسمح ذلك باستمرار التشغيل في الخلفية.
  }

  Future<void> disposePlayer() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();

    await _player.dispose();
  }
}

/// مدير الصوت الرئيسي للتطبيق.
///
/// يمنع إنشاء AudioHandler أكثر من مرة.
class AudioController {
  AudioController._();

  static final AudioController instance =
      AudioController._();

  Sa7biAudioHandler? _handler;
  bool _initialized = false;

  Sa7biAudioHandler? get handler => _handler;

  Future<void> initialize() async {
    if (_initialized && _handler != null) {
      return;
    }

    try {
      _handler = await AudioService.init(
        builder: () => Sa7biAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'com.sa7bi.ai.audio',
          androidNotificationChannelName:
              'صحبي AI - الصوت',
          androidNotificationOngoing: false,

          // لا نوقف الـ foreground service عند إيقاف الصوت.
          androidStopForegroundOnPause: false,

          // الملف موجود فعليًا هنا:
          // android/app/src/main/res/drawable/app_icon.png
          androidNotificationIcon:
              'drawable/app_icon',

          androidResumeOnClick: true,
        ),
      );

      _initialized = true;
    } catch (_) {
      _initialized = false;
      rethrow;
    }
  }

  Future<void> playUrl(
    String url, {
    String title = 'صحبي AI',
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) async {
    await initialize();

    await _handler!.playUrl(
      url,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );
  }

  Future<void> playLocalFile(
    String path, {
    String title = 'صحبي AI',
    String? artist,
    String? album,
  }) async {
    await initialize();

    await _handler!.playLocalFile(
      path,
      title: title,
      artist: artist,
      album: album,
    );
  }

  Future<void> pause() async {
    await _handler?.pause();
  }

  Future<void> play() async {
    await _handler?.play();
  }

  Future<void> stop() async {
    await _handler?.stop();
  }

  Future<void> seek(Duration position) async {
    await _handler?.seek(position);
  }
}

/// اسم توافق قديم في المشروع.
/// نتركه حتى لا نكسر أي ملف حالي يستخدمه.
class Sa7biAudioService {
  Sa7biAudioService._();

  static final Sa7biAudioService instance =
      Sa7biAudioService._();

  AudioController get controller =>
      AudioController.instance;

  Future<void> initialize() {
    return controller.initialize();
  }

  Future<void> playUrl(
    String url, {
    String title = 'صحبي AI',
    String? artist,
    String? album,
    Duration? duration,
    Uri? artUri,
  }) {
    return controller.playUrl(
      url,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artUri: artUri,
    );
  }

  Future<void> playLocalFile(
    String path, {
    String title = 'صحبي AI',
    String? artist,
    String? album,
  }) {
    return controller.playLocalFile(
      path,
      title: title,
      artist: artist,
      album: album,
    );
  }

  Future<void> pause() {
    return controller.pause();
  }

  Future<void> play() {
    return controller.play();
  }

  Future<void> stop() {
    return controller.stop();
  }

  Future<void> seek(Duration position) {
    return controller.seek(position);
  }
}
