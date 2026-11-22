
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/social_connect_hub_screen.dart';

void main() {
  testWidgets(
    'Connect hub shows public chat first, private chats, groups and one HERO',
    (tester) async {
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

      // Current public room destination.
      final publicRoom = find.text('الغرفة العامة');
      final privateChats = find.text('محادثاتي الخاصة');
      final groups = find.text('المجموعات');
      final hero = find.text('صاحبي HERO');

      expect(publicRoom, findsOneWidget);
      expect(find.text('افتح الشات العام'), findsOneWidget);

      expect(privateChats, findsOneWidget);
      expect(find.text('افتح المحادثات'), findsOneWidget);

      expect(groups, findsOneWidget);
      expect(find.text('استكشف المجموعات'), findsOneWidget);

      expect(hero, findsOneWidget);

      // Verify destination order.
      expect(
        tester.getTopLeft(publicRoom).dy,
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
      expect(find.text('صاحبي HERO'), findsOneWidget);
      expect(find.text('صاحبي الرفيق'), findsNothing);
      expect(
        find.textContaining('شخصية صاحبي 3D'),
        findsNothing,
      );

      // Current privacy notice.
      final safetyNotice = find.textContaining(
        'حافظ على خصوصيتك',
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
