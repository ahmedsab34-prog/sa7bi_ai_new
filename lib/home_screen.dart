
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_service.dart';
import 'monetization_config.dart';
import 'news_webview_screen.dart';
import 'services/ads_service.dart';
import 'services/ai_news_service.dart' as network_news;
import 'shorts_feed_screen.dart';
import 'tiktok_style_feed_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/affiliate_carousel.dart';
import 'widgets/app_header.dart';
import 'widgets/home_news_card.dart';
import 'widgets/sa7bi_hero_lite_panel.dart';
import 'widgets/sa7bi_glass_surface.dart';
import 'widgets/short_video_entry_carousel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onProfile,
    this.onAudio,
  });

  final VoidCallback? onProfile;
  final VoidCallback? onAudio;

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  static const String _newsCacheKey =
      'sa7bi_home_news_cache_v1';

  static const String _newsCacheTimeKey =
      'sa7bi_home_news_cache_time_v1';

  static const Duration _autoRefreshInterval =
      Duration(minutes: 20);

  static const Duration _newsTimeout =
      Duration(seconds: 25);

  Timer? _autoRefreshTimer;
  final ScrollController _scrollController = ScrollController();

  List<NewsItem> _news = <NewsItem>[];

  bool _loading = true;
  bool _refreshing = false;

  String? _error;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _autoRefreshTimer = Timer.periodic(
      _autoRefreshInterval,
      (_) {
        if (!mounted ||
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) {
          return;
        }

        unawaited(
          _loadNews(pullToRefresh: true),
        );
      },
    );

    unawaited(_initializeNews());
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state != AppLifecycleState.resumed) return;

    final lastUpdate = _lastUpdated;

    final shouldRefresh = lastUpdate == null ||
        DateTime.now().difference(lastUpdate) >=
            _autoRefreshInterval;

    if (shouldRefresh) {
      unawaited(
        _loadNews(pullToRefresh: true),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _initializeNews() async {
    await _loadCachedNews();

    if (!mounted) return;

    await _loadNews();
  }

  Future<void> refreshNews() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    await _loadNews(pullToRefresh: true);
  }

  bool _isFreshNews(String publishedAt) {
    final parsed =
        network_news.AiNewsService.parseNewsDate(publishedAt);

    // بعض مصادر RSS لا ترسل تاريخ نشر صالحًا. يحتفظ Worker بهذه
    // الأخبار بعد الأخبار المؤرخة، لذلك لا نحذفها كلها من الصفحة الرئيسية.
    // الأخبار المؤرخة تظل خاضعة لحد السبعة أيام ولرفض التاريخ المستقبلي.
    if (parsed == null) return true;

    final now = DateTime.now().toUtc();
    final age = now.difference(parsed.toUtc());

    return !age.isNegative &&
        age <= const Duration(days: 7);
  }

  bool _isSafeHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());

    return uri != null &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.userInfo.isEmpty;
  }

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

        final title = raw['title']?.toString().trim() ?? '';
        final link = raw['link']?.toString().trim() ?? '';
        final publishedAt = raw['pubDate']?.toString() ?? '';

        if (title.isEmpty ||
            !_isSafeHttpUrl(link) ||
            !_isFreshNews(publishedAt)) {
          continue;
        }

        cachedItems.add(
          NewsItem(
            title: title,
            source: raw['source']?.toString() ?? 'الأخبار',
            link: link,
            imageUrl: raw['imageUrl']?.toString() ?? '',
            description: raw['description']?.toString() ?? '',
            pubDate: publishedAt,
          ),
        );
      }

      if (cachedItems.isEmpty || !mounted) return;

      final cachedTime = prefs.getInt(_newsCacheTimeKey);

      setState(() {
        _news = cachedItems;

        _lastUpdated = cachedTime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                cachedTime,
              );

        _loading = false;

        _error =
            'تعرض الأخبار المحفوظة لحين تحديثها من الإنترنت.';
      });
    } catch (_) {
      // الكاش التالف لا يمنع محاولة الاتصال بالخدمة.
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

      await prefs.setString(
        _newsCacheKey,
        encoded,
      );

      await prefs.setInt(
        _newsCacheTimeKey,
        savedAt.millisecondsSinceEpoch,
      );
    } catch (_) {
      // فشل حفظ الكاش لا يمنع عرض الأخبار الحالية.
    }
  }

  Future<void> _loadNews({
    bool pullToRefresh = false,
  }) async {
    if (!mounted || _refreshing) return;

    setState(() {
      _refreshing = true;

      if (_news.isEmpty) {
        _loading = true;
      }

      _error = null;
    });

    try {
      final networkResult =
          await network_news.AiNewsService.getNews(
        forceRefresh: pullToRefresh,
      ).timeout(_newsTimeout);

      final result = networkResult
          .where(
            (item) =>
                item.title.trim().isNotEmpty &&
                _isSafeHttpUrl(item.link) &&
                _isFreshNews(item.pubDate),
          )
          .map(
            (item) => NewsItem(
              title: item.title,
              source: item.source,
              link: item.link,
              imageUrl: item.imageUrl,
              description: item.description,
              pubDate: item.pubDate,
            ),
          )
          .toList(growable: false);

      if (!mounted) return;

      if (result.isNotEmpty) {
        final updatedAt = DateTime.now();

        setState(() {
          _news = result;
          _lastUpdated = updatedAt;
          _error = null;
        });

        unawaited(
          _saveCachedNews(result, updatedAt),
        );
      } else {
        setState(() {
          _error = _news.isEmpty
              ? 'لا توجد أخبار متاحة حاليًا. تحقق من الإنترنت وحاول مرة أخرى.'
              : 'تعذر تحديث الأخبار؛ ما زالت الأخبار المحفوظة ظاهرة.';
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

  String _formatNewsPublishedAt(String value) {
    final publishedAt =
        network_news.AiNewsService.parseNewsDate(value);

    if (publishedAt == null) {
      return 'وقت النشر غير متاح';
    }

    final local = publishedAt.toLocal();
    final now = DateTime.now();

    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'اليوم • $time';
    }

    final yesterday = now.subtract(
      const Duration(days: 1),
    );

    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'أمس • $time';
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return '$day/$month • $time';
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) {
      return 'لم يتم التحديث بعد';
    }

    final local = value.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return 'آخر تحديث $hour:$minute';
  }

  Future<void> _openNews(NewsItem item) async {
    final url = item.link.trim();

    if (!mounted || !_isSafeHttpUrl(url)) return;

    final uri = Uri.parse(url);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NewsWebViewScreen(
          title: item.title,
          url: uri.toString(),
        ),
      ),
    );
  }

  void _openReels() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ShortsFeedScreen(
          onProfileTap: widget.onProfile,
          onAudioTap: widget.onAudio,
        ),
      ),
    );
  }

  void _openTikTokStyleShorts() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TikTokStyleFeedScreen(
          onProfileTap: widget.onProfile,
          onAudioTap: widget.onAudio,
        ),
      ),
    );
  }

  List<Widget> _buildNewsItems() {
    final widgets = <Widget>[];

    for (var index = 0; index < _news.length; index++) {
      final item = _news[index];

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: HomeNewsCard(
            item: item,
            index: index,
            publishedLabel: _formatNewsPublishedAt(
              item.pubDate,
            ),
            onTap: () => _openNews(item),
          ),
        ),
      );

      // إدراج الريلز بعد كل خمسة أخبار.
      if ((index + 1) % 5 == 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: ShortVideoEntryCarousel(
              onReelsTap: _openReels,
              onShortsTap: _openTikTokStyleShorts,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildOfflineStatus() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Sa7biGlassSurface(
        radius: 15,
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 8,
        ),
        borderColor: Sa7biTheme.blue.withValues(alpha: 0.4),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF192B43),
            Color(0xFF111B30),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Sa7biTheme.cyan,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error ?? '',
                style: const TextStyle(
                  color: Sa7biTheme.textSecondary,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
            IconButton(
              tooltip: 'تحديث الأخبار',
              visualDensity: VisualDensity.compact,
              onPressed: _refreshing ? null : refreshNews,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Sa7biTheme.cyan,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Sa7biGlassSurface(
      radius: 19,
      borderColor: Sa7biTheme.danger.withValues(alpha: 0.45),
      gradient: const LinearGradient(
        colors: [
          Color(0xFF351D32),
          Color(0xFF1A172B),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Sa7biTheme.danger,
            size: 31,
          ),
          const SizedBox(height: 9),
          Text(
            _error ?? 'تعذر تحميل الأخبار.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Sa7biTheme.textPrimary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 11),
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
    return const Sa7biGlassSurface(
      radius: 18,
      child: Column(
        children: [
          Icon(
            Icons.newspaper_rounded,
            color: Sa7biTheme.textMuted,
            size: 29,
          ),
          SizedBox(height: 9),
          Text(
            'الأخبار هتظهر هنا لما تكون متاحة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: const _HomeAdBanner(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: Sa7biTheme.goldBright,
              backgroundColor: Sa7biTheme.surface,
              onRefresh: refreshNews,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  12,
                  7,
                  12,
                  118,
                ),
                children: [
                  const SizedBox(height: 6),

                  // الشخصية الوحيدة تظهر في البوابة العائمة العامة.
                  const Sa7biHeroLitePanel(),

                  HomeNewsSectionHeader(
                    title: 'آخر الأخبار',
                    subtitle: _formatUpdatedAt(_lastUpdated),
                    refreshing: _refreshing,
                    onRefresh: refreshNews,
                  ),
                  const SizedBox(height: 10),

                  if (_error != null && _news.isNotEmpty)
                    _buildOfflineStatus(),

                  if (_loading && _news.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 34),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Sa7biTheme.cyan,
                        ),
                      ),
                    ),

                  if (_error != null && _news.isEmpty)
                    _buildErrorCard(),

                  if (_news.isEmpty &&
                      !_loading &&
                      _error == null)
                    _buildEmptyCard(),

                  ..._buildNewsItems(),

                  const SizedBox(height: 14),
                  const AffiliateCarousel(),
                  const SizedBox(height: 14),

                  Center(
                    child: Text(
                      _formatUpdatedAt(_lastUpdated),
                      style: const TextStyle(
                        color: Sa7biTheme.textMuted,
                        fontSize: 9,
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
      unawaited(_loadBanner());
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();

    final banner = _banner;
    _banner = null;

    if (banner != null) {
      AdsService.instance.releaseBanner(banner);
    }

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
        if (ad != null) {
          AdsService.instance.releaseBanner(ad);
        }
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
        setState(() {
          _loading = false;
        });
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
          unawaited(_loadBanner());
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
      return Sa7biGlassSurface(
        radius: 14,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        borderColor: Sa7biTheme.border,
        child: SizedBox(
          height: 34,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _failed
                    ? Icons.info_outline_rounded
                    : Icons.campaign_rounded,
                color: Sa7biTheme.textMuted,
                size: 15,
              ),
              const SizedBox(width: 7),
              Text(
                _failed
                    ? 'الإعلانات غير متاحة حاليًا'
                    : 'مساحة إعلانية',
                style: const TextStyle(
                  color: Sa7biTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
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
