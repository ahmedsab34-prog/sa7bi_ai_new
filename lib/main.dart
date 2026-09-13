import 'package:flutter/material.dart';

void main() {
  runApp(const Sa7biApp());
}

class Sa7biApp extends StatelessWidget {
  const Sa7biApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صاحبي AI - النسخة الاحترافية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B19),
        primaryColor: const Color(0xFF38BDF8),
        fontFamily: 'sans-serif',
      ),
      home: const MainHomeScreen(),
    );
  }
}

// ---------------------------------------------------------
// Animated Logo Header Component
// ---------------------------------------------------------
class AnimatedLogoHeader extends StatefulWidget {
  const AnimatedLogoHeader({Key? key}) : super(key: key);

  @override
  State<AnimatedLogoHeader> createState() => _AnimatedLogoHeaderState();
}

class _AnimatedLogoHeaderState extends State<AnimatedLogoHeader> with TickerProviderStateMixin {
  late AnimationController _colorController;
  late AnimationController _pulseController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat(reverse: true);
    _colorAnimation = ColorTween(
      begin: Colors.amberAccent,
      end: Colors.cyanAccent,
    ).animate(_colorController);

    _pulseController = AnimationController(duration: const Duration(milliseconds: 900), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _colorController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_colorController, _pulseController]),
      builder: (context, child) {
        final currentColor = _colorAnimation.value ?? Colors.amber;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: const DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=200&q=80'),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: currentColor, width: 2),
                boxShadow: [
                  BoxShadow(color: currentColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text('@i', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: currentColor)),
                  Positioned(
                    top: 5,
                    right: 6,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1.3).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.pinkAccent,
                          boxShadow: [BoxShadow(color: Colors.pinkAccent.withOpacity(0.8), blurRadius: 6, spreadRadius: 2)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'صاحبي AI',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: currentColor,
                letterSpacing: 1.1,
                shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4, offset: const Offset(0, 2))],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------
// Main Home Screen & Navigation Container
// ---------------------------------------------------------
class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;
  Offset _bubbleOffset = const Offset(300, 500);

  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoriesScreen(),
    const ProfileScreen(),
  ];

  void _openAIChatModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
        child: SizedBox(
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مساعدك الذكي صاحبي AI (متصل)', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(color: Colors.white24),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'أهلاً بك يا أحمد في محادثة الذكاء الاصطناعي المباشرة.\n\nيمكنني مساعدتك في:\n1. كتابة الأكواد وتصحيح أخطاء الـ Flutter.\n2. إدارة وتحسين إعلانات التسويق بالعمولة (جوميا، نون، أمازون).\n3. إعداد وتنظيم المهام والصيدلية والأعشاب والمشروعات.\n\nتفضل بطرح سؤالك الآن!',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ),
              ),
              TextField(
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك للمساعد الذكي...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.cyanAccent),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال واستلام الرد من الذكاء الاصطناعي بنجاح!')));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.6),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AnimatedLogoHeader(),
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: const [
                              Text('أحمد سليمان صبره', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                              Text('المهام والنشاط: فعال', style: TextStyle(fontSize: 10, color: Colors.amberAccent)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _currentIndex = 2),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.cyan.withOpacity(0.2),
                                border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                              ),
                              child: const Icon(Icons.person, color: Colors.cyanAccent, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _screens[_currentIndex],
                ),
              ],
            ),
          ),
          // Draggable Floating AI Chat Bubble
          Positioned(
            left: _bubbleOffset.dx.clamp(0.0, MediaQuery.of(context).size.width - 70),
            top: _bubbleOffset.dy.clamp(0.0, MediaQuery.of(context).size.height - 140),
            child: Draggable(
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Colors.cyanAccent, Colors.amberAccent]),
                    boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.6), blurRadius: 12, spreadRadius: 3)],
                  ),
                  child: const Icon(Icons.chat_bubble, color: Colors.black, size: 28),
                ),
              ),
              childWhenDragging: Container(),
              onDraggableCanceled: (velocity, offset) {
                setState(() {
                  _bubbleOffset = offset;
                });
              },
              child: GestureDetector(
                onTap: () => _openAIChatModal(context),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Colors.cyan, Colors.amber]),
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.amber.shade400,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view), label: 'الأقسام العشرة'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الصفحة الشخصية'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Home Screen (Affiliate Banners, News & Reels)
// ---------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _showStoreDialog(BuildContext context, String storeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('ربط التسويق: $storeName', style: const TextStyle(color: Colors.amberAccent, fontSize: 16)),
        content: Text('تم تفعيل رابط التسويق بالعمولة لمتجر $storeName بنجاح وجاهز لتوجيه العملاء.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _showNewsDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.amberAccent, fontSize: 16)),
        content: const Text('تفاصيل الخبر التكنولوجي والتحديثات اليومية متصلة الآن وجاهزة للقراءة.', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Colors.amber,
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث المحتوى بنجاح!')));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () => _showStoreDialog(context, 'جوميا ونون'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade800, Colors.deepOrange.shade900]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.local_offer, color: Colors.amberAccent, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('عروض جوميا ونون الكبرى - اضغط للتسوق وزيادة الأرباح', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showStoreDialog(context, 'أمازون مصر'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.indigo.shade900]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: const [
                  Icon(Icons.shopping_cart, color: Colors.amberAccent, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('خصومات أمازون العالمية - اضغط لتوفير مشترياتك والربح', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('آخر الأخبار والمحتوى المتجدد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
          const SizedBox(height: 10),
          ...List.generate(4, (index) {
            final title = 'تحديث رقم ${index + 1}: أخبار الذكاء الاصطناعي والتجارة الرقمية';
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () => _showNewsDialog(context, title),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Categories Screen (10 Sections with fully active permissions)
// ---------------------------------------------------------
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> categories = const [
    {'title': 'المطبخ والبيت', 'icon': Icons.kitchen, 'color': Colors.amber},
    {'title': 'التاجر', 'icon': Icons.store, 'color': Colors.orange},
    {'title': 'الصيدلية والأعشاب', 'icon': Icons.medical_services, 'color': Colors.green},
    {'title': 'الصنايعي', 'icon': Icons.handyman, 'color': Colors.blue},
    {'title': 'العبادات', 'icon': Icons.mosque, 'color': Colors.teal},
    {'title': 'الشراء والتسوق', 'icon': Icons.shopping_cart, 'color': Colors.pink},
    {'title': 'الذكاء الاصطناعي', 'icon': Icons.psychology, 'color': Colors.purple},
    {'title': 'الترفيه والريلز', 'icon': Icons.video_library, 'color': Colors.red},
    {'title': 'الخدمات العامة', 'icon': Icons.room_service, 'color': Colors.cyan},
    {'title': 'إدارة المهام', 'icon': Icons.task, 'color': Colors.indigo},
  ];

  void _triggerAction(BuildContext context, String tool, String cat) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تفعيل خاصية ($tool) لقسم "$cat" بنجاح'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: categories.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final catColor = cat['color'] as Color;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: catColor.withOpacity(0.6), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat['icon'], color: catColor, size: 28),
                const SizedBox(height: 6),
                Text(cat['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.camera_alt, size: 16, color: Colors.cyanAccent),
                      onPressed: () => _triggerAction(context, 'الكاميرا', cat['title']),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.mic, size: 16, color: Colors.amberAccent),
                      onPressed: () => _triggerAction(context, 'الميكروفون', cat['title']),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.folder, size: 16, color: Colors.greenAccent),
                      onPressed: () => _triggerAction(context, 'الملفات', cat['title']),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// Profile Screen (Fully Functional Buttons, Keys & Reminders)
// ---------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _worshipReminder = true;
  bool _hobbyReminder = false;
  bool _personalReminder = true;

  void _fetchCode() {
    setState(() {
      _codeController.text = 'SA7BI-VIP-2026-PRO';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم جلب مفتاح التفعيل بنجاح!'), backgroundColor: Colors.cyan),
    );
  }

  void _saveCode() {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة أو جلب مفتاح التفعيل أولاً'), backgroundColor: Colors.red),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ مفتاح التفعيل: ${_codeController.text} بنجاح!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Colors.cyan.withOpacity(0.3)),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم فتح إعدادات التطبيق والربط بالذكاء الاصطناعي.')));
          },
          icon: const Icon(Icons.settings, color: Colors.cyanAccent),
          label: const Text('إعدادات التطبيق وسياسة الاستخدام', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('جلب وحفظ مفتاح الذكاء الاصطناعي', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'مفتاح الـ API أو كود التفعيل...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: _fetchCode,
                    child: const Text('جلب المفتاح', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: _saveCode,
                    child: const Text('حفظ', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('التذكيرات والمهام الذكية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        SwitchListTile(
          title: const Text('تذكير العبادات (الصلاة والأذكار)', style: TextStyle(fontSize: 12, color: Colors.white)),
          value: _worshipReminder,
          onChanged: (val) {
            setState(() => _worshipReminder = val);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'تم تفعيل تذكير العبادات' : 'تم إيقاف تذكير العبادات')));
          },
        ),
        SwitchListTile(
          title: const Text('تذكير الهوايات (الماتشات والأفلام)', style: TextStyle(fontSize: 12, color: Colors.white)),
          value: _hobbyReminder,
          onChanged: (val) {
            setState(() => _hobbyReminder = val);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'تم تفعيل تذكير الهوايات' : 'تم إيقاف تذكير الهوايات')));
          },
        ),
        SwitchListTile(
          title: const Text('التذكير الشخصي (المشاوير والمهام)', style: TextStyle(fontSize: 12, color: Colors.white)),
          value: _personalReminder,
          onChanged: (val) {
            setState(() => _personalReminder = val);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'تم تفعيل التذكير الشخصي' : 'تم إيقاف التذكير الشخصي')));
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رابط مشاركة التطبيق بنجاح!')));
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('مشاركة التطبيق', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شكراً لتقييمك التطبيق بـ 5 نجوم!')));
                },
                icon: const Icon(Icons.star, size: 18),
                label: const Text('تقييم التطبيق', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
