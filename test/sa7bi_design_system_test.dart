import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/theme/sa7bi_theme.dart';
import 'package:sa7bi_ai/widgets/sa7bi_glass_surface.dart';

void main() {
  group('Sa7bi AI design system', () {
    test('uses the approved dark brand palette', () {
      final theme = Sa7biTheme.dark();

      expect(theme.brightness, Brightness.dark);
      expect(
        theme.scaffoldBackgroundColor,
        Sa7biTheme.background,
      );
      expect(
        theme.colorScheme.primary,
        Sa7biTheme.blueBright,
      );
      expect(
        theme.colorScheme.secondary,
        Sa7biTheme.violet,
      );
      expect(
        theme.colorScheme.tertiary,
        Sa7biTheme.cyan,
      );
    });

    test('keeps the gold accent available in the theme', () {
      final theme = Sa7biTheme.dark();

      expect(Sa7biTheme.gold, isA<Color>());
      expect(Sa7biTheme.goldBright, isA<Color>());
      expect(theme.colorScheme.error, Sa7biTheme.danger);
    });

    testWidgets('renders the shared glass surface child', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: const Scaffold(
            body: Sa7biGlassSurface(
              child: Text('بطاقة صاحبي'),
            ),
          ),
        ),
      );

      expect(find.text('بطاقة صاحبي'), findsOneWidget);
    });

    testWidgets('runs the callback when a glass surface is tapped', (
      tester,
    ) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: Scaffold(
            body: Sa7biGlassSurface(
              onTap: () {
                tapCount++;
              },
              child: const Text('افتح البطاقة'),
            ),
          ),
        ),
      );

      expect(find.text('افتح البطاقة'), findsOneWidget);

      await tester.tap(find.text('افتح البطاقة'));
      await tester.pump();

      expect(tapCount, 1);
    });

    testWidgets('renders a non-interactive surface safely', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: Sa7biTheme.dark(),
          home: const Scaffold(
            body: Sa7biGlassSurface(
              child: Text('محتوى ثابت'),
            ),
          ),
        ),
      );

      expect(find.text('محتوى ثابت'), findsOneWidget);
    });
  });
}
