import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AiService {
  static const String base =
      'https://sa7bi-ai-new.ahmedsab34.workers.dev';

  static const String chatEndpoint =
      '$base/v1/chat';

  static const String imageEndpoint =
      '$base/v1/image';

  static const String newsEndpoint =
      '$base/v1/news';

  static const String audioSearchEndpoint =
      '$base/v1/audio/search';

  static const int maxHistory = 8;

  static Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse(base))
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return false;
      }

      final data = jsonDecode(response.body);

      if (data is! Map) {
        return false;
      }

      return data['ok'] == true &&
          data['status'] == 'online' &&
          data['ai_configured'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> getResponse(
    String prompt, {
    String? serviceContext,
    List<Map<String, String>> history =
        const [],
  }) async {
    final text = prompt.trim();

    if (text.isEmpty) {
      return 'قول لي يا صاحبي 😊';
    }

    try {
      final validHistory = history
          .where(
            (item) =>
                (item['role'] == 'user' ||
                    item['role'] == 'assistant') &&
                (item['content'] ?? '')
                    .trim()
                    .isNotEmpty,
          )
          .toList();

      final start =
          validHistory.length > maxHistory
              ? validHistory.length - maxHistory
              : 0;

      final messages =
          <Map<String, String>>[];

      for (final item
          in validHistory.sublist(start)) {
        messages.add({
          'role': item['role']!,
          'content': item['content']!.trim(),
        });
      }

      var current = text;

      if (serviceContext != null &&
          serviceContext.trim().isNotEmpty) {
        current =
            'سياق الخدمة:\n'
            '${serviceContext.trim()}\n\n'
            'رسالة المستخدم:\n'
            '$text';
      }

      messages.add({
        'role': 'user',
        'content': current,
      });

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: const {
              'Content-Type':
                  'application/json',
            },
            body: jsonEncode({
              'messages': messages,
            }),
          )
          .timeout(
            const Duration(seconds: 45),
          );

      if (response.statusCode != 200) {
        return _serverError(response);
      }

      final data = jsonDecode(response.body);

      if (data is Map &&
          data['ok'] == true &&
          data['reply'] is String &&
          data['reply']
              .toString()
              .trim()
              .isNotEmpty) {
        return data['reply']
            .toString()
            .trim();
      }

      return 'صاحبي مش قادر يرد دلوقتي. جرّب تاني.';
    } catch (_) {
      return 'حصل تأخير في الاتصال بصاحبي. جرّب تاني.';
    }
  }

  static Future<String> analyzeImage(
    XFile file, {
    String prompt =
        'حلل الصورة المرسلة بدقة وباختصار.',
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
            'سياق الخدمة:\n'
            '${serviceContext.trim()}\n\n'
            'طلب المستخدم:\n'
            '$prompt';
      }

      final response = await http
          .post(
            Uri.parse(chatEndpoint),
            headers: const {
              'Content-Type':
                  'application/json',
            },
            body: jsonEncode({
              'messages': [
                {
                  'role': 'user',
                  'content': finalPrompt,
                },
              ],
              'image':
                  'data:${_mime(file.name)};base64,${base64Encode(bytes)}',
            }),
          )
          .timeout(
            const Duration(seconds: 60),
          );

      if (response.statusCode != 200) {
        return _serverError(response);
      }

      final data = jsonDecode(response.body);

      if (data is Map &&
          data['ok'] == true &&
          data['reply'] is String &&
          data['reply']
              .toString()
              .trim()
              .isNotEmpty) {
        return data['reply']
            .toString()
            .trim();
      }

      return 'الصورة وصلت، لكن التحليل لم يكتمل.';
    } catch (_) {
      return 'حصل تأخير أثناء تحليل الصورة. جرّب مرة ثانية.';
    }
  }

  static Future<ImageGenerationResult>
      generateImage(
    String prompt,
  ) async {
    final cleanPrompt = prompt.trim();

    if (cleanPrompt.isEmpty) {
      return const ImageGenerationResult.failure(
        'اكتب وصف الصورة الأول.',
      );
    }

    if (cleanPrompt.length > 8000) {
      return const ImageGenerationResult.failure(
        'وصف الصورة طويل جدًا.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(imageEndpoint),
            headers: const {
              'Content-Type':
                  'application/json',
            },
            body: jsonEncode({
              'prompt': cleanPrompt,
            }),
          )
          .timeout(
            const Duration(seconds: 120),
          );

      if (response.statusCode != 200) {
        return ImageGenerationResult.failure(
          _serverError(response),
        );
      }

      final data = jsonDecode(response.body);

      if (data is! Map) {
        return const ImageGenerationResult.failure(
          'رد خدمة الصور غير مفهوم.',
        );
      }

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

      try {
        final bytes = base64Decode(base64Image);

        if (bytes.isEmpty) {
          return const ImageGenerationResult.failure(
            'خدمة الصور رجعت بيانات فارغة.',
          );
        }

        return ImageGenerationResult.success(
          bytes,
        );
      } catch (_) {
        return const ImageGenerationResult.failure(
          'تعذر قراءة الصورة التي رجعتها الخدمة.',
        );
      }
    } catch (_) {
      return const ImageGenerationResult.failure(
        'الاتصال بخدمة الصور انتهى قبل وصول النتيجة.',
      );
    }
  }

  static Future<List<NewsItem>> getNews() async {
    try {
      final uri =
          Uri.parse(newsEndpoint).replace(
        queryParameters: {
          'refresh': DateTime.now()
              .millisecondsSinceEpoch
              .toString(),
        },
      );

      final response = await http
          .get(
            uri,
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);

      if (data is! Map) {
        return [];
      }

      final list = data['items'];

      if (list is! List) {
        return [];
      }

      return list
          .whereType<Map>()
          .map(
            (item) => NewsItem(
              title:
                  item['title']?.toString() ?? '',
              source:
                  item['source']?.toString() ??
                      'Google News',
              link:
                  item['link']?.toString() ?? '',
              imageUrl:
                  item['imageUrl']?.toString() ??
                      '',
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

  static Future<List<AudioSearchItem>>
      searchAudio(
    String query,
  ) async {
    final clean = query.trim();

    if (clean.isEmpty) {
      return [];
    }

    try {
      final uri =
          Uri.parse(audioSearchEndpoint).replace(
        queryParameters: {
          'q': clean,
        },
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);

      if (data is! Map ||
          data['items'] is! List) {
        return [];
      }

      return (data['items'] as List)
          .whereType<Map>()
          .map(
            (item) => AudioSearchItem(
              title:
                  item['title']?.toString() ?? '',
              artist:
                  item['artist']?.toString(),
              url:
                  item['url']?.toString() ?? '',
              type:
                  item['type']?.toString() ?? 'audio',
            ),
          )
          .where(
            (item) =>
                item.title.isNotEmpty &&
                item.url.isNotEmpty,
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

  static String _serverError(
    http.Response response,
  ) {
    try {
      final data = jsonDecode(response.body);

      if (data is Map) {
        final error = data['error'];

        if (error != null &&
            error.toString().trim().isNotEmpty) {
          return error.toString();
        }
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 400:
        return 'الطلب غير صحيح.';

      case 401:
      case 403:
        return 'خدمة الذكاء الاصطناعي تحتاج إعداد صلاحية صحيح.';

      case 429:
        return 'الخدمة مشغولة حاليًا. جرّب بعد لحظات.';

      case 500:
      case 502:
      case 503:
        return 'الخادم مشغول أو خدمة الذكاء الاصطناعي غير متاحة حاليًا.';

      default:
        return 'حصل خطأ في الاتصال بالخادم.';
    }
  }
}

class NewsItem {
  final String title;
  final String source;
  final String link;
  final String imageUrl;

  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
    this.imageUrl = '',
  });
}

class AudioSearchItem {
  final String title;
  final String? artist;
  final String url;
  final String type;

  const AudioSearchItem({
    required this.title,
    required this.url,
    this.artist,
    required this.type,
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
      bytes != null &&
      bytes!.isNotEmpty;
}
