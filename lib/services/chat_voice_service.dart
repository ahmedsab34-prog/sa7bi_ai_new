import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// خدمة الصوت الخاصة بالمحادثة في صاحبي AI.
///
/// المسؤوليات:
/// - تحويل كلام المستخدم إلى نص Speech To Text.
/// - قراءة ردود الذكاء الاصطناعي Text To Speech.
/// - دعم العربية المصرية ar-EG.
/// - إدارة حالة الاستماع.
/// - إدارة حالة قراءة الرد.
/// - منع تعارض الاستماع مع القراءة الصوتية.
///
/// لا تتعامل هذه الخدمة مع:
/// - رسائل المحادثة.
/// - API.
/// - تخزين المحادثات.
/// - الرصيد / Credits.
/// - الصور أو الفيديو.
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

  String _ttsLanguage = 'ar-EG';

  /// هل Speech To Text يعمل حاليًا؟
  bool get isListening => _isListening;

  /// هل Text To Speech يعمل حاليًا؟
  bool get isSpeaking => _isSpeaking;

  /// هل Speech To Text تم تهيئته؟
  bool get isSpeechInitialized => _speechInitialized;

  /// هل TTS تم تهيئته؟
  bool get isTtsInitialized => _ttsInitialized;

  // ============================================================
  // SPEECH TO TEXT
  // ============================================================

  /// تهيئة التعرف على الكلام.
  ///
  /// يتم استدعاؤها عند أول استخدام فقط.
  Future<bool> initializeSpeech() async {
    if (_speechInitialized) {
      return true;
    }

    try {
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
        debugLogging: false,
      );

      _speechInitialized = available;

      if (!available) {
        _isListening = false;
      }

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
      return;
    }

    if (normalized == 'notlistening' ||
        normalized == 'not listening' ||
        normalized == 'done') {
      _isListening = false;
    }
  }

  void _handleSpeechError(dynamic error) {
    _isListening = false;
  }

  /// بدء تحويل الكلام إلى نص.
  ///
  /// [onResult] يتم استدعاؤها أثناء الكلام:
  ///
  /// text:
  /// النص الذي تم التعرف عليه.
  ///
  /// isFinal:
  /// هل النتيجة نهائية أم ما زالت مؤقتة؟
  Future<bool> startListening({
    required void Function(
      String text,
      bool isFinal,
    ) onResult,
    String localeId = 'ar-EG',
  }) async {
    try {
      // لو TTS يعمل، نوقفه أولًا حتى لا يتداخل مع الميكروفون.
      if (_isSpeaking) {
        await stopSpeaking();
      }

      final initialized = await initializeSpeech();

      if (!initialized) {
        return false;
      }

      // لو هناك جلسة استماع قديمة، نغلقها أولًا.
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
          final text = result.recognizedWords.trim();

          onResult(
            text,
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
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {
      // لا نسمح بخطأ الميكروفون بإغلاق التطبيق.
    }

    _isListening = false;
  }

  /// إلغاء جلسة الاستماع الحالية.
  ///
  /// لا نعتمد على النتيجة الحالية.
  Future<void> cancelListening() async {
    try {
      if (_speech.isListening) {
        await _speech.cancel();
      }
    } catch (_) {
      // تجاهل خطأ الإلغاء.
    }

    _isListening = false;
  }

  /// إيقاف أو تشغيل الاستماع حسب الحالة الحالية.
  Future<bool> toggleListening({
    required void Function(
      String text,
      bool isFinal,
    ) onResult,
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

  /// تهيئة Text To Speech.
  Future<bool> initializeTts() async {
    if (_ttsInitialized) {
      return true;
    }

    try {
      await _tts.awaitSpeakCompletion(false);

      await _tts.setLanguage(_ttsLanguage);
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

      _ttsInitialized = true;

      return true;
    } catch (_) {
      _ttsInitialized = false;
      _isSpeaking = false;
      return false;
    }
  }

  /// تغيير لغة TTS.
  Future<bool> setLanguage(String language) async {
    final clean = language.trim();

    if (clean.isEmpty) {
      return false;
    }

    try {
      final initialized = await initializeTts();

      if (!initialized) {
        return false;
      }

      await _tts.setLanguage(clean);
      _ttsLanguage = clean;

      return true;
    } catch (_) {
      return false;
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
      // لا نريد الميكروفون يعمل أثناء قراءة AI.
      if (_isListening || _speech.isListening) {
        await stopListening();
      }

      final initialized = await initializeTts();

      if (!initialized) {
        return false;
      }

      if (language != null &&
          language.trim().isNotEmpty) {
        final cleanLanguage = language.trim();

        try {
          await _tts.setLanguage(cleanLanguage);
          _ttsLanguage = cleanLanguage;
        } catch (_) {
          // نكمل باللغة الحالية إذا كانت اللغة المطلوبة غير متاحة.
        }
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

      // إيقاف أي قراءة قديمة قبل بدء الجديدة.
      await _tts.stop();

      _isSpeaking = true;

      final result = await _tts.speak(cleaned);

      // بعض محركات Android تعيد رقمًا بدل bool.
      // نعتبر 1 أو true نجاحًا.
      if (result is bool) {
        if (!result) {
          _isSpeaking = false;
        }

        return result;
      }

      if (result is int) {
        final success = result == 1;

        if (!success) {
          _isSpeaking = false;
        }

        return success;
      }

      return true;
    } catch (_) {
      _isSpeaking = false;
      return false;
    }
  }

  /// إيقاف قراءة AI.
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // تجاهل خطأ TTS.
    }

    _isSpeaking = false;
  }

  /// تشغيل / إيقاف قراءة النص.
  Future<bool> toggleSpeaking(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    double? volume,
  }) async {
    if (_isSpeaking) {
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

  /// إيقاف كل وظائف الصوت.
  Future<void> stopAll() async {
    await stopListening();
    await stopSpeaking();
  }

  /// تنظيف الخدمة.
  ///
  /// الخدمة لا تمتلك موارد native مستقلة تحتاج dispose،
  /// لكننا نوقف أي جلسة صوت قبل التخلص منها.
  Future<void> dispose() async {
    await stopAll();

    _speechInitialized = false;
    _ttsInitialized = false;
  }
}
