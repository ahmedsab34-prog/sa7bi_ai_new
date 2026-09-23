import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// استخراج لقطات فعلية من الفيديو لتحليلها بالذكاء الاصطناعي.
///
/// مهم:
/// OpenAI في المسار الحالي يتعامل مع الصور داخل Responses API.
/// لذلك نحول الفيديو إلى مجموعة Frames موزعة زمنيًا، ثم نرسلها
/// معًا إلى نموذج الرؤية.
///
/// هذا ليس تحليلًا شكليًا للفيديو:
/// الفيديو -> Frames -> AI Vision -> نتيجة واحدة للمحادثة.
class VideoAnalysisService {
  VideoAnalysisService._();

  static const int maxFrames = 4;
  static const int maxWidth = 720;
  static const int quality = 62;

  /// استخراج مجموعة Frames من الفيديو.
  ///
  /// نأخذ 4 نقاط زمنية:
  /// 0 ثانية
  /// 5 ثوانٍ
  /// 10 ثوانٍ
  /// 15 ثانية
  ///
  /// video_thumbnail يختار أقرب Frame متاح.
  static Future<List<Uint8List>> extractFrames(
    XFile video,
  ) async {
    final path = video.path.trim();

    if (path.isEmpty) {
      return [];
    }

    const timesMs = <int>[
      0,
      5000,
      10000,
      15000,
    ];

    final frames = <Uint8List>[];

    for (final timeMs in timesMs) {
      try {
        final bytes =
            await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: maxWidth,
          quality: quality,
          timeMs: timeMs,
        );

        if (bytes == null || bytes.isEmpty) {
          continue;
        }

        if (_isDuplicateFrame(
          frames,
          bytes,
        )) {
          continue;
        }

        frames.add(bytes);

        if (frames.length >= maxFrames) {
          break;
        }
      } catch (_) {
        // لو Frame واحدة فشلت، نحاول باقي اللقطات.
      }
    }

    return frames;
  }

  static bool _isDuplicateFrame(
    List<Uint8List> existingFrames,
    Uint8List candidate,
  ) {
    for (final existing in existingFrames) {
      if (existing.length != candidate.length) {
        continue;
      }

      const sampleSize = 32;

      final length =
          candidate.length < sampleSize
              ? candidate.length
              : sampleSize;

      bool same = true;

      for (int i = 0; i < length; i++) {
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
}
