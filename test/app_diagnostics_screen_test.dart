
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/app_diagnostics_screen.dart';

const MethodChannel _performanceChannel =
    MethodChannel('sa7bi_ai/performance');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // بيانات جهاز تجريبية حتى لا ينتظر الاختبار
    // MethodChannel حقيقيًا أو مؤقت انتهاء المهلة.
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      _performanceChannel,
      (call) async {
        if (call.method != 'getDevicePerformanceInfo') {
          return null;
        }

        return <String, Object?>{
          'totalMemoryBytes': 6 * 1024 * 1024 * 1024,
          'availableMemoryBytes': 3 * 1024 * 1024 * 1024,
          'lowMemory': false,
          'logicalProcessors': 4,
        };
      },
    );
  });

  tearDown(() {
    // إزالة المحاكاة بعد كل اختبار.
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(
      _performanceChannel,
      null,
    );
  });

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

        // التشخيص السريع تلقائي، لكن الشامل لا يبدأ تلقائيًا.
        expect(
          find.text('ملخص التشخيص الشامل v5'),
          findsNothing,
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
