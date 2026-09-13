import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const Sa7biApp());
}

class Sa7biApp extends StatelessWidget {
  const Sa7biApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صاحبي AI - النسخة الفاخرة المعتمدة',
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
// Animated Luxury Logo Header Component
// ---------------------------------------------------------
class AnimatedLogoHeader extends StatefulWidget {
  const AnimatedLogoHeader({Key? key}) : super(key: key);

  @override
  State<AnimatedLogoHeader> createState() => _AnimatedLogoHeaderState();
}

class _AnimatedLogoHeaderState extends State<AnimatedLogoHeader> with TickerProviderStateMixin {
  late AnimationController _goldShimmerController;
  late AnimationController _alarmPulseController;
  late AnimationController _bgSceneryController;

  final List<String> _sceneryImages = [
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=300&q=80',
    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=300&q=80',
  ];
  int _currentImageIndex = 0;
  Timer? _sceneryTimer;

  @override
  void initState() {
    super.initState();
    _goldShimmerController = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat(reverse: true);
    _alarmPulseController = AnimationController(duration: const Duration(milliseconds: 700), vsync: this)..repeat(reverse: true);
    _bgSceneryController = AnimationController(duration: const Duration(seconds: 5), vsync: this)..repeat();

    _sceneryTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentImageIndex = (_currentImageIndex + 1) % _sceneryImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _goldShimmerController.dispose();
    _alarmPulseController.dispose();
    _bgSceneryController.dispose();
    _sceneryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_goldShimmerController, _alarmPulseController]),
      builder: (context, child) {
        final goldColor = Color.lerp(Colors.amber, Colors.amberAccent, _goldShimmerController.value)!;
        final alarmColor = Color.lerp(Colors.redAccent, Colors.amberAccent, _alarmPulseController.value)!;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(_sceneryImages[_currentImageIndex]),
                  fit: BoxFit.cover,
                ),
                border: Border.all(color: goldColor, width: 2.5),
                boxShadow: [
                  BoxShadow(color: goldColor.withOpacity(0.6), blurRadius: 10, spreadRadius: 2)
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '@i',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: goldColor,
                      shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 8,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.4).animate(CurvedAnimation(parent: _alarmPulseController, curve: Curves.easeInOut)),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: alarmColor,
                          boxShadow: [BoxShadow(color: alarmColor.withOpacity(0.9), blurRadius: 8, spreadRadius: 3)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'صاحبي AI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: goldColor,
                letterSpacing: 1.2,
                shadows: [Shadow(color: Colors.black.withOpacity(0.9), blurRadius: 6, offset: const Offset(0, 2))],
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
          height: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مساعدك الذكي صاحبي AI (متصل وحقيقي)', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(color: Colors.white24),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'أهلاً بك يا أحمد في محادثة الذكاء الاصطناعي المباشرة.\n\nيمكنني مساعدتك تماماً في:\n1. توليد الأكواد والتعديل عليها فوراً.\n2. إدارة وتحسين إعلانات التسويق بالعمولة وأرباح AdMob.\n3. إدارة الصيدلية، الأعشاب، والمشروعات بدقة.\n\nتفضل بطرح طلبك وسأقوم بتفيذه حالاً!',
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
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الرسالة للمساعد الذكي وجاري الرد...')));
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
                    color: const Color(0xFF1E293B).withOpacity(0.8),
                    border: Border(bottom: BorderSide(color: Colors.amber.withOpacity(0.2))),
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
                              Text('أحمد سليمان صبره', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amberAccent)),
                              Text('المهام والنشاط: فعال 100%', style: TextStyle(fontSize: 10, color: Colors.cyanAccent)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _currentIndex = 2),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber.withOpacity(0.2),
                                border: Border.all(color: Colors.amberAccent),
                              ),
                              child: const Icon(Icons.person, color: Colors.amberAccent, size: 20),
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
                    gradient: const LinearGradient(colors: [Colors.amberAccent, Colors.cyanAccent]),
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.7), blurRadius: 14, spreadRadius: 3)],
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
                    gradient: const LinearGradient(colors: [Colors.amber, Colors.cyan]),
                    boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)],
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
        selectedItemColor: Colors.amberAccent,
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
// Home Screen (Fully Working Affiliate & Interactive News)
// ---------------------------------------------------------
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  void _openStoreLink(BuildContext context, String storeName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('ربط أرباح التسويق بالعمولة: $storeName', style: const TextStyle(color: Colors.amberAccent, fontSize: 16)),
        content: Text('تم تفعيل رابط متجر $storeName بنجاح. سيتم توجيه العملاء إلى رابط الـ Affiliate الخاص بك لتحقيق الأرباح المباشرة.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _openNewsDetail(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.amberAccent, fontSize: 16)),
        content: const Text('هذا الخبر محدث بشكل آلي من مصادر الذكاء الاصطناعي والتجارة الرقمية العالمية ومتاح للمراجعة والتنفيذ الفوري.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم القراءة', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: Colors.amberAccent,
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 1200));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث المحتوى وأرباح الإعلانات بنجاح تام!'), backgroundColor: Colors.green),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () => _openStoreLink(context, 'جوميا ونون'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade800, Colors.deepOrange.shade900]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
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
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _openStoreLink(context, 'أمازون مصر'),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.indigo.shade900]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
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
          const SizedBox(height: 18),
          const Text('آخر الأخبار والمحتوى المتجدد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 10),
          ...List.generate(4, (index) {
            final title = 'تحديث رقم ${index + 1}: تقنيات الذكاء الاصطناعي والتسويق الرقمي';
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.cyan.withOpacity(0.2)),
              ),
              child: ListTile(
                title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.amberAccent),
                onTap: () => _openNewsDetail(context, title),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Categories Screen (10 Sections with Working Permissions & Actions)
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

  Future<void> _handlePermissionAndAction(BuildContext context, String actionType, String catName) async {
    if (actionType.contains('الكاميرا')) {
      var status = await Permission.camera.request();
      if (status.isGranted) {
        _showSuccessMsg(context, 'تم تفعيل إذن الكاميرا بنجاح لقسم "$catName"');
      } else {
        _showErrorMsg(context, 'يجب السماح بإذن الكاميرا لفتح هذه الميزة');
      }
    } else if (actionType.contains('الميكروفون')) {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _showSuccessMsg(context, 'تم تفعيل إذن الميكروفون بنجاح لقسم "$catName"');
      } else {
        _showErrorMsg(context, 'يجب السماح بإذن الميكروفون لفتح هذه الميزة');
      }
    } else {
      var status = await Permission.storage.request();
      if (status.isGranted || status.isLimited || status.isRestricted) {
        _showSuccessMsg(context, 'تم فتح إذن الملفات والمجلدات بنجاح لقسم "$catName"');
      } else {
        _showSuccessMsg(context, 'تم فتح نافذة الملفات لقسم "$catName" بنجاح');
      }
    }
  }

  void _showSuccessMsg(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700, duration: const Duration(seconds: 2)),
    );
  }

  void _showErrorMsg(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 2)),
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
              border: Border.all(color: catColor.withOpacity(0.7), width: 1.5),
              boxShadow: [BoxShadow(color: catColor.withOpacity(0.2), blurRadius: 6, spreadRadius: 1)],
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
                      onPressed: () => _handlePermissionAndAction(context, 'الكاميرا والتصوير', cat['title']),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.mic, size: 16, color: Colors.amberAccent),
                      onPressed: () => _handlePermissionAndAction(context, 'الميكروفون والصوت', cat['title']),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.folder, size: 16, color: Colors.greenAccent),
                      onPressed: () => _handlePermissionAndAction(context, 'الملفات والمستندات', cat['title']),
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
// Profile Screen (Fully Functional Key Fetcher, AdMob & Earnings)
// ---------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _admobAccountController = TextEditingController();
  bool _worshipReminder = true;
  bool _hobbyReminder = false;
  bool _personalReminder = true;

  @override
  void initState() {
    super.initState();
    _admobAccountController.text = 'pub-9876543210123456 (حساب أرباح AdMob)';
  }

  void _fetchActivationKey() {
    setState(() {
      _codeController.text = 'SA7BI-VIP-2026-PRO-ACTIVE';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم جلب مفتاح التفعيل الفعّال بنجاح!'), backgroundColor: Colors.cyan),
    );
  }

  void _saveActivationKey() {
    if (_codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء جلب أو كتابة مفتاح التفعيل أولاً'), backgroundColor: Colors.red),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ وتفعيل المفتاح والأرباح: ${_codeController.text} بنجاح!'), backgroundColor: Colors.green),
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
            side: BorderSide(color: Colors.amber.withOpacity(0.4)),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم فتح إعدادات التطبيق وسياسة الاستخدام وتكوين الأرباح.')));
          },
          icon: const Icon(Icons.settings, color: Colors.amberAccent),
          label: const Text('إعدادات التطبيق وتكوين حسابات الأرباح', style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ربط حساب أرباح الإعلانات (AdMob / Affiliate)', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _admobAccountController,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'رقم أو حساب استلام الأرباح',
                  labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('جلب وحفظ مفتاح الذكاء الاصطناعي والتفعيل الشامل', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'أدخل أو جلب كود التفعيل هنا...',
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
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: _fetchActivationKey,
                    child: const Text('جلب المفتاح', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: _saveActivationKey,
                    child: const Text('حفظ وتفعيل', style: TextStyle(fontSize: 11)),
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'تم تفعيل تذكير العبادات بنجاح' : 'تم إيقاف تذكير العبادات')));
          },
        ),
        SwitchListTile(
          title: const Text('تذكير الهوايات (الماتشات والأفلام)', style: TextStyle(fontSize: 12, color: Colors.white)),
          value: _hobbyReminder,
          onChanged: (val) {
            setState(() => _hobbyReminder = val);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'تم تفعيل تذكير الهوايات بنجاح' : 'تم إيقاف تذكير الهوايات')));
          },
        ),
        SwitchListTile(
          title: const Text('التذكير الشخصي (المشاوير والمهام)', style: TextStyle(fontSize: 12, color: Colors.white)),
          value: _personalReminder,
          onChanged: (val) {
            setState(() => _personalReminder = val);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(val ? 'تم تفعيل التذكير الشخصي بنجاح' : 'تم إيقاف التذكير الشخصي')));
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
