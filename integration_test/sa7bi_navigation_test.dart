import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sa7bi_ai/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'التنقل بين صفحات صاحبي AI الأربع على Android',
    (tester) async {
      final semantics = tester.ensureSemantics();

      try {
        await tester.pumpWidget(const app.Sa7biAiApp());
        await tester.pump(const Duration(seconds: 2));

        const destinations = [
          'الرئيسية',
          'الشات',
          'الألعاب',
          'حسابي',
        ];

        for (final label in destinations) {
          final button = find.bySemanticsLabel(label).last;

          await _pumpUntilHitTestable(
            tester,
            button,
            description: 'زر التنقل "$label"',
          );

          await tester.tap(button.hitTestable().first);

          await _waitUntilSelected(
            tester,
            button,
            label,
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'فتح صفحة "$label" يجب ألا ينتج خطأ Flutter.',
          );
        }

        // Selecting Home while it is already active must remain safe.
        final homeButton = find.bySemanticsLabel('الرئيسية').last;

        await _pumpUntilHitTestable(
          tester,
          homeButton,
          description: 'زر الرئيسية',
        );

        await tester.tap(homeButton.hitTestable().first);

        await _waitUntilSelected(
          tester,
          homeButton,
          'الرئيسية',
        );

        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

Future<void> _pumpUntilHitTestable(
  WidgetTester tester,
  Finder finder, {
  required String description,
  int maxPumps = 40,
}) async {
  final hitTestableFinder = finder.hitTestable();

  for (var attempt = 0; attempt < maxPumps; attempt++) {
    if (hitTestableFinder.evaluate().isNotEmpty) {
      return;
    }

    await tester.pump(const Duration(milliseconds: 100));
  }

  expect(
    hitTestableFinder,
    findsWidgets,
    reason: '$description لم يصبح قابلًا للضغط.',
  );
}

Future<void> _waitUntilSelected(
  WidgetTester tester,
  Finder finder,
  String label,
) async {
  var selected = false;

  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));

    final selectedState = tester
        .getSemantics(finder)
        .getSemanticsData()
        .flagsCollection
        .isSelected;

    if (selectedState == Tristate.isTrue) {
      selected = true;
      break;
    }
  }

  expect(
    selected,
    isTrue,
    reason: 'يجب أن تصبح صفحة "$label" هي الصفحة المحددة بعد الضغط.',
  );
}
