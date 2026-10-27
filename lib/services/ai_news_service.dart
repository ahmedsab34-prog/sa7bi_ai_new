
import 'dart:convert';

import '../config/app_config.dart';
import '../models/ai_service_models.dart';
import 'sa7bi_network_client.dart';

/// خدمة الأخبار المستقلة لتطبيق صاحبي AI.
///
/// التحميل العادي يسمح بالاستفادة من التخزين المؤقت.
/// التحديث اليدوي فقط يطلب بيانات جديدة دون الاعتماد على الكاش.
class AiNewsService {
  AiNewsService._();

  static const String newsEndpoint = AppConfig.newsEndpoint;

  static Future<List<NewsItem>> getNews({
    bool forceRefresh = false,
  }) async {
    try {
      final baseUri = Uri.parse(newsEndpoint);
      final query = Map<String, String>.from(
        baseUri.queryParameters,
      );

      if (forceRefresh) {
        query['refresh'] = DateTime.now()
            .millisecondsSinceEpoch
            .toString();
      }

      final uri = baseUri.replace(
        queryParameters: query.isEmpty ? null : query,
      );

      final headers = forceRefresh
          ? const <String, String>{
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store',
              'Pragma': 'no-cache',
            }
          : const <String, String>{
              'Accept': 'application/json',
            };

      final response = await Sa7biNetworkClient.client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));

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
      // فشل الشبكة لا يُسقط التطبيق؛ الرئيسية تحتفظ بالأخبار المحفوظة.
      return [];
    }
  }
}
