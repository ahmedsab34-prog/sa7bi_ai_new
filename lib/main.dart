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
// LOGO
// ============================================================

class Sa7biLogo extends StatefulWidget {
  const Sa7biLogo({super.key});

  @override
  State<Sa7biLogo> createState() => _Sa7biLogoState();
}

class _Sa7biLogoState extends State<Sa7biLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final Animation<double> _dotOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _rotation = Tween<double>(
      begin: 0,
      end: 6.283185307,
    ).animate(_controller);

    _dotOpacity = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: _rotation.value,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: GradientRotation(_rotation.value),
                    colors: const [
                      Color(0xFFFFD54F),
                      Color(0xFF00E5FF),
                      Color(0xFFB15CFF),
                      Color(0xFFFF4FD8),
                      Color(0xFFFFD54F),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55FFD54F),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(5),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10121A),
                  ),
                  child: Transform.rotate(
                    angle: -_rotation.value,
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: '@',
                              style: TextStyle(
                                color: Color(0xFFFFD76A),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFFFFB300),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            TextSpan(
                              text: 'i',
                              style: TextStyle(
                                color: const Color(0xFFFFD76A),
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color.lerp(
                                      Colors.transparent,
                                      const Color(0xFFFFF59D),
                                      _dotOpacity.value,
                                    )!,
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'صاحبي',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD76A),
                shadows: [
                  Shadow(
                    color: Color(0xFFFFB300),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 800));

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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          const AppHeader(),
          const SizedBox(height: 18),

          // Shopping / affiliate banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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

          // Reels / TikTok strip
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
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
                    icon: Icons.play_circle_fill,
                    onTap: () {},
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 20),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: const Color(0x22111111),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0x44FFD54F),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x22FFFFFF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
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
              crossAxisAlignment: CrossAxisAlignment.start,
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

class _ShortVideoBox extends StatelessWidget {
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
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: const Color(0xFFFFD54F),
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
// CATEGORIES / SERVICES
// ============================================================

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<_CategoryData> categories = [
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          sliver: SliverToBoxAdapter(
            child: const AppHeader(),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = categories[index];

                return _CategoryCard(
                  data: category,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceDetailScreen(
                          data: category,
                        ),
                      ),
                    );
                  },
                );
              },
              childCount: categories.length,
            ),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 25),
        ),
      ],
    );
  }
}

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

class _CategoryCard extends StatelessWidget {
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF202431),
              Color(0xFF10121A),
            ],
          ),
          border: Border.all(
            color: const Color(0x33FFD54F),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFD54F),
                    Color(0xFFB15CFF),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33FFD54F),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Icon(
                data.icon,
                size: 35,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: Color(0xFFFFD54F),
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

class ServiceDetailScreen extends StatelessWidget {
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
        backgroundColor: const Color(0xFF0D0F16),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF242836),
                  Color(0xFF11131C),
                ],
              ),
              border: Border.all(
                color: const Color(0x33FFD54F),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFFD54F),
                        Color(0xFFB15CFF),
                      ],
                    ),
                  ),
                  child: Icon(
                    data.icon,
                    size: 48,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _ActionTile(
            icon: Icons.camera_alt,
            title: 'صورة',
            subtitle: 'استخدم صورة للحصول على مساعدة وتحليل.',
            onTap: () {},
          ),

          _ActionTile(
            icon: Icons.videocam,
            title: 'فيديو',
            subtitle: 'استخدم فيديو لشرح المشكلة أو الطلب.',
            onTap: () {},
          ),

          _ActionTile(
            icon: Icons.mic,
            title: 'صوت',
            subtitle: 'تحدث بصوتك وسيتم تحويل كلامك إلى نص.',
            onTap: () {},
          ),

          _ActionTile(
            icon: Icons.chat_bubble,
            title: 'محادثة',
            subtitle: 'اكتب طلبك وتحدث مع المساعد.',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'المحادثة الذكية سيتم ربطها في مرحلة AI التالية.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0x22FFFFFF),
          ),
        ),
        tileColor: const Color(0xFF131620),
        leading: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
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
            fontSize: 17,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Color(0xFFFFD54F),
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _shareApp(BuildContext context) async {
    const appLink = 'https://github.com/ahmedsab34-prog/sa7bi_ai_new';

    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(
        'جرّب تطبيق صاحبي AI\n$appLink',
      )}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('مشاركة التطبيق'),
            content: const SelectableText(
              'https://github.com/ahmedsab34-prog/sa7bi_ai_new',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          );
        },
      );
    }
  }

  void _showMessage(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنًا'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 25),
      children: [
        const AppHeader(),
        const SizedBox(height: 25),

        Center(
          child: Column(
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 3,
                  ),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF292D3A),
                      Color(0xFF12141D),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: Color(0xFFFFD54F),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'حسابي',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'صاحبي AI',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        _ProfileButton(
          icon: Icons.settings,
          title: 'الإعدادات',
          subtitle: 'إعدادات التطبيق والمساعد الذكي',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            );
          },
        ),

        _ProfileButton(
          icon: Icons.share,
          title: 'مشاركة التطبيق',
          subtitle: 'شارك صاحبي مع أصدقائك',
          onTap: () => _shareApp(context),
        ),

        _ProfileButton(
          icon: Icons.chat,
          title: 'مفتاح الذكاء الاصطناعي',
          subtitle: 'إعداد وربط مفتاح AI',
          onTap: () {
            _showMessage(
              context,
              'مفتاح الذكاء الاصطناعي',
              'سيتم ربط إعداد مفتاح Gemini مع خدمة الذكاء الاصطناعي في المرحلة التالية.',
            );
          },
        ),

        const SizedBox(height: 20),

        const Text(
          'التذكيرات',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 10),

        _ReminderTile(
          icon: Icons.mosque,
          title: 'تذكير العبادات',
          subtitle:
              'الصلاة والأذكار والمواعيد التي تختارها.',
        ),

        _ReminderTile(
          icon: Icons.sports,
          title: 'تذكير الهوايات والرياضة',
          subtitle:
              'تذكير بالمباريات والهوايات والاهتمامات.',
        ),

        _ReminderTile(
          icon: Icons.alarm,
          title: 'التذكير الشخصي',
          subtitle:
              'منبه أو موعد أو رحلة أو ملاحظة شخصية.',
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF11141D),
            border: Border.all(
              color: const Color(0x22FFFFFF),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.verified_user,
                color: Color(0xFFFFD54F),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'التطبيق متصل ويعمل. سيتم إضافة المزايا المتقدمة تدريجيًا.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PROFILE BUTTON
// ============================================================

class _ProfileButton extends StatelessWidget {
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 7,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: Color(0x22FFFFFF),
          ),
        ),
        tileColor: const Color(0xFF12151E),
        leading: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
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
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 15,
          color: Color(0xFFFFD54F),
        ),
      ),
    );
  }
}

// ============================================================
// REMINDERS
// ============================================================

class _ReminderTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ReminderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends State<_ReminderTile> {
  bool enabled = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled
              ? const Color(0x55FFD54F)
              : const Color(0x22FFFFFF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFD54F),
                  Color(0xFFB15CFF),
                ],
              ),
            ),
            child: Icon(
              widget.icon,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: const Color(0xFFFFD54F),
            onChanged: (value) {
              setState(() {
                enabled = value;
              });
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SETTINGS
// ============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController =
      TextEditingController();

  bool _saved = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveKey() {
    setState(() {
      _saved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم حفظ الإعداد على شاشة التطبيق مؤقتًا.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        backgroundColor: const Color(0xFF0D0F16),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: const Color(0xFF12151E),
              border: Border.all(
                color: const Color(0x22FFFFFF),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFFFD54F),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'الذكاء الاصطناعي',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'مفتاح Gemini API',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'أدخل مفتاح API',
                    filled: true,
                    fillColor: const Color(0xFF080A10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveKey,
                    icon: const Icon(Icons.save),
                    label: Text(
                      _saved
                          ? 'تم الحفظ'
                          : 'حفظ مفتاح الذكاء الاصطناعي',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          ListTile(
            tileColor: const Color(0xFF12151E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            leading: const Icon(
              Icons.notifications,
              color: Color(0xFFFFD54F),
            ),
            title: const Text('الإشعارات'),
            subtitle: const Text(
              'سيتم تطوير نظام الإشعارات والتذكيرات.',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 15),
            onTap: () {},
          ),

          const SizedBox(height: 10),

          ListTile(
            tileColor: const Color(0xFF12151E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            leading: const Icon(
              Icons.security,
              color: Color(0xFFFFD54F),
            ),
            title: const Text('الخصوصية والأمان'),
            subtitle: const Text(
              'إعدادات الخصوصية والحماية.',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 15),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
