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
  final VoidCallback onProfile;
  final VoidCallback onAudio;

  const HomeScreen({
    super.key,
    required this.onProfile,
    required this.onAudio,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController =
      ScrollController();

  bool loadingNews = true;

  List<NewsItem> news = [];

  double _savedScrollOffset = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _rememberScrollPosition,
    );

    unawaited(
      loadNews(
        showLoading: true,
        restorePosition: false,
      ),
    );
  }

  // ============================================================
  // SCROLL POSITION
  // ============================================================

  void _rememberScrollPosition() {
    if (!_scrollController.hasClients) {
      return;
    }

    _savedScrollOffset =
        _scrollController.offset;
  }

  void _restoreScrollPosition() {
    if (!_scrollController.hasClients) {
      return;
    }

    final max =
        _scrollController.position.maxScrollExtent;

    final target =
        _savedScrollOffset.clamp(0.0, max);

    _scrollController.jumpTo(target);
  }

  // ============================================================
  // NEWS
  // ============================================================

  Future<void> loadNews({
    bool showLoading = true,
    bool restorePosition = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        loadingNews = true;
      });
    }

    try {
      final result =
          await AiService.getNews();

      if (!mounted) {
        return;
      }

      setState(() {
        news = result;
        loadingNews = false;
      });

      if (restorePosition) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) {
          if (!mounted) return;
          _restoreScrollPosition();
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        loadingNews = false;
      });
    }
  }

  Future<void> _refreshNews() async {
    await loadNews(
      showLoading: false,
      restorePosition: true,
    );
  }

  // ============================================================
  // OPEN NEWS
  // ============================================================

  void openNews(
    String url,
    String title,
  ) {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewsWebViewScreen(
          url: cleanUrl,
          title: title,
        ),
      ),
    );
  }

  // ============================================================
  // OPEN SHORTS
  // ============================================================

  void _openShorts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const ShortsFeedScreen(),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _scrollController.removeListener(
      _rememberScrollPosition,
    );

    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      color: const Color(0xFFFFD76A),
      backgroundColor:
          const Color(0xFF151923),
      displacement: 35,
      onRefresh: _refreshNews,
      child: ListView(
        controller: _scrollController,
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          14,
          8,
          14,
          125,
        ),
        children: [
          // ====================================================
          // HEADER
          // ====================================================

          AppHeader(
            onProfileTap:
                widget.onProfile,
            onAudioTap:
                widget.onAudio,
          ),

          const SizedBox(height: 10),

          // ====================================================
          // ADMOB
          // ====================================================

          const _HomeAdBanner(),

          const SizedBox(height: 15),

          // ====================================================
          // NEWS HEADER
          // ====================================================

          Row(
            children: [
              IconButton(
                onPressed: () {
                  unawaited(
                    loadNews(
                      showLoading: true,
                      restorePosition: true,
                    ),
                  );
                },
                tooltip: 'تحديث الأخبار',
                icon: const Icon(
                  Icons.refresh_rounded,
                  color:
                      Color(0xFFFFD76A),
                ),
              ),

              const Spacer(),

              const Text(
                'آخر الأخبار',
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.right,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // ====================================================
          // NEWS
          // ====================================================

          if (loadingNews)
            const Padding(
              padding:
                  EdgeInsets.all(28),
              child: Center(
                child:
                    CircularProgressIndicator(
                  color:
                      Color(0xFFFFD76A),
                ),
              ),
            )
          else if (news.isEmpty)
            _EmptyNews(
              onRetry: () {
                unawaited(
                  loadNews(
                    showLoading: true,
                    restorePosition: true,
                  ),
                );
              },
            )
          else
            ..._buildNewsList(),

          const SizedBox(height: 20),

          // ====================================================
          // AFFILIATE SHOPPING
          // منفصل تمامًا عن AdMob
          // ====================================================

          const AffiliateCarousel(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD NEWS LIST
  // ============================================================

  List<Widget> _buildNewsList() {
    final widgets = <Widget>[];

    for (int i = 0;
        i < news.length;
        i++) {
      final item = news[i];

      widgets.add(
        _NewsCard(
          item: item,
          onTap: () {
            openNews(
              item.link,
              item.title,
            );
          },
        ),
      );

      // بعد كل 5 أخبار يظهر مدخل الريلز.
      if ((i + 1) % 5 == 0 &&
          i != news.length - 1) {
        widgets.add(
          _ShortsEntryCard(
            onTap: _openShorts,
          ),
        );
      }
    }

    return widgets;
  }
}

// ============================================================
// ADMOB HOME BANNER
// ============================================================

class _HomeAdBanner extends StatefulWidget {
  const _HomeAdBanner();

  @override
  State<_HomeAdBanner> createState() =>
      _HomeAdBannerState();
}

class _HomeAdBannerState
    extends State<_HomeAdBanner> {
  BannerAd? _bannerAd;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    unawaited(
      _loadBanner(),
    );
  }

  Future<void> _loadBanner() async {
    if (!MonetizationConfig
        .admobEnabled) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    if (!MonetizationConfig
        .homeBannerEnabled) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final ad =
          await AdsService.instance
              .loadBanner(
        adSize: AdSize.banner,
      );

      if (!mounted) {
        ad?.dispose();
        return;
      }

      setState(() {
        _bannerAd = ad;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!MonetizationConfig
            .admobEnabled ||
        !MonetizationConfig
            .homeBannerEnabled) {
      return const SizedBox.shrink();
    }

    final banner = _bannerAd;

    if (banner == null) {
      if (_loading) {
        return const SizedBox(
          height: 12,
        );
      }

      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        width: banner.size.width
            .toDouble(),
        height: banner.size.height
            .toDouble(),
        margin:
            const EdgeInsets.symmetric(
          vertical: 2,
        ),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(8),
          color:
              const Color(0xFF10131C),
        ),
        clipBehavior:
            Clip.antiAlias,
        child: AdWidget(
          ad: banner,
        ),
      ),
    );
  }
}

// ============================================================
// NEWS CARD
// ============================================================

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const _NewsCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        item.imageUrl
            .trim()
            .isNotEmpty;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF11141D),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Padding(
          padding:
              const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(
                Icons
                    .arrow_back_ios_new_rounded,
                color:
                    Color(0xFFFFD76A),
                size: 16,
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.title,
                      textDirection:
                          TextDirection.rtl,
                      textAlign:
                          TextAlign.right,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      item.source,
                      textDirection:
                          TextDirection.rtl,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                child: Container(
                  width: 68,
                  height: 58,
                  color:
                      const Color(
                    0xFF1A2030,
                  ),
                  child: hasImage
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) {
                            return const Icon(
                              Icons
                                  .newspaper_rounded,
                              color:
                                  Color(
                                0xFF63E6FF,
                              ),
                              size: 25,
                            );
                          },
                        )
                      : const Icon(
                          Icons
                              .newspaper_rounded,
                          color:
                              Color(
                            0xFF63E6FF,
                          ),
                          size: 25,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY NEWS
// ============================================================

class _EmptyNews
    extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyNews({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF11141D),
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'الأخبار مش متاحة دلوقتي 📡',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          TextButton(
            onPressed: onRetry,
            child:
                const Text('حاول تاني'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHORTS ENTRY
// ============================================================

class _ShortsEntryCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _ShortsEntryCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(
        top: 4,
        bottom: 13,
      ),
      height: 100,
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(20),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topRight,
          end:
              Alignment.bottomLeft,
          colors: [
            Color(0xFF2C1C42),
            Color(0xFF121725),
          ],
        ),
        border: Border.all(
          color:
              const Color(0x4463E6FF),
        ),
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            const SizedBox(
              width: 12,
            ),

            Container(
              width: 62,
              height: 72,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  17,
                ),
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xFF63E6FF),
                    Color(0xFFB45CFF),
                  ],
                ),
              ),
              child: const Icon(
                Icons
                    .play_arrow_rounded,
                color: Colors.black,
                size: 34,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            const Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    'ريلز صاحبي',
                    textDirection:
                        TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'شاهد الفيديوهات القصيرة واكتشف محتوى جديد',
                    textDirection:
                        TextDirection.rtl,
                    textAlign:
                        TextAlign.right,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.white60,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            const Icon(
              Icons
                  .arrow_back_ios_new_rounded,
              color:
                  Color(0xFFFFD76A),
              size: 16,
            ),

            const SizedBox(
              width: 10,
            ),
          ],
        ),
      ),
    );
  }
}
