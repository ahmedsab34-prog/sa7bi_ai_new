import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/social_connect_hub_screen.dart';

void main() {
  testWidgets(
    'Connect hub shows HERO as the only 3D character and keeps destinations',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SocialConnectHubScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('صاحبي HERO'), findsOneWidget);
      expect(find.textContaining('البطل الخارق الوحيد'), findsOneWidget);
      expect(find.text('صاحبي الرفيق'), findsNothing);
      expect(find.textContaining('شخصية صاحبي 3D'), findsNothing);

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
