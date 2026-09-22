import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
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
/// - الحفاظ على سلوك التشغيل الحالي عند الانتقال لتطبيق آخر.
///
/// ملاحظة مهمة:
/// AudioController لا يتم تهيئته عند تشغيل التطبيق.
/// تتم التهيئة عند أول استخدام للصوت، حتى لا يتسبب AudioService
/// في تأخير ظهور أول شاشة للتطبيق.
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
    final playing = _player.playing;

    // تحديث حالة التشغيل التي تستخدمها واجهة التطبيق.
    AudioController._updatePlayingState(playing);

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
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  @override
  Future<void> play() async {
    await _player.play();
    _broadcastState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();

    AudioController._updatePlayingState(false);

    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
      _broadcastState();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
      _broadcastState();
    }
  }

  @override
  Future<void> fastForward() async {
    final current = _player.position;
    final duration = _player.duration ?? Duration.zero;

    var target =
        current + const Duration(seconds: 10);

    if (duration > Duration.zero &&
        target > duration) {
      target = duration;
    }

    await _player.seek(target);
    _broadcastState();
  }

  @override
  Future<void> rewind() async {
    var target =
        _player.position -
        const Duration(seconds: 10);

    if (target < Duration.zero) {
      target = Duration.zero;
    }

    await _player.seek(target);
    _broadcastState();
  }

  @override
  Future<void> playMediaItem(
    MediaItem mediaItem,
  ) async {
    final cleanUrl = mediaItem.id.trim();

    if (cleanUrl.isEmpty) {
      throw ArgumentError(
        'Audio URL is empty',
      );
    }

    this.mediaItem.add(mediaItem);
    queue.add([mediaItem]);

    await _player.setUrl(cleanUrl);
    await _player.play();

    _broadcastState();
  }

  /// تشغيل رابط صوت مباشر.
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

  /// تشغيل ملف صوت موجود على الهاتف.
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

  bool get isPlaying => _player.playing;

  Duration get position => _player.position;

  Duration? get duration => _player.duration;

  @override
  Future<void> onTaskRemoved() async {
    // مهم:
    // لا نوقف الصوت عند إزالة التطبيق من شاشة التطبيقات الأخيرة.
    //
    // هذا يحافظ على السلوك الذي تم اختباره بالفعل:
    // الصوت يستمر في الخلفية عند مغادرة التطبيق.
  }

  Future<void> disposePlayer() async {
    await _playerStateSubscription?.cancel();
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();

    _playerStateSubscription = null;
    _positionSubscription = null;
    _durationSubscription = null;

    AudioController._updatePlayingState(false);

    await _player.dispose();
  }
}

/// مدير الصوت الرئيسي للتطبيق.
///
/// التهيئة Lazy:
/// لا يتم إنشاء AudioService عند فتح التطبيق.
/// يتم إنشاؤه عند أول عملية صوت فعلية.
class AudioController {
  AudioController._();

  static Sa7biAudioHandler? _handler;

  static bool _initialized = false;

  static Future<Sa7biAudioHandler>? _initializing;

  /// يتغير عندما يتم إنشاء AudioHandler.
  ///
  /// تستخدمه الواجهات التي تحتاج معرفة أن نظام الصوت
  /// أصبح جاهزًا بعد الـLazy Initialization.
  static final ValueNotifier<Sa7biAudioHandler?>
      handlerNotifier =
      ValueNotifier<Sa7biAudioHandler?>(null);

  /// حالة تشغيل الصوت.
  ///
  /// true:
  /// الصوت يعمل.
  ///
  /// false:
  /// الصوت متوقف/متوقف مؤقتًا.
  ///
  /// يستخدمها الهيدر لعمل Pulse أثناء التشغيل.
  static final ValueNotifier<bool>
      isPlayingNotifier =
      ValueNotifier<bool>(false);

  /// الـAudioHandler الحالي.
  static Sa7biAudioHandler? get handler =>
      _handler;

  /// هل تم تهيئة نظام الصوت؟
  static bool get isInitialized =>
      _initialized && _handler != null;

  /// Stream حالة التشغيل.
  ///
  /// إذا لم تتم تهيئة الصوت بعد، يتم إرجاع Stream فارغ.
  static Stream<PlaybackState>
      get playbackStateStream {
    final currentHandler = _handler;

    if (currentHandler == null) {
      return const Stream<
          PlaybackState>.empty();
    }

    return currentHandler.playbackState;
  }

  /// تحديث حالة التشغيل من الـAudioHandler.
  static void _updatePlayingState(
    bool playing,
  ) {
    if (isPlayingNotifier.value !=
        playing) {
      isPlayingNotifier.value = playing;
    }
  }

  /// تهيئة نظام الصوت مرة واحدة فقط.
  ///
  /// إذا بدأ أكثر من طلب في نفس اللحظة،
  /// كل الطلبات تنتظر نفس عملية التهيئة بدل إنشاء
  /// أكثر من AudioHandler.
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

    final future = _createHandler();

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
        config: const AudioServiceConfig(
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
          androidResumeOnClick: true,
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

  /// تشغيل رابط صوت.
  ///
  /// هذه أول نقطة ستؤدي إلى تهيئة AudioService
  /// إذا لم يكن قد تم تهيئته بعد.
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

  /// تشغيل ملف صوت محلي.
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

  /// إيقاف مؤقت.
  static Future<void> pause() async {
    await _handler?.pause();
    _updatePlayingState(false);
  }

  /// استكمال التشغيل.
  static Future<void> play() async {
    await _handler?.play();

    if (_handler != null) {
      _updatePlayingState(
        _handler!.isPlaying,
      );
    }
  }

  /// إيقاف كامل.
  static Future<void> stop() async {
    await _handler?.stop();
    _updatePlayingState(false);
  }

  /// الانتقال إلى موضع محدد.
  static Future<void> seek(
    Duration position,
  ) async {
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
