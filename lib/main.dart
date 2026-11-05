import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_diagnostics_screen.dart';
import 'audio_player_service.dart';
import 'chat_tab_screen.dart';
import 'home_screen.dart';
import 'interactive_experiences_screen.dart';
import 'khalasana_portal_screen.dart';
import 'profile_screen.dart';
import 'services/ads_service.dart';
import 'services/ai_request_service.dart';
import 'services/credits_service.dart';
import 'services/profile_service.dart';
import 'services/sa7bi_network_client.dart';
import 'social_community_hub_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/audio_center_with_header.dart';
import 'widgets/khalasana_portal.dart';
import 'widgets/social_invite_link_listener.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>();

final _Sa7biNavigationObserver _sa7biNavigationObserver =
    _Sa7biNavigationObserver();

void main() {
  http.runWithClient(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      runApp(const Sa7biAiApp());

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_initializeApplicationServices()),
      );
    },
    Sa7biNetworkClient.factory,
  );
}

Future<void> _initializeApplicationServices() async {
  try {
    await CreditsService.instance.initialize();
  } catch (_) {}

  try {
    final backend = await AiRequestService.checkBackend();

    if (backend.isAvailable) {
      await ProfileService.instance.markAiConnected();
    } else {
      await ProfileService.instance.markAiDisconnected();
    }
  } catch (_) {
    try {
      await ProfileService.instance.markAiDisconnected();
    } catch (_) {}
  }

  try {
    await AudioController.initialize();
  } catch (_) {}

  try {
    final ads = AdsService.instance;
    await ads.initialize();

    if (ads.isAdMobInitialized) {
      unawaited(ads.loadInterstitial());
      unawaited(ads.loadRewarded());
    }
  } catch (_) {}
}

class Sa7biAiApp extends StatelessWidget {
  const Sa7biAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _rootNavigatorKey,
      navigatorObservers: <NavigatorObserver>[
        _sa7biNavigationObserver,
      ],
      debugShowCheckedModeBanner: false,
      title: 'صاحبي AI',
      theme: Sa7biTheme.dark(),
      routes: {
        '/diagnostics': (_) => const AppDiagnosticsScreen(),
      },
      builder: (context, child) {
        return ValueListenableBuilder<_Sa7biRouteSnapshot>(
          valueListenable: _sa7biNavigationObserver.snapshot,
          builder: (context, route, _) {
            final keyboardIsOpen =
                MediaQuery.viewInsetsOf(context).bottom > 0;

            final hidePortal = route.isPopup ||
                route.routeName == '/khalasana' ||
                keyboardIsOpen;

            // على الصفحة الرئيسية نرفع الروبوت فوق المشغل والشريط السفلي.
            // داخل الصفحات الداخلية نقرّبه للأسفل حتى لا يحجب محتوى الشاشة.
            final bottomOffset = route.depth <= 1 ? 146.0 : 82.0;

            return Stack(
              fit: StackFit.expand,
              children: [
                if (child != null) child,
                if (!hidePortal)
                  Positioned(
                    right: 8,
                    bottom: MediaQuery.viewPaddingOf(context).bottom +
                        bottomOffset,
                    child: KhalasanaPortal(
                      onTap: _openGlobalKhalasana,
                    ),
                  ),
              ],
            );
          },
        );
      },
      home: const SocialInviteLinkListener(
        child: MainContainerScreen(),
      ),
    );
  }
}

void _openGlobalKhalasana() {
  final navigator = _rootNavigatorKey.currentState;
  if (navigator == null) return;

  navigator.push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/khalasana'),
      builder: (_) => const KhalasanaPortalScreen(),
    ),
  );
}

class _Sa7biRouteSnapshot {
  const _Sa7biRouteSnapshot({
    required this.depth,
    required this.activeRoute,
  });

  final int depth;
  final Route<dynamic>? activeRoute;

  String? get routeName => activeRoute?.settings.name;

  bool get isPopup => activeRoute is PopupRoute<dynamic>;
}

class _Sa7biNavigationObserver extends NavigatorObserver {
  int _depth = 0;

  final ValueNotifier<_Sa7biRouteSnapshot> snapshot =
      ValueNotifier<_Sa7biRouteSnapshot>(
    const _Sa7biRouteSnapshot(
      depth: 0,
      activeRoute: null,
    ),
  );

  void _publish(Route<dynamic>? route) {
    snapshot.value = _Sa7biRouteSnapshot(
      depth: _depth,
      activeRoute: route,
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _depth++;
    _publish(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_depth > 1) _depth--;
    _publish(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);

    if (_depth > 1) _depth--;

    final activeRoute = snapshot.value.activeRoute;
    _publish(activeRoute == route ? previousRoute : activeRoute);
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);

    if (oldRoute == snapshot.value.activeRoute) {
      _publish(newRoute);
    }
  }
}

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() =>
      _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  // 0 الرئيسية، 1 الشات، 2 الألعاب، 3 حسابي.
  int index = 0;
  late final PageController _pageController = PageController(initialPage: index);

  final GlobalKey<HomeScreenState> _homeKey =
      GlobalKey<HomeScreenState>();

  void _goToPage(int value) {
    if (!mounted || value < 0 || value > 3) return;

    if (value == index) return;

    setState(() => index = value);

    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          value,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void openProfile() {
    _goToPage(3);
  }

  void openAudioCenter() {
    if (!mounted) return;

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudioCenterWithHeader(
          onProfileTap: openProfile,
        ),
      ),
    );
  }

  void openDiagnostics() {
    if (!mounted) return;
    Navigator.of(context).pushNamed('/diagnostics');
  }

  void openSocialConnections() {
    if (!mounted) return;

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialCommunityHubScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        key: _homeKey,
        onProfile: openProfile,
        onAudio: openAudioCenter,
      ),
      const ChatTabScreen(),
      const InteractiveExperiencesScreen(),
      ProfileScreen(
        onProfileTap: openProfile,
        onAudio: openAudioCenter,
      ),
    ];

    final isChatTab = index == 1;

    return Scaffold(
      backgroundColor: Sa7biTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              onPageChanged: (value) {
                if (!mounted || index == value) return;
                setState(() => index = value);
              },
              children: [
                for (final page in pages) _KeepAliveMainPage(child: page),
              ],
            ),

            // مشغل الصوت مخفي في الشات حتى لا يغطي الرسائل.
            if (!isChatTab)
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: MiniAudioPlayer(
                  onProfileTap: openProfile,
                ),
              ),

            // زر التشخيص لا يظهر فوق محتوى الشات.
            if (!isChatTab)
              Positioned(
                left: 12,
                bottom: 78,
                child: Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: 'تشخيص التطبيق',
                    child: InkWell(
                      onTap: openDiagnostics,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Sa7biTheme.surface.withValues(
                            alpha: 0.96,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Sa7biTheme.border,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.health_and_safety_outlined,
                          color: Sa7biTheme.cyan,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // اختصار مركز التواصل يظهر داخل تبويب الألعاب.
            if (index == 2)
              Positioned(
                right: 10,
                bottom: 130,
                child: Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message:
                        'الرسائل والمجموعات واللعب مع الذكاء الاصطناعي',
                    child: InkWell(
                      onTap: openSocialConnections,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Sa7biTheme.surface.withValues(
                            alpha: 0.98,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Sa7biTheme.border,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Sa7biTheme.cyan,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),

      // الشريط السفلي: أربع تبويبات صغيرة كما اتفقنا.
      bottomNavigationBar: NavigationBar(
        height: 60,
        backgroundColor: Sa7biTheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Sa7biTheme.cyan.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: index,
        onDestinationSelected: (value) {
          if (!mounted) return;

          if (value == index) {
            // الضغط على الرئيسية مرة أخرى يحدّث الأخبار.
            if (value == 0) {
              unawaited(_homeKey.currentState?.refreshNews());
            }
            return;
          }

          _goToPage(value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 20),
            selectedIcon: Icon(Icons.home_rounded, size: 21),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
            ),
            selectedIcon: Icon(Icons.chat_rounded, size: 21),
            label: 'الشات',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.sports_esports_outlined,
              size: 20,
            ),
            selectedIcon: Icon(
              Icons.sports_esports_rounded,
              size: 21,
            ),
            label: 'الألعاب',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
              size: 20,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
              size: 21,
            ),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class _KeepAliveMainPage extends StatefulWidget {
  const _KeepAliveMainPage({required this.child});

  final Widget child;

  @override
  State<_KeepAliveMainPage> createState() => _KeepAliveMainPageState();
}

class _KeepAliveMainPageState extends State<_KeepAliveMainPage>
    with AutomaticKeepAliveClientMixin<_KeepAliveMainPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class MiniAudioPlayer extends StatelessWidget {
  final VoidCallback onProfileTap;

  const MiniAudioPlayer({
    super.key,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: AudioController.handler?.mediaItem,
      builder: (context, mediaSnapshot) {
        final item = mediaSnapshot.data;
        if (item == null) return const SizedBox.shrink();

        final handler = AudioController.handler;
        if (handler == null) return const SizedBox.shrink();

        return Material(
          color: Colors.transparent,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: Sa7biTheme.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Sa7biTheme.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 19,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => AudioCenterWithHeader(
                        onProfileTap: onProfileTap,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Sa7biTheme.brandGradient,
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Color(0xFF08111C),
                      size: 21,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => AudioCenterWithHeader(
                          onProfileTap: onProfileTap,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.title,
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Sa7biTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          item.artist ?? 'صاحبي AI',
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Sa7biTheme.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                StreamBuilder<PlaybackState>(
                  stream: handler.playbackState,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;

                    return IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 38,
                        minHeight: 38,
                      ),
                      onPressed: () {
                        if (playing) {
                          handler.pause();
                        } else {
                          handler.play();
                        }
                      },
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Sa7biTheme.cyan,
                        size: 25,
                      ),
                    );
                  },
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 38,
                  ),
                  onPressed: () => handler.stop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Sa7biTheme.textSecondary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
