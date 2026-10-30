import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import '../models/ai_service_models.dart';
import 'sa7bi_network_client.dart';

/// خدمة الأخبار المستقلة لتطبيق صاحبي AI.
///
/// الوظائف:
/// - جلب الأخبار من Worker.
/// - طلب تحديث جديد عند السحب لأسفل.
/// - إزالة تكرار الروابط والعناوين.
/// - ترتيب الأخبار من الأحدث إلى الأقدم.
/// - تجاهل روابط الأخبار غير الصالحة.
/// - الحفاظ على سلوك آمن عند تعذر الاتصال.
///
/// ملاحظة:
/// لا يمكن ضمان وجود خبر جديد في كل تحديث إذا لم تنشر
/// المصادر أخبارًا جديدة؛ لكننا لا نعرض تكرارات واضحة
/// داخل القائمة الواحدة.
class AiNewsService {
  AiNewsService._();

  static const String newsEndpoint = AppConfig.newsEndpoint;

  /// جلب الأخبار.
  ///
  /// forceRefresh = true:
  /// - يضيف قيمة متغيرة إلى الرابط لكسر كاش الرابط السابق.
  /// - يرسل ترويسات تمنع التخزين المؤقت لدى العميل.
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
            .microsecondsSinceEpoch
            .toString();
      }

      final uri = baseUri.replace(
        queryParameters: query.isEmpty ? null : query,
      );

      final headers = forceRefresh
          ? const <String, String>{
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store, max-age=0',
              'Pragma': 'no-cache',
            }
          : const <String, String>{
              'Accept': 'application/json',
            };

      final response = await Sa7biNetworkClient.client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return <NewsItem>[];
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['items'] is! List) {
        return <NewsItem>[];
      }

      final rawItems = decoded['items'] as List;
      final parsedItems = <NewsItem>[];

      for (final raw in rawItems) {
        if (raw is! Map) {
          continue;
        }

        final title = raw['title']?.toString().trim() ?? '';
        final rawLink = raw['link']?.toString().trim() ?? '';

        if (title.isEmpty || rawLink.isEmpty) {
          continue;
        }

        final canonicalLink = canonicalizeNewsLink(rawLink);

        if (canonicalLink.isEmpty) {
          continue;
        }

        parsedItems.add(
          NewsItem(
            title: title,
            source: raw['source']?.toString().trim().isNotEmpty == true
                ? raw['source'].toString().trim()
                : 'الأخبار',
            link: canonicalLink,
            imageUrl: (
              raw['imageUrl'] ??
              raw['image'] ??
              raw['thumbnail'] ??
              ''
            ).toString().trim(),
            description:
                raw['description']?.toString().trim() ?? '',
            pubDate: (
              raw['pubDate'] ??
              raw['publishedAt'] ??
              raw['published'] ??
              raw['date'] ??
              ''
            ).toString().trim(),
          ),
        );
      }

      return normalizeAndSortNews(
        parsedItems,
        maximumItems: AppConfig.maximumNewsItems,
      );
    } catch (_) {
      // فشل الشبكة لا يُسقط التطبيق.
      // الشاشة الرئيسية تحتفظ بالأخبار المحفوظة لديها.
      return <NewsItem>[];
    }
  }

  /// إزالة التكرار وترتيب أحدث الأخبار أولًا.
  ///
  /// يمكن اختبار هذه الدالة دون اتصال بالإنترنت.
  static List<NewsItem> normalizeAndSortNews(
    List<NewsItem> input, {
    int maximumItems = AppConfig.maximumNewsItems,
  }) {
    if (input.isEmpty || maximumItems <= 0) {
      return <NewsItem>[];
    }

    final seenLinks = <String>{};
    final seenTitles = <String>{};
    final ranked = <_RankedNews>[];

    for (var index = 0; index < input.length; index++) {
      final item = input[index];

      final title = item.title.trim();
      final link = canonicalizeNewsLink(item.link);

      if (title.isEmpty || link.isEmpty) {
        continue;
      }

      final titleKey = normalizeNewsTitle(title);

      if (titleKey.isEmpty) {
        continue;
      }

      // يمنع تكرار الرابط حتى لو اختلفت صياغة العنوان.
      if (seenLinks.contains(link)) {
        continue;
      }

      // يمنع تكرار العنوان حتى لو اختلف رابط التتبع.
      if (seenTitles.contains(titleKey)) {
        continue;
      }

      seenLinks.add(link);
      seenTitles.add(titleKey);

      ranked.add(
        _RankedNews(
          item: NewsItem(
            title: title,
            source: item.source.trim().isEmpty
                ? 'الأخبار'
                : item.source.trim(),
            link: link,
            imageUrl: item.imageUrl.trim(),
            description: item.description.trim(),
            pubDate: item.pubDate.trim(),
          ),
          originalIndex: index,
          publishedAt: parseNewsDate(item.pubDate),
        ),
      );
    }

    ranked.sort((a, b) {
      final dateA = a.publishedAt;
      final dateB = b.publishedAt;

      // الأخبار ذات التاريخ المعروف تظهر قبل الأخبار
      // التي لم يصلها تاريخ نشر صالح.
      if (dateA == null && dateB != null) {
        return 1;
      }

      if (dateA != null && dateB == null) {
        return -1;
      }

      if (dateA != null && dateB != null) {
        final newestFirst = dateB.compareTo(dateA);

        if (newestFirst != 0) {
          return newestFirst;
        }
      }

      // الحفاظ على ترتيب المصدر عند تساوي التواريخ
      // أو عدم توفر التاريخ.
      return a.originalIndex.compareTo(b.originalIndex);
    });

    return ranked
        .take(maximumItems)
        .map((entry) => entry.item)
        .toList(growable: false);
  }

  /// توحيد شكل العنوان عند المقارنة ومنع التكرار.
  ///
  /// لا نغيّر العنوان الذي يظهر للمستخدم؛ التوحيد للمقارنة فقط.
  static String normalizeNewsTitle(String value) {
    var result = value.trim().toLowerCase();

    // إزالة التشكيل والتطويل العربي.
    result = result.replaceAll(
      RegExp(r'[\u064B-\u065F\u0670\u0640]'),
      '',
    );

    // توحيد أشكال الألف والياء والتاء المربوطة للمقارنة.
    result = result
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');

    // إزالة علامات الترقيم والفواصل مع الإبقاء على الحروف.
    result = result.replaceAll(
      RegExp(r'[^\u0600-\u06FFa-zA-Z0-9\s]'),
      ' ',
    );

    return result
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// توحيد رابط الخبر وإزالة معاملات التتبع غير الضرورية.
  ///
  /// نحتفظ بمعاملات الرابط المهمة وبكل قيم المعاملات المكررة.
  /// نزيل معاملات التتبع، والمسار الزائد في نهاية الرابط، والـ fragment.
  static String canonicalizeNewsLink(String value) {
    final raw = value.trim();

    if (raw.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(raw);

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty) {
      return '';
    }

    const trackingParameters = <String>{
      'fbclid',
      'gclid',
      'dclid',
      'mc_cid',
      'mc_eid',
      'igshid',
      'ref',
      'ref_src',
      'source',
      'si',
    };

    // queryParametersAll يحافظ على المعاملات التي تتكرر أكثر من مرة.
    final keptParameters = <String, List<String>>{};

    for (final entry in uri.queryParametersAll.entries) {
      final lowerKey = entry.key.toLowerCase();

      if (lowerKey.startsWith('utm_') ||
          trackingParameters.contains(lowerKey)) {
        continue;
      }

      keptParameters[entry.key] = List<String>.from(entry.value);
    }

    final originalPath = uri.path;
    final cleanedPath = originalPath.length > 1
        ? originalPath.replaceFirst(RegExp(r'/+$'), '')
        : originalPath;

    // إنشاء Uri جديد مهم هنا:
    // Uri.replace(queryParameters: null) يحتفظ بالـ query القديم،
    // وfragment: '' ينشئ علامة # فارغة بدل حذف الـ fragment تمامًا.
    final normalizedUri = Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: cleanedPath,
      queryParameters: keptParameters.isEmpty ? null : keptParameters,
    );

    return normalizedUri.toString();
  }

  /// قراءة تاريخ ISO أو تاريخ RSS شائع.
  ///
  /// إذا وصل تاريخ غير مفهوم، نعيد null بدل اختراع تاريخ.
  static DateTime? parseNewsDate(String value) {
    final clean = value.trim();

    if (clean.isEmpty) {
      return null;
    }

    final isoDate = DateTime.tryParse(clean);

    if (isoDate != null) {
      return isoDate.toUtc();
    }

    try {
      return HttpDate.parse(clean).toUtc();
    } catch (_) {
      return null;
    }
  }
}

class _RankedNews {
  final NewsItem item;
  final int originalIndex;
  final DateTime? publishedAt;

  const _RankedNews({
    required this.item,
    required this.originalIndex,
    required this.publishedAt,
  });
}
