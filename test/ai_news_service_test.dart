import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/models/ai_service_models.dart';
import 'package:sa7bi_ai/services/ai_news_service.dart';

void main() {
  group('AiNewsService.normalizeNewsTitle', () {
    test('normalizes Arabic hamza and diacritics', () {
      expect(
        AiNewsService.normalizeNewsTitle('أَخْبار اليوم'),
        AiNewsService.normalizeNewsTitle('اخبار اليوم'),
      );
    });

    test('normalizes spaces and punctuation', () {
      expect(
        AiNewsService.normalizeNewsTitle('خبر جديد!!!   اليوم'),
        AiNewsService.normalizeNewsTitle('خبر جديد اليوم'),
      );
    });
  });

  group('AiNewsService.canonicalizeNewsLink', () {
    test('removes common tracking parameters and fragment', () {
      final first = AiNewsService.canonicalizeNewsLink(
        'https://example.com/news/123?utm_source=app&fbclid=abc#details',
      );

      final second = AiNewsService.canonicalizeNewsLink(
        'https://example.com/news/123',
      );

      expect(first, second);
      expect(first, 'https://example.com/news/123');
    });

    test('preserves meaningful query parameters', () {
      expect(
        AiNewsService.canonicalizeNewsLink(
          'https://example.com/news?id=123&utm_medium=social&lang=ar',
        ),
        'https://example.com/news?id=123&lang=ar',
      );
    });

    test('preserves repeated values for meaningful query parameters', () {
      expect(
        AiNewsService.canonicalizeNewsLink(
          'https://example.com/search?tag=one&tag=two&utm_source=feed',
        ),
        'https://example.com/search?tag=one&tag=two',
      );
    });

    test('preserves a non-default port', () {
      expect(
        AiNewsService.canonicalizeNewsLink(
          'https://example.com:8443/news/123?utm_source=app',
        ),
        'https://example.com:8443/news/123',
      );
    });

    test('removes a trailing slash and fragment', () {
      expect(
        AiNewsService.canonicalizeNewsLink(
          'https://example.com/news/123/#details',
        ),
        'https://example.com/news/123',
      );
    });

    test('rejects invalid and unsupported links', () {
      expect(
        AiNewsService.canonicalizeNewsLink('not a link'),
        isEmpty,
      );

      expect(
        AiNewsService.canonicalizeNewsLink(
          'file:///tmp/news.html',
        ),
        isEmpty,
      );
    });
  });

  group('AiNewsService.normalizeAndSortNews', () {
    const older = NewsItem(
      title: 'خبر قديم',
      source: 'المصدر الأول',
      link: 'https://example.com/old',
      pubDate: '2026-10-27T10:00:00Z',
    );

    const newer = NewsItem(
      title: 'خبر جديد',
      source: 'المصدر الثاني',
      link: 'https://example.com/new',
      pubDate: '2026-10-29T10:00:00Z',
    );

    test('sorts valid dates from newest to oldest', () {
      final result = AiNewsService.normalizeAndSortNews(
        const [older, newer],
      );

      expect(result, hasLength(2));
      expect(result.first.title, 'خبر جديد');
      expect(result.last.title, 'خبر قديم');
    });

    test('removes duplicate titles with different links', () {
      const first = NewsItem(
        title: 'أحدث الأخبار اليوم',
        source: 'المصدر الأول',
        link: 'https://example.com/article-a',
        pubDate: '2026-10-29T12:00:00Z',
      );

      const duplicate = NewsItem(
        title: 'احدث الاخبار اليوم',
        source: 'المصدر الثاني',
        link: 'https://another-example.com/article-b',
        pubDate: '2026-10-29T11:00:00Z',
      );

      final result = AiNewsService.normalizeAndSortNews(
        const [first, duplicate],
      );

      expect(result, hasLength(1));
      expect(result.single.link, first.link);
    });

    test('removes duplicate links with tracking parameters', () {
      const first = NewsItem(
        title: 'عنوان الخبر الأول',
        source: 'المصدر الأول',
        link: 'https://example.com/article/1?utm_source=feed',
      );

      const duplicateLink = NewsItem(
        title: 'عنوان مختلف لنفس الرابط',
        source: 'المصدر الثاني',
        link: 'https://example.com/article/1',
      );

      final result = AiNewsService.normalizeAndSortNews(
        const [first, duplicateLink],
      );

      expect(result, hasLength(1));
    });

    test('preserves input order when both dates are unknown', () {
      const first = NewsItem(
        title: 'الخبر الأول',
        source: 'مصدر',
        link: 'https://example.com/first',
      );

      const second = NewsItem(
        title: 'الخبر الثاني',
        source: 'مصدر',
        link: 'https://example.com/second',
      );

      final result = AiNewsService.normalizeAndSortNews(
        const [first, second],
      );

      expect(result, hasLength(2));
      expect(result.first.title, first.title);
      expect(result.last.title, second.title);
    });

    test('does not exceed the requested maximum', () {
      final result = AiNewsService.normalizeAndSortNews(
        const [newer, older],
        maximumItems: 1,
      );

      expect(result, hasLength(1));
      expect(result.single.title, 'خبر جديد');
    });

    test('returns an empty list for an empty input', () {
      expect(
        AiNewsService.normalizeAndSortNews(const []),
        isEmpty,
      );
    });
  });
}
