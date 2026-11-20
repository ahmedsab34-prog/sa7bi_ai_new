import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sa7bi_ai/app_diagnostics_screen.dart';
import 'package:sa7bi_ai/chat_tab_screen.dart';
import 'package:sa7bi_ai/interactive_experiences_screen.dart';
import 'package:sa7bi_ai/local_board_games_screen.dart';
import 'package:sa7bi_ai/local_games_hub_screen.dart';
import 'package:sa7bi_ai/main.dart' as sa7bi;
import 'package:sa7bi_ai/owner_profile_screen.dart';
import 'package:sa7bi_ai/profile_screen.dart';
import 'package:sa7bi_ai/services/hero_face_runtime.dart';
import 'package:sa7bi_ai/settings_screen.dart';
import 'package:sa7bi_ai/social_ai_games_screen.dart';
import 'package:sa7bi_ai/social_connect_hub_screen.dart';
import 'package:sa7bi_ai/social_connections_screen.dart';
import 'package:sa7bi_ai/social_games_hub_screen.dart';
import 'package:sa7bi_ai/social_groups_screen.dart';
import 'package:sa7bi_ai/social_groups_workspace_screen.dart';
import 'package:sa7bi_ai/social_private_groups_screen.dart';
import 'package:sa7bi_ai/widgets/app_header.dart';
import 'package:sa7bi_ai/widgets/audio_center_with_header.dart';
import 'package:sa7bi_ai/widgets/sa7bi_hero_3d.dart';
import 'package:sa7bi_ai/widgets/sa7bi_hero_lite_panel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Sa7bi AI final navigation, chat, groups, games, profile, HERO and diagnostics smoke test',
    (tester) async {
      final semantics = tester.ensureSemantics();

      try {
        await tester.pumpWidget(const sa7bi.Sa7biAiApp());
        await tester.pump(const Duration(seconds: 2));

        // ------------------------------------------------------------
        // Home screen, HERO, header and pull-to-refresh.
        // ------------------------------------------------------------

        await _pumpUntilFound(
          tester,
          find.byType(AppHeader),
          description: 'Home header',
        );

        expect(find.byType(AppHeader), findsOneWidget);
        expect(find.byType(Sa7biHeroLitePanel), findsOneWidget);
        expect(find.byType(Sa7biHero3D), findsOneWidget);
        expect(find.byType(RefreshIndicator), findsOneWidget);

        // The Android WebView must report the actual animation names loaded
        // from the packaged GLB before the test sends face/speech commands.
        await _waitForHeroFaceAnimations(tester);
        await _exerciseHeroFaceAnimations(tester);

        final audioHeaderButton = _semanticButton('مركز الصوت');
        final profileHeaderButton = _semanticButton('الملف الشخصي');

        expect(audioHeaderButton, findsOneWidget);
        expect(profileHeaderButton, findsOneWidget);

        // Header audio button opens the audio center.
        await tester.tap(audioHeaderButton.hitTestable().first);

        await _pumpUntilFound(
          tester,
          find.byType(AudioCenterWithHeader),
          description: 'Audio center opened from the home header',
        );

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 400,
        );

        // Header profile button selects the Profile main tab. Wait for the
        // PageController animation as well as the selected semantics flag.
        final currentProfileButton = _semanticButton('الملف الشخصي');

        await _pumpUntilHitTestable(
          tester,
          currentProfileButton,
          description: 'Profile button in the home header',
        );

        await tester.tap(currentProfileButton.hitTestable().first);

        await _waitForMainTabSelected(
          tester,
          'حسابي',
        );

        await _pumpUntilFound(
          tester,
          find.byType(ProfileScreen),
          description: 'Profile screen after the header PageView transition',
        );
        expect(find.byType(ProfileScreen), findsOneWidget);

        await _tapMainTab(tester, 'الرئيسية');

        // Test actual horizontal PageView navigation, not only tab taps.
        await _swipeToMainTab(tester, 'الشات');

        // ------------------------------------------------------------
        // Chat tab and Connect navigation.
        // ------------------------------------------------------------

        await _pumpUntilFound(
          tester,
          find.byType(ChatTabScreen),
          description: 'Chat tab',
        );

        expect(find.byType(AppHeader), findsOneWidget);
        expect(find.text('المحادثات'), findsOneWidget);
        expect(find.text('صاحبي Connect'), findsOneWidget);
        expect(find.text('فضفضة مع صاحبي'), findsOneWidget);
        expect(
          find.text('للتواصل مع الأشخاص الحقيقيين'),
          findsOneWidget,
        );
        expect(
          find.text('محادثتك الشخصية مع الذكاء الاصطناعي'),
          findsOneWidget,
        );

        // Connect uses the app's existing guest session.
        await _tapText(
          tester,
          'افتح صاحبي Connect',
          maxPumps: 60,
        );

        await _pumpUntilFound(
          tester,
          find.byType(SocialConnectHubScreen),
          description: 'Sa7bi Connect home',
          maxPumps: 120,
        );

        expect(find.text('صاحبي HERO'), findsOneWidget);
        expect(find.text('المحادثات والأصدقاء'), findsOneWidget);
        expect(find.text('المجموعات العامة'), findsOneWidget);

        // Open the private conversations list. This is read-only.
        await _tapText(tester, 'افتح المحادثات');

        await _pumpUntilFound(
          tester,
          find.byType(SocialConnectionsScreen),
          description: 'Private conversations and invitations screen',
        );

        expect(tester.takeException(), isNull);

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        // Open the public/private groups workspace.
        await _tapText(tester, 'استكشف المجموعات');

        await _pumpUntilFound(
          tester,
          find.byType(SocialGroupsWorkspaceScreen),
          description: 'Public and private groups workspace',
        );

        expect(find.text('المجموعات العامة'), findsOneWidget);
        expect(find.text('مجموعاتي الخاصة'), findsOneWidget);

        // Open public groups. No group is created or joined.
        await _tapText(tester, 'المجموعات العامة');

        await _pumpUntilFound(
          tester,
          find.byType(SocialGroupsScreen),
          description: 'Public groups screen',
        );

        expect(tester.takeException(), isNull);

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        // Open private groups. No group is created or joined.
        await _tapText(tester, 'مجموعاتي الخاصة');

        await _pumpUntilFound(
          tester,
          find.byType(SocialPrivateGroupsScreen),
          description: 'Private groups screen',
        );

        expect(tester.takeException(), isNull);

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        // Return from workspace to Connect and then to Chat.
        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        expect(find.byType(ChatTabScreen), findsOneWidget);

        // ------------------------------------------------------------
        // Games: local games and online game lobbies.
        // ------------------------------------------------------------

        await _tapMainTab(tester, 'الألعاب');

        await _pumpUntilFound(
          tester,
          find.byType(InteractiveExperiencesScreen),
          description: 'Games tab',
        );

        expect(
          find.text('ألعاب بدون إنترنت'),
          findsOneWidget,
        );

        // Local games hub.
        await _tapText(tester, 'ألعاب بدون إنترنت');

        await _pumpUntilFound(
          tester,
          find.byType(LocalGamesHubScreen),
          description: 'Local games hub',
        );

        expect(tester.takeException(), isNull);

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        // Local chess, XO and Rock-Paper-Scissors hub.
        await _tapText(
          tester,
          'الشطرنج وXO وحجر ورقة مقص',
        );

        await _pumpUntilFound(
          tester,
          find.byType(LocalBoardGamesScreen),
          description: 'Local board games screen',
        );

        expect(tester.takeException(), isNull);

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        // Wait for the online guest session check to finish.
        const checkingOnlineText = 'جاري تجهيز حساب اللعب...';
        const onlineUnavailableText =
            'الألعاب الجماعية تحتاج اتصالًا بالإنترنت. '
            'الألعاب المحلية تعمل بدون اتصال.';

        for (var attempt = 0;
            attempt < 120 &&
                find.text(checkingOnlineText).evaluate().isNotEmpty;
            attempt++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        expect(
          find.text(checkingOnlineText),
          findsNothing,
          reason: 'Online guest session initialization did not finish.',
        );

        expect(
          find.text(onlineUnavailableText),
          findsNothing,
          reason:
              'The online games session is not ready. Check the live Worker and guest-session endpoints.',
        );

        // Open the online multiplayer lobby without creating a match.
        await _tapText(tester, 'العب مع أصحابك');

        await _pumpUntilFound(
          tester,
          find.byType(SocialGamesHubScreen),
          description: 'Online multiplayer games lobby',
          maxPumps: 120,
        );

        await _pumpUntilFound(
          tester,
          find.text('اختار لعبتك'),
          description: 'Online multiplayer game choices',
          maxPumps: 120,
        );

        expect(find.text('إكس أو'), findsOneWidget);
        expect(find.text('الشطرنج'), findsOneWidget);

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        // Open AI games lobby without creating a match.
        await _tapText(tester, 'العب ضد صاحبي AI');

        await _pumpUntilFound(
          tester,
          find.byType(SocialAiGamesScreen),
          description: 'AI games lobby',
          maxPumps: 120,
        );

        await _pumpUntilFound(
          tester,
          find.text('اختار اللعبة'),
          description: 'AI game choices',
          maxPumps: 120,
        );

        expect(tester.takeException(), isNull);

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        // ------------------------------------------------------------
        // Profile, settings, founder page and Android back behavior.
        // ------------------------------------------------------------

        await _tapMainTab(tester, 'حسابي');

        await _pumpUntilFound(
          tester,
          find.byType(ProfileScreen),
          description: 'Profile screen',
        );

        expect(find.byType(AppHeader), findsOneWidget);

        final settingsTile = find.text('الإعدادات');

        await tester.ensureVisible(settingsTile);

        await _pumpUntilHitTestable(
          tester,
          settingsTile,
          description: 'Profile settings tile',
        );

        await tester.tap(settingsTile.hitTestable().first);

        await _pumpUntilFound(
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

        await _pumpUntilFound(
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

        // Pop the founder screen and Settings screen.
        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        await _pressAndroidBack(
          tester,
          settleMilliseconds: 350,
        );

        // Simulate the Android system Back button from the Profile tab.
        // The app must return to Home instead of closing.
        await _pressAndroidBack(tester);

        await _waitForMainTabSelected(
          tester,
          'الرئيسية',
        );

        expect(find.byType(Sa7biHeroLitePanel), findsOneWidget);
        expect(find.byType(Sa7biHero3D), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Test the Home pull-to-refresh gesture.
        final homeRefresh = find.byType(RefreshIndicator);

        expect(homeRefresh, findsOneWidget);

        await tester.drag(
          homeRefresh,
          const Offset(0, 420),
        );

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);

        // ------------------------------------------------------------
        // App diagnostics.
        // ------------------------------------------------------------

        final diagnosticsButton =
            find.byTooltip('تشخيص التطبيق');

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

        await tester.tap(
          diagnosticsButton.first.hitTestable().first,
        );

        await _pumpUntilFound(
          tester,
          find.byType(AppDiagnosticsScreen),
          description: 'Diagnostics screen',
        );

        await _pumpUntilFound(
          tester,
          find.text('فحص تلقائي سريع'),
          description: 'Automatic quick diagnostics section',
        );

        await _pumpUntilFound(
          tester,
          find.byKey(
            const ValueKey<String>('automatic-quick-check'),
          ),
          description: 'Automatic quick diagnostics heading',
        );

        expect(
          find.textContaining('فحص صاحبي AI الشامل v5'),
          findsOneWidget,
        );

        await _pumpUntilFound(
          tester,
          find.text('Build/source metadata'),
          description: 'Build/source metadata',
        );

        expect(tester.takeException(), isNull);

        // Do not start full diagnostics in this UI smoke test.
        await _pressAndroidBack(
          tester,
          settleMilliseconds: 400,
        );

        await _waitForMainTabSelected(
          tester,
          'الرئيسية',
        );

        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

Future<void> _waitForHeroFaceAnimations(
  WidgetTester tester,
) async {
  final runtime = HeroFaceRuntime.instance;
  const requiredBodyAnimations = <String>{
    'Hero_Idle',
    'Hero_Welcome',
    'Hero_Power',
  };

  for (var attempt = 0; attempt < 120; attempt++) {
    final animations = runtime.availableAnimations.value;
    if (runtime.isFaceRigAvailable &&
        animations.containsAll(requiredBodyAnimations)) {
      return;
    }

    await tester.pump(const Duration(milliseconds: 200));
  }

  final available = runtime.availableAnimations.value.toList()..sort();
  final missingFace = runtime.missingRequiredAnimations.toList()..sort();
  final missingBody =
      requiredBodyAnimations.difference(runtime.availableAnimations.value).toList()
        ..sort();

  fail(
    'HERO Android WebView did not report the complete GLB animation set. '
    'Missing face animations: $missingFace. '
    'Missing body animations: $missingBody. '
    'Animations reported by model-viewer: $available',
  );
}

Future<void> _exerciseHeroFaceAnimations(
  WidgetTester tester,
) async {
  final runtime = HeroFaceRuntime.instance;
  final initialRevision = runtime.lastCommand?.revision ?? 0;

  runtime.playExpression(HeroExpression.smile);
  final expressionCommand = runtime.lastCommand;

  expect(expressionCommand, isNotNull);
  expect(expressionCommand!.type, HeroFaceCommandType.expression);
  expect(expressionCommand.animationName, 'HERO_FACE_SMILE');
  expect(
    runtime.availableAnimations.value,
    contains('HERO_FACE_SMILE'),
  );
  expect(runtime.liteStatus.value.expression, HeroExpression.smile);

  await tester.pump(const Duration(milliseconds: 150));

  // Simulate the word-boundary callbacks supplied by Flutter TTS.
  runtime.onSpeechStarted();
  runtime.onSpeechWord('مرحبا');

  final visemeCommand = runtime.lastCommand;
  expect(visemeCommand, isNotNull);
  expect(visemeCommand!.type, HeroFaceCommandType.viseme);
  expect(visemeCommand.animationName, 'HERO_VISEME_PP');
  expect(
    runtime.availableAnimations.value,
    contains('HERO_VISEME_PP'),
  );
  expect(runtime.liteStatus.value.isSpeaking, isTrue);
  expect(runtime.liteStatus.value.activeWord, 'مرحبا');
  expect(runtime.liteStatus.value.activeViseme, 'PP');

  await tester.pump(const Duration(milliseconds: 150));

  runtime.onSpeechFinished();

  expect(runtime.liteStatus.value.isSpeaking, isFalse);
  expect(runtime.liteStatus.value.activeWord, isEmpty);
  expect(runtime.liteStatus.value.activeViseme, 'sil');
  expect(runtime.liteStatus.value.expression, HeroExpression.neutral);
  expect(runtime.lastCommand?.type, HeroFaceCommandType.reset);
  expect(
    runtime.lastCommand!.revision,
    greaterThan(initialRevision),
  );
  expect(
    tester.takeException(),
    isNull,
    reason: 'HERO expression and speech callbacks must not throw.',
  );
}

Future<void> _pressAndroidBack(
  WidgetTester tester, {
  int settleMilliseconds = 400,
}) async {
  // Simulate Android's system Back event without requiring a Cupertino back button.
  await tester.binding.handlePopRoute();
  await tester.pump(
    Duration(milliseconds: settleMilliseconds),
  );
}

Finder _semanticButton(String label) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is! Semantics) return false;

      return widget.properties.label == label &&
          widget.properties.button == true;
    },
    description: 'Semantic button: $label',
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

bool _isMainTabSelected(
  WidgetTester tester,
  String label,
) {
  final button = _mainTabButton(label);

  if (button.evaluate().isEmpty) {
    return false;
  }

  final selectedState = tester
      .getSemantics(button.first)
      .getSemanticsData()
      .flagsCollection
      .isSelected;

  return selectedState == Tristate.isTrue;
}

Finder _mainPageViewFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is PageView &&
        widget.scrollDirection == Axis.horizontal &&
        widget.children.length == 4 &&
        widget.children.every(
          (child) => child.runtimeType.toString() == '_KeepAliveMainPage',
        ),
    description: 'The four-tab main PageView',
  );
}

int _mainTabIndex(String label) {
  switch (label) {
    case 'الرئيسية':
      return 0;
    case 'الشات':
      return 1;
    case 'الألعاب':
      return 2;
    case 'حسابي':
      return 3;
    default:
      throw ArgumentError.value(label, 'label', 'Unknown main tab');
  }
}

double? _mainPagePosition(WidgetTester tester) {
  final finder = _mainPageViewFinder();
  if (finder.evaluate().length != 1) return null;

  final controller = tester.widget<PageView>(finder.first).controller;
  if (controller == null || !controller.hasClients) return null;

  try {
    return controller.page;
  } catch (_) {
    return null;
  }
}

bool _isMainPageSettled(WidgetTester tester, String label) {
  if (!_isMainTabSelected(tester, label)) return false;

  final page = _mainPagePosition(tester);
  return page != null && (page - _mainTabIndex(label)).abs() < 0.02;
}

Future<void> _waitForMainTabSelected(
  WidgetTester tester,
  String label, {
  int maxPumps = 80,
}) async {
  for (var attempt = 0; attempt < maxPumps; attempt++) {
    if (_isMainPageSettled(tester, label)) {
      return;
    }

    await tester.pump(const Duration(milliseconds: 50));
  }

  expect(
    _isMainTabSelected(tester, label),
    isTrue,
    reason: 'The "$label" tab did not become selected.',
  );
  final page = _mainPagePosition(tester);
  expect(
    page,
    isNotNull,
    reason: 'The main PageView controller is not attached.',
  );
  expect(
    (page! - _mainTabIndex(label)).abs(),
    lessThan(0.02),
    reason:
        'The "$label" tab was selected before its PageView animation finished. '
        'Actual page position: $page',
  );
}

Future<void> _swipeToMainTab(
  WidgetTester tester,
  String label,
) async {
  final pageView = _mainPageViewFinder();
  expect(pageView, findsOneWidget);

  final topLeft = tester.getTopLeft(pageView);
  final size = tester.getSize(pageView);
  final edgeInset = size.width * 0.025;
  final startY = topLeft.dy + size.height * 0.16;

  // Start at the page edge, not in the central HERO WebView. This keeps
  // the horizontal gesture in the Flutter PageView gesture arena.
  final swipeDirections = <Offset>[
    Offset(size.width * 0.72, 0),
    Offset(-size.width * 0.72, 0),
  ];

  for (final direction in swipeDirections) {
    final start = Offset(
      direction.dx > 0
          ? topLeft.dx + edgeInset
          : topLeft.dx + size.width - edgeInset,
      startY,
    );

    await tester.dragFrom(
      start,
      direction,
      duration: const Duration(milliseconds: 350),
    );

    for (var attempt = 0; attempt < 50; attempt++) {
      if (_isMainPageSettled(tester, label)) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  await _waitForMainTabSelected(
    tester,
    label,
    maxPumps: 20,
  );

  expect(
    _isMainPageSettled(tester, label),
    isTrue,
    reason: 'Horizontal swipe did not settle on "$label".',
  );
}

Future<void> _tapMainTab(
  WidgetTester tester,
  String label,
) async {
  final button = _mainTabButton(label);

  expect(button, findsOneWidget);

  await _pumpUntilHitTestable(
    tester,
    button,
    description: 'Main navigation button: $label',
  );

  await tester.tap(button.hitTestable().first);

  await _waitForMainTabSelected(
    tester,
    label,
  );

  expect(
    tester.takeException(),
    isNull,
    reason: 'Opening "$label" must not throw a Flutter UI exception.',
  );
}

Future<void> _tapText(
  WidgetTester tester,
  String label, {
  int maxPumps = 40,
}) async {
  final finder = find.text(label);

  await tester.ensureVisible(finder);

  await _pumpUntilHitTestable(
    tester,
    finder,
    description: 'Text action: $label',
    maxPumps: maxPumps,
  );

  await tester.tap(finder.hitTestable().first);
}

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
    reason:
        '$description did not appear after waiting for async UI updates.',
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
    reason: '$description did not become hit-testable.',
  );
}
