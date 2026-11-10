import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../audio_player_service.dart';

/// خدمة تحويل الكلام إلى نص وتحويل النص إلى كلام.
/// قراءة النص تتم بمحرك النظام ولا تستبدل قائمة القرآن/الراديو المركزية.
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
    } catch (error, stackTrace) {
      debugPrint('Speech initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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
    debugPrint('Speech recognition error: $error');
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

      // يوقف/يخفض المشغل مؤقتًا أثناء التقاط الميكروفون ثم يعيده حسب حالته.
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
          unawaited(_deliverFinalResult(text: recognized, onResult: onResult));
        },
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('Starting speech recognition failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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
      if (_speech.isListening) await _speech.stop();
    } catch (error) {
      debugPrint('Stopping speech recognition failed: $error');
    } finally {
      _isListening = false;
      await _finishMicrophoneCapture();
    }
  }

  Future<void> cancelListening() async {
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (error) {
      debugPrint('Cancelling speech recognition failed: $error');
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
    } catch (error) {
      debugPrint('Resuming audio after microphone capture failed: $error');
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
    return startListening(onResult: onResult, localeId: localeId);
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
      _tts.setErrorHandler((error) {
        debugPrint('Text-to-speech engine error: $error');
        _nativeTtsActive = false;
        _isSpeaking = false;
      });

      _ttsInitialized = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('TTS initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _ttsInitialized = false;
      _isSpeaking = false;
      _nativeTtsActive = false;
      return false;
    }
  }

  Future<bool> setLanguage(String language) async {
    final clean = language.trim();
    if (clean.isEmpty || !await initializeTts()) return false;
    try {
      await _tts.setLanguage(clean);
      _ttsLanguage = clean;
      return true;
    } catch (error) {
      debugPrint('Setting TTS language failed: $error');
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
      if (_nativeTtsActive) {
        try {
          await _tts.stop();
        } catch (_) {}
        _nativeTtsActive = false;
        _isSpeaking = false;
      }

      if (!await initializeTts()) return false;

      if (language != null && language.trim().isNotEmpty) {
        final cleanLanguage = language.trim();
        try {
          await _tts.setLanguage(cleanLanguage);
          _ttsLanguage = cleanLanguage;
        } catch (error) {
          debugPrint('Requested TTS language unavailable: $error');
        }
      }
      if (rate != null) await _tts.setSpeechRate(rate.clamp(0.1, 1.0).toDouble());
      if (pitch != null) await _tts.setPitch(pitch.clamp(0.5, 2.0).toDouble());
      if (volume != null) await _tts.setVolume(volume.clamp(0.0, 1.0).toDouble());

      // لا نوقف AudioController ولا نستبدل الـQueue الحالي.
      // محرك النظام يتولى audio focus ويعيد المصدر الآخر حسب دعم الجهاز.
      _nativeTtsActive = true;
      _isSpeaking = true;
      final result = await _tts.speak(cleaned, focus: true);
      if (result is bool && !result) {
        _nativeTtsActive = false;
        _isSpeaking = false;
        return false;
      }
      if (result is int && result != 1) {
        _nativeTtsActive = false;
        _isSpeaking = false;
        return false;
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('ChatVoiceService speak failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _isSpeaking = false;
      _nativeTtsActive = false;
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    if (!_nativeTtsActive && !_isSpeaking) return;
    try {
      await _tts.stop();
    } catch (error) {
      debugPrint('Stopping TTS failed: $error');
    } finally {
      _nativeTtsActive = false;
      _isSpeaking = false;
    }
  }

  Future<bool> toggleSpeaking(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    double? volume,
  }) async {
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

  /// لا نوقف تشغيل الخلفية لمجرد مغادرة شاشة المحادثة.
  Future<void> dispose() async {
    await stopListening();
    // لا نستدعي AudioController.stop() ولا نوقف جلسة الصوت المركزية.
    _speechInitialized = false;
    _ttsInitialized = false;
  }
}
