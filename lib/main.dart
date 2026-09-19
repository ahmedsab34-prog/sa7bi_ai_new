import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'categories_screen.dart';
import 'khalasana_portal_screen.dart';
import 'settings_screen.dart';
import 'ai_service.dart';
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

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() =>
      _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  int index = 0;

  void openProfile() {
    setState(() => index = 2);
  }

  void openKhalasana() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const KhalasanaPortalScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onProfile: openProfile),
      const CategoriesScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(
              index: index,
              children: pages,
            ),
            Positioned(
              right: 15,
              bottom: 16,
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
          setState(() => index = value);
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

  const HomeScreen({
    super.key,
    required this.onProfile,
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
      setState(() => loadingNews = true);
    }

    final result = await AiService.getNews();

    if (!mounted) return;

    setState(() {
      news = result;
      loadingNews = false;
    });
  }

  Future<void> openLink(String url) async {
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);

    if (uri == null) return;

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadNews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          AppHeader(
            onProfileTap: widget.onProfile,
          ),
          const SizedBox(height: 16),
          const _WelcomeCard(),
          const SizedBox(height: 18),
          const Text(
            'آخر الأخبار',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 25,
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
            ...news.map(
              (item) => _NewsCard(
                item: item,
                onTap: () => openLink(item.link),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'تسوق بسرعة',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 23,
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
                icon: Icons.shopping_cart,
                url: 'https://www.amazon.eg/',
              ),
              _StoreButton(
                title: 'Jumia',
                icon: Icons.shopping_bag,
                url: 'https://www.jumia.com.eg/',
              ),
              _StoreButton(
                title: 'Noon',
                icon: Icons.store,
                url: 'https://www.noon.com/egypt-ar/',
              ),
              _StoreButton(
                title: 'Facebook',
                icon: Icons.facebook,
                url: 'https://www.facebook.com/marketplace/',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
            width: 51,
            height: 51,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF151820),
              border: Border.all(
                color: const Color(0xFFFFD76A),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33FFD76A),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFFFFD76A),
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

class Sa7biLogo extends StatefulWidget {
  const Sa7biLogo({super.key});

  @override
  State<Sa7biLogo> createState() => _Sa7biLogoState();
}

class _Sa7biLogoState extends State<Sa7biLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
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
            (math.sin(controller.value * math.pi * 2) + 1) / 2;

        return SizedBox(
          width: 86,
          height: 86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5BD9FF)
                          .withOpacity(0.10 + pulse * 0.08),
                      blurRadius: 25,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD76A)
                          .withOpacity(0.10 + pulse * 0.08),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: controller.value * math.pi * 2,
                child: Container(
                  width: 81,
                  height: 81,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        Color(0xFFFFD76A),
                        Color(0xFF5BD9FF),
                        Color(0xFF8B5CF6),
                        Color(0xFF49E6A8),
                        Color(0xFFFFD76A),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
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
              Positioned(
                right: 12,
                top: 7,
                child: Container(
                  width: 8 + pulse * 3,
                  height: 8 + pulse * 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF63E6FF),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF63E6FF)
                            .withOpacity(0.8),
                        blurRadius: 10 + pulse * 5,
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

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF211A0D),
            Color(0xFF11141D),
            Color(0xFF1D1527),
          ],
        ),
        border: Border.all(
          color: const Color(0x44FFD76A),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'أهلاً يا صاحبي 👋',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'اسأل، اتكلم، ابعت صورة أو افتح خلصانة AI.',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white60,
              height: 1.4,
            ),
          ),
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
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0x2238D9FF),
          child: Icon(
            Icons.newspaper_rounded,
            color: Color(0xFF63E6FF),
          ),
        ),
        title: Text(
          item.title,
          textDirection: TextDirection.rtl,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          item.source,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white54,
          ),
        ),
        trailing: const Icon(
          Icons.open_in_new_rounded,
          color: Color(0xFFFFD76A),
          size: 18,
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
    const appLink =
        'https://github.com/ahmedsab34-prog/sa7bi_ai_new';

    final text = Uri.encodeComponent(
      'جرّب تطبيق صاحبي AI 🤖\n'
      'مساعدك الذكي في كل يوم.\n'
      '$appLink',
    );

    await launchUrl(
      Uri.parse('https://wa.me/?text=$text'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        const Text(
          'حسابي',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(23),
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
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD76A),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: photo == null
                        ? const Icon(
                            Icons.person_rounded,
                            color: Color(0xFFFFD76A),
                            size: 48,
                          )
                        : Image.memory(
                            photo!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'صورتك الشخصية',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: choosePhoto,
                      icon: const Icon(Icons.photo),
                      label: const Text('الصورة'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: chooseReel,
                      icon: const Icon(Icons.movie),
                      label: const Text('ريلز'),
                    ),
                  ),
                ],
              ),
              if (reelName != null) ...[
                const SizedBox(height: 9),
                Text(
                  '🎬 $reelName',
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ProfileButton(
          icon: Icons.share_rounded,
          title: 'مشاركة التطبيق',
          subtitle: 'شارك صاحبي مع أصحابك',
          onTap: shareApp,
        ),
        _ProfileButton(
          icon: Icons.settings_rounded,
          title: 'الإعدادات',
          subtitle: 'إعدادات التطبيق والذكاء الاصطناعي',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsScreen(),
              ),
            );
          },
        ),
      ],
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
          width: 46,
          height: 46,
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
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
        ),
      ),
    );
  }
}
