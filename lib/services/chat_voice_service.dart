import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// خدمات الصوت الخاصة بالمحادثة.
///
/// مسؤول عن:
/// - Speech To Text: تحويل كلام المستخدم إلى نص.
/// - Text To Speech: قراءة رد الـAI بصوت.
///
/// لا يحفظ الرسائل ولا يتعامل مع الـAI API.
/// هذه المسؤوليات تظل في ChatController / ChatScreen / AiService.
class ChatVoiceService {
  ChatVoiceService({
    SpeechToText? speechToText,
    FlutterTts? textToSpeech,
  })  : _speech = speechToText ?? SpeechToText(),
        _tts = textToSpeech ?? FlutterTts();

  final SpeechToText _speech;
  final FlutterTts _tts;

  bool _speechInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;

  /// تهيئة خدمة التعرف على الكلام.
  Future<bool> initializeSpeech() async {
    if (_speechInitialized) {
      return true;
    }

    try {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          } else if (status == 'listening') {
            _isListening = true;
          }
        },
        onError: (_) {
          _isListening = false;
        },
      );

      return _speechInitialized;
    } catch (_) {
      _speechInitialized = false;
      return false;
    }
  }

  /// بدء الاستماع وتحويل كلام المستخدم إلى نص.
  ///
  /// onResult يتم استدعاؤها أثناء التعرف على الكلام.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    String localeId = 'ar-EG',
  }) async {
    final initialized = await initializeSpeech();

    if (!initialized) {
      return false;
    }

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }

      _isListening = true;

      await _speech.listen(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        onResult: (result) {
          onResult(
            result.recognizedWords,
            result.finalResult,
          );

          if (result.finalResult) {
            _isListening = false;
          }
        },
      );

      return true;
    } catch (_) {
      _isListening = false;
      return false;
    }
  }

  /// إيقاف الاستماع.
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {
      // لا نسمح بخطأ الصوت بإيقاف التطبيق.
    }

    _isListening = false;
  }

  /// إلغاء الاستماع بدون الاعتماد على النتيجة الحالية.
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (_) {
      // تجاهل خطأ الإلغاء.
    }

    _isListening = false;
  }

  /// تهيئة إعدادات تحويل النص إلى كلام.
  Future<void> initializeTts() async {
    try {
      await _tts.awaitSpeakCompletion(false);

      await _tts.setLanguage('ar-EG');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((_) {
        _isSpeaking = false;
      });
    } catch (_) {
      // إعدادات TTS تختلف من جهاز لآخر.
    }
  }

  /// قراءة نص بصوت.
  Future<bool> speak(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    double? volume,
  }) async {
    final cleaned = text.trim();

    if (cleaned.isEmpty) {
      return false;
    }

    try {
      await initializeTts();

      if (language != null && language.trim().isNotEmpty) {
        await _tts.setLanguage(language);
      }

      if (rate != null) {
        await _tts.setSpeechRate(rate);
      }

      if (pitch != null) {
        await _tts.setPitch(pitch);
      }

      if (volume != null) {
        await _tts.setVolume(volume);
      }

      await _tts.stop();

      _isSpeaking = true;
      await _tts.speak(cleaned);

      return true;
    } catch (_) {
      _isSpeaking = false;
      return false;
    }
  }

  /// إيقاف قراءة النص الحالي.
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // تجاهل خطأ الإيقاف.
    }

    _isSpeaking = false;
  }

  /// إيقاف كل خدمات الصوت.
  Future<void> stopAll() async {
    await stopListening();
    await stopSpeaking();
  }

  /// تنظيف الموارد.
  Future<void> dispose() async {
    await stopAll();
  }
}
