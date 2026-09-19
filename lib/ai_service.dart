import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AiService {
  static const String base =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  static const String chatEndpoint = '$base/v1/chat';
  static const String imageEndpoint = '$base/v1/image';
  static const String newsEndpoint = '$base/v1/news';

  static const int maxHistory = 6;

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final text = prompt.trim();

      if (text.isEmpty) {
        return 'قول لي يا صاحبي 😊';
      }

      final validHistory = history
          .where(
            (item) =>
                (item['role'] == 'user' ||
                    item['role'] == 'assistant') &&
                (item['content'] ?? '').trim().isNotEmpty,
          )
          .toList();

      final start = validHistory.length > maxHistory
          ? validHistory.length - maxHistory
          : 0;

      final messages = <Map<String, String>>[];

      for (final item in validHistory.sublist(start)) {
        messages.add({
          'role': item['role']!,
          'content': item['content']!.trim(),
        });
      }

      var current = text;

      if (serviceContext != null &&
          serviceContext.trim().isNotEmpty) {
        current =
            'سياق القسم: ${serviceContext.trim()}\n\n'
            'رسالة المستخدم: $text';
      }

      messages.add({
        'role': 'user',
        'content': current,
      });

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'messages': messages,
            }),
          )
          .timeout(
            const Duration(seconds: 25),
          );

      if (response.statusCode != 200) {
        return _serverError(response);
      }

      final data = jsonDecode(response.body);

      if (data['ok'] == true &&
          data['reply'] is String &&
          data['reply'].toString().trim().isNotEmpty) {
        return data['reply'].toString().trim();
      }

      return 'خلصانة مش قادرة ترد دلوقتي 😕';
    } catch (_) {
      return 'الرد اتأخر شوية 😅 جرّب تاني.';
    }
  }

  static Future<String> analyzeImage(
    XFile file, {
    String prompt = 'حلل الصورة المرسلة بدقة وباختصار.',
    String? serviceContext,
  }) async {
    try {
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        return 'الصورة لم يتم قراءتها.';
      }

      if (bytes.length > 5 * 1024 * 1024) {
        return 'الصورة كبيرة جدًا. ابعت صورة أصغر.';
      }

      var finalPrompt = prompt;

      if (serviceContext != null &&
          serviceContext.trim().isNotEmpty) {
        finalPrompt =
            'سياق القسم: ${serviceContext.trim()}\n\n'
            'طلب المستخدم: $prompt';
      }

      final body = {
        'messages': [
          {
            'role': 'user',
            'content': finalPrompt,
          },
        ],
        'image':
            'data:${_mime(file.name)};base64,${base64Encode(bytes)}',
      };

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 45),
          );

      if (response.statusCode != 200) {
        return _serverError(response);
      }

      final data = jsonDecode(response.body);

      if (data['ok'] == true &&
          data['reply'] is String &&
          data['reply'].toString().trim().isNotEmpty) {
        return data['reply'].toString().trim();
      }

      return 'الصورة وصلت، لكن التحليل لم يكتمل.';
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الصورة 📷 جرّب مرة ثانية.';
    }
  }

  static Future<ImageGenerationResult> generateImage(
    String prompt,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(imageEndpoint),
            headers: const {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'prompt': prompt.trim(),
            }),
          )
          .timeout(
            const Duration(seconds: 90),
          );

      if (response.statusCode != 200) {
        return ImageGenerationResult.failure(
          _serverError(response),
        );
      }

      final data = jsonDecode(response.body);

      final base64Image =
          data['image_base64']?.toString();

      if (data['ok'] != true ||
          base64Image == null ||
          base64Image.isEmpty) {
        return ImageGenerationResult.failure(
          data['error']?.toString() ??
              'خدمة الصور لم ترجع صورة.',
        );
      }

      return ImageGenerationResult.success(
        base64Decode(base64Image),
      );
    } catch (_) {
      return const ImageGenerationResult.failure(
        'إنشاء الصورة اتأخر. جرّب مرة ثانية 🎨',
      );
    }
  }

  static Future<List<NewsItem>> getNews() async {
    try {
      final response = await http
          .get(Uri.parse(newsEndpoint))
          .timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      final list = data['items'];

      if (list is! List) {
        return [];
      }

      return list
          .whereType<Map>()
          .map(
            (item) => NewsItem(
              title: item['title']?.toString() ?? '',
              source:
                  item['source']?.toString() ?? 'Google News',
              link: item['link']?.toString() ?? '',
            ),
          )
          .where(
            (item) =>
                item.title.isNotEmpty &&
                item.link.isNotEmpty,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _mime(String name) {
    final value = name.toLowerCase();

    if (value.endsWith('.png')) {
      return 'image/png';
    }

    if (value.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'image/jpeg';
  }

  static String _serverError(http.Response response) {
    try {
      final data = jsonDecode(response.body);

      final error = data['error'];

      if (error != null &&
          error.toString().trim().isNotEmpty) {
        return error.toString();
      }
    } catch (_) {}

    if (response.statusCode == 429) {
      return 'الخدمة مشغولة حاليًا ⏳';
    }

    if (response.statusCode >= 500) {
      return 'الخدمة حصل فيها ضغط مؤقت.';
    }

    return 'حصل خطأ في الاتصال بالخادم.';
  }
}

class NewsItem {
  final String title;
  final String source;
  final String link;

  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
  });
}

class ImageGenerationResult {
  final Uint8List? bytes;
  final String? error;

  const ImageGenerationResult._({
    this.bytes,
    this.error,
  });

  const ImageGenerationResult.success(
    Uint8List bytes,
  ) : this._(
          bytes: bytes,
        );

  const ImageGenerationResult.failure(
    String error,
  ) : this._(
          error: error,
        );

  bool get isSuccess =>
      bytes != null && bytes!.isNotEmpty;
}
