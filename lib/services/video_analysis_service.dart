import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// استخراج لقطات فعلية من الفيديو من خلال Android
/// ثم إرسال اللقطات إلى OpenAI Vision.
///
/// المسار:
///
/// فيديو
/// ↓
/// Android MediaMetadataRetriever
/// ↓
/// 4 Frames
/// ↓
/// OpenAI Vision
/// ↓
/// تحليل واحد داخل المحادثة
class VideoAnalysisService {
  VideoAnalysisService._();

  static const MethodChannel _channel =
      MethodChannel('sa7bi_ai/video');

  static const int maxFrames = 4;

  static const List<int> _timesMs = [
    0,
    5000,
    10000,
    15000,
  ];

  static Future<List<Uint8List>> extractFrames(
    XFile video,
  ) async {
    final path =
        video.path.trim();

    if (path.isEmpty) {
      return [];
    }

    try {
      final dynamic result =
          await _channel.invokeMethod(
        'extractFrames',
        <String, dynamic>{
          'path': path,
          'timesMs': _timesMs,
        },
      );

      if (result is! List) {
        return [];
      }

      final frames =
          <Uint8List>[];

      for (final item in result) {
        if (item is Uint8List) {
          if (item.isEmpty) {
            continue;
          }

          if (
              _isDuplicateFrame(
                frames,
                item,
              )) {
            continue;
          }

          frames.add(item);

          if (
              frames.length >=
              maxFrames) {
            break;
          }

          continue;
        }

        if (item is List) {
          try {
            final bytes =
                Uint8List.fromList(
              item
                  .whereType<int>()
                  .toList(),
            );

            if (bytes.isEmpty) {
              continue;
            }

            if (
                _isDuplicateFrame(
                  frames,
                  bytes,
                )) {
              continue;
            }

            frames.add(bytes);

            if (
                frames.length >=
                maxFrames) {
              break;
            }
          } catch (_) {
            continue;
          }
        }
      }

      return frames;
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  static bool _isDuplicateFrame(
    List<Uint8List> existingFrames,
    Uint8List candidate,
  ) {
    for (
      final existing
      in existingFrames
    ) {
      if (
          existing.length !=
          candidate.length) {
        continue;
      }

      const sampleSize = 32;

      final length =
          candidate.length <
                  sampleSize
              ? candidate.length
              : sampleSize;

      bool same = true;

      for (
        int i = 0;
        i < length;
        i++
      ) {
        if (
            existing[i] !=
            candidate[i]) {
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
