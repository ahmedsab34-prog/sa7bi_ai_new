import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
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
  // معرفات الإعلانات الحقيقية الخاصة بك
  static const String bannerAdUnitId = 'ca-app-pub-9077658292229374/1672148581';
  static const String interstitialAdUnitId = 'ca-app-pub-9077658292229374/9768287146';
  static const String rewardedAdUnitId = 'ca-app-pub-9077658292229374/4621745555';

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  final TextEditingController _chatController = TextEditingController();
  final List<String> _chatMessages = [];

  @override
  void initState() {
    super.initState();
    _initBannerAd();
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  // 1. تهيئة وتحميل إعلان البانر
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

  // 2. تحميل الإعلان البيني (Interstitial)
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  // عرض الإعلان البيني بشكل ذكي عند الإرسال
  void _showInterstitialAd(VoidCallback onComplete) {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          onComplete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
          onComplete();
        },
      );
      _interstitialAd!.show();
    } else {
      onComplete();
    }
  }

  // 3. تحميل إعلان المكافأة (Rewarded)
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  // عرض إعلان المكافأة لفتح ميزات ذكاء اصطناعي إضافية
  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('مبارك! حصلت على نقاط ومميزات إضافية من صاحبي AI 🎁')),
          );
          _loadRewardedAd();
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإعلان غير جاهز حالاً، حاول بعد قليل.')),
      );
      _loadRewardedAd();
    }
  }

  // دالة التوجيه للتسويق بالعمولة (Affiliate Links)
  Future<void> _launchAffiliateLink(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard, color: Colors.amber),
            onPressed: _showRewardedAd,
            tooltip: 'احصل على مكافأة',
          ),
        ],
      ),
      body: Column(
        children: [
          // منطقة محادثة الذكاء الاصطناعي
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_chatMessages[index]),
                );
              },
            ),
          ),

          // قسم التوجيه للشراء والتسويق بالعمولة (Affiliate Offers)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1A1A1A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () => _launchAffiliateLink('https://www.jumia.com.eg'),
                  icon: const Icon(Icons.shopping_bag, size: 18),
                  label: const Text('عروض جوميا'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                  onPressed: () => _launchAffiliateLink('https://www.noon.com'),
                  icon: const Icon(Icons.flash_on, size: 18, color: Colors.black),
                  label: const Text('عروض نون', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),

          // حقل إدخال الرسائل
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF1F1F1F),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: const InputDecoration(
                      hintText: 'اسأل صاحبي AI أي شيء...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurpleAccent),
                  onPressed: () {
                    if (_chatController.text.trim().isNotEmpty) {
                      setState(() {
                        _chatMessages.add("أنت: ${_chatController.text}");
                        _chatMessages.add("صاحبي AI: أهلاً بك يا أحمد، أنا جاهز لمساعدتك بكامل طاقتي!");
                        _chatController.clear();
                      });
                      
                      // عرض الإعلان البيني عند الإرسال بشكل احترافي
                      _showInterstitialAd(() {});
                    }
                  },
                ),
              ],
            ),
          ),

          // مكان إعلان البانر في الأسفل
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
