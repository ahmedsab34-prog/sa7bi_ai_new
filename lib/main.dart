import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';
import 'audio_center_screen.dart';
import 'audio_player_service.dart';
import 'categories_screen.dart';
import 'khalasana_portal_screen.dart';
import 'monetization_config.dart';
import 'news_webview_screen.dart';
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

// ============================================================
// HOME
// ============================================================

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
        loadingNews = false;
      });
    }
  }

  void openNews(
    String url,
    String title,
  ) {
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

          Row(
            children: [
              const Expanded(
                child: Text(
                  'آخر الأخبار',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: loadNews,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFFFD76A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 5),

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
            textAlign: TextAlign.right,
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
          onTap: () {
            openNews(
              item.link,
              item.title,
            );
          },
        ),
      );

      if ((i + 1) % 5 == 0 &&
          i != news.length - 1) {
        widgets.add(
          const _ReelStrip(),
        );
      }
    }

    return widgets;
  }
}

// ============================================================
// HEADER
// ============================================================

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
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
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

// ============================================================
// LOGO
// ============================================================

class Sa7biLogo extends StatefulWidget {
  const Sa7biLogo({super.key});

  @override
  State<Sa7biLogo> createState() =>
      _Sa7biLogoState();
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
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF63E6FF)
                          .withOpacity(
                        0.08 + pulse * 0.10,
                      ),
                      blurRadius: 18,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD76A)
                          .withOpacity(
                        0.08 + pulse * 0.10,
                      ),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),

              Transform.rotate(
                angle: controller.value *
                    math.pi *
                    2,
                child: Container(
                  width: 67,
                  height: 67,
                  decoration:
                      const BoxDecoration(
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
                width: 61,
                height: 61,
                padding:
                    const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      const Color(0xFF080A10),
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

              Positioned(
                right: 7,
                top: 8,
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 300,
                  ),
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      Colors.white,
                      const Color(
                        0xFFFFD76A,
                      ),
                      pulse,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFFFFD76A,
                        ).withOpacity(
                          0.65 + pulse * 0.35,
                        ),
                        blurRadius:
                            8 + pulse * 7,
                      ),
                    ],
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

// ============================================================
// WELCOME
// ============================================================

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
    'جاهز أساعدك في أي حاجة 🤖',
    'قول اللي في بالك وأنا معاك 💙',
    'خلينا ننجزها سوا 🚀',
    'صاحبي AI معاك كل يوم ✨',
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
          index =
              (index + 1) %
                  messages.length;
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
          padding:
              const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(19),
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
                decoration:
                    const BoxDecoration(
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
                      duration:
                          const Duration(
                        milliseconds: 350,
                      ),
                      child: Text(
                        messages[index],
                        key: ValueKey(index),
                        textDirection:
                            TextDirection.rtl,
                        textAlign:
                            TextAlign.right,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      'اسأل، اتكلم، ابعت صورة، اسمع صوت، أو افتح خلصانة AI.',
                      textDirection:
                          TextDirection.rtl,
                      textAlign:
                          TextAlign.right,
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

// ============================================================
// AFFILIATE / ADS BANNER
// ============================================================

class _AffiliateBanner
    extends StatefulWidget {
  const _AffiliateBanner();

  @override
  State<_AffiliateBanner> createState() =>
      _AffiliateBannerState();
}

class _AffiliateBannerState
    extends State<_AffiliateBanner> {
  late final Timer timer;

  int index = 0;

  final List<_OfferData> offers = [
    _OfferData(
      title:
          'عروض وتسوق من صاحبي AI',
      subtitle:
          'Jumia • Noon • Amazon • Facebook',
      icon:
          Icons.local_offer_rounded,
      color:
          Color(0xFFFFD76A),
      url:
          MonetizationConfig.jumiaUrl,
    ),
    _OfferData(
      title:
          'تسوق أذكى مع صاحبي',
      subtitle:
          'اختيارات من Amazon وNoon',
      icon:
          Icons.shopping_cart_rounded,
      color:
          Color(0xFF63E6FF),
      url:
          MonetizationConfig.amazonUrl,
    ),
    _OfferData(
      title:
          'اكتشف عروض جديدة',
      subtitle:
          'Jumia • Noon • Facebook Marketplace',
      icon:
          Icons.shopping_bag_rounded,
      color:
          Color(0xFFB45CFF),
      url:
          MonetizationConfig.noonUrl,
    ),
  ];

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted) return;

        setState(() {
          index =
              (index + 1) %
                  offers.length;
        });
      },
    );
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Future<void> openOffer() async {
    final offer = offers[index];

    await launchUrl(
      Uri.parse(offer.url),
      mode:
          LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = offers[index];

    return AnimatedSwitcher(
      duration:
          const Duration(milliseconds: 450),
      child: Container(
        key: ValueKey(index),
        height: 76,
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(20),
          gradient:
              const LinearGradient(
            begin:
                Alignment.centerRight,
            end:
                Alignment.centerLeft,
            colors: [
              Color(0xFF32230B),
              Color(0xFF171A28),
              Color(0xFF10151D),
            ],
          ),
          border: Border.all(
            color:
                const Color(0x55FFD76A),
          ),
          boxShadow: const [
            BoxShadow(
              color:
                  Color(0x22000000),
              blurRadius: 16,
              offset:
                  Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(20),
          onTap: openOffer,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 13,
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    gradient:
                        LinearGradient(
                      colors: [
                        offer.color,
                        const Color(
                          0xFFB45CFF,
                        ),
                      ],
                    ),
                  ),
                  child: Icon(
                    offer.icon,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .center,
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .end,
                    children: [
                      Text(
                        offer.title,
                        textDirection:
                            TextDirection
                                .rtl,
                        style:
                            const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        offer.subtitle,
                        textDirection:
                            TextDirection
                                .rtl,
                        style:
                            const TextStyle(
                          color:
                              Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  color:
                      Color(0xFFFFD76A),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String url;

  const _OfferData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.url,
  });
}

// ============================================================
// NEWS
// ============================================================

class _NewsCard
    extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const _NewsCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        item.imageUrl
            .trim()
            .isNotEmpty;

    return Container(
      margin:
          const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color:
            const Color(0xFF11141D),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Padding(
          padding:
              const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(
                Icons
                    .arrow_back_ios_new_rounded,
                color:
                    Color(0xFFFFD76A),
                size: 16,
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .end,
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
                      style:
                          const TextStyle(
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
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(13),
                child: Container(
                  width: 68,
                  height: 58,
                  color:
                      const Color(0xFF1A2030),
                  child: hasImage
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) {
                            return const Icon(
                              Icons
                                  .newspaper_rounded,
                              color:
                                  Color(0xFF63E6FF),
                              size: 25,
                            );
                          },
                        )
                      : const Icon(
                          Icons
                              .newspaper_rounded,
                          color:
                              Color(0xFF63E6FF),
                          size: 25,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNews
    extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyNews({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color:
            const Color(0xFF11141D),
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          const Text(
            'الأخبار مش متاحة دلوقتي 📡',
            textDirection:
                TextDirection.rtl,
          ),
          TextButton(
            onPressed: onRetry,
            child:
                const Text('حاول تاني'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REELS STRIP
// ============================================================

class _ReelStrip
    extends StatelessWidget {
  const _ReelStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 5,
        bottom: 13,
      ),
      height: 105,
      child: ListView(
        scrollDirection:
            Axis.horizontal,
        children: const [
          _ReelCard(
            title:
                'ريلز صاحبي',
            subtitle:
                'شاهد المزيد',
            icon:
                Icons.play_circle_fill_rounded,
          ),
          _ReelCard(
            title:
                'فيديوهات مختارة',
            subtitle:
                'قريبًا',
            icon:
                Icons.movie_filter_rounded,
          ),
          _ReelCard(
            title:
                'محتوى جديد',
            subtitle:
                'اكتشف',
            icon:
                Icons.auto_awesome_rounded,
          ),
        ],
      ),
    );
  }
}

class _ReelCard
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ReelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      margin:
          const EdgeInsets.only(
        left: 8,
      ),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(19),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topRight,
          end:
              Alignment.bottomLeft,
          colors: [
            Color(0xFF2D2042),
            Color(0xFF101521),
          ],
        ),
        border: Border.all(
          color:
              const Color(0x4463E6FF),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),

          Container(
            width: 45,
            height: 70,
            decoration:
                const BoxDecoration(
              borderRadius:
                  BorderRadius.all(
                Radius.circular(15),
              ),
              gradient:
                  LinearGradient(
                colors: [
                  Color(0xFF63E6FF),
                  Color(0xFFB45CFF),
                ],
              ),
            ),
            child: Icon(
              icon,
              color:
                  Colors.black,
              size: 27,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  subtitle,
                  textDirection:
                      TextDirection.rtl,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ============================================================
// STORE BUTTON
// ============================================================

class _StoreButton
    extends StatelessWidget {
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
          mode:
              LaunchMode.externalApplication,
        );
      },
      icon: Icon(
        icon,
        color:
            const Color(0xFFFFD76A),
        size: 18,
      ),
      label: Text(title),
      style:
          OutlinedButton.styleFrom(
        foregroundColor:
            Colors.white,
        side: const BorderSide(
          color:
              Color(0x44FFD76A),
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ============================================================
// MINI AUDIO PLAYER
// ============================================================

class MiniAudioPlayer
    extends StatelessWidget {
  const MiniAudioPlayer({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream:
          AudioController
              .handler
              ?.mediaItem,
      builder:
          (context, mediaSnapshot) {
        final item =
            mediaSnapshot.data;

        if (item == null) {
          return const SizedBox
              .shrink();
        }

        final handler =
            AudioController.handler;

        if (handler == null) {
          return const SizedBox
              .shrink();
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            height: 66,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFF151923)
                      .withOpacity(0.98),
              borderRadius:
                  BorderRadius.circular(20),
              border: Border.all(
                color:
                    const Color(0x55FFD76A),
              ),
              boxShadow: const [
                BoxShadow(
                  color:
                      Color(0x66000000),
                  blurRadius: 20,
                  offset:
                      Offset(0, 7),
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
                      shape:
                          BoxShape.circle,
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
                      color:
                          Colors.black,
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
                          MainAxisAlignment
                              .center,
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .end,
                      children: [
                        Text(
                          item.title,
                          textDirection:
                              TextDirection
                                  .rtl,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .w900,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          item.artist ??
                              'صاحبي AI',
                          textDirection:
                              TextDirection
                                  .rtl,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white54,
                            fontSize: 10,
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
                      (
                    context,
                    snapshot,
                  ) {
                    final playing =
                        snapshot.data
                                ?.playing ??
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
                            ? Icons
                                .pause_rounded
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
                    Icons
                        .close_rounded,
                    color:
                        Colors.white54,
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

// ============================================================
// PROFILE
// ============================================================

class ProfileScreen
    extends StatefulWidget {
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
  final ImagePicker picker =
      ImagePicker();

  final TextEditingController
      nameController =
      TextEditingController();

  Uint8List? photo;
  String? reelName;

  bool loadingProfile = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    final savedName =
        prefs.getString(
      'profile_name',
    );

    final savedPhoto =
        prefs.getString(
      'profile_photo_base64',
    );

    final savedReel =
        prefs.getString(
      'profile_reel_name',
    );

    Uint8List? decodedPhoto;

    if (savedPhoto != null &&
        savedPhoto.isNotEmpty) {
      try {
        decodedPhoto =
            Uint8List.fromList(
          base64Decode(
            savedPhoto,
          ),
        );
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      nameController.text =
          savedName ?? '';
      photo = decodedPhoto;
      reelName = savedReel;
      loadingProfile = false;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> choosePhoto() async {
    final file =
        await picker.pickImage(
      source:
          ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 900,
    );

    if (file == null) return;

    final bytes =
        await file.readAsBytes();

    if (bytes.isEmpty) return;

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      'profile_photo_base64',
      base64Encode(bytes),
    );

    if (!mounted) return;

    setState(() {
      photo = bytes;
    });
  }

  Future<void> chooseReel() async {
    final file =
        await picker.pickVideo(
      source:
          ImageSource.gallery,
      maxDuration:
          const Duration(
        minutes: 2,
      ),
    );

    if (file == null) return;

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      'profile_reel_name',
      file.name,
    );

    if (!mounted) return;

    setState(() {
      reelName = file.name;
    });
  }

  Future<void> saveName() async {
    final name =
        nameController.text.trim();

    if (name.isEmpty) return;

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      'profile_name',
      name,
    );

    if (!mounted) return;

    FocusScope.of(context)
        .unfocus();

    setState(() {});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content:
            Text('تم حفظ الاسم'),
      ),
    );
  }

  Future<void> shareApp() async {
    await Share.share(
      'جرّب تطبيق صاحبي AI 🤖\n'
      'مساعدك الذكي في كل يوم.\n'
      '${MonetizationConfig.appDownloadUrl}',
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (loadingProfile) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    final displayName =
        nameController.text
                .trim()
                .isEmpty
            ? 'صاحبي'
            : nameController.text
                .trim();

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        120,
      ),
      children: [
        AppHeader(
          onAudioTap:
              widget.onAudio,
        ),

        const SizedBox(height: 10),

        const Text(
          'حسابي',
          textDirection:
              TextDirection.rtl,
          textAlign:
              TextAlign.right,
          style: TextStyle(
            fontSize: 25,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              23,
            ),
            gradient:
                const LinearGradient(
              colors: [
                Color(0xFF20243A),
                Color(0xFF10131C),
              ],
            ),
            border:
                Border.all(
              color:
                  const Color(
                0x44FFD76A,
              ),
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: choosePhoto,
                child: Container(
                  width: 98,
                  height: 98,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFFFFD76A,
                      ),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color:
                            Color(
                          0x44FFD76A,
                        ),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photo == null
                        ? const Icon(
                            Icons
                                .person_rounded,
                            color:
                                Color(
                              0xFFFFD76A,
                            ),
                            size: 46,
                          )
                        : Image.memory(
                            photo!,
                            fit:
                                BoxFit.cover,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                displayName,
                textDirection:
                    TextDirection.rtl,
                style:
                    const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller:
                    nameController,
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.right,
                decoration:
                    InputDecoration(
                  hintText:
                      'اكتب اسمك',
                  prefixIcon:
                      const Icon(
                    Icons
                        .badge_outlined,
                  ),
                  suffixIcon:
                      IconButton(
                    onPressed:
                        saveName,
                    icon:
                        const Icon(
                      Icons
                          .check_rounded,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      const Color(
                    0xFF0D1018,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      15,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
                onSubmitted:
                    (_) =>
                        saveName(),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton
                            .icon(
                      onPressed:
                          choosePhoto,
                      icon:
                          const Icon(
                        Icons.photo,
                      ),
                      label:
                          const Text(
                        'الصورة',
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                        OutlinedButton
                            .icon(
                      onPressed:
                          chooseReel,
                      icon:
                          const Icon(
                        Icons.movie,
                      ),
                      label:
                          const Text(
                        'ريلز',
                      ),
                    ),
                  ),
                ],
              ),

              if (reelName != null) ...[
                const SizedBox(
                  height: 8,
                ),
                Text(
                  '🎬 $reelName',
                  textDirection:
                      TextDirection.rtl,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white60,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        _ReminderCard(
          icon:
              Icons.mosque_rounded,
          title: 'عبادات',
          subtitle:
              'تذكيرات للعبادات والأذكار والمهام الدينية.',
          color:
              const Color(0xFF26A69A),
        ),

        _ReminderCard(
          icon:
              Icons
                  .sports_soccer_rounded,
          title: 'هوايات',
          subtitle:
              'تذكيرات للرياضة والهوايات والأشياء التي تحبها.',
          color:
              const Color(0xFF2196F3),
        ),

        _ReminderCard(
          icon:
              Icons.person_rounded,
          title: 'شخصي',
          subtitle:
              'تذكيرات شخصية للمهام والمواعيد والأهداف.',
          color:
              const Color(0xFFB45CFF),
        ),

        const SizedBox(height: 4),

        _ProfileButton(
          icon:
              Icons.share_rounded,
          title:
              'مشاركة التطبيق',
          subtitle:
              'شارك صاحبي مع أصحابك برابط التحميل عبر التطبيقات المتاحة.',
          onTap:
              shareApp,
        ),

        _ProfileButton(
          icon:
              Icons.settings_rounded,
          title:
              'الإعدادات',
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

// ============================================================
// REMINDERS
// ============================================================

class _ReminderCard
    extends StatelessWidget {
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
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(11),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              color.withOpacity(0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chevron_left_rounded,
            color:
                Colors.white38,
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
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  subtitle,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
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
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  color.withOpacity(
                0.16,
              ),
              border:
                  Border.all(
                color:
                    color.withOpacity(
                  0.4,
                ),
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

// ============================================================
// PROFILE BUTTON
// ============================================================

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
      margin:
          const EdgeInsets.only(
        bottom: 9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration:
              const BoxDecoration(
            shape:
                BoxShape.circle,
            gradient:
                LinearGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFB45CFF),
              ],
            ),
          ),
          child: Icon(
            icon,
            color:
                Colors.black,
          ),
        ),
        title: Text(
          title,
          textDirection:
              TextDirection.rtl,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection:
              TextDirection.rtl,
          style:
              const TextStyle(
            color:
                Colors.white54,
            fontSize: 11,
          ),
        ),
        trailing:
            const Icon(
          Icons
              .chevron_left_rounded,
        ),
      ),
    );
  }
}
