
typedef AudioSpeechStopper = Future<void> Function();

/// منسق واحد لمنع تداخل محركات TTS المختلفة مع بعضها
/// ومع مشغل القرآن والراديو والبودكاست.
///
/// لا يعتمد على Flutter أو AudioService حتى لا ينشئ
/// اعتمادًا دائريًا بين خدمات الصوت.
class AudioFocusCoordinator {
  AudioFocusCoordinator._();

  static final Map<Object, AudioSpeechStopper> _speechControllers =
      <Object, AudioSpeechStopper>{};

  static Future<void> _operationTail = Future<void>.value();

  static void registerSpeechController(
    Object owner,
    AudioSpeechStopper stop,
  ) {
    _speechControllers[owner] = stop;
  }

  static void unregisterSpeechController(Object owner) {
    _speechControllers.remove(owner);
  }

  /// إيقاف كل محركات TTS المسجلة.
  ///
  /// يتم إيقاف كل محرك بشكل مستقل حتى لا يمنع تعطل
  /// محرك واحد إيقاف المحركات الأخرى.
  static Future<void> stopAllSpeech() {
    return _enqueue<void>(_stopSpeechControllers);
  }

  /// يمنح محرك TTS حق استخدام الصوت بعد:
  /// 1. إيقاف كل محركات TTS السابقة.
  /// 2. إيقاف مشغل الوسائط المركزي.
  /// 3. بدء القراءة الجديدة.
  static Future<T> runWithSpeechFocus<T>({
    required Future<void> Function() stopMediaPlayback,
    required Future<T> Function() startSpeech,
  }) {
    return _enqueue<T>(() async {
      await _stopSpeechControllers();

      // لا نبدأ TTS إذا تعذر إيقاف مشغل الوسائط؛
      // منع الصوتين معًا أهم من إظهار نجاح غير حقيقي.
      await stopMediaPlayback();

      return await startSpeech();
    });
  }

  static Future<void> _stopSpeechControllers() async {
    final callbacks = List<AudioSpeechStopper>.from(
      _speechControllers.values,
    );

    for (final stop in callbacks) {
      try {
        await stop();
      } catch (_) {
        // نستمر لإيقاف بقية محركات الصوت.
      }
    }
  }

  /// تسلسل عمليات أخذ وإعادة تركيز الصوت.
  /// يمنع تنفيذ عمليتي TTS متزامنتين من خدمتين مختلفتين.
  static Future<T> _enqueue<T>(
    Future<T> Function() operation,
  ) {
    final next = _operationTail
        .catchError((Object _) {})
        .then<T>((_) => operation());

    _operationTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );

    return next;
  }
}
