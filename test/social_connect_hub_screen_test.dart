import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/social_connect_hub_screen.dart';

void main() {
  testWidgets(
    'Connect hub shows both companion characters and destinations',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SocialConnectHubScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('صاحبي الرفيق'), findsOneWidget);
      expect(find.text('صاحبي HERO'), findsOneWidget);
      expect(find.text('المحادثات والأصدقاء'), findsOneWidget);
      expect(find.text('المجموعات العامة'), findsOneWidget);
      expect(find.text('افتح المحادثات'), findsOneWidget);
      expect(find.text('استكشف المجموعات'), findsOneWidget);

      final infoNote = find.textContaining('المجموعات هنا عامة');
      await tester.scrollUntilVisible(
        infoNote,
        250,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(infoNote, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
