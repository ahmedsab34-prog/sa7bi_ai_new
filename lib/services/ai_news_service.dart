import 'dart:convert';

import '../config/app_config.dart';
import '../models/ai_service_models.dart';
import 'sa7bi_network_client.dart';

/// خدمة الأخبار المستقلة لتطبيق صاحبي AI.
class AiNewsService {
  AiNewsService._();

  static const String newsEndpoint = AppConfig.newsEndpoint;

  /// تحميل الأخبار باستخدام عميل الشبكة الموحد.
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

      final response = await Sa7biNetworkClient.client
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
          description: raw['description']?.toString() ?? '',
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
