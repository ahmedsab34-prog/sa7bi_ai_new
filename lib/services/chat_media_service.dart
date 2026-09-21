import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// خدمة الوسائط الخاصة بالمحادثة.
///
/// مسؤوليتها فقط:
/// - التقاط صورة بالكاميرا.
/// - اختيار صورة من المعرض.
/// - اختيار فيديو.
///
/// لا تقوم بتحليل الوسائط ولا ترسلها للـAI.
/// الإرسال والتحليل يظلان في ChatScreen / AiService.
class ChatMediaService {
  ChatMediaService({
    ImagePicker? picker,
  }) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// التقاط صورة من كاميرا الجهاز.
  Future<Uint8List?> takePhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (file == null) {
        return null;
      }

      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// اختيار صورة من المعرض.
  Future<Uint8List?> pickPhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (file == null) {
        return null;
      }

      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// اختيار فيديو من الجهاز.
  ///
  /// ترجع XFile لأن الفيديو لا نريد تحميله بالكامل
  /// إلى الذاكرة بدون حاجة.
  Future<XFile?> pickVideo() async {
    try {
      return await _picker.pickVideo(
        source: ImageSource.gallery,
      );
    } catch (_) {
      return null;
    }
  }

  /// تسجيل فيديو بالكاميرا.
  Future<XFile?> recordVideo() async {
    try {
      return await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
    } catch (_) {
      return null;
    }
  }
}
