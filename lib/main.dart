import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';
import 'audio_center_screen.dart';
import 'audio_player_service.dart';
import 'categories_screen.dart';
import 'khalasana_portal_screen.dart';
import 'monetization_config.dart';
import 'settings_screen.dart';
import 'widgets/khalasana_portal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const Sa7biAiApp());

  // لا ننتظر الصوت قبل ظهور التطبيق.
  // تهيئة الصوت تعمل في الخلفية.
  unawaited(AudioController.initialize());
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
        scaffoldBackgroundColor: const Color(0xFF080A10),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD54F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainContainerScreen(),
    );
  }
}

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

  void openKhalasana() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const KhalasanaPortalScreen(),
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

            const Positioned(
              left: 12,
              right: 12,
              bottom: 8,
              child: MiniAudioPlayer(),
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
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF17181F),
        indicatorColor: const Color(0x3348D8FF),
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() {
            index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'الخدمات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onProfile;
  final VoidCallback onAudio;

  const HomeScreen({
    super.key,
    required this.onProfile,
    required this.onAudio,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loadingNews = true;
  List<NewsItem> news = [];

  @override
  void initState() {
    super.initState();
    loadNews();
  }

  Future<void> loadNews() async {
    if (mounted) {
      setState(() {
        loadingNews = true;
      });
    }

    try {
      final result = await AiService.getNews();

      if (!mounted) return;

      setState(() {
        news = result;
        loadingNews = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        news = [];
        loadingNews = false;
      });
    }
  }

  void openNews(String url, String title) {
    if (url.trim().isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsWebViewScreen(
          url: url,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadNews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          10,
          16,
          120,
        ),
        children: [
          AppHeader(
            onProfileTap: widget.onProfile,
            onAudioTap: widget.onAudio,
          ),

          const SizedBox(height: 10),

          const _WelcomeCard(),

          const SizedBox(height: 10),

          const _AffiliateBanner(),

          const SizedBox(height: 18),

          const Text(
            'آخر الأخبار',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 9),

          if (loadingNews)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (news.isEmpty)
            _EmptyNews(
              onRetry: loadNews,
            )
          else
            ..._buildNewsList(),

          const SizedBox(height: 16),

          const Text(
            'تسوق بسرعة',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 9),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StoreButton(
                title: 'Amazon',
                icon: Icons.shopping_cart_rounded,
                url: MonetizationConfig.amazonUrl,
              ),
              _StoreButton(
                title: 'Jumia',
                icon: Icons.shopping_bag_rounded,
                url: MonetizationConfig.jumiaUrl,
              ),
              _StoreButton(
                title: 'Noon',
                icon: Icons.store_rounded,
                url: MonetizationConfig.noonUrl,
              ),
              _StoreButton(
                title: 'Facebook',
                icon: Icons.facebook_rounded,
                url: MonetizationConfig.facebookShopUrl,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNewsList() {
    final widgets = <Widget>[];

    for (int i = 0; i < news.length; i++) {
      final item = news[i];

      widgets.add(
        _NewsCard(
          item: item,
          onTap: () => openNews(
            item.link,
            item.title,
          ),
        ),
      );

      // فاصل ريلز كل 5 أخبار.
      if ((i + 1) % 5 == 0 && i != news.length - 1) {
        widgets.add(
          const _ReelStrip(),
        );
      }
    }

    return widgets;
  }
}

class AppHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;

  const AppHeader({
    super.key,
    this.onProfileTap,
    this.onAudioTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Sa7biLogo(),

        Row(
          children: [
            _HeaderAction(
              icon: Icons.graphic_eq_rounded,
              color: const Color(0xFF63E6FF),
              onTap: onAudioTap,
            ),

            const SizedBox(width: 8),

            _HeaderAction(
              icon: Icons.person_rounded,
              color: const Color(0xFFFFD76A),
              onTap: onProfileTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _HeaderAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF151820),
          border: Border.all(
            color: color,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.18),
              blurRadius: 14,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 25,
        ),
      ),
    );
  }
}

class Sa7biLogo extends StatefulWidget {
  const Sa7biLogo({super.key});

  @override
  State<Sa7biLogo> createState() => _Sa7biLogoState();
}

class _Sa7biLogoState
    extends State<Sa7biLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final pulse =
            (math.sin(
                      controller.value *
                          math.pi *
                          2,
                    ) +
                    1) /
                2;

        return SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF63E6FF)
                          .withOpacity(
                        0.07 + pulse * 0.07,
                      ),
                      blurRadius: 17,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD76A)
                          .withOpacity(
                        0.07 + pulse * 0.07,
                      ),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),

              Transform.rotate(
                angle: controller.value *
                    math.pi *
                    2,
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFFFD76A),
                        Color(0xFF63E6FF),
                        Color(0xFF7864FF),
                        Color(0xFF49E6A8),
                        Color(0xFFFFD76A),
                      ],
                    ),
                  ),
                ),
              ),

              Container(
                width: 59,
                height: 59,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF080A10),
                  border: Border.all(
                    color: Colors.white24,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WelcomeCard extends StatefulWidget {
  const _WelcomeCard();

  @override
  State<_WelcomeCard> createState() =>
      _WelcomeCardState();
}

class _WelcomeCardState
    extends State<_WelcomeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Timer timer;

  final List<String> messages = [
    'أهلاً يا صاحبي 👋',
    'صباحك أو مساءك AI ✨',
    'جاهز أساعدك في أي حاجة 🤖',
    'قول اللي في بالك وأنا معاك 💙',
    'خلينا ننجزها سوا 🚀',
  ];

  int index = 0;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!mounted) return;

        setState(() {
          index = (index + 1) % messages.length;
        });
      },
    );
  }

  @override
  void dispose() {
    timer.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.lerp(
                  const Color(0xFF2A210E),
                  const Color(0xFF17283A),
                  controller.value,
                )!,
                const Color(0xFF10141D),
                Color.lerp(
                  const Color(0xFF1D1527),
                  const Color(0xFF102820),
                  controller.value,
                )!,
              ],
            ),
            border: Border.all(
              color: const Color(0x44FFD76A),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFD76A),
                      Color(0xFF63E6FF),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.black,
                  size: 19,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(
                        milliseconds: 350,
                      ),
                      child: Text(
                        messages[index],
                        key: ValueKey(index),
                        textDirection:
                            TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      'اسأل، اتكلم، ابعت صورة، اسمع صوت، أو افتح خلصانة AI.',
                      textDirection:
                          TextDirection.rtl,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white60,
                        height: 1.25,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AffiliateBanner extends StatelessWidget {
  const _AffiliateBanner();

  void _open(String url) {
    launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            Color(0xFF32230B),
            Color(0xFF171A28),
            Color(0xFF10151D),
          ],
        ),
        border: Border.all(
          color: const Color(0x55FFD76A),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(
          MonetizationConfig.jumiaUrl,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFD76A),
                      Color(0xFFB45CFF),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  color: Colors.black,
                ),
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      'عروض وتسوق من صاحبي AI',
                      textDirection:
                          TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Jumia • Noon • Amazon • Facebook',
                      textDirection:
                          TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFFFD76A),
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelStrip extends StatelessWidget {
  const _ReelStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        top: 5,
        bottom: 10,
      ),
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF21143A),
            Color(0xFF10151E),
            Color(0xFF102B31),
          ],
        ),
        border: Border.all(
          color: const Color(0x4463E6FF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              gradient: LinearGradient(
                colors: [
                  Color(0xFF7864FF),
                  Color(0xFF63E6FF),
                ],
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.black,
              size: 35,
            ),
          ),

          const SizedBox(width: 11),

          const Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  'ريلز صاحبي',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'محتوى سريع ومفيد — قريبًا داخل التطبيق',
                  textDirection:
                      TextDirection.rtl,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const _NewsCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF11141D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFFFD76A),
                size: 16,
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.title,
                      textDirection:
                          TextDirection.rtl,
                      textAlign:
                          TextAlign.right,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      item.source,
                      textDirection:
                          TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x2238D9FF),
                  border: Border.all(
                    color: const Color(0x3363E6FF),
                  ),
                ),
                child: const Icon(
                  Icons.newspaper_rounded,
                  color: Color(0xFF63E6FF),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNews extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyNews({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF11141D),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          const Text(
            'الأخبار مش متاحة دلوقتي 📡',
            textDirection: TextDirection.rtl,
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('حاول تاني'),
          ),
        ],
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final String url;

  const _StoreButton({
    required this.title,
    required this.icon,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      },
      icon: Icon(
        icon,
        color: const Color(0xFFFFD76A),
        size: 18,
      ),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(
          color: Color(0x44FFD76A),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
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

        if (item == null) {
          return const SizedBox.shrink();
        }

        final handler = AudioController.handler;

        if (handler == null) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(
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
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
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
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          item.artist ?? 'صاحبي AI',
                          textDirection:
                              TextDirection.rtl,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
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
                            : Icons.play_arrow_rounded,
                        color:
                            const Color(0xFFFFD76A),
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

class ProfileScreen extends StatefulWidget {
  final VoidCallback onAudio;

  const ProfileScreen({
    super.key,
    required this.onAudio,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  final ImagePicker picker = ImagePicker();

  Uint8List? photo;
  String? reelName;

  Future<void> choosePhoto() async {
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (!mounted) return;

    setState(() {
      photo = bytes;
    });
  }

  Future<void> chooseReel() async {
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );

    if (file == null) return;

    if (!mounted) return;

    setState(() {
      reelName = file.name;
    });
  }

  Future<void> shareApp() async {
    final appLink =
        MonetizationConfig.appDownloadUrl;

    final text = Uri.encodeComponent(
      'جرّب تطبيق صاحبي AI 🤖\n'
      'مساعدك الذكي في كل يوم.\n'
      '$appLink',
    );

    await launchUrl(
      Uri.parse(
        'https://wa.me/?text=$text',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        120,
      ),
      children: [
        AppHeader(
          onAudioTap: widget.onAudio,
        ),

        const SizedBox(height: 10),

        const Text(
          'حسابي',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(23),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF20243A),
                Color(0xFF10131C),
              ],
            ),
            border: Border.all(
              color: const Color(0x44FFD76A),
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: choosePhoto,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(
                        0xFFFFD76A,
                      ),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: photo == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: Color(
                              0xFFFFD76A,
                            ),
                            size: 44,
                          )
                        : Image.memory(
                            photo!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'صورتك الشخصية',
                textDirection:
                    TextDirection.rtl,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: choosePhoto,
                      icon: const Icon(
                        Icons.photo,
                      ),
                      label: const Text(
                        'الصورة',
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: chooseReel,
                      icon: const Icon(
                        Icons.movie,
                      ),
                      label: const Text(
                        'ريلز',
                      ),
                    ),
                  ),
                ],
              ),

              if (reelName != null) ...[
                const SizedBox(height: 8),
                Text(
                  '🎬 $reelName',
                  textDirection:
                      TextDirection.rtl,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        _ReminderCard(
          icon: Icons.mosque_rounded,
          title: 'عبادات',
          subtitle:
              'تذكيرات للعبادات والأذكار والمهام الدينية.',
          color: const Color(0xFF26A69A),
        ),

        _ReminderCard(
          icon: Icons.sports_soccer_rounded,
          title: 'هوايات',
          subtitle:
              'تذكيرات للرياضة والهوايات والأشياء التي تحبها.',
          color: const Color(0xFF2196F3),
        ),

        _ReminderCard(
          icon: Icons.person_rounded,
          title: 'شخصي',
          subtitle:
              'تذكيرات شخصية للمهام والمواعيد والأهداف.',
          color: const Color(0xFFB45CFF),
        ),

        const SizedBox(height: 4),

        _ProfileButton(
          icon: Icons.share_rounded,
          title: 'مشاركة التطبيق',
          subtitle:
              'شارك صاحبي مع أصحابك برابط التحميل.',
          onTap: shareApp,
        ),

        _ProfileButton(
          icon: Icons.settings_rounded,
          title: 'الإعدادات',
          subtitle:
              'إعدادات التطبيق والذكاء الاصطناعي.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const SettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ReminderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chevron_left_rounded,
            color: Colors.white38,
          ),

          const Spacer(),

          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textDirection:
                      TextDirection.rtl,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textDirection:
                      TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.16),
              border: Border.all(
                color: color.withOpacity(0.4),
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileButton
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFB45CFF),
              ],
            ),
          ),
          child: Icon(
            icon,
            color: Colors.black,
          ),
        ),
        title: Text(
          title,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
        ),
      ),
    );
  }
}
