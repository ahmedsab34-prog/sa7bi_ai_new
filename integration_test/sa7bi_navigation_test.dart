
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sa7bi_ai/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'التنقل بين صفحات صاحبي AI الأربع على Android',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

      app.main();

      // Allow the real app and its first frame to initialize.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      const destinations = [
        'الرئيسية',
        'الشات',
        'الألعاب',
        'حسابي',
      ];

      for (final label in destinations) {
        final finder = find.bySemanticsLabel(label).last;

        expect(
          finder,
          findsOneWidget,
          reason: 'زر التنقل "$label" يجب أن يكون موجودًا.',
        );

        await tester.tap(finder);

        // Wait for PageController animation without waiting for
        // network loading indicators to disappear.
        await tester.pump(
          const Duration(milliseconds: 350),
        );
        await tester.pump();

        final node = tester.getSemantics(finder);

        expect(
          node.hasFlag(SemanticsFlag.isSelected),
          isTrue,
          reason: 'يجب أن تصبح صفحة "$label" هي المحددة بعد الضغط.',
        );
      }

      // Selecting Home while it is already active must remain safe.
      final homeFinder =
          find.bySemanticsLabel('الرئيسية').last;

      await tester.tap(homeFinder);
      await tester.pump(
        const Duration(milliseconds: 300),
      );

      expect(
        tester
            .getSemantics(homeFinder)
            .hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
    },
  );
}
