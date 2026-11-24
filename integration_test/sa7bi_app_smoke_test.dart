import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sa7bi_ai/main.dart' as sa7bi;
import 'package:sa7bi_ai/chat_tab_screen.dart';
import 'package:sa7bi_ai/interactive_experiences_screen.dart';
import 'package:sa7bi_ai/profile_screen.dart';
import 'package:sa7bi_ai/services/hero_face_runtime.dart';
import 'package:sa7bi_ai/widgets/app_header.dart';
import 'package:sa7bi_ai/widgets/khalasana_portal.dart';
import 'package:sa7bi_ai/widgets/sa7bi_hero_3d.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Sa7bi AI main navigation and HERO smoke test',
      (tester) async {
    Sa7biHero3D.debugDisableWebViewForTests = true;

    addTearDown(() {
      Sa7biHero3D.debugDisableWebViewForTests = false;
    });

    await tester.pumpWidget(const sa7bi.Sa7biAiApp());
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(AppHeader), findsOneWidget);
    expect(find.byType(KhalasanaPortal), findsOneWidget);
    expect(find.byType(Sa7biHero3D), findsOneWidget);

    final heroIcon = find.descendant(
      of: find.byType(Sa7biHero3D),
      matching: find.byIcon(Icons.smart_toy_rounded),
    );
    expect(heroIcon, findsOneWidget);

    final pageViewFinder = find.byWidgetPredicate(
      (widget) =>
          widget is PageView &&
          widget.scrollDirection == Axis.horizontal,
      description: 'Main horizontal PageView',
    );
    expect(pageViewFinder, findsOneWidget);

    await _tapMainTab(tester, 'الشات');
    expect(find.byType(ChatTabScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapMainTab(tester, 'الألعاب');
    expect(find.byType(InteractiveExperiencesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapMainTab(tester, 'حسابي');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapMainTab(tester, 'الرئيسية');
    expect(find.byType(KhalasanaPortal), findsOneWidget);
    expect(find.byType(Sa7biHero3D), findsOneWidget);
    expect(tester.takeException(), isNull);

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

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'HERO GLB loads all body, expression and viseme clips on Android',
    (tester) async {
      Sa7biHero3D.debugDisableWebViewForTests = false;

      final runtime = HeroFaceRuntime.instance;
      runtime.reportAvailableAnimations(const <String>[]);

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        Sa7biHero3D.debugDisableWebViewForTests = false;
        runtime.reportAvailableAnimations(const <String>[]);
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                height: 440,
                child: Sa7biHero3D(
                  animationName: 'Hero_Idle',
                  cameraControls: true,
                  enableFaceAnimations: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 45));
        while (!runtime.isFaceRigAvailable &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      });

      await tester.pump(const Duration(milliseconds: 300));

      expect(
        runtime.availableAnimations.value,
        containsAll(const <String>{
          'Hero_Idle',
          'Hero_Welcome',
          'Hero_Power',
          'HERO_FACE_SMILE',
          'HERO_FACE_SAD',
          'HERO_FACE_SURPRISE',
          'HERO_FACE_ANGRY',
          'HERO_FACE_WINK',
          'HERO_FACE_BLINK',
          'HERO_VISEME_sil',
          'HERO_VISEME_PP',
          'HERO_VISEME_FF',
          'HERO_VISEME_TH',
          'HERO_VISEME_DD',
          'HERO_VISEME_kk',
          'HERO_VISEME_CH',
          'HERO_VISEME_SS',
          'HERO_VISEME_nn',
          'HERO_VISEME_RR',
          'HERO_VISEME_aa',
          'HERO_VISEME_E',
          'HERO_VISEME_I',
          'HERO_VISEME_O',
          'HERO_VISEME_U',
        }),
        reason:
            'Android Model Viewer must load the complete HERO GLB face rig.',
      );
      expect(runtime.isFaceRigAvailable, isTrue);

      runtime.playExpression(HeroExpression.smile);
      runtime.onSpeechStarted();
      runtime.onSpeechWord('مرحبا');
      await tester.pump(const Duration(milliseconds: 250));
      runtime.onSpeechFinished();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
    },
  );
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
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();

  expect(
    tester.takeException(),
    isNull,
    reason: 'Opening "$label" caused a Flutter exception.',
  );
}
