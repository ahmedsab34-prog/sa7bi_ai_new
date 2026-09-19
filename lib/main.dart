import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'categories_screen.dart';
import 'khalasana_portal_screen.dart';
import 'settings_screen.dart';
import 'widgets/khalasana_portal.dart';

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
  State<MainContainerScreen> createState() =>
      _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int _currentIndex = 0;

  // مكان البوابة العائمة.
  // القيم نسبية من أعلى/يمين منطقة المحتوى.
  double _portalRight = 16;
  double _portalBottom = 18;

  bool _portalWasDragged = false;

  final List<Widget> _pages = const [
    HomeScreen(),
    CategoriesScreen(),
    ProfileScreen(),
  ];

  void _openKhalasana() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KhalasanaPortalScreen(),
      ),
    );
  }

  void _movePortal(DragUpdateDetails details) {
    setState(() {
      _portalWasDragged = true;

      _portalRight -= details.delta.dx;
      _portalBottom -= details.delta.dy;

      final size = MediaQuery.of(context).size;

      // حدود آمنة تقريبية حتى لا تخرج الأيقونة خارج الشاشة.
      const double portalWidth = 92;
      const double portalHeight = 112;

      final maxRight =
          math.max(8.0, size.width - portalWidth - 8);

      final maxBottom =
          math.max(8.0, size.height - portalHeight - 8);

      _portalRight =
          _portalRight.clamp(8.0, maxRight);

      _portalBottom =
          _portalBottom.clamp(8.0, maxBottom);
    });
  }

  void _endPortalDrag() {
    // نترك الإشارة للـtap داخل KhalasanaPortal.
    // إعادة الضبط تتم بعد انتهاء الحركة.
    Future<void>.delayed(
      const Duration(milliseconds: 80),
      () {
        if (mounted) {
          setState(() {
            _portalWasDragged = false;
          });
        }
      },
    );
  }

  void _handlePortalTap() {
    if (_portalWasDragged) {
      return;
    }

    _openKhalasana();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ==================================================
            // الصفحات الثلاث الأصلية — بدون تغيير
            // ==================================================
            IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),

            // ==================================================
            // البوابة العائمة
            // ==================================================
            Positioned(
              right: _portalRight,
              bottom: _portalBottom,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _movePortal,
                onPanEnd: (_) => _endPortalDrag(),
                child: KhalasanaPortal(
                  onTap: _handlePortalTap,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF211F1D),
        indicatorColor: const Color(0x664F421F),
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
      duration: const Duration(seconds: 6),
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

        final signalColor =
            HSVColor.fromAHSV(
              1,
              (185 + t * 170) % 360,
              0.82,
              1,
            ).toColor();

        final glowColor =
            HSVColor.fromAHSV(
              1,
              (42 + t * 45) % 360,
              0.72,
              1,
            ).toColor();

        return SizedBox(
          width: 78,
          height: 78,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 70 + pulse * 4,
                height: 70 + pulse * 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(0.35),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: signalColor.withOpacity(0.20),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              ClipOval(
                child: Image.asset(
                  'app_icon.png',
                  width: 74,
                  height: 74,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 16,
                top: 13,
                child: Container(
                  width: 8 + pulse * 4,
                  height: 8 + pulse * 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: signalColor.withOpacity(0.82),
                    boxShadow: [
                      BoxShadow(
                        color: signalColor.withOpacity(0.90),
                        blurRadius: 7 + pulse * 8,
                        spreadRadius: 1 + pulse * 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 2,
                top: 1,
                child: CustomPaint(
                  size: const Size(35, 27),
                  painter: _Sa7biSignalPainter(
                    progress: t,
                    color: signalColor,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipOval(
                    child: Align(
                      alignment: Alignment(
                        -1.2 + t * 2.4,
                        -0.2,
                      ),
                      child: Transform.rotate(
                        angle: -0.42,
                        child: Container(
                          width: 14,
                          height: 62,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.16),
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _Sa7biSignalPainter extends CustomPainter {
  final double progress;
  final Color color;

  _Sa7biSignalPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width * 0.50,
      size.height * 0.92,
    );

    for (int i = 0; i < 3; i++) {
      final phase =
          (progress + i * 0.18) % 1.0;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(
          0.25 + phase * 0.65,
        );

      final rect = Rect.fromCenter(
        center: center,
        width: size.width * (0.40 + i * 0.22),
        height: size.height * (0.50 + i * 0.24),
      );

      canvas.drawArc(
        rect,
        math.pi * 1.16,
        math.pi * 0.67,
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
      const Duration(milliseconds: 700),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
        padding: const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          24,
        ),
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
                        color: Color(0xFFFFD54F),
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر المتجر وشوف أحدث المنتجات والعروض.',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StoreButton(
                      title: 'Amazon',
                      icon: Icons.shopping_cart,
                      onTap: () => _openUrl(
                        'https://www.amazon.eg/',
                      ),
                    ),
                    _StoreButton(
                      title: 'Jumia',
                      icon: Icons.shopping_bag,
                      onTap: () => _openUrl(
                        'https://www.jumia.com.eg/',
                      ),
                    ),
                    _StoreButton(
                      title: 'Noon',
                      icon: Icons.store,
                      onTap: () => _openUrl(
                        'https://www.noon.com/egypt-ar/',
                      ),
                    ),
                    _StoreButton(
                      title: 'Facebook Shop',
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

          const SizedBox(height: 26),

          const Text(
            'آخر الأخبار',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 14),

          const _NewsCard(
            icon: Icons.public,
            title: 'أخبار وتقنيات جديدة',
            description:
                'هنا ستظهر الأخبار والمحتوى المهم من المصادر المختلفة.',
          ),

          const _NewsCard(
            icon: Icons.auto_awesome,
            title: 'أخبار الذكاء الاصطناعي',
            description:
                'آخر التطورات والأدوات الجديدة في عالم الذكاء الاصطناعي.',
          ),

          const _NewsCard(
            icon: Icons.devices,
            title: 'أخبار التكنولوجيا',
            description:
                'متابعة أهم أخبار الأجهزة والتطبيقات والتكنولوجيا.',
          ),

          const SizedBox(height: 10),

          const Text(
            'الفيديوهات القصيرة',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: const [
                _ShortVideoBox(
                  title: 'فيديو جديد',
                ),
                _ShortVideoBox(
                  title: 'Reels',
                ),
                _ShortVideoBox(
                  title: 'TikTok',
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
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _StoreButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(
        icon,
        color: const Color(0xFFFFD54F),
      ),
      label: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(
          color: Color(0x55FFD54F),
        ),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _NewsCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11141D),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0x332F3545),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(20),
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFFFFD54F),
                  Color(0xFFB45CFF),
                ],
              ),
            ),
            child: Icon(
              icon,
              color: Colors.black,
              size: 34,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textDirection:
                      TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  description,
                  textDirection:
                      TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 16,
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

  const _ShortVideoBox({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 125,
      margin:
          const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        gradient:
            const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF172B55),
            Color(0xFF30163D),
          ],
        ),
        border: Border.all(
          color: const Color(0x44FFD54F),
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
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

  static const String appShareLink =
      'https://github.com/ahmedsab34-prog/sa7bi_ai_new';

  Future<void> _shareApp() async {
    final message =
        'جرّب تطبيق صاحبي AI 🤖\n\n'
        'مساعدك الذكي في كل يوم.\n\n'
        '$appShareLink';

    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        24,
      ),
      children: [
        const AppHeader(),
        const SizedBox(height: 22),

        const Text(
          'حسابي',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'إدارة حسابك وإعدادات تطبيق صاحبي AI',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 24),

        _ProfileButton(
          icon: Icons.share,
          title: 'مشاركة التطبيق',
          subtitle:
              'شارك رابط صاحبي مع أصدقائك',
          onTap: _shareApp,
        ),

        _ProfileButton(
          icon: Icons.settings,
          title: 'الإعدادات',
          subtitle:
              'إعدادات التطبيق والاتصال بالذكاء الاصطناعي',
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
              'المساعد الذكي يعمل من خلال الخادم الآمن',
          onTap: () {
            _showMessage(
              context,
              'الذكاء الاصطناعي متصل من خلال Cloudflare Worker.',
            );
          },
        ),

        _ProfileButton(
          icon: Icons.notifications,
          title: 'التذكيرات',
          subtitle:
              'إدارة التنبيهات والتذكيرات',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const RemindersScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
        ),
      );
  }
}

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
      margin:
          const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0x333A4152),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 7,
        ),
        onTap: onTap,
        leading: Container(
          width: 58,
          height: 58,
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
            size: 29,
          ),
        ),
        title: Text(
          title,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white60,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white70,
          size: 30,
        ),
      ),
    );
  }
}

// ============================================================
// REMINDERS
// ============================================================

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF080A10),
      appBar: AppBar(
        title: const Text(
          'التذكيرات',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor:
            const Color(0xFF11141D),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          _ReminderTile(
            icon: Icons.notifications_active,
            title: 'التذكيرات اليومية',
            subtitle:
                'سيتم تفعيلها عند ربط نظام الإشعارات.',
          ),
          _ReminderTile(
            icon: Icons.access_time,
            title: 'مواعيد مخصصة',
            subtitle:
                'إضافة تذكيرات حسب اختيارك.',
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ReminderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF12151E),
      margin:
          const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.all(12),
        leading: Icon(
          icon,
          color: const Color(0xFFFFD54F),
          size: 30,
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
        ),
      ),
    );
  }
}
