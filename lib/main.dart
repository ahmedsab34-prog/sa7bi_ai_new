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

  // الصوت يتهيأ في الخلفية حتى لا نؤخر فتح التطبيق.
  // لا نلمس AudioService نفسه هنا.
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
        scaffoldBackgroundColor: const Color(0xFF070A12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD76A),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'sans',
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

class _MainContainerScreenState extends State<MainContainerScreen> {
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
              left: 10,
              right: 10,
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
        backgroundColor: const Color(0xFF11141D),
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
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded),
            label: 'الخدمات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
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
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsWebViewScreen(
          url: cleanUrl,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFFFFD76A),
      backgroundColor: const Color(0xFF151923),
      onRefresh: loadNews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          14,
          8,
          14,
          125,
        ),
        children: [
          AppHeader(
            onProfileTap: widget.onProfile,
            onAudioTap: widget.onAudio,
          ),

          const SizedBox(height: 12),

          const _AffiliateBanner(),

          const SizedBox(height: 17),

          Row(
            children: [
              IconButton(
                onPressed: loadNews,
                tooltip: 'تحديث الأخبار',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFFFFD76A),
                ),
              ),

              const Spacer(),

              const Text(
                'آخر الأخبار',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          if (loadingNews)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFFD76A),
                ),
              ),
            )
          else if (news.isEmpty)
            _EmptyNews(
              onRetry: loadNews,
            )
          else
            ..._buildNewsList(),

          const SizedBox(height: 15),

          const Text(
            'تسوق بسرعة',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 9),

          Wrap(
            spacing: 7,
            runSpacing: 7,
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

      // مكان مخصص لاحقًا لمحتوى Reels حقيقي من الـ backend.
      // لا نعرض Placeholder على أنه محتوى حقيقي.
      if ((i + 1) % 5 == 0 &&
          i != news.length - 1) {
        widgets.add(
          const _RealContentNotice(),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Sa7biLogo(),

        const SizedBox(width: 9),

        const Expanded(
          child: _HeaderWelcome(),
        ),

        const SizedBox(width: 7),

        _HeaderAction(
          icon: Icons.graphic_eq_rounded,
          color: Color(0xFF63E6FF),
          onTap: onAudioTap,
        ),

        const SizedBox(width: 7),

        _HeaderAction(
          icon: Icons.person_rounded,
          color: Color(0xFFFFD76A),
          onTap: onProfileTap,
        ),
      ],
    );
  }
}

class _HeaderWelcome extends StatefulWidget {
  const _HeaderWelcome();

  @override
  State<_HeaderWelcome> createState() =>
      _HeaderWelcomeState();
}

class _HeaderWelcomeState
    extends State<_HeaderWelcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Timer timer;

  final messages = const [
    'أهلاً يا صاحبي 👋',
    'أنا معاك في كل حاجة 🤖',
    'قول اللي في بالك 💙',
    'خلينا ننجزها سوا 🚀',
  ];

  int index = 0;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 4,
      ),
    )..repeat(reverse: true);

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
        final glow =
            0.06 + controller.value * 0.08;

        return Container(
          constraints: const BoxConstraints(
            minHeight: 58,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF1B2130),
                Color(0xFF10131C),
              ],
            ),
            border: Border.all(
              color: const Color(0x44FFD76A),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD76A)
                    .withOpacity(glow),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 350,
                ),
                child: Text(
                  messages[index],
                  key: ValueKey(index),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'صاحبي AI معاك كل يوم',
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      },
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
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF10131C),
          border: Border.all(
            color: color.withOpacity(0.75),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 13,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: 22,
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
      duration: const Duration(
        seconds: 9,
      ),
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
        final rotation =
            controller.value *
                math.pi *
                2;

        final glow =
            0.12 +
                ((math.sin(rotation) + 1) /
                        2) *
                    0.10;

        return SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // هالة خارجية هادئة
              Container(
                width: 59,
                height: 59,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF132A55,
                      ).withOpacity(glow),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFF651B32,
                      ).withOpacity(glow),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),

              // الحلقة أعرض وأصغر من القديمة
              Transform.rotate(
                angle: rotation,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFF8A1834),
                        Color(0xFF183D72),
                        Color(0xFF254F82),
                        Color(0xFF5C1630),
                        Color(0xFF8A1834),
                      ],
                    ),
                  ),
                ),
              ),

              // الحلقة الداخلية السميكة
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF070A12),
                  border: Border.all(
                    color: const Color(
                      0xFF315277,
                    ),
                    width: 2.2,
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

// ============================================================
// AFFILIATE BANNER
// ============================================================

class _AffiliateBanner extends StatefulWidget {
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
      title: 'عروض وتسوق',
      subtitle: 'Amazon • منتجات وعروض',
      icon: Icons.shopping_cart_rounded,
      color: Color(0xFFFFB300),
      url: MonetizationConfig.amazonUrl,
    ),
    _OfferData(
      title: 'اكتشف Jumia',
      subtitle: 'تسوق منتجات متنوعة',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFFB45CFF),
      url: MonetizationConfig.jumiaUrl,
    ),
    _OfferData(
      title: 'Noon',
      subtitle: 'عروض ومنتجات جديدة',
      icon: Icons.store_rounded,
      color: Color(0xFF63E6FF),
      url: MonetizationConfig.noonUrl,
    ),
    _OfferData(
      title: 'Marketplace',
      subtitle: 'منتجات من Facebook Marketplace',
      icon: Icons.facebook_rounded,
      color: Color(0xFF4D8DFF),
      url: MonetizationConfig.facebookShopUrl,
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
    final url = offers[index].url;

    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final offer = offers[index];

    return AnimatedSwitcher(
      duration: const Duration(
        milliseconds: 450,
      ),
      child: Container(
        key: ValueKey(index),
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Color(0xFF281C0D),
              Color(0xFF171A27),
              Color(0xFF0F131C),
            ],
          ),
          border: Border.all(
            color: const Color(0x55FFD76A),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: openOffer,
          borderRadius: BorderRadius.circular(19),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        offer.color,
                        const Color(0xFFB45CFF),
                      ],
                    ),
                  ),
                  child: Icon(
                    offer.icon,
                    color: Colors.black,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text(
                        offer.title,
                        textDirection:
                            TextDirection.rtl,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        offer.subtitle,
                        textDirection:
                            TextDirection.rtl,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 7),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFFFD76A),
                  size: 14,
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

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const _NewsCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        item.imageUrl.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10141D),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFFFFD76A),
                size: 15,
              ),

              const SizedBox(width: 8),

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
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      item.source,
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

              const SizedBox(width: 9),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(12),
                child: Container(
                  width: 68,
                  height: 57,
                  color: const Color(0xFF1A2030),
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
                              size: 24,
                            );
                          },
                        )
                      : const Icon(
                          Icons.newspaper_rounded,
                          color: Color(0xFF63E6FF),
                          size: 24,
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

class _EmptyNews extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyNews({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF11141D),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            color: Color(0xFF63E6FF),
            size: 32,
          ),
          const SizedBox(height: 7),
          const Text(
            'الأخبار مش متاحة دلوقتي 📡',
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 5),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            label: const Text(
              'حاول تاني',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// REAL CONTENT NOTICE
// ============================================================

class _RealContentNotice extends StatelessWidget {
  const _RealContentNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        top: 2,
        bottom: 10,
      ),
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF171C2B),
            Color(0xFF10131B),
          ],
        ),
        border: Border.all(
          color: Color(0x335FCFFF),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(width: 12),

          Icon(
            Icons.play_circle_outline_rounded,
            color: Color(0xFF63E6FF),
            size: 34,
          ),

          SizedBox(width: 10),

          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  'محتوى قصير',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'سيظهر هنا المحتوى الحقيقي عند ربط مصدر الريلز.',
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 12),
        ],
      ),
    );
  }
}

// ============================================================
// STORE BUTTON
// ============================================================

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
      onPressed: () async {
        try {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {}
      },
      icon: Icon(
        icon,
        color: const Color(0xFFFFD76A),
        size: 17,
      ),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(
          color: Color(0x44FFD76A),
        ),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(13),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 8,
        ),
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
      stream: AudioController
          .handler
          ?.mediaItem,
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
            height: 62,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 7,
            ),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF121720)
                      .withOpacity(0.98),
              borderRadius:
                  BorderRadius.circular(19),
              border: Border.all(
                color: const Color(0x55FFD76A),
              ),
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
                    width: 44,
                    height: 44,
                    decoration:
                        const BoxDecoration(
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

                const SizedBox(width: 8),

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

                StreamBuilder<PlaybackState>(
                  stream:
                      handler.playbackState,
                  builder: (
                    context,
                    snapshot,
                  ) {
                    final playing =
                        snapshot.data?.playing ??
                            false;

                    return IconButton(
                      padding: EdgeInsets.zero,
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
                            ? Icons.pause_rounded
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
                  padding: EdgeInsets.zero,
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
                    color: Colors.white54,
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

// ============================================================
// PROFILE
// ============================================================

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
        await SharedPreferences.getInstance();

    final savedName =
        prefs.getString('profile_name');

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
          base64Decode(savedPhoto),
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
    try {
      final file =
          await picker.pickImage(
        source: ImageSource.gallery,
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
    } catch (_) {}
  }

  Future<void> chooseReel() async {
    try {
      final file =
          await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration:
            const Duration(minutes: 2),
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
    } catch (_) {}
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

    FocusScope.of(context).unfocus();

    setState(() {});

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الاسم ✅',
            textDirection:
                TextDirection.rtl,
          ),
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
  Widget build(BuildContext context) {
    if (loadingProfile) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFD76A),
        ),
      );
    }

    final displayName =
        nameController.text.trim().isEmpty
            ? 'صاحبي'
            : nameController.text.trim();

    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        125,
      ),
      children: [
        AppHeader(
          onAudioTap: widget.onAudio,
        ),

        const SizedBox(height: 13),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(23),
            gradient:
                const LinearGradient(
              colors: [
                Color(0xFF20243A),
                Color(0xFF10131C),
              ],
            ),
            border: Border.all(
              color:
                  const Color(0x44FFD76A),
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: choosePhoto,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          const Color(
                        0xFFFFD76A,
                      ),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color:
                            Color(0x44FFD76A),
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
                            size: 45,
                          )
                        : Image.memory(
                            photo!,
                            fit: BoxFit.cover,
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
                controller: nameController,
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.right,
                decoration:
                    InputDecoration(
                  hintText: 'اكتب اسمك',
                  prefixIcon:
                      const Icon(
                    Icons.badge_outlined,
                  ),
                  suffixIcon:
                      IconButton(
                    onPressed: saveName,
                    icon: const Icon(
                      Icons.check_rounded,
                    ),
                  ),
                  filled: true,
                  fillColor:
                      const Color(0xFF0D1018),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
                onSubmitted:
                    (_) => saveName(),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          choosePhoto,
                      icon:
                          const Icon(
                        Icons.photo_rounded,
                      ),
                      label:
                          const Text(
                        'الصورة',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          chooseReel,
                      icon:
                          const Icon(
                        Icons.movie_rounded,
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
                const SizedBox(height: 8),
                Text(
                  '🎬 $reelName',
                  textDirection:
                      TextDirection.rtl,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
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
              'إعدادات تذكيرات العبادات والأذكار.',
          color:
              const Color(0xFF26A69A),
        ),

        _ReminderCard(
          icon:
              Icons.sports_soccer_rounded,
          title: 'هوايات',
          subtitle:
              'إعدادات تذكيرات الرياضة والهوايات.',
          color:
              const Color(0xFF2196F3),
        ),

        _ReminderCard(
          icon: Icons.person_rounded,
          title: 'شخصي',
          subtitle:
              'إعدادات التذكيرات الشخصية.',
          color:
              const Color(0xFFB45CFF),
        ),

        const SizedBox(height: 4),

        _ProfileButton(
          icon: Icons.share_rounded,
          title: 'مشاركة التطبيق',
          subtitle:
              'شارك رابط تحميل صاحبي AI مع أصحابك.',
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

// ============================================================
// REMINDER CARD
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
          const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.all(11),
      decoration: BoxDecoration(
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
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  color.withOpacity(0.16),
              border: Border.all(
                color:
                    color.withOpacity(0.4),
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
          const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color:
            const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration:
              const BoxDecoration(
            shape: BoxShape.circle,
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
            color: Colors.black,
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
          Icons.chevron_left_rounded,
        ),
      ),
    );
  }
}
