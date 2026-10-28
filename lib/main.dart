
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_diagnostics_screen.dart';
import 'audio_center_screen.dart';
import 'audio_player_service.dart';
import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'home_screen.dart';
import 'interactive_experiences_screen.dart';
import 'khalasana_portal_screen.dart';
import 'profile_screen.dart';
import 'services/ads_service.dart';
import 'services/ai_request_service.dart';
import 'services/credits_service.dart';
import 'services/profile_service.dart';
import 'services/sa7bi_network_client.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/khalasana_portal.dart';

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
      debugShowCheckedModeBanner: false,
      title: 'صاحبي AI',
      theme: Sa7biTheme.dark(),
      routes: {
        '/diagnostics': (_) => const AppDiagnosticsScreen(),
      },
      home: const MainContainerScreen(),
    );
  }
}

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  // 0 الرئيسية، 1 الشات، 2 الألعاب، 3 حسابي.
  int index = 0;

  final GlobalKey<HomeScreenState> _homeKey =
      GlobalKey<HomeScreenState>();

  void openProfile() {
    if (!mounted) return;
    setState(() => index = 3);
  }

  void openAudioCenter() {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AudioCenterScreen(),
      ),
    );
  }

  void openKhalasana() {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KhalasanaPortalScreen(),
      ),
    );
  }

  void openDiagnostics() {
    if (!mounted) return;
    Navigator.of(context).pushNamed('/diagnostics');
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        key: _homeKey,
        onProfile: openProfile,
        onAudio: openAudioCenter,
      ),
      const ChatScreen(
        serviceKey: ServiceKeys.general,
        serviceTitle: 'المحادثة العامة',
        serviceContext:
            'أنت صاحبي AI، مساعد عربي عام. أجب بوضوح وبشكل مفيد، '
            'وحافظ على سياق المحادثة العامة.',
      ),
      const InteractiveExperiencesScreen(),
      ProfileScreen(
        onAudio: openAudioCenter,
      ),
    ];

    final isChatTab = index == 1;

    return Scaffold(
      backgroundColor: Sa7biTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: index,
              children: pages,
            ),

            // مشغل الصوت مخفي في الشات حتى لا يغطي مربع الكتابة.
            if (!isChatTab)
              const Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: MiniAudioPlayer(),
              ),

            // زر التشخيص لا يظهر فوق مربع كتابة الشات.
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

            // روبوت خلصانة العائم متاح في كل التبويبات.
            Positioned(
              right: 8,
              bottom: isChatTab ? 100 : 76,
              child: KhalasanaPortal(
                onTap: openKhalasana,
              ),
            ),
          ],
        ),
      ),
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
            // الضغط على الرئيسية مرة أخرى يطلب تحديث الأخبار.
            if (value == 0) {
              unawaited(_homeKey.currentState?.refreshNews());
            }
            return;
          }

          setState(() => index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, size: 20),
            selectedIcon: Icon(Icons.home_rounded, size: 21),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded, size: 20),
            selectedIcon: Icon(Icons.chat_rounded, size: 21),
            label: 'الشات',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined, size: 20),
            selectedIcon: Icon(Icons.sports_esports_rounded, size: 21),
            label: 'الألعاب',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, size: 20),
            selectedIcon: Icon(Icons.person_rounded, size: 21),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({super.key});

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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AudioCenterScreen(),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AudioCenterScreen(),
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
