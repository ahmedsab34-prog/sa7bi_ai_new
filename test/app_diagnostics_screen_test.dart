
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/app_diagnostics_screen.dart';

void main() {
  group('AppDiagnosticsScreen', () {
    testWidgets(
      'shows the diagnostics start action and safety explanation',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AppDiagnosticsScreen(),
          ),
        );

        await tester.pump();

        expect(
          find.text('تشخيص صاحبي AI'),
          findsOneWidget,
        );

        expect(
          find.text('🛠️ فحص صاحبي AI الشامل v5'),
          findsOneWidget,
        );

        expect(
          find.text('ابدأ الفحص الشامل'),
          findsOneWidget,
        );

        expect(
          find.textContaining('الفحص لا يرسل طلب AI مدفوعًا'),
          findsOneWidget,
        );

        expect(
          find.textContaining('لم يتم اختبار'),
          findsNothing,
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'does not start network diagnostics during screen initialization',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AppDiagnosticsScreen(),
          ),
        );

        await tester.pump();

        // The service is constructed in initState only.
        // No diagnostic request should run until the user taps Start.
        expect(
          find.text('ابدأ الفحص الشامل'),
          findsOneWidget,
        );

        expect(
          find.textContaining('تم تنفيذ'),
          findsNothing,
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
