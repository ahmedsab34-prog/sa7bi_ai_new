
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/social_connect_hub_screen.dart';

void main() {
  testWidgets(
    'Connect hub shows public chat first, private chats, groups and one HERO',
    (tester) async {
      // Give the ListView enough room to build all destination cards.
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SocialConnectHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Public chat is the first destination.
      final publicChat = find.text('الشات العام');
      final privateChats = find.text('المحادثات والأصدقاء');
      final groups = find.text('المجموعات');
      final hero = find.text('صاحبي HERO');

      expect(publicChat, findsOneWidget);
      expect(find.text('ادخل الشات العام'), findsOneWidget);

      expect(privateChats, findsOneWidget);
      expect(find.text('افتح المحادثات'), findsOneWidget);

      expect(groups, findsOneWidget);
      expect(find.text('استكشف المجموعات'), findsOneWidget);

      expect(hero, findsOneWidget);

      // Verify the intended visual order.
      expect(
        tester.getTopLeft(publicChat).dy,
        lessThan(tester.getTopLeft(privateChats).dy),
      );

      expect(
        tester.getTopLeft(privateChats).dy,
        lessThan(tester.getTopLeft(groups).dy),
      );

      expect(
        tester.getTopLeft(groups).dy,
        lessThan(tester.getTopLeft(hero).dy),
      );

      // HERO is the only character destination.
      expect(
        find.textContaining('البطل الخارق الوحيد'),
        findsOneWidget,
      );

      expect(find.text('صاحبي الرفيق'), findsNothing);
      expect(find.textContaining('شخصية صاحبي 3D'), findsNothing);

      // The public-room safety notice is present.
      final safetyNotice = find.textContaining(
        'الشات العام مساحة مشتركة بين مستخدمي صاحبي',
      );

      await tester.scrollUntilVisible(
        safetyNotice,
        250,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(safetyNotice, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
