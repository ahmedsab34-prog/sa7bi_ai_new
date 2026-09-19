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

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final text = prompt.trim();

      if (text.isEmpty) {
        return 'اكتب رسالتك أولاً.';
      }

      final messages = <Map<String, String>>[];

      for (final item in history) {
        final role = item['role'];
        final content = item['content'];

        if ((role == 'user' || role == 'assistant') &&
            content != null &&
            content.trim().isNotEmpty) {
          messages.add({
            'role': role!,
            'content': content.trim(),
          });
        }
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
            const Duration(seconds: 45),
          );

      if (response.statusCode != 200) {
        return _readError(response);
      }

      final data = jsonDecode(response.body);

      if (data['ok'] == true &&
          data['reply'] is String &&
          data['reply'].toString().trim().isNotEmpty) {
        return data['reply'].toString();
      }

      return 'عذراً، لم يصل رد من صَحبي AI.';
    } catch (_) {
      return 'تعذر الاتصال بصَحبي AI. تأكد من الإنترنت ثم حاول مرة أخرى.';
    }
  }

  static Future<String> analyzeImage(
    XFile image, {
    String prompt = 'حلل الصورة بالتفصيل وساعدني في فهم ما فيها.',
    String? serviceContext,
  }) async {
    try {
      final bytes = await image.readAsBytes();

      if (bytes.isEmpty) {
        return 'الصورة فارغة أو لم يتم قراءتها.';
      }

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
              'image': 'data:$mimeType;base64,$base64Image',
            }),
          )
          .timeout(
            const Duration(seconds: 90),
          );

      if (response.statusCode != 200) {
        return _readError(response);
      }

      final data = jsonDecode(response.body);

      if (data['ok'] == true &&
          data['reply'] is String &&
          data['reply'].toString().trim().isNotEmpty) {
        return data['reply'].toString();
      }

      return 'لم أستطع تحليل الصورة.';
    } catch (_) {
      return 'حدث خطأ أثناء إرسال الصورة للذكاء الاصطناعي.';
    }
  }

  static Future<Uint8List?> generateImage(
    String prompt,
  ) async {
    try {
      final text = prompt.trim();

      if (text.isEmpty) {
        return null;
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
            const Duration(seconds: 120),
          );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      final imageBase64 =
          data['image_base64']?.toString();

      if (imageBase64 == null ||
          imageBase64.trim().isEmpty) {
        return null;
      }

      return base64Decode(imageBase64);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse(statusUrl))
          .timeout(
            const Duration(seconds: 10),
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

    return 'حدث خطأ في الاتصال بالخادم (${response.statusCode}).';
  }

  static String _mimeType(String name) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/jpeg';
  }
}
