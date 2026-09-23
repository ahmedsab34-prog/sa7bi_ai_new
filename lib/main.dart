import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'audio_center_screen.dart';
import 'audio_player_service.dart';
import 'categories_screen.dart';
import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'widgets/khalasana_portal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // مهم:
  // لا ننتظر AudioService أو AdMob أو أي خدمة خارجية
  // قبل أول Frame.
  //
  // AudioService يظل Lazy ويُهيأ عند استخدام الصوت.
  runApp(const Sa7biAiApp());
}

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD76A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainContainerScreen(),
    );
  }
}

// ============================================================
// MAIN CONTAINER
// ============================================================

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() =>
      _MainContainerScreenState();
}

class _MainContainerScreenState
    extends State<MainContainerScreen> {
  int index = 0;

  void openProfile() {
    setState(() {
      index = 2;
    });
  }

  // ==========================================================
  // KHALASANA
  // ==========================================================
  //
  // خلصانة تفتح الشات مباشرة.
  // لا توجد شاشة وسيطة ولا انتظار للبوابة.
  //

  void openKhalasana() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatScreen(
          serviceKey: ServiceKeys.khalasana,
          serviceTitle: 'خلصانة AI',
          serviceContext: '''
أنت خلصانة AI، المساعد الشامل داخل تطبيق صاحبي.

ساعد المستخدم مباشرة في أي موضوع بدون إجباره على اختيار قسم.
يمكنه الكتابة، إرسال صورة أو فيديو، استخدام الصوت، أو طلب إنشاء صورة.

إذا أرسل المستخدم صورة، حللها بقدر ما تسمح به الصورة ولا تخمن الأشياء غير الواضحة.
إذا طلب إنشاء صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.
إذا كان الموضوع مرتبطًا بخدمة أو مجال محدد، استخدم أفضل سياق مناسب تلقائيًا.
كن واضحًا ومفيدًا ومباشرًا.
لا تدّعي تنفيذ شيء لم يتم تنفيذه فعليًا.
إذا فشلت خدمة فعلية، وضح ذلك وقدم بديلًا مفيدًا.
''',
        ),
      ),
    );
  }

  void openAudioCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AudioCenterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onProfile: openProfile,
        onAudio: openAudioCenter,
      ),
      CategoriesScreen(
        onAudio: openAudioCenter,
      ),
      ProfileScreen(
        onAudio: openAudioCenter,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: index,
              children: pages,
            ),

            // مشغل الصوت المصغر.
            // لا نلمس نظام الصوت الحالي لأنه يعمل في الخلفية.
            const Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: MiniAudioPlayer(),
            ),

            // بوابة خلصانة العائمة.
            // الضغط عليها يفتح ChatScreen مباشرة.
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
      bottomNavigationBar: NavigationBar(
        backgroundColor:
            const Color(0xFF11141D),
        indicatorColor:
            const Color(0x3348D8FF),
        selectedIndex: index,
        onDestinationSelected: (value) {
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
              Icons.apps_outlined,
            ),
            selectedIcon: Icon(
              Icons.apps_rounded,
            ),
            label: 'الخدمات',
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

class MiniAudioPlayer extends StatelessWidget {
  const MiniAudioPlayer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream:
          AudioController.handler?.mediaItem,
      builder: (
        context,
        mediaSnapshot,
      ) {
        final item = mediaSnapshot.data;

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
            height: 66,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF151923)
                  .withOpacity(0.98),
              borderRadius:
                  BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0x55FFD76A),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 20,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const AudioCenterScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 46,
                    height: 46,
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
                      Icons.graphic_eq_rounded,
                      color: Colors.black,
                    ),
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AudioCenterScreen(),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
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
                            fontSize: 12,
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
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                StreamBuilder<PlaybackState>(
                  stream: handler.playbackState,
                  builder: (
                    context,
                    snapshot,
                  ) {
                    final playing =
                        snapshot.data?.playing ??
                            false;

                    return IconButton(
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
                            : Icons
                                .play_arrow_rounded,
                        color:
                            const Color(
                          0xFFFFD76A,
                        ),
                        size: 28,
                      ),
                    );
                  },
                ),

                IconButton(
                  onPressed: () {
                    handler.stop();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 20,
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
