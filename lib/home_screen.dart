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
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _news = [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNews({bool pullToRefresh = false}) async {
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

      final normalized = _normalizeNews(result);

      setState(() {
        _news = normalized;
        _lastUpdated = DateTime.now();
        _error = normalized.isEmpty
            ? 'مفيش أخبار متاحة دلوقتي. جرّب تحدّث الصفحة بعد شوية.'
            : null;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        if (_news.isEmpty) {
          _error =
              'الاتصال بالأخبار اتأخر. اتأكد من الإنترنت وحاول تاني.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_news.isEmpty) {
          _error =
              'مش قادرين نحمّل الأخبار دلوقتي. اتأكد من الإنترنت وحاول تاني.';
        }
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

  List<dynamic> _normalizeNews(dynamic result) {
    if (result is List) return result;

    if (result is Map) {
      final dynamic data =
          result['news'] ?? result['articles'] ?? result['data'];

      if (data is List) return data;
    }

    return <dynamic>[];
  }

  String _readString(
    dynamic item,
    List<String> keys, {
    String fallback = '',
  }) {
    if (item is! Map) return fallback;

    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return fallback;
  }

  String _formatUpdatedAt(DateTime? value) {
    if (value == null) return 'لم يتم التحديث بعد';

    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return 'آخر تحديث $hour:$minute';
  }

  Future<void> _openNews(dynamic item) async {
    final url = _readString(
      item,
      ['url', 'link', 'articleUrl', 'web_url'],
    );

    if (url.isEmpty || !mounted) return;

    final title = _readString(
      item,
      ['title', 'headline', 'name'],
      fallback: 'الأخبار',
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsWebViewScreen(
          title: title,
          url: url,
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
            onProfile: widget.onProfile,
            onAudio: widget.onAudio,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadNews(pullToRefresh: true),
              child: ListView(
                controller: _scrollController,
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
                  _buildFooter(),
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
            _error ?? 'تعذّر تحميل الأخبار.',
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

  Widget _buildNewsCard(dynamic item, int index) {
    final title = _readString(
      item,
      ['title', 'headline', 'name'],
      fallback: 'خبر ${index + 1}',
    );

    final description = _readString(
      item,
      ['description', 'summary', 'content', 'excerpt'],
      fallback: 'اضغط لقراءة تفاصيل الخبر.',
    );

    final source = _readString(
      item,
      ['source', 'publisher', 'author'],
      fallback: 'مصدر إخباري',
    );

    final imageUrl = _readString(
      item,
      ['image', 'imageUrl', 'image_url', 'thumbnail'],
    );

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
                      fontSize: 14
