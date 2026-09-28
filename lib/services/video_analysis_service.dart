import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// خدمة تحليل الفيديو.
///
/// مسؤوليتها هنا هي تجهيز الفيديو فقط:
///
/// الفيديو
///   ↓
/// Android MediaMetadataRetriever
///   ↓
/// لقطات JPEG فعلية
///   ↓
/// AiRequestService
///   ↓
/// Cloudflare Worker
///   ↓
/// Gemini / Workers AI fallback
///
/// ملاحظة مهمة:
/// هذه الخدمة لا تحتوي أي API Key، ولا تقوم بحساب Credits بنفسها.
/// تحديد نوع العملية (video_analysis) وحساب الـ5 Credits يتم في
/// مسار طلب الذكاء الاصطناعي والـBackend.
class VideoAnalysisService {
  VideoAnalysisService._();

  static const MethodChannel _channel =
      MethodChannel('sa7bi_ai/video');

  /// الحد الأقصى للقطات التي نرسلها للتحليل.
  static const int maxFrames = 4;

  /// أوقات اللقطات الافتراضية بالمللي ثانية.
  ///
  /// نبدأ من بداية الفيديو ثم نأخذ لقطات متباعدة.
  static const List<int> defaultTimesMs = <int>[
    0,
    5000,
    10000,
    15000,
  ];

  /// أقصى حجم إجمالي للـFrames التي يتم تجهيزها.
  ///
  /// هذا حد أمان محلي قبل إرسال البيانات للشبكة.
  static const int maxTotalBytes = 5 * 1024 * 1024;

  /// استخراج اللقطات من الفيديو.
  ///
  /// إذا تعذر استخراج أي لقطة، ترجع قائمة فارغة.
  static Future<List<Uint8List>> extractFrames(
    XFile video,
  ) async {
    final path = video.path.trim();

    if (path.isEmpty) {
      return <Uint8List>[];
    }

    try {
      final dynamic result = await _channel.invokeMethod<dynamic>(
        'extractFrames',
        <String, dynamic>{
          'path': path,
          'timesMs': defaultTimesMs,
        },
      );

      return _normalizeFrames(result);
    } on PlatformException {
      return <Uint8List>[];
    } catch (_) {
      return <Uint8List>[];
    }
  }

  /// استخراج اللقطات مع أوقات مخصصة.
  ///
  /// يستخدم فقط عندما نحتاج تحكمًا أكبر في توزيع اللقطات.
  static Future<List<Uint8List>> extractFramesAt(
    XFile video, {
    List<int> timesMs = defaultTimesMs,
  }) async {
    final path = video.path.trim();

    if (path.isEmpty) {
      return <Uint8List>[];
    }

    final safeTimes = timesMs
        .where((int value) => value >= 0)
        .take(maxFrames)
        .toList(growable: false);

    if (safeTimes.isEmpty) {
      return <Uint8List>[];
    }

    try {
      final dynamic result = await _channel.invokeMethod<dynamic>(
        'extractFrames',
        <String, dynamic>{
          'path': path,
          'timesMs': safeTimes,
        },
      );

      return _normalizeFrames(result);
    } on PlatformException {
      return <Uint8List>[];
    } catch (_) {
      return <Uint8List>[];
    }
  }

  /// يحول نتيجة Android إلى Uint8List بشكل آمن.
  static List<Uint8List> _normalizeFrames(
    dynamic result,
  ) {
    if (result is! List) {
      return <Uint8List>[];
    }

    final frames = <Uint8List>[];
    var totalBytes = 0;

    for (final dynamic item in result) {
      final Uint8List? frame = _toBytes(item);

      if (frame == null || frame.isEmpty) {
        continue;
      }

      if (_isDuplicateFrame(frames, frame)) {
        continue;
      }

      if (totalBytes + frame.length > maxTotalBytes) {
        break;
      }

      frames.add(frame);
      totalBytes += frame.length;

      if (frames.length >= maxFrames) {
        break;
      }
    }

    return List<Uint8List>.unmodifiable(frames);
  }

  /// تحويل قيمة قادمة من MethodChannel إلى Bytes.
  static Uint8List? _toBytes(dynamic item) {
    if (item is Uint8List) {
      return item;
    }

    if (item is List) {
      try {
        final values = item.whereType<int>().toList();

        if (values.isEmpty) {
          return null;
        }

        return Uint8List.fromList(values);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// يمنع إرسال نفس الـFrame أكثر من مرة.
  ///
  /// لا نعتمد على مقارنة كل Bytes حتى لا نستهلك وقتًا وذاكرة
  /// بدون داعٍ؛ نستخدم عينة صغيرة من بداية الملف.
  static bool _isDuplicateFrame(
    List<Uint8List> existingFrames,
    Uint8List candidate,
  ) {
    const int sampleSize = 64;

    for (final Uint8List existing in existingFrames) {
      if (existing.length != candidate.length) {
        continue;
      }

      final int length = candidate.length < sampleSize
          ? candidate.length
          : sampleSize;

      var same = true;

      for (var i = 0; i < length; i++) {
        if (existing[i] != candidate[i]) {
          same = false;
          break;
        }
      }

      if (same) {
        return true;
      }
    }

    return false;
  }

  /// هل الفيديو أنتج Frames صالحة للتحليل؟
  static bool hasUsableFrames(
    List<Uint8List> frames,
  ) {
    return frames.any(
      (Uint8List frame) => frame.isNotEmpty,
    );
  }

  /// إجمالي حجم اللقطات.
  static int totalBytes(
    List<Uint8List> frames,
  ) {
    var total = 0;

    for (final Uint8List frame in frames) {
      total += frame.length;
    }

    return total;
  }

  /// تنظيف قائمة Frames قبل إرسالها للخدمة التالية.
  static List<Uint8List> prepareForAnalysis(
    List<Uint8List> frames,
  ) {
    final prepared = <Uint8List>[];
    var total = 0;

    for (final Uint8List frame in frames) {
      if (frame.isEmpty) {
        continue;
      }

      if (_isDuplicateFrame(prepared, frame)) {
        continue;
      }

      if (prepared.length >= maxFrames) {
        break;
      }

      if (total + frame.length > maxTotalBytes) {
        break;
      }

      prepared.add(frame);
      total += frame.length;
    }

    return List<Uint8List>.unmodifiable(prepared);
  }
}
