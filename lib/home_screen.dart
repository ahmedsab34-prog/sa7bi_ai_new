import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';
import 'monetization_config.dart';
import 'news_webview_screen.dart';
import 'shorts_feed_screen.dart';

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

          const _WelcomeCard(),

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
          color: const Color(0xFF63E6FF),
          onTap: onAudioTap,
        ),

        const SizedBox(width: 7),

        _HeaderAction(
          icon: Icons.person_rounded,
          color: const Color(0xFFFFD76A),
          onTap: onProfileTap,
        ),
      ],
    );
  }
}

// ============================================================
// HEADER WELCOME
// ============================================================

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
      duration: const Duration(seconds: 4),
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

// ============================================================
// HEADER ACTION
// ============================================================

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
// SA7BI LOGO
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
      duration: const Duration(seconds: 9),
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
            controller.value * 3.141592653589793 * 2;

        final glow =
            0.12 +
            (((rotation == rotation) ? 0 : 0) +
                    1) *
                0.05;

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

              // الحلقة الخارجية فقط هي التي تدور.
              // محتوى الشعار نفسه لا يتم تغييره.
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
                    color: const Color(0xFF315277),
                    width: 2.2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFFFD76A),
                      );
                    },
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
// WELCOME CARD
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

  final messages = const [
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
            horizontal: 14,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      'اسأل، اتكلم، ابعت صورة، اسمع صوت، أو افتح خلصانة AI.',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white60,
                        height: 1.25,
                        fontSize: 10.5,
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
      color: const Color(0xFFFFB300),
      url: MonetizationConfig.amazonUrl,
    ),
    _OfferData(
      title: 'اكتشف Jumia',
      subtitle: 'تسوق منتجات متنوعة',
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFFB45CFF),
      url: MonetizationConfig.jumiaUrl,
    ),
    _OfferData(
      title: 'Noon',
      subtitle: 'عروض ومنتجات جديدة',
      icon: Icons.store_rounded,
      color: const Color(0xFF63E6FF),
      url: MonetizationConfig.noonUrl,
    ),
    _OfferData(
      title: 'Marketplace',
      subtitle: 'منتجات من Facebook Marketplace',
      icon: Icons.facebook_rounded,
      color: const Color(0xFF4D8DFF),
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
          index = (index + 1) % offers.length;
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

    final uri = Uri.tryParse(offer.url);

    if (uri == null) return;

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final offer = offers[index];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: Container(
        key: ValueKey(index),
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
          onTap: openOffer,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
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
                  ),
                ),

                const SizedBox(width: 10),

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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        offer.subtitle,
                        textDirection:
                            TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFFFFD76A),
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
// NEWS CARD
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
      margin: const EdgeInsets.only(bottom: 8),
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
          padding: const EdgeInsets.all(10),
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
                        fontWeight: FontWeight.w800,
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

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(13),
                child: Container(
                  width: 68,
                  height: 58,
                  color: const Color(0xFF1A2030),
                  child: hasImage
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) {
                            return const Icon(
                              Icons.newspaper_rounded,
                              color:
                                  Color(0xFF63E6FF),
                              size: 25,
                            );
                          },
                        )
                      : const Icon(
                          Icons.newspaper_rounded,
                          color: Color(0xFF63E6FF),
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

// ============================================================
// EMPTY NEWS
// ============================================================

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

// ============================================================
// SHORTS ENTRY
// ============================================================

class _ShortsEntryCard extends StatelessWidget {
  const _ShortsEntryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(
        top: 4,
        bottom: 13,
      ),
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF2C1C42),
            Color(0xFF121725),
          ],
        ),
        border: Border.all(
          color: const Color(0x4463E6FF),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ShortsFeedScreen(),
            ),
          );
        },
        child: Row(
          children: [
            const SizedBox(width: 12),

            Container(
              width: 62,
              height: 72,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(17),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF63E6FF),
                    Color(0xFFB45CFF),
                  ],
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.black,
                size: 34,
              ),
            ),

            const SizedBox(width: 12),

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
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'شاهد الفيديوهات القصيرة واكتشف محتوى جديد',
                    textDirection:
                        TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFFFD76A),
              size: 16,
            ),

            const SizedBox(width: 10),
          ],
        ),
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
        final uri = Uri.tryParse(url);

        if (uri == null) return;

        try {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {}
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
