import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// استخراج لقطات فعلية من الفيديو لتحليلها بالذكاء الاصطناعي.
///
/// المسار:
///
/// فيديو
/// ↓
/// Frames حقيقية
/// ↓
/// OpenAI Vision
/// ↓
/// تحليل واحد داخل المحادثة
class VideoAnalysisService {
  VideoAnalysisService._();

  static const int maxFrames = 4;
  static const int maxWidth = 720;
  static const int quality = 62;

  static const List<int> _timesMs = [
    0,
    5000,
    10000,
    15000,
  ];

  static Future<List<Uint8List>> extractFrames(
    XFile video,
  ) async {
    final path = video.path.trim();

    if (path.isEmpty) {
      return [];
    }

    final frames =
        <Uint8List>[];

    for (final timeMs in _timesMs) {
      try {
        final bytes =
            await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: maxWidth,
          quality: quality,
          timeMs: timeMs,
        );

        if (bytes == null ||
            bytes.isEmpty) {
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
        // نحاول باقي اللقطات.
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
