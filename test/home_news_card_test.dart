import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/ai_service.dart';
import 'package:sa7bi_ai/theme/sa7bi_theme.dart';
import 'package:sa7bi_ai/widgets/home_news_card.dart';

void main() {
  const sampleNews = NewsItem(
    title: 'عنوان خبر تجريبي',
    source: 'مصدر الأخبار',
    link: 'https://example.com/news/1',
    imageUrl: '',
    description: 'وصف مختصر للخبر التجريبي.',
    pubDate: '2026-11-22T10:00:00Z',
  );

  group('HomeNewsCard', () {
    testWidgets('shows the news title, source and description', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: Scaffold(
            body: HomeNewsCard(
              item: sampleNews,
              index: 0,
              publishedLabel: 'اليوم • 10:00',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('عنوان خبر تجريبي'), findsOneWidget);
      expect(find.text('مصدر الأخبار'), findsOneWidget);
      expect(
        find.text('وصف مختصر للخبر التجريبي.'),
        findsOneWidget,
      );
      expect(find.text('اليوم • 10:00'), findsOneWidget);
      expect(find.text('اقرأ الخبر'), findsOneWidget);
    });

    testWidgets('opens the selected news when tapped', (
      tester,
    ) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: Scaffold(
            body: HomeNewsCard(
              item: sampleNews,
              index: 0,
              publishedLabel: 'اليوم',
              onTap: () {
                tapCount++;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('عنوان خبر تجريبي'));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('uses a fallback title when the title is empty', (
      tester,
    ) async {
      const emptyTitleNews = NewsItem(
        title: '',
        source: 'مصدر تجريبي',
        link: 'https://example.com/news/2',
        imageUrl: '',
        description: '',
        pubDate: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: Scaffold(
            body: HomeNewsCard(
              item: emptyTitleNews,
              index: 2,
              publishedLabel: 'وقت النشر غير متاح',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('خبر 3'), findsOneWidget);
      expect(
        find.text('اضغط لقراءة تفاصيل الخبر.'),
        findsOneWidget,
      );
    });

    testWidgets('renders the image placeholder without an image URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: Scaffold(
            body: HomeNewsCard(
              item: sampleNews,
              index: 0,
              publishedLabel: 'اليوم',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.byIcon(Icons.newspaper_rounded),
        findsOneWidget,
      );
    });
  });

  group('HomeNewsSectionHeader', () {
    testWidgets('shows its title and refresh action', (
      tester,
    ) async {
      var refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: Scaffold(
            body: HomeNewsSectionHeader(
              title: 'آخر الأخبار',
              subtitle: 'آخر تحديث 10:30',
              refreshing: false,
              onRefresh: () {
                refreshCount++;
              },
            ),
          ),
        ),
      );

      expect(find.text('آخر الأخبار'), findsOneWidget);
      expect(find.text('آخر تحديث 10:30'), findsOneWidget);

      await tester.tap(
        find.byTooltip('تحديث الأخبار'),
      );
      await tester.pump();

      expect(refreshCount, 1);
    });

    testWidgets('shows a progress indicator while refreshing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: Scaffold(
            body: HomeNewsSectionHeader(
              title: 'آخر الأخبار',
              subtitle: 'جارٍ التحديث',
              refreshing: true,
              onRefresh: () {},
            ),
          ),
        ),
      );

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );
    });
  });
}
