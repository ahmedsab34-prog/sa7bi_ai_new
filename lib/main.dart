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
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF080812),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: Brightness.dark,
        ),
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

  final List<Widget> _screens = const [
    HomeScreen(),
    CategoriesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11111D),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFF11111D),
          indicatorColor: const Color(0x22FFD700),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(
                Icons.home,
                color: Color(0xFFFFD700),
              ),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(
                Icons.grid_view_rounded,
                color: Color(0xFFFFD700),
              ),
              label: 'الخدمات',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(
                Icons.person,
                color: Color(0xFFFFD700),
              ),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOGO
// ============================================================

class Sa7biLogo extends StatefulWidget {
  final double size;

  const Sa7biLogo({
    super.key,
    this.size = 58,
  });

  @override
  State<Sa7biLogo> createState() => _Sa7biLogoState();
}

class _Sa7biLogoState extends State<Sa7biLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  transform: GradientRotation(
                    _controller.value * 6.28318,
                  ),
                  colors: const [
                    Color(0xFFFFD700),
                    Color(0xFF00E5FF),
                    Color(0xFF9C27FF),
                    Color(0xFFFF1493),
                    Color(0xFFFFD700),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withOpacity(0.18),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.16),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF090914),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [
                          Color(0xFFFFF4A3),
                          Color(0xFFFFD700),
                          Color(0xFFFFA500),
                          Color(0xFFFFF4A3),
                        ],
                      ).createShader(bounds);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          '@i',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                            color: Colors.white,
                          ),
                        ),
                        Positioned(
                          right: 11,
                          top: 11,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _controller.value < 0.5
                                  ? Colors.cyanAccent
                                  : Colors.pinkAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 9),
        ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              colors: [
                Color(0xFFFFF4A3),
                Color(0xFFFFD700),
                Color(0xFFFFA500),
                Color(0xFFFFD700),
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'صاحبي',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          const Sa7biLogo(),
          const Spacer(),
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF171725),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.5),
              ),
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFFFFD700),
            ),
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _refresh() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final news = [
      'أحدث الأخبار والتحديثات المهمة',
      'أخبار التكنولوجيا والذكاء الاصطناعي',
      'أخبار الأسواق والتجارة الإلكترونية',
      'أخبار الرياضة والفرق المفضلة',
      'أهم الأخبار المحلية والعالمية',
      'تحديثات جديدة في عالم التطبيقات',
      'أخبار الهواتف والتصوير',
      'أخبار السيارات والتقنية',
      'أخبار الألعاب والترفيه',
      'آخر الأخبار العاجلة',
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const AppHeader(),

          // Advertisement / Shopping banner
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E1633),
                  Color(0xFF17172A),
                  Color(0xFF10232A),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_offer,
                  color: Color(0xFFFFD700),
                  size: 30,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'عروض وتسوق ذكي\nابحث عن أفضل الأسعار',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _open(
                    'https://www.amazon.eg',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('تسوق'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'آخر الأخبار',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD700),
              ),
            ),
          ),

          const SizedBox(height: 10),

          ...List.generate(news.length, (index) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12121E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.07),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF8A2BE2),
                            Color(0xFF00BCD4),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.newspaper,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      news[index],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'اضغط لعرض التفاصيل',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 15,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                ),

                if ((index + 1) % 5 == 0)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    height: 125,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF25153D),
                          Color(0xFF102A35),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 15),
                        const Icon(
                          Icons.play_circle_fill,
                          color: Colors.pinkAccent,
                          size: 48,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            index == 4
                                ? 'Reels • فيديوهات قصيرة'
                                : 'TikTok • فيديوهات قصيرة',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Color(0xFFFFD700),
                        ),
                        const SizedBox(width: 15),
                      ],
                    ),
                  ),
              ],
            );
          }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ============================================================
// CATEGORIES
// ============================================================

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  final List<Map<String, dynamic>> categories = const [
    {
      'title': 'المطبخ والبيت',
      'icon': Icons.kitchen,
      'color': Color(0xFFFF7043),
    },
    {
      'title': 'التاجر',
      'icon': Icons.storefront,
      'color': Color(0xFF42A5F5),
    },
    {
      'title': 'الصيدلية والأعشاب',
      'icon': Icons.local_pharmacy,
      'color': Color(0xFF66BB6A),
    },
    {
      'title': 'الصنايعي',
      'icon': Icons.handyman,
      'color': Color(0xFFFFCA28),
    },
    {
      'title': 'العبادات',
      'icon': Icons.mosque,
      'color': Color(0xFF26A69A),
    },
    {
      'title': 'الشراء والتسوق',
      'icon': Icons.shopping_bag,
      'color': Color(0xFFAB47BC),
    },
    {
      'title': 'التواصل الاجتماعي',
      'icon': Icons.groups,
      'color': Color(0xFF29B6F6),
    },
    {
      'title': 'الفضفضة الخاصة',
      'icon': Icons.lock,
      'color': Color(0xFFEC407A),
    },
    {
      'title': 'الهوايات والرياضة',
      'icon': Icons.sports_soccer,
      'color': Color(0xFFFFA726),
    },
    {
      'title': 'البودكاست',
      'icon': Icons.podcasts,
      'color': Color(0xFF7E57C2),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const AppHeader(),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 5, 16, 16),
          child: Text(
            'خدمات صاحبي AI',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFFD700),
            ),
          ),
        ),

        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final item = categories[index];

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'سيتم فتح قسم ${item['title']} في المرحلة التالية',
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item['color'].withOpacity(0.30),
                        const Color(0xFF11111D),
                      ],
                    ),
                    border: Border.all(
                      color: item['color'].withOpacity(0.55),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item['color'].withOpacity(0.10),
                        blurRadius: 18,
                        spreadRadius: 1,
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
                          color: item['color'].withOpacity(0.15),
                          border: Border.all(
                            color: item['color'].withOpacity(0.5),
                          ),
                        ),
                        child: Icon(
                          item['icon'],
                          size: 38,
                          color: item['color'],
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        item['title'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 25),
      ],
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _shareApp() async {
    final uri = Uri.parse(
      'https://github.com/ahmedsab34-prog/sa7bi_ai_new',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/?text=جرب%20تطبيق%20صاحبي%20AI',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppHeader(),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF21182F),
                Color(0xFF101923),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.30),
            ),
          ),
          child: const Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFF1B1B2A),
                child: Icon(
                  Icons.person,
                  size: 48,
                  color: Color(0xFFFFD700),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'حسابي',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'صاحبي AI',
                style: TextStyle(
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        _ProfileButton(
          icon: Icons.settings,
          title: 'الإعدادات',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'الإعدادات الكاملة سيتم تفعيلها في المرحلة التالية',
                ),
              ),
            );
          },
        ),

        _ProfileButton(
          icon: Icons.share,
          title: 'مشاركة التطبيق',
          onTap: _shareApp,
        ),

        _ProfileButton(
          icon: Icons.chat,
          title: 'مشاركة عبر WhatsApp',
          onTap: _openWhatsApp,
        ),

        _ProfileButton(
          icon: Icons.key,
          title: 'مفتاح الذكاء الاصطناعي',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                final controller = TextEditingController();

                return AlertDialog(
                  title: const Text('مفتاح Gemini AI'),
                  content: TextField(
                    controller: controller,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'ضع المفتاح هنا',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                );
              },
            );
          },
        ),

        const SizedBox(height: 14),

        const Text(
          'التذكيرات',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFFFFD700),
          ),
        ),

        const SizedBox(height: 8),

        _ReminderCard(
          icon: Icons.mosque,
          title: 'تذكير العبادات',
          subtitle:
              'الصلاة والأذكار ومواعيد العبادات',
        ),

        _ReminderCard(
          icon: Icons.sports,
          title: 'تذكير الهوايات',
          subtitle:
              'الرياضة والفرق والاهتمامات',
        ),

        _ReminderCard(
          icon: Icons.alarm,
          title: 'تذكير شخصي',
          subtitle:
              'موعد أو منبه أو رحلة أو
