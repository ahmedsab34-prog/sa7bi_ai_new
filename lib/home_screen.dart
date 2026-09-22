import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';
import 'audio_player_service.dart';
import 'monetization_config.dart';
import 'news_webview_screen.dart';
import 'services/profile_service.dart';
import 'shorts_feed_screen.dart';

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

class _HomeScreenState
    extends State<HomeScreen> {
  bool loadingNews = true;
  List<NewsItem> news = [];

  @override
  void initState() {
    super.initState();
    loadNews();
  }

  Future<void> loadNews() async {
    if (mounted) {
      setState(() {
        loadingNews = true;
      });
    }

    try {
      final result =
          await AiService.getNews();

      if (!mounted) return;

      setState(() {
        news = result;
        loadingNews = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingNews = false;
      });
    }
  }

  void openNews(
    String url,
    String title,
  ) {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NewsWebViewScreen(
          url: cleanUrl,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color:
          const Color(0xFFFFD76A),
      backgroundColor:
          const Color(0xFF151923),
      onRefresh: loadNews,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          14,
          8,
          14,
          125,
        ),
        children: [
          AppHeader(
            onProfileTap:
                widget.onProfile,
            onAudioTap:
                widget.onAudio,
          ),

          const SizedBox(height: 12),

          const _WelcomeCard(),

          const SizedBox(height: 12),

          const _AffiliateBanner(),

          const SizedBox(height: 17),

          Row(
            children: [
              IconButton(
                onPressed:
                    loadNews,
                tooltip:
                    'تحديث الأخبار',
                icon: const Icon(
                  Icons
                      .refresh_rounded,
                  color: Color(
                    0xFFFFD76A,
                  ),
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

          if (loadingNews)
            const Padding(
              padding:
                  EdgeInsets.all(28),
              child: Center(
                child:
                    CircularProgressIndicator(
                  color: Color(
                    0xFFFFD76A,
                  ),
                ),
              ),
            )
          else if (news.isEmpty)
            _EmptyNews(
              onRetry: loadNews,
            )
          else
            ..._buildNewsList(),

          const SizedBox(height: 15),

          const Text(
            'تسوق بسرعة',
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.right,
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(height: 9),

          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _StoreButton(
                title: 'Amazon',
                icon: Icons
                    .shopping_cart_rounded,
                url:
                    MonetizationConfig
                        .amazonUrl,
              ),
              _StoreButton(
                title: 'Jumia',
                icon: Icons
                    .shopping_bag_rounded,
                url:
                    MonetizationConfig
                        .jumiaUrl,
              ),
              _StoreButton(
                title: 'Noon',
                icon:
                    Icons.store_rounded,
                url:
                    MonetizationConfig
                        .noonUrl,
              ),
              _StoreButton(
                title: 'Facebook',
                icon:
                    Icons.facebook_rounded,
                url:
                    MonetizationConfig
                        .facebookShopUrl,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNewsList() {
    final widgets =
        <Widget>[];

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

      if ((i + 1) % 5 == 0 &&
          i != news.length - 1) {
        widgets.add(
          const _ShortsEntryCard(),
        );
      }
    }

    return widgets;
  }
}

// ============================================================
// HEADER
// ============================================================

class AppHeader
    extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;

  const AppHeader({
    super.key,
    this.onProfileTap,
    this.onAudioTap,
  });

  @override
  State<AppHeader> createState() =>
      _AppHeaderState();
}

class _AppHeaderState
    extends State<AppHeader> {
  final ProfileService
      profileService =
      ProfileService.instance;

  @override
  void initState() {
    super.initState();

    profileService.changes
        .addListener(
      _profileChanged,
    );

    _initializeProfile();
  }

  Future<void>
      _initializeProfile() async {
    try {
      await profileService
          .initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  void _profileChanged() {
    if (!mounted) return;

    setState(() {});
  }

  @override
  void dispose() {
    profileService.changes
        .removeListener(
      _profileChanged,
    );

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        const Sa7biLogo(),

        const SizedBox(
          width: 9,
        ),

        const Expanded(
          child:
              _HeaderWelcome(),
        ),

        const SizedBox(
          width: 6,
        ),

        _AudioHeaderAction(
          onTap:
              widget.onAudioTap,
        ),

        const SizedBox(
          width: 5,
        ),

        _ProfileHeaderAction(
          name:
              profileService
                  .displayName,
          photo:
              profileService
                  .photoBytes,
          hasReel:
              profileService
                  .hasReel,
          onTap:
              widget.onProfileTap,
        ),
      ],
    );
  }
}

// ============================================================
// PROFILE HEADER ACTION
// ============================================================

class _ProfileHeaderAction
    extends StatelessWidget {
  final String name;
  final Uint8List? photo;
  final bool hasReel;
  final VoidCallback? onTap;

  const _ProfileHeaderAction({
    required this.name,
    required this.photo,
    required this.hasReel,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final safeName =
        name.trim().isEmpty
            ? 'صاحبي'
            : name.trim();

    return GestureDetector(
      onTap: onTap,
      behavior:
          HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        height: 61,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior:
                  Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFFFFD76A,
                      ),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color:
                            Color(
                          0x33FFD76A,
                        ),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photo ==
                            null
                        ? const ColoredBox(
                            color: Color(
                              0xFF10131C,
                            ),
                            child:
                                Icon(
                              Icons
                                  .person_rounded,
                              color:
                                  Color(
                                0xFFFFD76A,
                              ),
                              size: 22,
                            ),
                          )
                        : Image.memory(
                            photo!,
                            fit: BoxFit
                                .cover,
                            errorBuilder:
                                (
                              _,
                              __,
                              ___,
                            ) {
                              return const ColoredBox(
                                color:
                                    Color(
                                  0xFF10131C,
                                ),
                                child:
                                    Icon(
                                  Icons
                                      .person_rounded,
                                  color:
                                      Color(
                                    0xFFFFD76A,
                                  ),
                                  size: 22,
                                ),
                              );
                            },
                          ),
                  ),
                ),

                if (hasReel)
                  Positioned(
                    right: -3,
                    bottom: -2,
                    child:
                        Container(
                      width: 17,
                      height: 17,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape
                                .circle,
                        gradient:
                            const LinearGradient(
                          colors: [
                            Color(
                              0xFFFFD54F,
                            ),
                            Color(
                              0xFFB45CFF,
                            ),
                            Color(
                              0xFF63E6FF,
                            ),
                          ],
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFF10131C,
                          ),
                          width: 2,
                        ),
                      ),
                      child:
                          const Icon(
                        Icons
                            .play_arrow_rounded,
                        color:
                            Colors.black,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(
              height: 2,
            ),

            SizedBox(
              width: 60,
              child: Text(
                safeName,
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.center,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUDIO HEADER ACTION
// ============================================================

class _AudioHeaderAction
    extends StatelessWidget {
  final VoidCallback? onTap;

  const _AudioHeaderAction({
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ValueListenableBuilder<
        bool>(
      valueListenable:
          AudioController
              .isPlayingNotifier,
      builder: (
        context,
        playing,
        child,
      ) {
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 280,
            ),
            curve:
                Curves.easeOut,
            width: playing
                ? 47
                : 43,
            height: playing
                ? 47
                : 43,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  const Color(
                0xFF10131C,
              ),
              border:
                  Border.all(
                color:
                    const Color(
                  0xFF63E6FF,
                ).withOpacity(
                  playing
                      ? 1
                      : 0.75,
                ),
                width:
                    playing ? 2 : 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      const Color(
                    0xFF63E6FF,
                  ).withOpacity(
                    playing
                        ? 0.45
                        : 0.15,
                  ),
                  blurRadius:
                      playing
                          ? 20
                          : 13,
                  spreadRadius:
                      playing ? 2 : 0,
                ),
              ],
            ),
            child:
                _PulsingAudioIcon(
              playing: playing,
            ),
          ),
        );
      },
    );
  }
}

class _PulsingAudioIcon
    extends StatefulWidget {
  final bool playing;

  const _PulsingAudioIcon({
    required this.playing,
  });

  @override
  State<_PulsingAudioIcon>
      createState() =>
          _PulsingAudioIconState();
}

class _PulsingAudioIconState
    extends State<
        _PulsingAudioIcon>
    with
        SingleTickerProviderStateMixin {
  late final AnimationController
      controller;

  @override
  void initState() {
    super.initState();

    controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 900,
      ),
    );

    _updateAnimation();
  }

  @override
  void didUpdateWidget(
    cov
