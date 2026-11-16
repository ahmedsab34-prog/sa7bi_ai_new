import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/social_connect_hub_screen.dart';

void main() {
  testWidgets(
    'Connect hub shows private conversations and public groups',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SocialConnectHubScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // العناصر الموجودة بالقرب من أعلى الشاشة.
      expect(find.text('صاحبي Connect'), findsOneWidget);
      expect(find.text('المحادثات والأصدقاء'), findsOneWidget);
      expect(find.text('المجموعات العامة'), findsOneWidget);
      expect(find.text('افتح المحادثات'), findsOneWidget);
      expect(find.text('استكشف المجموعات'), findsOneWidget);

      // الملاحظة موجودة أسفل البطاقات داخل ListView.
      // نمرر إليها أولًا لأن القائمة تبني عناصرها عند الحاجة.
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
