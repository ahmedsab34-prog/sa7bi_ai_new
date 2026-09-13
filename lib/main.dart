import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'categories_screen.dart';
import 'chat_screen.dart';
import 'ai_service.dart';

void main() {
  runApp(const Sa7biAIApp());
}

class Sa7biAIApp extends StatelessWidget {
  const Sa7biAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sa7bi AI - صحبي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primarySwatch: Colors.blue,
      ),
      home: const MainContainerScreen(),
    );
  }
}

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({Key? key}) : super(key: key);

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
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
            const AppHeader(),
            Expanded(
              child: _screens[_currentIndex],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: 'الأقسام العشرة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'الصفحة الشخصية',
          ),
        ],
      ),
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1E293B),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [Colors.amber, Colors.orange, Colors.amberAccent, Colors.amber],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0F172A),
                    ),
                    child: const Center(
                      child: Text(
                        '@i',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'صحبي AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    'أحمد سليمان',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'التفاعلات: 120',
                    style: TextStyle(fontSize: 10, color: Colors.cyanAccent),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.cyan,
                child: Icon(Icons.person, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // زر سريع لفتح الشات الذكي
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          },
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.amber),
          label: const Text('ابدأ المحادثة مع المساعد الذكي صاحبي AI', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF334155), Color(0xFF1E293B)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.local_offer, size: 40, color: Colors.amber),
                SizedBox(height: 8),
                Text(
                  'عروض مميزة وتجار التطبيق - اضغط للشراء',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'آخر الأخبار والمحتوى المتجدد',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 10),
        ...List.generate(5, (index) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('خبر تكنولوجي أو عام رقم ${index + 1} - اضغط للتفاصيل داخل التطبيق'),
        )),
      ],
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
        const Text(
          'لوحة التحكم الشخصية والإعدادات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
          icon: const Icon(Icons.settings),
          label: const Text('إعدادات التطبيق ومفتاح التشغيل'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
        ),
      ],
    );
  }
}
