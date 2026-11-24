
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/chat_tab_screen.dart';

void main() {
  testWidgets(
    'Chat tab opens Connect hub with public, private and games entries',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ChatTabScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('صاحبي Connect'), findsOneWidget);
      expect(find.text('الغرفة العامة'), findsOneWidget);
      expect(find.text('محادثاتي الخاصة'), findsOneWidget);
      expect(find.text('المجموعات'), findsOneWidget);
      expect(find.text('مركز الألعاب'), findsOneWidget);
      expect(find.text('صاحبي HERO'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
