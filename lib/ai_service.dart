import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AiService {
  static const String baseUrl =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  static const String workerUrl =
      '$baseUrl/v1/chat';

  static const String imageUrl =
      '$baseUrl/v1/image';

  static const String statusUrl =
      '$baseUrl/';

  // نرسل عددًا محدودًا من الرسائل السابقة حتى لا تصبح كل رسالة
  // أثقل من السابقة.
  static const int maxHistoryMessages = 10;

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final text = prompt.trim();

      if (text.isEmpty) {
        return 'اكتب رسالتك الأولًا يا صاحبي 😊';
      }

      final messages = <Map<String, String>>[];

      final validHistory = history
          .where((item) {
            final role = item['role'];
            final content = item['content'];

            return (role == 'user' || role == 'assistant') &&
                content != null &&
                content.trim().isNotEmpty;
          })
          .toList();

      final start = validHistory.length > maxHistoryMessages
          ? validHistory.length - maxHistoryMessages
          : 0;

      for (final item in validHistory.sublist(start)) {
        messages.add({
          'role': item['role']!,
          'content': item['content']!.trim(),
        });
      }

      var currentMessage = text;

      if (serviceContext != null &&
          serviceContext.trim().isNotEmpty) {
        currentMessage =
            'سياق القسم: ${serviceContext.trim()}\n\n'
            'رسالة المستخدم: $text';
      }

      messages.add({
        'role': 'user',
        'content': currentMessage,
      });

      final response = await http
          .post(
            Uri.parse(workerUrl),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'messages': messages,
            }),
          )
          .timeout(
            const Duration(seconds: 35),
          );

      if (response.statusCode != 200) {
        return _readError(response);
      }

      final data = jsonDecode(response.body);

      if (data['ok'] == true &&
          data['reply'] is String &&
          data['reply'].toString().trim().isNotEmpty) {
        return data['reply'].toString().trim();
      }

      return 'صَحبي ما قدرش يكوّن رد دلوقتي 😕';
    } catch (error) {
      return 'الاتصال بصَحبي اتأخر شوية 😅\n'
          'جرّب تبعت الرسالة مرة تانية.';
    }
  }

  static Future<String> analyzeImage(
    XFile image, {
    String prompt =
        'حلل الصورة بوضوح وساعدني في فهم ما فيها.',
    String? serviceContext,
  }) async {
    try {
      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        return 'الصورة فاضية أو لم يتم قراءتها.';
      }

      // نحافظ على حجم الطلب منخفضًا.
      if (bytes.length > 4 * 1024 * 1024) {
        return 'الصورة كبيرة جدًا. حاول التقاط صورة أصغر.';
      }

      final base64Image = base64Encode(bytes);
      final mimeType = _mimeType(image.name);

      var finalPrompt = prompt.trim();

      if (serviceContext != null &&
          serviceContext.trim().isNotEmpty) {
        finalPrompt =
            'سياق القسم: ${serviceContext.trim()}\n\n'
            'طلب المستخدم: $finalPrompt';
      }

      final response = await http
          .post(
            Uri.parse(workerUrl),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'messages': [
                {
                  'role': 'user',
                  'content': finalPrompt,
                }
              ],
              'image':
                  'data:$mimeType;base64,$base64Image',
            }),
          )
          .timeout(
            const Duration(seconds: 60),
          );

      if (response.statusCode != 200) {
        return _readError(response);
      }

      final data = jsonDecode(response.body);

      if (data['ok'] == true &&
          data['reply'] is String &&
          data['reply'].toString().trim().isNotEmpty) {
        return data['reply'].toString().trim();
      }

      return 'الصورة وصلت، لكن صَحبي ما قدرش يحللها دلوقتي.';
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الصورة. جرّب مرة ثانية 📷';
    }
  }

  static Future<ImageGenerationResult> generateImage(
    String prompt,
  ) async {
    try {
      final text = prompt.trim();

      if (text.isEmpty) {
        return const ImageGenerationResult.failure(
          'اكتب وصف الصورة الأول.',
        );
      }

      final response = await http
          .post(
            Uri.parse(imageUrl),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'prompt': text,
            }),
          )
          .timeout(
            const Duration(seconds: 90),
          );

      if (response.statusCode != 200) {
        return ImageGenerationResult.failure(
          _readError(response),
        );
      }

      final data = jsonDecode(response.body);

      if (data['ok'] != true) {
        return ImageGenerationResult.failure(
          data['error']?.toString() ??
              'خدمة الصور لم ترجع نتيجة.',
        );
      }

      final imageBase64 =
          data['image_base64']?.toString();

      if (imageBase64 == null ||
          imageBase64.trim().isEmpty) {
        return const ImageGenerationResult.failure(
          'خدمة الصور رجعت بدون صورة.',
        );
      }

      try {
        final bytes = base64Decode(imageBase64);

        if (bytes.isEmpty) {
          return const ImageGenerationResult.failure(
            'الصورة الناتجة فارغة.',
          );
        }

        return ImageGenerationResult.success(bytes);
      } catch (_) {
        return const ImageGenerationResult.failure(
          'تعذر قراءة الصورة الناتجة.',
        );
      }
    } catch (_) {
      return const ImageGenerationResult.failure(
        'إنشاء الصورة اتأخر. جرّب مرة ثانية 🎨',
      );
    }
  }

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse(statusUrl))
          .timeout(
            const Duration(seconds: 6),
          );

      if (response.statusCode != 200) {
        return false;
      }

      final data = jsonDecode(response.body);

      return data['ok'] == true &&
          data['status'] == 'online';
    } catch (_) {
      return false;
    }
  }

  static String _readError(
    http.Response response,
  ) {
    try {
      final data = jsonDecode(response.body);
      final error = data['error'];

      if (error != null &&
          error.toString().trim().isNotEmpty) {
        return error.toString();
      }
    } catch (_) {}

    if (response.statusCode == 429) {
      return 'الخدمة مشغولة حاليًا. جرّب بعد لحظات ⏳';
    }

    if (response.statusCode >= 500) {
      return 'الخدمة حصل فيها ضغط مؤقت. جرّب مرة ثانية.';
    }

    return 'حصل خطأ في الاتصال بالخادم '
        '(${response.statusCode}).';
  }

  static String _mimeType(String name) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    return 'image/jpeg';
  }
}

class ImageGenerationResult {
  final Uint8List? bytes;
  final String? error;

  const ImageGenerationResult._({
    this.bytes,
    this.error,
  });

  const ImageGenerationResult.success(
    Uint8List image,
  ) : this._(bytes: image);

  const ImageGenerationResult.failure(
    String message,
  ) : this._(error: message);

  bool get isSuccess =>
      bytes != null && bytes!.isNotEmpty;
}
