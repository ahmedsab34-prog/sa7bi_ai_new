
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/ai_service_models.dart';

/// خدمة الأخبار المستقلة لتطبيق صاحبي AI.
class AiNewsService {
  AiNewsService._();

  static const String newsEndpoint = AppConfig.newsEndpoint;

  /// تحميل الأخبار من الخادم.
  ///
  /// ترجع قائمة فارغة عند فشل الاتصال أو عدم صلاحية البيانات.
  static Future<List<NewsItem>> getNews() async {
    try {
      final uri = Uri.parse(newsEndpoint).replace(
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
              'Cache-Control': 'no-cache, no-store',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return [];
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map ||
          decoded['items'] is! List) {
        return [];
      }

      final result = <NewsItem>[];

      for (final raw in decoded['items'] as List) {
        if (raw is! Map) {
          continue;
        }

        final item = NewsItem(
          title: raw['title']?.toString() ?? '',
          source: raw['source']?.toString() ?? 'الأخبار',
          link: raw['link']?.toString() ?? '',
          imageUrl: (
            raw['imageUrl'] ??
            raw['image'] ??
            raw['thumbnail'] ??
            ''
          ).toString(),
          description:
              raw['description']?.toString() ?? '',
          pubDate: (
            raw['pubDate'] ??
            raw['publishedAt'] ??
            ''
          ).toString(),
        );

        if (item.title.trim().isEmpty ||
            item.link.trim().isEmpty) {
          continue;
        }

        result.add(item);

        if (result.length >= AppConfig.maximumNewsItems) {
          break;
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }
}
