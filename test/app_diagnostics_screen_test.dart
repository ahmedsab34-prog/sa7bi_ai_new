import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/app_diagnostics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDiagnosticsScreen', () {
    testWidgets(
      'shows diagnostics action and the correct safety explanation',
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
          find.byKey(
            const ValueKey('automatic-quick-check'),
          ),
          findsOneWidget,
        );

        expect(
          find.textContaining(
            'الفحص السريع والشامل لا يرسلان طلب AI مدفوعًا',
          ),
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
      'shows automatic quick checks without starting full diagnostics',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AppDiagnosticsScreen(),
          ),
        );

        await tester.pump();

        expect(
          find.text('فحص تلقائي سريع'),
          findsOneWidget,
        );

        // لا يتم تشغيل التشخيص الشامل تلقائيًا.
        expect(
          find.text('ملخص التشخيص الشامل v5'),
          findsNothing,
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
