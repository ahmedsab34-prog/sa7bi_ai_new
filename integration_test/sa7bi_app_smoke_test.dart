
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sa7bi_ai/main.dart' as sa7bi;
import 'package:sa7bi_ai/widgets/app_header.dart';
import 'package:sa7bi_ai/widgets/khalasana_portal.dart';
import 'package:sa7bi_ai/widgets/sa7bi_hero_3d.dart';
import 'package:sa7bi_ai/chat_tab_screen.dart';
import 'package:sa7bi_ai/interactive_experiences_screen.dart';
import 'package:sa7bi_ai/profile_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sa7bi AI main navigation and HERO smoke test',
      (tester) async {
    // اختبار التبويبات لا يحتاج إلى تشغيل محرك WebView ثلاثي الأبعاد.
    // اختبار ملف GLB والـFace Rig موجود بصورة مستقلة.
    Sa7biHero3D.debugDisableWebViewForTests = true;

    addTearDown(() {
      Sa7biHero3D.debugDisableWebViewForTests = false;
    });

    await tester.pumpWidget(const sa7bi.Sa7biAiApp());
    await tester.pump(const Duration(seconds: 2));

    // Home screen and the single floating HERO character.
    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(KhalasanaPortal), findsOneWidget);
    expect(find.byType(Sa7biHero3D), findsOneWidget);
    expect(
      find.bySemanticsLabel('HERO 3D test placeholder'),
      findsOneWidget,
    );

    final pageViewFinder = find.byWidgetPredicate(
      (widget) =>
          widget is PageView &&
          widget.scrollDirection == Axis.horizontal,
      description: 'Main horizontal PageView',
    );

    expect(pageViewFinder, findsOneWidget);

    // Navigate to Chat.
    await _tapMainTab(tester, 'الشات');
    expect(find.byType(ChatTabScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Navigate to Games.
    await _tapMainTab(tester, 'الألعاب');
    expect(find.byType(InteractiveExperiencesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Navigate to Profile.
    await _tapMainTab(tester, 'حسابي');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Return to Home.
    await _tapMainTab(tester, 'الرئيسية');
    expect(find.byType(KhalasanaPortal), findsOneWidget);
    expect(find.byType(Sa7biHero3D), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Verify horizontal PageView dragging.
    final pageView = pageViewFinder.first;
    final topLeft = tester.getTopLeft(pageView);
    final size = tester.getSize(pageView);

    await tester.timedDragFrom(
      Offset(
        topLeft.dx + size.width * 0.85,
        topLeft.dy + size.height * 0.20,
      ),
      Offset(-size.width * 0.65, 0),
      const Duration(milliseconds: 350),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Finder _mainTabButton(String label) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is! Semantics) return false;

      return widget.properties.label == label &&
          widget.properties.button == true;
    },
    description: 'Main navigation button: $label',
  );
}

Future<void> _tapMainTab(
  WidgetTester tester,
  String label,
) async {
  final button = _mainTabButton(label);

  expect(
    button,
    findsOneWidget,
    reason: 'Main tab "$label" was not found.',
  );

  await tester.ensureVisible(button);
  await tester.pump();

  final hitTarget = button.hitTestable();
  expect(hitTarget, findsOneWidget);

  await tester.tap(hitTarget);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
  );

  expect(
    tester.takeException(),
    isNull,
    reason: 'Opening "$label" caused a Flutter exception.',
  );
}
