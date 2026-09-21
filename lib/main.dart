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
import 'shorts_feed_screen.dart';
import 'widgets/khalasana_portal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const Sa7biAiApp());

  // نعرض أول إطار للتطبيق أولاً، ثم نهيّئ نظام الصوت
  // بعده بقليل حتى لا يعطل بداية تشغيل التطبيق.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 700),
        () async {
          try {
            await AudioController.initialize();
          } catch (_) {}
        },
      ),
    );
  });
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

      // بعد كل 5 أخبار نعرض محتوى Shorts حقيقي من الـ backend.
      if ((i + 1) % 5 == 0 &&
          i != news.length - 1) {
        widgets.add(
          const _ShortsEntryCard(),
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
      const Duration(seconds:
