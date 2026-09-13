import 'package:flutter/material.dart';

void main() {
  runApp(const Sa7biApp());
}

class Sa7biApp extends StatelessWidget {
  const Sa7biApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صاحبي AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF38BDF8),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CategoriesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.5),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.amber.shade400, Colors.cyan],
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)
                          ],
                          border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Text('@i', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                            Positioned(
                              top: 6,
                              right: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.greenAccent,
                                  boxShadow: [BoxShadow(color: Colors.green, blurRadius: 4, spreadRadius: 2)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'صاحبي',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text('أحمد سليمان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          Text('التفاعلات: 120', style: TextStyle(fontSize: 11, color: Colors.amberAccent)),
                        ],
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.cyan.withOpacity(0.2),
                            border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.person, color: Colors.cyanAccent, size: 22),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF1E293B),
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.chat_bubble_outline, color: Colors.amber, size: 28),
                SizedBox(width: 12),
                Text('AI ابدأ المحادثة مع المساعد الذكي صاحبي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.indigo.shade800]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.local_offer, color: Colors.amberAccent, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Text('عروض مميزة وتجار التطبيق - اضغط للشراء وزيادة الدخل', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('آخر الأخبار والمحتوى المتجدد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
          const SizedBox(height: 10),
          ...List.generate(8, (index) {
            if (index > 0 && index % 5 == 0) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.video_collection, color: Colors.purpleAccent),
                    SizedBox(width: 8),
                    Text('شريط ريلز / تيك توك تفاعلي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }
            return Card(
              color: const Color(0xFF1E293B),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text('خبر تكنولوجي أو عام رقم ${index + 1} - اضغط للتفاصيل داخل التطبيق', style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                onTap: () {},
              ),
            );
          }),
        ],
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('العشرة AI أقسام صاحبي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              itemCount: categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (cat['color'] as Color).withOpacity(0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: (cat['color'] as Color).withOpacity(0.1), blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat['icon'], color: cat['color'], size: 32),
                      const SizedBox(height: 8),
                      Text(cat['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.camera_alt, size: 14, color: Colors.grey),
                          SizedBox(width: 6),
                          Icon(Icons.mic, size: 14, color: Colors.grey),
                          SizedBox(width: 6),
                          Icon(Icons.chat, size: 14, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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
          onPressed: () {},
          icon: const Icon(Icons.settings, color: Colors.cyanAccent),
          label: const Text('إعدادات التطبيق وسياسة الاستخدام'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تفعيل الأكواد والعروض', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'اكتب كود التفعيل هنا...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: () {}, child: const Text('جلب')),
                  const SizedBox(width: 4),
                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () {}, child: const Text('حفظ')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('التذكيرات والمهام الذكية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('تذكير العبادات (الصلاة والأذكار)', style: TextStyle(fontSize: 13, color: Colors.white)),
          value: true,
          onChanged: (val) {},
        ),
        SwitchListTile(
          title: const Text('تذكير الهوايات (الماتشات والأفلام)', style: TextStyle(fontSize: 13, color: Colors.white)),
          value: false,
          onChanged: (val) {},
        ),
        SwitchListTile(
          title: const Text('التذكير الشخصي (المشاوير والمهام)', style: TextStyle(fontSize: 13, color: Colors.white)),
          value: true,
          onChanged: (val) {},
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                onPressed: () {},
                icon: const Icon(Icons.share),
                label: const Text('مشاركة التطبيق'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800),
                onPressed: () {},
                icon: const Icon(Icons.star),
                label: const Text('تقييم التطبيق'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
