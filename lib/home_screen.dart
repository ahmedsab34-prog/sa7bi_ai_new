
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_service.dart';
import 'monetization_config.dart';
import 'news_webview_screen.dart';
import 'services/ads_service.dart';
import 'shorts_feed_screen.dart';
import 'widgets/affiliate_carousel.dart';
import 'widgets/app_header.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onProfile;
  final VoidCallback? onAudio;

  const HomeScreen({
    super.key,
    this.onProfile,
    this.onAudio,
  });

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  static const String _newsCacheKey = 'sa7bi_home_news_cache_v1';
  static const String _newsCacheTimeKey = 'sa7bi_home_news_cache_time_v1';

  List<NewsItem> _news = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeNews());
  }

  /// يعرض الأخبار المحفوظة أولًا، ثم يحاول جلب الأحدث من الإنترنت.
  Future<void> _initializeNews() async {
    await _loadCachedNews();

    if (!mounted) return;

    await _loadNews();
  }

  /// يستدعيها الشريط السفلي عند الضغط على الرئيسية مرة أخرى.
  Future<void> refreshNews() => _loadNews(pullToRefresh: true);

  Future<void> _loadCachedNews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_newsCacheKey);

      if (cachedJson == null || cachedJson.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(cachedJson);
      if (decoded is! List) return;

      final cachedItems = <NewsItem>[];

      for (final raw in decoded) {
        if (raw is! Map) continue;

        final item = NewsItem(
          title: raw['title']?.toString() ?? '',
          source: raw['source']?.toString() ?? 'الأخبار',
          link: raw['link']?.toString() ?? '',
          imageUrl: raw['imageUrl']?.toString() ?? '',
          description: raw['description']?.toString() ?? '',
          pubDate: raw['pubDate']?.toString() ?? '',
        );

        if (item.title.trim().isEmpty || item.link.trim().isEmpty) {
          continue;
        }

        final uri = Uri.tryParse(item.link.trim());
        if (uri == null ||
            (uri.scheme != 'https' && uri.scheme != 'http')) {
          continue;
        }

        cachedItems.add(item);
      }

      if (cachedItems.isEmpty || !mounted) return;

      final cachedTime = prefs.getInt(_newsCacheTimeKey);

      setState(() {
        _news = cachedItems;
        _lastUpdated = cachedTime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(cachedTime);
        _loading = false;
        _error = 'تعرض الأخبار المحفوظة لحين تحديثها من الإنترنت.';
      });
    } catch (_) {
      // تلف الكاش لا يمنع تحميل الأخبار من الإنترنت.
    }
  }

  Future<void> _saveCachedNews(
    List<NewsItem> items,
    DateTime savedAt,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final encoded = jsonEncode(
        items.map((item) {
          return <String, String>{
            'title': item.title,
            'source': item.source,
            'link': item.link,
            'imageUrl': item.imageUrl,
            'description': item.description,
            'pubDate': item.pubDate,
          };
        }).toList(),
      );

      await prefs.setString(_newsCacheKey, encoded);
      await prefs.setInt(
        _newsCacheTimeKey,
        savedAt.millisecondsSinceEpoch,
      );
    } catch (_) {
      // فشل حفظ الكاش لا يمنع عرض الأخبار التي وصلت من الخادم.
    }
  }

  Future<void> _loadNews({bool pullToRefresh = false}) async {
    if (!mounted || _refreshing) return;

    setState(() {
      _refreshing = true;
      if (_news.isEmpty) _loading = true;
      _error = null;
    });

    try {
      final result = await AiService.getNews().timeout(
        const Duration(seconds: 25),
      );

      if (!mounted) return;

      if (result.isNotEmpty) {
        final updatedAt = DateTime.now();

        setState(() {
          _news = result;
          _lastUpdated = updatedAt;
          _error = null;
        });

        unawaited(_saveCachedNews(result, updatedAt));
      } else {
        setState(() {
          if (_news.isEmpty) {
            _error =
                'لا توجد أخبار متاحة حاليًا. تحقق من الإنترنت وحاول مرة أخرى.';
          } else {
            _error =
                'تعذر تحديث الأخبار؛ ما زالت الأخبار المحفوظة ظاهرة.';
          }
        });
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error = _news.isEmpty
            ? 'تأخر تحميل الأخبار. تحقق من الإنترنت وحاول مرة أخرى.'
            : 'الاتصال بطيء؛ تعرض الأخبار المحفوظة لحين نجاح التحديث.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = _news.isEmpty
            ? 'تعذر تحميل الأخبار حاليًا. تحقق من الإنترنت وحاول مرة أخرى.'
            : 'تعذر تحديث الأخبار؛ ما زالت الأخبار المحفوظة ظاهرة.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) return 'لم يتم التحديث بعد';

    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return 'آخر تحديث $hour:$minute';
  }

  Future<void> _openNews(NewsItem item) async {
    final url = item.link.trim();
    if (url.isEmpty || !mounted) return;

    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsWebViewScreen(
          title: item.title,
          url: uri.toString(),
        ),
      ),
    );
  }

  void _openReels() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ShortsFeedScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          AppHeader(
            onProfileTap: widget.onProfile,
            onAudioTap: widget.onAudio,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshNews,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
                children: [
                  const _HomeAdBanner(),
                  const SizedBox(height: 12),
                  _buildNewsHeader(),
                  const SizedBox(height: 8),
                  if (_error != null && _news.isNotEmpty)
                    _buildOfflineStatus(),
                  if (_loading && _news.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 38),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null && _news.isEmpty) _buildErrorCard(),
                  if (_news.isEmpty && !_loading && _error == null)
                    _buildEmptyCard(),
                  ..._buildNewsItems(),
                  const SizedBox(height: 14),
                  const AffiliateCarousel(),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      _formatUpdatedAt(_lastUpdated),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsHeader() {
    return Row(
      children: [
        const Icon(
          Icons.newspaper_rounded,
          color: Color(0xFFFFD76A),
          size: 22,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'آخر الأخبار',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (_refreshing)
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text(
            _formatUpdatedAt(_lastUpdated),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
      ],
    );
  }

  Widget _buildOfflineStatus() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF182333),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x3372D7FF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFF72D7FF),
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
            tooltip: 'تحديث الأخبار',
            onPressed: _refreshing ? null : refreshNews,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFFFD76A),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF251A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x66FF7979)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFFF8B8B),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'تعذر تحميل الأخبار.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _refreshing ? null : refreshNews,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11141D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'الأخبار هتظهر هنا لما تكون متاحة.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  List<Widget> _buildNewsItems() {
    final widgets = <Widget>[];

    for (var i = 0; i < _news.length; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _buildNewsCard(_news[i], i),
        ),
      );

      // مدخل ريلز واحد بعد كل خمسة أخبار فقط.
      if ((i + 1) % 5 == 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCompactReelsCard(),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildNewsCard(NewsItem item, int index) {
    final title =
        item.title.trim().isEmpty ? 'خبر ${index + 1}' : item.title.trim();

    final description = item.description.trim().isEmpty
        ? 'اضغط لقراءة تفاصيل الخبر.'
        : item.description.trim();

    final source =
        item.source.trim().isEmpty ? 'مصدر إخباري' : item.source.trim();

    final imageUrl = item.imageUrl.trim();

    return Material(
      color: const Color(0xFF11141D),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openNews(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              SizedBox(
                height: 100,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildNewsImagePlaceholder(),
                ),
              )
            else
              _buildNewsImagePlaceholder(),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFD76A),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'اقرأ التفاصيل',
                        style: TextStyle(
                          color: Color(0xFF72D7FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 5),
                      Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF72D7FF),
                        size: 14,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsImagePlaceholder() {
    return Container(
      height: 82,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF202B43), Color(0xFF151923)],
        ),
      ),
      child: const Icon(
        Icons.newspaper_rounded,
        size: 30,
        color: Color(0x66FFD76A),
      ),
    );
  }

  Widget _buildCompactReelsCard() {
    return Material(
      color: const Color(0xFF171C2B),
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openReels,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x3372D7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF72D7FF),
                  size: 25,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'استراحة ريلز',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'افتح مقاطع الفيديو القصيرة',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white60,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAdBanner extends StatefulWidget {
  const _HomeAdBanner();

  @override
  State<_HomeAdBanner> createState() => _HomeAdBannerState();
}

class _HomeAdBannerState extends State<_HomeAdBanner> {
  BannerAd? _banner;
  bool _loading = false;
  bool _failed = false;
  int _attempts = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();

    if (MonetizationConfig.admobEnabled &&
        MonetizationConfig.homeBannerEnabled) {
      _loadBanner();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _loadBanner() async {
    if (!mounted || _loading || _banner != null) return;

    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      final ad = await AdsService.instance
          .loadBanner(adSize: AdSize.banner)
          .timeout(const Duration(seconds: 12));

      if (!mounted) {
        ad?.dispose();
        return;
      }

      if (ad == null) {
        _scheduleRetry();
        return;
      }

      setState(() {
        _banner = ad;
        _failed = false;
        _attempts = 0;
      });
    } catch (_) {
      _scheduleRetry();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _scheduleRetry() {
    if (!mounted) return;

    _failed = true;

    if (_attempts >= 3) return;

    _attempts++;
    _retryTimer?.cancel();

    _retryTimer = Timer(
      Duration(seconds: 4 * _attempts),
      () {
        if (mounted) unawaited(_loadBanner());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!MonetizationConfig.admobEnabled ||
        !MonetizationConfig.homeBannerEnabled) {
      return const SizedBox.shrink();
    }

    final banner = _banner;

    if (banner == null) {
      return Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF10141E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x22FFFFFF)),
        ),
        child: Text(
          _failed
              ? 'الإعلانات غير متاحة حاليًا'
              : 'مساحة إعلانية',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
          ),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}
