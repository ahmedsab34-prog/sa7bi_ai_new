import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sa7bi_ai/app_diagnostics_screen.dart';
import 'package:sa7bi_ai/chat_tab_screen.dart';
import 'package:sa7bi_ai/interactive_experiences_screen.dart';
import 'package:sa7bi_ai/local_games_hub_screen.dart';
import 'package:sa7bi_ai/main.dart' as sa7bi;
import 'package:sa7bi_ai/owner_profile_screen.dart';
import 'package:sa7bi_ai/profile_screen.dart';
import 'package:sa7bi_ai/settings_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Sa7bi AI tabs, conversation services, games, profile and diagnostics open without UI exceptions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

      await tester.pumpWidget(const sa7bi.Sa7biAiApp());
      await tester.pump(const Duration(seconds: 2));

      // Chat tab.
      await _tapMainTab(tester, 'الشات');

      await _pumpUntilHitTestable(
        tester,
        find.byType(ChatTabScreen),
        description: 'Chat tab',
      );

      // The chat entry contains two clear services.
      expect(find.text('المحادثات'), findsOneWidget);
      expect(find.text('صاحبي Connect'), findsOneWidget);
      expect(find.text('فضفضة مع صاحبي'), findsOneWidget);
      expect(find.text('للتواصل مع الأشخاص الحقيقيين'), findsOneWidget);
      expect(
        find.text('محادثتك الشخصية مع الذكاء الاصطناعي'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Games tab.
      await _tapMainTab(tester, 'الألعاب');

      await _pumpUntilHitTestable(
        tester,
        find.byType(InteractiveExperiencesScreen),
        description: 'Games tab',
      );

      expect(find.text('ألعاب بدون إنترنت'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Open a local game hub without creating an online match.
      final localGames = find.text('ألعاب بدون إنترنت');

      await tester.ensureVisible(localGames);

      await _pumpUntilHitTestable(
        tester,
        localGames,
        description: 'Local games card',
      );

      await tester.tap(localGames.hitTestable().first);

      await _pumpUntilHitTestable(
        tester,
        find.byType(LocalGamesHubScreen),
        description: 'Local games hub',
      );

      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));

      // Profile tab. Profile data loads without initializing reminders.
      await _tapMainTab(tester, 'حسابي');

      await _pumpUntilHitTestable(
        tester,
        find.byType(ProfileScreen),
        description: 'Profile screen',
      );

      final settingsTile = find.text('الإعدادات');

      await tester.ensureVisible(settingsTile);

      await _pumpUntilHitTestable(
        tester,
        settingsTile,
        description: 'Profile settings tile',
      );

      await tester.tap(settingsTile.hitTestable().first);

      await _pumpUntilHitTestable(
        tester,
        find.byType(SettingsScreen),
        description: 'Settings screen',
      );

      final founderTile = find.text('المؤسس والمطوّر');

      await tester.ensureVisible(founderTile);

      await _pumpUntilHitTestable(
        tester,
        founderTile,
        description: 'Founder settings tile',
      );

      await tester.tap(founderTile.hitTestable().first);

      await _pumpUntilHitTestable(
        tester,
        find.byType(OwnerProfileScreen),
        description: 'Founder profile screen',
      );

      expect(
        find.text(OwnerProfileScreen.founderArabicName),
        findsOneWidget,
      );

      final founderImage = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'file_00000000b58881f4b9d70abfa1298442.png',
        description: 'Founder portrait asset',
      );

      expect(founderImage, findsOneWidget);
      expect(tester.takeException(), isNull);

      // Return to the main screen.
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));

      // Open the in-app diagnostics screen.
      final diagnosticsButton = find.byTooltip('تشخيص التطبيق');

      await _pumpUntilFound(
        tester,
        diagnosticsButton,
        description: 'Diagnostics button',
      );

      await tester.ensureVisible(diagnosticsButton.first);

      await _pumpUntilHitTestable(
        tester,
        diagnosticsButton.first,
        description: 'Diagnostics button',
      );

      await tester.tap(diagnosticsButton.first.hitTestable().first);

      await _pumpUntilHitTestable(
        tester,
        find.byType(AppDiagnosticsScreen),
        description: 'Diagnostics screen',
      );

      await _pumpUntilFound(
        tester,
        find.text('فحص تلقائي سريع'),
        description: 'Automatic quick diagnostics section',
      );

      // This stable key remains available while the quick check is running.
      await _pumpUntilFound(
        tester,
        find.byKey(
          const ValueKey<String>('automatic-quick-check'),
        ),
        description: 'Automatic quick diagnostics heading',
      );

      // Verify the page title, not the changing text of the running button.
      expect(
        find.textContaining('فحص صاحبي AI الشامل v5'),
        findsOneWidget,
      );

      // Build metadata is local and does not require paid AI requests.
      await _pumpUntilFound(
        tester,
        find.text('Build/source metadata'),
        description: 'Build/source metadata',
      );

      expect(tester.takeException(), isNull);

      // Do not start full diagnostics in this UI smoke test.
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));

      await _tapMainTab(tester, 'الرئيسية');

      expect(tester.takeException(), isNull);
    },
  );
}

/// Waits for asynchronous screen content without pumpAndSettle.
///
/// The app has continuous decorative animations, so pumpAndSettle is not
/// appropriate for these integration tests.
Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  required String description,
  int maxPumps = 40,
}) async {
  for (var attempt = 0;
      attempt < maxPumps && finder.evaluate().isEmpty;
      attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
  }

  expect(
    finder,
    findsWidgets,
    reason: '$description did not appear after waiting for async UI updates.',
  );
}

/// Waits until a widget is actually available for a pointer tap.
///
/// PageView keeps neighboring screens alive, so a widget can exist in the
/// tree while its page is still offstage or moving during navigation.
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
    reason: '$description did not become hit-testable.',
  );
}

Future<void> _tapMainTab(
  WidgetTester tester,
  String label,
) async {
  final button = find.byWidgetPredicate(
    (widget) {
      if (widget is! Semantics) return false;

      return widget.properties.label == label &&
          widget.properties.button == true;
    },
    description: 'Main navigation button: $label',
  );

  expect(button, findsOneWidget);

  await _pumpUntilHitTestable(
    tester,
    button,
    description: 'Main navigation button: $label',
  );

  await tester.tap(button.hitTestable().first);

  var selected = false;

  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));

    final selectedState = tester
        .getSemantics(button.first)
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
    reason: 'The "$label" tab must become selected after tapping it.',
  );

  await tester.pump(const Duration(milliseconds: 100));

  expect(
    tester.takeException(),
    isNull,
    reason: 'Opening "$label" must not throw a Flutter UI exception.',
  );
}
