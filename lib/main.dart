import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

// ============================================================
// MAIN CONTAINER
// ============================================================

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    CategoriesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF11131C),
        indicatorColor: const Color(0x33FFD54F),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
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
// SA7BI LOGO
// ============================================================

class Sa7biLogo extends StatefulWidget {
  const Sa7biLogo({super.key});

  @override
  State<Sa7biLogo> createState() => _Sa7biLogoState();
}

class _Sa7biLogoState extends State<Sa7biLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        final pulse =
            (math.sin(t * math.pi * 2) + 1) / 2;

        final signalColor = HSVColor.fromAHSV(
          1,
          (185 + t * 150) % 360,
          .82,
          1,
        ).toColor();

        final edgeColor = HSVColor.fromAHSV(
          1,
          (42 + t * 45) % 360,
          .65,
          1,
        ).toColor();

        return SizedBox(
          width: 76,
          height: 76,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // الإضاءة الخارجية
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: edgeColor.withOpacity(.45),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: signalColor.withOpacity(.18),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),

              // الإطار الخارجي
              Container(
                width: 70,
                height: 70,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: GradientRotation(
                      t * math.pi * 2,
                    ),
                    colors: [
                      const Color(0xFFFFB300),
                      const Color(0xFFFFF0A6),
                      const Color(0xFFFFC107),
                      signalColor,
                      const Color(0xFF1769FF),
                      const Color(0xFFFFB300),
                    ],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF082B61),
                        Color(0xFF03152F),
                        Color(0xFF061B3B),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(.32),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // لمعة زجاج متحركة
                      Positioned(
                        left: -18 + (t * 70),
                        top: 3,
                        child: Transform.rotate(
                          angle: -.45,
                          child: Container(
                            width: 23,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0),
                                  Colors.white.withOpacity(.18),
                                  Colors.white.withOpacity(0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // @
                      Positioned(
                        left: 7,
                        top: 14,
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFF1A8),
                                Color(0xFFFFC107),
                                Color(0xFFD88A00),
                                Color(0xFFFFE082),
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            '@',
                            style: TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFB300),
                                  blurRadius: 7,
                                  offset: Offset(1, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // i
                      Positioned(
                        right: 10,
                        top: 16,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFB9F7FF),
                                    Color(0xFF00C8FF),
                                    Color(0xFF087BFF),
                                    Color(0xFFFFC107),
                                  ],
                                ).createShader(bounds);
                              },
                              child: const Text(
                                'i',
                                style: TextStyle(
                                  fontSize: 31,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // النقطة المضيئة
                            Positioned(
                              left: 7,
                              top: -3,
                              child: Container(
                                width: 9 + pulse * 3,
                                height: 9 + pulse * 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: signalColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: signalColor
                                          .withOpacity(.95),
                                      blurRadius:
                                          6 + pulse * 8,
                                      spreadRadius:
                                          1 + pulse * 2,
                                    ),
                                    const BoxShadow(
                                      color: Color(0xFFFFC107),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // إشارات Wi-Fi
                      Positioned(
                        right: 1,
                        top: -4,
                        child: CustomPaint(
                          size: const Size(36, 25),
                          painter: _Sa7biSignalPainter(
                            progress: t,
                            color: signalColor,
                          ),
                        ),
                      ),

                      // صاحبي داخل الدائرة
                      Positioned(
                        bottom: 7,
                        left: 0,
                        right: 0,
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                              colors: [
                                Color(0xFFFFF3B0),
                                Color(0xFFFFC107),
                                Color(0xFFD98A00),
                                Color(0xFFFFE082),
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'صاحبي',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 3,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // لمعة صغيرة
                      Positioned(
                        left: 8,
                        top: 7,
                        child: Container(
                          width: 16,
                          height: 4,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(.65),
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
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
// WIFI SIGNAL
// ============================================================

class _Sa7biSignalPainter extends CustomPainter {
  final double progress;
  final Color color;

  _Sa7biSignalPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height * .92,
    );

    for (int i = 0; i < 3; i++) {
      final phase =
          (progress + i * .18) % 1.0;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(
          .28 + phase * .65,
        );

      final rect = Rect.fromCenter(
        center: center,
        width: size.width *
            (.38 + i * .23),
        height: size.height *
            (.55 + i * .24),
      );

      canvas.drawArc(
        rect,
        math.pi * 1.17,
        math.pi * .66,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _Sa7biSignalPainter oldDelegate,
  ) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}

// ============================================================
// HEADER
// ============================================================

class AppHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;

  const AppHeader({
    super.key,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        const Sa7biLogo(),

        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFD54F),
                width: 2,
              ),
              color: const Color(0xFF171A24),
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFFFFD54F),
              size: 27,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _refresh() async {
    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث المحتوى'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const AppHeader(),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2B1F08),
                  Color(0xFF171A24),
                  Color(0xFF21142A),
                ],
              ),
              border: Border.all(
                color: const Color(0x55FFD54F),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 15,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.local_offer,
                      color: Color(0xFFFFD54F),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'عروض وتسوق',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD54F),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  'اختار المتجر وشوف أحدث المنتجات والعروض.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StoreButton(
                      name: 'Amazon',
                      icon: Icons.shopping_cart,
                      onTap: () => _openUrl(
                        'https://www.amazon.eg/',
                      ),
                    ),
                    _StoreButton(
                      name: 'Jumia',
                      icon: Icons.shopping_bag,
                      onTap: () => _openUrl(
                        'https://www.jumia.com.eg/',
                      ),
                    ),
                    _StoreButton(
                      name: 'Noon',
                      icon: Icons.store,
                      onTap: () => _openUrl(
                        'https://www.noon.com/egypt-en/',
                      ),
                    ),
                    _StoreButton(
                      name: 'Facebook Shop',
                      icon: Icons.facebook,
                      onTap: () => _openUrl(
                        'https://www.facebook.com/marketplace/',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'آخر الأخبار',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 12),

          const _NewsCard(
            title: 'أخبار وتقنيات جديدة',
            subtitle:
                'هنا ستظهر الأخبار والمحتوى المهم من المصادر المختلفة.',
            icon: Icons.public,
          ),

          const _NewsCard(
            title: 'أخبار الذكاء الاصطناعي',
            subtitle:
                'آخر التطورات والأدوات الجديدة في عالم الذكاء الاصطناعي.',
            icon: Icons.auto_awesome,
          ),

          const _NewsCard(
            title: 'أخبار التكنولوجيا',
            subtitle:
                'متابعة أهم أخبار الأجهزة والتطبيقات والتكنولوجيا.',
            icon: Icons.devices,
          ),

          const _NewsCard(
            title: 'أخبار الأعمال والتسوق',
            subtitle:
                'أحدث المنتجات والعروض والأفكار التجارية.',
            icon: Icons.trending_up,
          ),

          const _NewsCard(
            title: 'أخبار عامة',
            subtitle:
                'محتوى متنوع يتم تحديثه باستمرار داخل التطبيق.',
            icon: Icons.newspaper,
          ),

          const SizedBox(height: 18),

          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0x33FFFFFF),
              ),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF151824),
                  Color(0xFF211329),
                ],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ShortVideoBox(
                    title: 'Reels',
                    icon:
                        Icons.play_circle_fill,
                    onTap: () {},
                  ),
                ),
                Container(
                  width: 1,
                  margin:
                      const EdgeInsets.symmetric(
                    vertical: 20,
                  ),
                  color: Colors.white24,
                ),
                Expanded(
                  child: _ShortVideoBox(
                    title: 'TikTok',
                    icon: Icons.music_note,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STORE BUTTON
// ============================================================

class _StoreButton extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  const _StoreButton({
    required this.name,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: const Color(0x22111111),
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0x44FFD54F),
          ),
        ),
        child: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: const Color(0xFFFFD54F),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NEWS CARD
// ============================================================

class _NewsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _NewsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x22FFFFFF),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(15),
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFFFFD54F),
                  Color(0xFFB15CFF),
                ],
              ),
            ),
            child: Icon(
              icon,
              color: Colors.black,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHORT VIDEO
// ============================================================

class _ShortVideoBox
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ShortVideoBox({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color:
                const Color(0xFFFFD54F),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'محتوى قصير',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CATEGORIES
// ============================================================

class CategoriesScreen
    extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<_CategoryData>
      categories = [
    _CategoryData(
      title: 'المطبخ والبيت',
      icon: Icons.kitchen,
      description:
          'صور أو فيديو للمكونات والأجهزة والمساعدة في احتياجات البيت.',
    ),
    _CategoryData(
      title: 'التاجر',
      icon: Icons.storefront,
      description:
          'مساعدة التجار في عرض المنتجات والصور والأسعار والتسويق.',
    ),
    _CategoryData(
      title: 'الصيدلية والأعشاب',
      icon: Icons.local_pharmacy,
      description:
          'معلومات عامة عن الأدوية والأعشاب مع التنبيه لاستشارة المختص.',
    ),
    _CategoryData(
      title: 'الصنايعي',
      icon: Icons.handyman,
      description:
          'مساعدة في مشاكل المنزل والأعمال والإصلاحات المختلفة.',
    ),
    _CategoryData(
      title: 'العبادات',
      icon: Icons.mosque,
      description:
          'قرآن وأذكار ومعلومات عن مواقيت الصلاة والتذكيرات.',
    ),
    _CategoryData(
      title: 'الشراء والتسوق',
      icon: Icons.shopping_cart,
      description:
          'البحث عن المنتجات ومقارنة الخيارات وتوجيهك للمتاجر.',
    ),
    _CategoryData(
      title: 'التواصل الاجتماعي',
      icon: Icons.groups,
      description:
          'مشاركة وتواصل نصي وصوتي وفيديو ومجموعات.',
    ),
    _CategoryData(
      title: 'الفضفضة الخاصة',
      icon: Icons.lock,
      description:
          'مساحة خاصة للمحادثة الشخصية مع حماية إضافية.',
    ),
    _CategoryData(
      title: 'الهوايات والرياضة',
      icon: Icons.sports_soccer,
      description:
          'الرياضة والهوايات والفرق والمسابقات والتذكيرات.',
    ),
    _CategoryData(
      title: 'البودكاست',
      icon: Icons.podcasts,
      description:
          'محتوى صوتي وفيديو مباشر وقديم وقادم.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding:
              const EdgeInsets.fromLTRB(
            16,
            14,
            16,
            10,
          ),
          sliver:
              const SliverToBoxAdapter(
            child: AppHeader(),
          ),
        ),

        const SliverPadding(
          padding:
              EdgeInsets.symmetric(
            horizontal: 16,
          ),
          sliver:
              SliverToBoxAdapter(
            child: Text(
              'خدمات صاحبي AI',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 15),
        ),

        SliverPadding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          sliver: SliverGrid(
            delegate:
                SliverChildBuilderDelegate(
              (context, index) {
                final category =
                    categories[index];

                return _CategoryCard(
                  data: category,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ServiceDetailScreen(
                          data: category,
                        ),
                      ),
                    );
                  },
                );
              },
              childCount:
                  categories.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .88,
            ),
          ),
        ),

        const SliverPadding(
          padding: EdgeInsets.only(
            bottom: 25,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CATEGORY DATA
// ============================================================

class _CategoryData {
  final String title;
  final IconData icon;
  final String description;

  const _CategoryData({
    required this.title,
    required this.icon,
    required this.description,
  });
}

// ============================================================
// CATEGORY CARD
// ============================================================

class _CategoryCard
    extends StatelessWidget {
  final _CategoryData data;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(24),
      child: Container(
        padding:
            const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(24),
          gradient:
              const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF18243A),
              Color(0xFF0D121F),
            ],
          ),
          border: Border.all(
            color: const Color(0x33FFD54F),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFFFFD54F),
                    Color(0xFFB16CFF),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55FFD54F),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Icon(
                data.icon,
                color: Colors.black,
                size: 31,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              data.title,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'اضغط للدخول',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SERVICE DETAIL
// ============================================================

class ServiceDetailScreen
    extends StatelessWidget {
  final _CategoryData data;

  const ServiceDetailScreen({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(data.title),
        backgroundColor:
            const Color(0xFF0D1018),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(18),
        children: [
          Container(
            padding:
                const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(25),
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF18243A),
                  Color(0xFF0C101A),
                ],
              ),
              border: Border.all(
                color: const Color(0x44FFD54F),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  data.icon,
                  size: 70,
                  color:
                      const Color(0xFFFFD54F),
                ),
                const SizedBox(height: 15),
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.description,
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          _ActionTile(
            icon: Icons.camera_alt,
            title: 'الكاميرا',
            subtitle:
                'صوّر صورة أو فيديو وأرسله للخدمة.',
            onTap: () {},
          ),

          _ActionTile(
            icon: Icons.mic,
            title: 'الصوت',
            subtitle:
                'استخدم صوتك للتحدث مع الخدمة.',
            onTap: () {},
          ),

          _ActionTile(
            icon: Icons.chat,
            title: 'المحادثة',
            subtitle:
                'اكتب رسالتك وابدأ المحادثة.',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ACTION TILE
// ============================================================

class _ActionTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121722),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x22FFFFFF),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x22FFD54F),
          ),
          child: Icon(
            icon,
            color:
                const Color(0xFFFFD54F),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfileScreen
    extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _shareApp() async {
    final uri = Uri.parse(
      'https://github.com/ahmedsab34-prog/sa7bi_ai_new',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        25,
      ),
      children: [
        const AppHeader(),

        const SizedBox(height: 25),

        Center(
          child: Column(
            children: [
              const Sa7biLogo(),

              const SizedBox(height: 15),

              const Text(
                'صاحبي AI',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'مساعدك الذكي في كل يوم',
                style: TextStyle(
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        _ProfileButton(
          icon: Icons.share,
          title: 'مشاركة التطبيق',
          subtitle:
              'شارك رابط صاحبي مع أصدقائك.',
          onTap: _shareApp,
        ),

        _ProfileButton(
          icon: Icons.settings,
          title: 'الإعدادات',
          subtitle:
              'إعدادات التطبيق والحساب.',
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

        _ProfileButton(
          icon: Icons.auto_awesome,
          title: 'الذكاء الاصطناعي',
          subtitle:
              'إعدادات الذكاء الاصطناعي.',
          onTap: () {},
        ),

        _ProfileButton(
          icon: Icons.notifications,
          title: 'التذكيرات',
          subtitle:
              'إدارة التنبيهات والتذكيرات.',
          onTap: () {},
        ),
      ],
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
          const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121722),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x22FFFFFF),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                const LinearGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFB15CFF),
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right),
      ),
    );
  }
}

// ============================================================
// SETTINGS
// ============================================================

class SettingsScreen
    extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor:
            const Color(0xFF0D1018),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          _SettingTile(
            icon: Icons.notifications,
            title: 'الإشعارات',
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.lock,
            title: 'الخصوصية والأمان',
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.language,
            title: 'اللغة',
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.info_outline,
            title: 'عن صاحبي AI',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SETTING TILE
// ============================================================

class _SettingTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121722),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color:
              const Color(0xFFFFD54F),
        ),
        title: Text(title),
        trailing:
            const Icon(Icons.chevron_right),
      ),
    );
  }
}
