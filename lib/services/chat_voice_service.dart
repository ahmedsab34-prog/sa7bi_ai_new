import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../audio_player_service.dart';

/// خدمة الصوت الخاصة بالمحادثة.
/// تدير التعرف على الكلام، وقراءة النص، والتكامل مع مشغل الصوت المركزي.
class ChatVoiceService {
  ChatVoiceService({
    SpeechToText? speechToText,
    FlutterTts? textToSpeech,
  })  : _speech = speechToText ?? SpeechToText(),
        _tts = textToSpeech ?? FlutterTts();

  final SpeechToText _speech;
  final FlutterTts _tts;

  bool _speechInitialized = false;
  bool _ttsInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _nativeTtsActive = false;
  bool _microphoneCaptureStarted = false;

  String _ttsLanguage = 'ar-EG';
  String? _activeTtsPath;

  StreamSubscription<PlaybackState>? _audioPlaybackSubscription;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isSpeechInitialized => _speechInitialized;
  bool get isTtsInitialized => _ttsInitialized;

  // ============================================================
  // SPEECH TO TEXT
  // ============================================================

  Future<bool> initializeSpeech() async {
    if (_speechInitialized) return true;

    try {
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
        debugLogging: false,
      );

      _speechInitialized = available;
      if (!available) _isListening = false;
      return available;
    } catch (_) {
      _speechInitialized = false;
      _isListening = false;
      return false;
    }
  }

  void _handleSpeechStatus(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'listening') {
      _isListening = true;
    } else if (normalized == 'notlistening' ||
        normalized == 'not listening' ||
        normalized == 'done') {
      _isListening = false;
    }
  }

  void _handleSpeechError(dynamic error) {
    _isListening = false;
    unawaited(_finishMicrophoneCapture());
  }

  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'ar-EG',
  }) async {
    try {
      if (_isListening || _speech.isListening) {
        await stopListening();
      }

      if (_nativeTtsActive) {
        await _tts.stop();
        _nativeTtsActive = false;
        _isSpeaking = false;
      }

      // يوقف المشغل مؤقتًا أثناء فتح الميكروفون ثم يعيده حسب حالته.
      await AudioController.beginMicrophoneCapture();

      final handler = AudioController.handler;
      _microphoneCaptureStarted =
          handler != null && handler.isMicrophoneCaptureActive;

      final initialized = await initializeSpeech();
      if (!initialized) {
        await _finishMicrophoneCapture();
        return false;
      }

      if (_speech.isListening) {
        await _speech.stop();
      }

      _isListening = true;
      var finalResultHandled = false;

      await _speech.listen(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        onResult: (result) {
          final recognized = result.recognizedWords.trim();

          if (!result.finalResult) {
            onResult(recognized, false);
            return;
          }

          if (finalResultHandled) return;
          finalResultHandled = true;

          unawaited(
            _deliverFinalResult(
              text: recognized,
              onResult: onResult,
            ),
          );
        },
      );

      return true;
    } catch (_) {
      _isListening = false;
      await _finishMicrophoneCapture();
      return false;
    }
  }

  Future<void> _deliverFinalResult({
    required String text,
    required void Function(String text, bool isFinal) onResult,
  }) async {
    await stopListening();
    onResult(text, true);
  }

  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {
      // خطأ إيقاف الميكروفون لا يجب أن يغلق التطبيق.
    } finally {
      _isListening = false;
      await _finishMicrophoneCapture();
    }
  }

  Future<void> cancelListening() async {
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (_) {
      // تجاهل خطأ الإلغاء.
    } finally {
      _isListening = false;
      await _finishMicrophoneCapture();
    }
  }

  Future<void> _finishMicrophoneCapture() async {
    if (!_microphoneCaptureStarted) return;

    _microphoneCaptureStarted = false;

    try {
      await AudioController.endMicrophoneCapture();
    } catch (_) {
      // لا نترك خطأ الاستئناف يعطل بقية التطبيق.
    }
  }

  Future<bool> toggleListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'ar-EG',
  }) async {
    if (_isListening || _speech.isListening) {
      await stopListening();
      return false;
    }

    return startListening(
      onResult: onResult,
      localeId: localeId,
    );
  }

  // ============================================================
  // TEXT TO SPEECH
  // ============================================================

  Future<bool> initializeTts() async {
    if (_ttsInitialized) return true;

    try {
      await _tts.awaitSpeakCompletion(false);
      await _tts.setLanguage(_ttsLanguage);
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      _tts.setStartHandler(() {
        _nativeTtsActive = true;
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _nativeTtsActive = false;
        _isSpeaking = false;
      });

      _tts.setCancelHandler(() {
        _nativeTtsActive = false;
        _isSpeaking = false;
      });

      _tts.setErrorHandler((_) {
        _nativeTtsActive = false;
        _isSpeaking = false;
      });

      _ttsInitialized = true;
      return true;
    } catch (_) {
      _ttsInitialized = false;
      _isSpeaking = false;
      _nativeTtsActive = false;
      return false;
    }
  }

  Future<bool> setLanguage(String language) async {
    final clean = language.trim();
    if (clean.isEmpty) return false;

    try {
      if (!await initializeTts()) return false;

      await _tts.setLanguage(clean);
      _ttsLanguage = clean;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> speak(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    double? volume,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return false;

    try {
      if (_isListening || _speech.isListening) {
        await stopListening();
      }

      // أوقف أي قراءة أصلية سابقة قبل تبديل المصدر.
      if (_nativeTtsActive) {
        try {
          await _tts.stop();
        } catch (_) {}
        _nativeTtsActive = false;
      }

      // التعديل الأساسي: إيقاف المصدر المركزي الجاري أيضًا،
      // سواء كان قرآنًا أو راديو أو بودكاست أو ملفًا صوتيًا.
      // يتم ذلك قبل انتظار توليد ملف القراءة الجديد.
      try {
        await AudioController.stop();
      } catch (error, stackTrace) {
        debugPrint('Stopping previous audio before speech failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      _activeTtsPath = null;
      await _audioPlaybackSubscription?.cancel();
      _audioPlaybackSubscription = null;
      _isSpeaking = false;

      if (!await initializeTts()) return false;

      if (language != null && language.trim().isNotEmpty) {
        final cleanLanguage = language.trim();
        try {
          await _tts.setLanguage(cleanLanguage);
          _ttsLanguage = cleanLanguage;
        } catch (_) {
          // الاحتفاظ باللغة الحالية إذا لم تتوفر اللغة المطلوبة.
        }
      }

      if (rate != null) await _tts.setSpeechRate(rate);
      if (pitch != null) await _tts.setPitch(pitch);
      if (volume != null) await _tts.setVolume(volume);

      final extension = Platform.isIOS ? 'caf' : 'wav';
      final fileName =
          'sa7bi_tts_${DateTime.now().microsecondsSinceEpoch}.$extension';
      final filePath = [
        Directory.systemTemp.path,
        fileName,
      ].join(Platform.pathSeparator);

      try {
        await _tts.synthesizeToFile(cleaned, filePath, true);

        final ready = await _waitForAudioFile(filePath);

        if (ready) {
          await AudioController.playLocalFile(
            path: filePath,
            title: 'قراءة صوتية - صاحبي AI',
            artist: 'صاحبي AI',
          );

          final activeHandler = AudioController.handler;
          if (activeHandler != null) {
            _activeTtsPath = filePath;
            _isSpeaking = true;

            await _watchAudioPlayback(activeHandler, filePath);
            return true;
          }
        }

        await _deleteTemporaryFile(filePath);
      } catch (error) {
        debugPrint('TTS file synthesis failed: $error');
        await _deleteTemporaryFile(filePath);
      }

      // احتياطي للأجهزة التي لا تدعم إنشاء ملف TTS.
      return await _speakNatively(cleaned);
    } catch (error, stackTrace) {
      debugPrint('ChatVoiceService speak failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _isSpeaking = false;
      _nativeTtsActive = false;
      return false;
    }
  }

  Future<bool> _waitForAudioFile(String path) async {
    final file = File(path);

    for (var attempt = 0; attempt < 60; attempt++) {
      try {
        if (await file.exists() && await file.length() > 44) {
          return true;
        }
      } catch (_) {
        // الملف قد يكون ما زال قيد الإنشاء.
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      );
    }

    return false;
  }

  Future<void> _deleteTemporaryFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // تعذر حذف ملف مؤقت لا يجب أن يمنع القراءة الاحتياطية.
    }
  }

  Future<void> _watchAudioPlayback(
    Sa7biAudioHandler handler,
    String path,
  ) async {
    await _audioPlaybackSubscription?.cancel();

    _audioPlaybackSubscription = handler.playbackState.listen(
      (state) {
        if (_activeTtsPath != path) return;

        final currentItem = handler.mediaItem.value;

        if (currentItem?.id != path) {
          // تم تشغيل مصدر آخر، فلا ننسبه إلى قراءة TTS.
          _activeTtsPath = null;
          _isSpeaking = false;
          unawaited(_audioPlaybackSubscription?.cancel());
          return;
        }

        if (state.processingState == AudioProcessingState.completed) {
          _isSpeaking = false;
          return;
        }

        _isSpeaking = state.playing;
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('TTS playback listener error: $error');
        _isSpeaking = false;
      },
    );
  }

  Future<bool> _speakNatively(String text) async {
    try {
      _activeTtsPath = null;
      await _tts.stop();

      _nativeTtsActive = true;
      _isSpeaking = true;

      final result = await _tts.speak(text, focus: true);

      if (result is bool) {
        if (!result) {
          _nativeTtsActive = false;
          _isSpeaking = false;
        }
        return result;
      }

      if (result is int) {
        final success = result == 1;
        if (!success) {
          _nativeTtsActive = false;
          _isSpeaking = false;
        }
        return success;
      }

      return true;
    } catch (_) {
      _nativeTtsActive = false;
      _isSpeaking = false;
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    final activePath = _activeTtsPath;
    final handler = AudioController.handler;

    try {
      // لا نوقف القرآن أو الراديو إذا كانا المصدر الحالي.
      // نوقف المشغل المركزي هنا فقط إذا كان يشغل ملف TTS الخاص بنا.
      if (activePath != null &&
          handler != null &&
          handler.mediaItem.value?.id == activePath) {
        await handler.stop();
      }
    } catch (_) {
      // نتعامل مع أخطاء الإيقاف بأمان.
    }

    try {
      if (_nativeTtsActive) {
        await _tts.stop();
      }
    } catch (_) {}

    await _audioPlaybackSubscription?.cancel();
    _audioPlaybackSubscription = null;

    _activeTtsPath = null;
    _nativeTtsActive = false;
    _isSpeaking = false;
  }

  Future<bool> toggleSpeaking(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    double? volume,
  }) async {
    final activePath = _activeTtsPath;
    final handler = AudioController.handler;

    if (activePath != null &&
        handler != null &&
        handler.mediaItem.value?.id == activePath) {
      if (handler.isPlaying) {
        await handler.pause();
        return false;
      }

      if (handler.processingState != ProcessingState.completed) {
        await handler.play();
        return true;
      }
    }

    if (_nativeTtsActive || _isSpeaking) {
      await stopSpeaking();
      return false;
    }

    return speak(
      text,
      language: language,
      rate: rate,
      pitch: pitch,
      volume: volume,
    );
  }

  // ============================================================
  // GENERAL
  // ============================================================

  Future<void> stopAll() async {
    await stopListening();
    await stopSpeaking();
  }

  /// لا توقف هذه الدالة جلسة AudioService عند مغادرة الشاشة،
  /// حتى يستمر المقطع الحالي في الخلفية.
  Future<void> dispose() async {
    await stopListening();

    try {
      if (_nativeTtsActive) {
        await _tts.stop();
      }
    } catch (_) {}

    await _audioPlaybackSubscription?.cancel();
    _audioPlaybackSubscription = null;

    _isSpeaking = false;
    _nativeTtsActive = false;
    _activeTtsPath = null;

    _speechInitialized = false;
    _ttsInitialized = false;
  }
}
