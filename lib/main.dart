import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint("Ads init error: $e");
  }
  runApp(const Sa7biAiApp());
}

class Sa7biAiApp extends StatelessWidget {
  const Sa7biAiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صاحبي AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String bannerAdUnitId = 'ca-app-pub-9077658292229374/1672148581';
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {"sender": "ai", "text": "أهلاً بك يا أحمد! أنا صاحبي AI، جاهز لمساعدتك بكل طاقتى."}
  ];

  @override
  void initState() {
    super.initState();
    _initBannerAd();
  }

  void _initBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صاحبي AI - المساعد الذكي'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1F1F1F),
      ),
      body: Column(
        children: [
          // قائمة الشات
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["sender"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple[700] : const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg["text"] ?? ''),
                  ),
                );
              },
            ),
          ),

          // أزرار التسويق بالعمولة (نون وجوميا)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1A1A1A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () => _launchUrl('https://www.jumia.com.eg'),
                  icon: const Icon(Icons.shopping_bag, size: 18),
                  label: const Text('عروض جوميا'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                  onPressed: () => _launchUrl('https://www.noon.com'),
                  icon: const Icon(Icons.flash_on, size: 18, color: Colors.black),
                  label: const Text('عروض نون', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),

          // خانة إدخال الرسائل
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF1F1F1F),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurpleAccent),
                  onPressed: () {
                    if (_chatController.text.trim().isNotEmpty) {
                      final text = _chatController.text;
                      setState(() {
                        _messages.add({"sender": "user", "text": text});
                        _messages.add({
                          "sender": "ai",
                          "text": "أنا أستمع إليك يا أحمد، جارٍ معالجة طلبك..."
                        });
                        _chatController.clear();
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // مكان إعلان البانر إن وجد
          if (_isBannerAdLoaded && _bannerAd != null)
            SizedBox(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}
