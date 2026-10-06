import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_diagnostics_screen.dart';
import 'audio_center_screen.dart';
import 'audio_player_service.dart';
import 'home_screen.dart';
import 'khalasana_portal_screen.dart';
import 'profile_screen.dart';
import 'services/ads_service.dart';
import 'services/ai_request_service.dart';
import 'services/credits_service.dart';
import 'services/profile_service.dart';
import 'services/sa7bi_network_client.dart';
import 'widgets/khalasana_portal.dart';

void main() {
  // ============================================================
  // UNIFIED NETWORK TRANSPORT
  // ============================================================
  //
  // كل package:http top-level request داخل التطبيق:
  //
  // http.get(...)
  // http.post(...)
  // http.put(...)
  // http.delete(...)
  // Client()
  //
  // يستخدم العميل الموحد هنا.
  //
  // Android -> Cronet
  // Other platforms -> IO fallback
  //
  // مهم:
  // runWithClient يجب أن يحيط بـrunApp حتى تكون Zone
  // الخاصة بـpackage:http هي Zone التطبيق الأساسية.
  http.runWithClient(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      runApp(const Sa7biAiApp());

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          unawaited(
            _initializeApplicationServices(),
          );
        },
      );
    },
    Sa7biNetworkClient.factory,
  );
}

Future<void> _initializeApplicationServices() async {
  // ============================================================
  // CREDITS
  // ============================================================

  try {
    await CreditsService.instance.initialize();
  } catch (_) {
    // فشل Credits لا يمنع التطبيق من العمل.
  }

  // ============================================================
  // AI BACKEND CONNECTION
  // ============================================================

  try {
    final backend =
        await AiRequestService.checkBackend();

    if (backend.isAvailable) {
      await ProfileService.instance
          .markAiConnected();
    } else {
      await ProfileService.instance
          .markAiDisconnected();
    }
  } catch (_) {
    try {
      await ProfileService.instance
          .markAiDisconnected();
    } catch (_) {
      // لا شيء.
    }
  }

  // ============================================================
  // AUDIO
  // ============================================================

  try {
    await AudioController.initialize();
  } catch (_) {
    // الصوت لا يمنع باقي التطبيق من العمل.
  }

  // ============================================================
  // ADMOB
  // ============================================================

  try {
    final ads = AdsService.instance;

    await ads.initialize();

    if (ads.isAdMobInitialized) {
      unawaited(
        ads.loadInterstitial(),
      );

      unawaited(
        ads.loadRewarded(),
      );
    }
  } catch (_) {
    // فشل الإعلانات لا يمنع التطبيق من العمل.
  }
}

// ============================================================
// APP
// ============================================================

class Sa7biAiApp extends StatelessWidget {
  const Sa7biAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صاحبي AI',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            const Color(0xFF070A12),
        colorScheme:
            ColorScheme.fromSeed(
          seedColor:
              const Color(0xFFFFD76A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'sans',
      ),

      routes: {
        '/diagnostics': (_) =>
            const AppDiagnosticsScreen(),
      },

      home:
          const MainContainerScreen(),
    );
  }
}

// ============================================================
// MAIN CONTAINER
// ============================================================

class MainContainerScreen
    extends StatefulWidget {
  const MainContainerScreen({
    super.key,
  });

  @override
  State<MainContainerScreen>
      createState() =>
          _MainContainerScreenState();
}

class _MainContainerScreenState
    extends State<MainContainerScreen> {
  // 0 = Home, 1 = Profile.
  int index = 0;

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  void openProfile() {
    if (!mounted) {
      return;
    }

    setState(() {
      index = 1;
    });
  }

  void openAudioCenter() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const AudioCenterScreen(),
      ),
    );
  }

  void openKhalasana() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const KhalasanaPortalScreen(),
      ),
    );
  }

  void openDiagnostics() {
    if (!mounted) {
      return;
    }

    Navigator.of(context)
        .pushNamed('/diagnostics');
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        onProfile: openProfile,
        onAudio: openAudioCenter,
      ),
      ProfileScreen(
        onAudio: openAudioCenter,
      ),
    ];

    return Scaffold(
      backgroundColor:
          const Color(0xFF070A12),
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: index,
              children: pages,
            ),

            const Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: MiniAudioPlayer(),
            ),

            // ==================================================
            // DIAGNOSTICS ENTRY
            // ==================================================

            Positioned(
              left: 12,
              bottom: 92,
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'تشخيص التطبيق',
                  child: InkWell(
                    onTap: openDiagnostics,
                    borderRadius:
                        BorderRadius.circular(24),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration:
                          BoxDecoration(
                        color: const Color(
                          0xFF11141D,
                        ).withOpacity(0.96),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              const Color(
                            0x55FFD76A,
                          ),
                        ),
                        boxShadow:
                            const [
                          BoxShadow(
                            color:
                                Color(0x55000000),
                            blurRadius: 12,
                            offset:
                                Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons
                            .health_and_safety_outlined,
                        color:
                            Color(0xFFFFD76A),
                        size: 23,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              right: 12,
              bottom: 92,
              child: KhalasanaPortal(
                onTap: openKhalasana,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          NavigationBar(
        backgroundColor:
            const Color(0xFF11141D),
        indicatorColor:
            const Color(0x3348D8FF),
        selectedIndex: index,
        onDestinationSelected:
            (value) {
          if (!mounted) {
            return;
          }

          setState(() {
            index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_rounded,
            ),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline_rounded,
            ),
            selectedIcon: Icon(
              Icons.person_rounded,
            ),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MINI AUDIO PLAYER
// ============================================================

class MiniAudioPlayer
    extends StatelessWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream:
          AudioController.handler?.mediaItem,
      builder:
          (context, mediaSnapshot) {
        final item =
            mediaSnapshot.data;

        if (item == null) {
          return const SizedBox.shrink();
        }

        final handler =
            AudioController.handler;

        if (handler == null) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            height: 62,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 7,
            ),
            decoration:
                BoxDecoration(
              color: const Color(
                0xFF121720,
              ).withOpacity(0.98),
              borderRadius:
                  BorderRadius.circular(19),
              border: Border.all(
                color:
                    const Color(0x55FFD76A),
              ),
              boxShadow: const [
                BoxShadow(
                  color:
                      Color(0x66000000),
                  blurRadius: 19,
                  offset:
                      Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context)
                        .push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const AudioCenterScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration:
                        const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient:
                          LinearGradient(
                        colors: [
                          Color(0xFFFFD76A),
                          Color(0xFF7164FF),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .graphic_eq_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context)
                          .push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const AudioCenterScreen(),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .end,
                      children: [
                        Text(
                          item.title,
                          textDirection:
                              TextDirection.rtl,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          item.artist ??
                              'صاحبي AI',
                          textDirection:
                              TextDirection.rtl,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white54,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                StreamBuilder<
                    PlaybackState>(
                  stream:
                      handler.playbackState,
                  builder:
                      (context, snapshot) {
                    final playing =
                        snapshot.data
                                ?.playing ??
                            false;

                    return IconButton(
                      padding:
                          EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
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
                            ? Icons
                                .pause_rounded
                            : Icons
                                .play_arrow_rounded,
                        color:
                            const Color(
                          0xFFFFD76A,
                        ),
                        size: 27,
                      ),
                    );
                  },
                ),

                IconButton(
                  padding:
                      EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(
                    minWidth: 34,
                    minHeight: 40,
                  ),
                  onPressed: () {
                    handler.stop();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color:
                        Colors.white54,
                    size: 19,
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
