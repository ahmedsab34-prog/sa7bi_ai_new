import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../audio_player_service.dart';
import 'audio_focus_coordinator.dart';

/// Records a short AAC voice note for Sa7bi Connect.
///
/// The recorder uses the existing central audio focus hooks:
/// - all active TTS sessions are stopped before recording;
/// - the shared Quran/radio/podcast player is paused while the microphone is
///   active and is resumed only when it was playing before capture;
/// - the result is kept in the app's temporary directory until uploaded.
class SocialVoiceRecordingService {
  SocialVoiceRecordingService._();

  static final SocialVoiceRecordingService instance =
      SocialVoiceRecordingService._();

  static const Duration maximumDuration = Duration(minutes: 2);
  static const int maximumFileBytes = 5 * 1024 * 1024;

  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _audioFocusHeld = false;
  String? _activePath;
  DateTime? _startedAt;

  bool get isRecording => _isRecording;
  Duration get elapsed => _startedAt == null
      ? Duration.zero
      : DateTime.now().difference(_startedAt!);

  /// Starts a new voice-note capture.
  /// Throws a descriptive [SocialVoiceRecordingException] on failure.
  Future<void> start() async {
    if (_isRecording) {
      throw const SocialVoiceRecordingException(
        'RECORDING_ALREADY_ACTIVE',
        'التسجيل الصوتي شغال بالفعل.',
      );
    }

    await AudioFocusCoordinator.stopAllSpeech();

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw const SocialVoiceRecordingException(
          'MICROPHONE_PERMISSION_DENIED',
          'اسمح لصاحبي AI باستخدام الميكروفون لتسجيل الرسالة الصوتية.',
        );
      }

      await AudioController.beginMicrophoneCapture();
      _audioFocusHeld = AudioController.handler?.isMicrophoneCaptureActive == true;

      final temporaryDirectory = await getTemporaryDirectory();
      final voiceDirectory = Directory(
        '${temporaryDirectory.path}/sa7bi_voice_messages',
      );
      await voiceDirectory.create(recursive: true);

      final path = '${voiceDirectory.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 24000,
          numChannels: 1,
        ),
        path: path,
      );

      _activePath = path;
      _startedAt = DateTime.now();
      _isRecording = true;
    } on SocialVoiceRecordingException {
      await _releaseAudioFocus();
      rethrow;
    } catch (error) {
      await _releaseAudioFocus();
      throw SocialVoiceRecordingException(
        'RECORDING_START_FAILED',
        'تعذر بدء التسجيل الصوتي. تأكد من الميكروفون وحاول مرة أخرى ($error).',
      );
    }
  }

  /// Stops capture and returns the temporary audio file for upload.
  /// The caller should upload the file, then delete it when finished.
  Future<File> stop() async {
    if (!_isRecording) {
      throw const SocialVoiceRecordingException(
        'RECORDING_NOT_ACTIVE',
        'لا يوجد تسجيل صوتي جارٍ لإيقافه.',
      );
    }

    final startedAt = _startedAt;
    String? stoppedPath;
    Object? stopError;

    try {
      stoppedPath = await _recorder.stop();
    } catch (error) {
      stopError = error;
    } finally {
      _isRecording = false;
      _startedAt = null;
      await _releaseAudioFocus();
    }

    final path = stoppedPath ?? _activePath;
    _activePath = null;

    if (stopError != null || path == null || path.trim().isEmpty) {
      throw SocialVoiceRecordingException(
        'RECORDING_STOP_FAILED',
        'تعذر إنهاء التسجيل الصوتي بصورة صحيحة ($stopError).',
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      throw const SocialVoiceRecordingException(
        'RECORDING_FILE_MISSING',
        'ملف التسجيل لم يتم حفظه على الجهاز.',
      );
    }

    final elapsed = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);
    if (elapsed > maximumDuration) {
      await _deleteQuietly(file);
      throw const SocialVoiceRecordingException(
        'RECORDING_TOO_LONG',
        'الحد الأقصى للرسالة الصوتية دقيقتان.',
      );
    }

    final size = await file.length();
    if (size <= 0 || size > maximumFileBytes) {
      await _deleteQuietly(file);
      throw const SocialVoiceRecordingException(
        'RECORDING_FILE_TOO_LARGE',
        'حجم الرسالة الصوتية أكبر من المسموح. حاول تسجيلها مرة أخرى.',
      );
    }

    return file;
  }

  /// Cancels capture and deletes any unfinished recording.
  Future<void> cancel() async {
    final path = _activePath;
    _activePath = null;
    _startedAt = null;

    try {
      if (_isRecording) {
        await _recorder.cancel();
      }
    } catch (_) {
      // Cleanup continues even if the native recorder already stopped.
    } finally {
      _isRecording = false;
      await _releaseAudioFocus();
    }

    if (path != null) {
      await _deleteQuietly(File(path));
    }
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }

  Future<void> _releaseAudioFocus() async {
    if (!_audioFocusHeld) return;
    _audioFocusHeld = false;

    try {
      await AudioController.endMicrophoneCapture();
    } catch (_) {
      // A failed resume must not leave the recording service locked.
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

class SocialVoiceRecordingException implements Exception {
  const SocialVoiceRecordingException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SocialVoiceRecordingException($code): $message';
}
