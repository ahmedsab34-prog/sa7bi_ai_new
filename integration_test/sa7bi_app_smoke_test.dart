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
    'Sa7bi AI tabs, games, founder page and diagnostics open without UI exceptions',
    (tester) async {
      await tester.pumpWidget(const sa7bi.Sa7biAiApp());
      await tester.pump(const Duration(seconds: 2));

      // Chat tab: it contains private messages, friend search and secure venting.
      // The general AI conversation belongs to Khalasana, not this tab.
      await _tapMainTab(tester, 'الشات');

      expect(find.byType(ChatTabScreen), findsOneWidget);
      expect(find.text('الرسائل'), findsOneWidget);
      expect(find.text('بحث الأصدقاء'), findsOneWidget);
      expect(find.text('فضفضة سرية'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Games tab.
      await _tapMainTab(tester, 'الألعاب');

      expect(
        find.byType(InteractiveExperiencesScreen),
        findsOneWidget,
      );
      expect(find.text('ألعاب بدون إنترنت'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Open a local game hub without creating an online match.
      final localGames = find.text('ألعاب بدون إنترنت');

      await tester.tap(localGames);
      await tester.pump(
        const Duration(milliseconds: 500),
      );

      expect(find.byType(LocalGamesHubScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pump(
        const Duration(milliseconds: 400),
      );

      // Profile tab.
      await _tapMainTab(tester, 'حسابي');

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Open Settings and verify the existing founder page and asset.
      final settingsTile = find.text('الإعدادات').first;
      await tester.ensureVisible(settingsTile);
      await tester.tap(settingsTile);
      await tester.pump(
        const Duration(milliseconds: 500),
      );

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('المؤسس والمطوّر'), findsOneWidget);

      await tester.tap(find.text('المؤسس والمطوّر'));
      await tester.pump(
        const Duration(milliseconds: 500),
      );

      expect(find.byType(OwnerProfileScreen), findsOneWidget);
      expect(find.text(OwnerProfileScreen.founderArabicName), findsOneWidget);

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

      await tester.pageBack();
      await tester.pump(
        const Duration(milliseconds: 350),
      );
      await tester.pageBack();
      await tester.pump(
        const Duration(milliseconds: 350),
      );

      // Open the in-app diagnostics screen.
      final diagnosticsButton =
          find.byTooltip('تشخيص التطبيق');

      expect(diagnosticsButton, findsWidgets);

      await tester.tap(diagnosticsButton.first);
      await tester.pump(
        const Duration(milliseconds: 500),
      );

      expect(
        find.byType(AppDiagnosticsScreen),
        findsOneWidget,
      );

      expect(
        find.text('فحص تلقائي سريع'),
        findsOneWidget,
      );

      expect(
        find.text('ابدأ الفحص الشامل'),
        findsOneWidget,
      );

      // Local build metadata should be visible without paid AI requests.
      await tester.pump(
        const Duration(seconds: 1),
      );

      expect(
        find.text('Build/source metadata'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);

      // Do not start the full diagnostics run here; it may contact services.
      await tester.pageBack();
      await tester.pump(
        const Duration(milliseconds: 400),
      );

      await _tapMainTab(tester, 'الرئيسية');

      expect(tester.takeException(), isNull);
    },
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

  await tester.tap(button);
  await tester.pump(
    const Duration(milliseconds: 450),
  );

  expect(
    tester.takeException(),
    isNull,
    reason: 'Opening "$label" must not throw a Flutter UI exception.',
  );
}
