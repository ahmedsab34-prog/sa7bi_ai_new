import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<NewsItem> _news = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews({
    bool pullToRefresh = false,
  }) async {
    if (!mounted) return;

    setState(() {
      if (pullToRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });

    try {
      final result = await AiService.getNews().timeout(
        const Duration(seconds: 25),
      );

      if (!mounted) return;

      setState(() {
        _news = result;
        _lastUpdated = DateTime.now();
        _error = result.isEmpty
            ? 'لا توجد أخبار متاحة حاليًا. حاول التحديث بعد قليل.'
            : null;
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error = _news.isEmpty
            ? 'تأخر تحميل الأخبار. تحقق من الإنترنت وحاول مرة أخرى.'
            : null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = _news.isEmpty
            ? 'تعذر تحميل الأخبار حاليًا. تحقق من الإنترنت وحاول مرة أخرى.'
            : null;
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
              onRefresh: () => _loadNews(pullToRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 112),
                children: [
                  _buildWelcomeCard(),
                  const SizedBox(height: 12),
                  const _HomeAdBanner(),
                  const SizedBox(height: 14),
                  _buildNewsHeader(),
                  const SizedBox(height: 10),
                  if (_loading && _news.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 38),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (_error != null && _news.isEmpty)
                    _buildErrorCard(),
                  if (_news.isEmpty && !_loading && _error == null)
                    _buildEmptyCard(),
                  ..._buildNewsItems(),
                  const SizedBox(height: 14),
                  _buildReelsEntry(),
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

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF202B43),
            Color(0xFF111827),
            Color(0xFF11141D),
          ],
        ),
        border: Border.all(
          color: const Color(0x33FFD76A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFD76A),
                  Color(0xFFEF9F45),
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF17130A),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بيك في صاحبي AI',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'أخبارك، صوتك، مساعدك الذكي وترفيهك في مكان واحد.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: Colors.white70,
                  ),
                ),
              ],
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
          size: 23,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'آخر الأخبار',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (_refreshing)
          const SizedBox(
            width: 16,
            height: 16,
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

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF251A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0x66FF7979),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFFF8B8B),
            size: 30,
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _loadNews(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF11141D),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'الأخبار هتظهر هنا لما تكون متاحة.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
    );
  }

  List<Widget> _buildNewsItems() {
    final widgets = <Widget>[];

    for (var i = 0; i < _news.length; i++) {
      final item = _news[i];

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildNewsCard(item, i),
        ),
      );

      if ((i + 1) % 5 == 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCompactReelsCard(),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildNewsCard(NewsItem item, int index) {
    final title = item.title.trim().isEmpty
        ? 'خبر ${index + 1}'
        : item.title.trim();

    final description = item.description.trim().isEmpty
        ? 'اضغط لقراءة تفاصيل الخبر.'
        : item.description.trim();

    final source = item.source.trim().isEmpty
        ? 'مصدر إخباري'
        : item.source.trim();

    final imageUrl = item.imageUrl.trim();

    return Material(
      color: const Color(0xFF11141D),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openNews(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              SizedBox(
                height: 155,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _buildNewsImagePlaceholder(),
                ),
              )
            else
              _buildNewsImagePlaceholder(),
            Padding(
              padding: const EdgeInsets.all(13),
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
                  const SizedBox(height: 7),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 9),
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
                        size: 15,
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
      height: 115,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF202B43),
            Color(0xFF151923),
          ],
        ),
      ),
      child: const Icon(
        Icons.newspaper_rounded,
        size: 35,
        color: Color(0x66FFD76A),
      ),
    );
  }

  Widget _buildCompactReelsCard() {
    return Material(
      color: const Color(0xFF171C2B),
      borderRadius: BorderRadius.circular(17),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openReels,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x3372D7FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Color(0xFF72D7FF),
                  size: 27,
                ),
              ),
              const SizedBox(width: 11),
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
                    SizedBox(height: 4),
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
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReelsEntry() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF322A57),
            Color(0xFF17213B),
          ],
        ),
        border: Border.all(
          color: const Color(0x4472D7FF),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: _openReels,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF72D7FF),
                        Color(0xFF8B7BFF),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFF101421),
                    size: 34,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ريلز صاحبي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'مقاطع قصيرة في مكان واحد',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ],
            ),
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
        if (mounted) {
          _loadBanner();
        }
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
          border: Border.all(
            color: const Color(0x22FFFFFF),
          ),
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
