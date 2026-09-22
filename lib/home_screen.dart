import 'dart:async';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ai_service.dart';
import 'audio_player_service.dart';
import 'monetization_config.dart';
import 'news_webview_screen.dart';
import 'services/ads_service.dart';
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
  State<HomeScreen> createState() => _HomeScreenState();
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

  void _rememberScrollPosition() {
    if (!_scrollController.hasClients) {
      return;
    }

    _savedScrollOffset =
        _scrollController.offset;
  }

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

  Future<void> _refreshNews() async {
    await loadNews(
      showLoading: false,
      restorePosition: true,
    );
  }

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

  void _openShorts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const ShortsFeedScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController
        .removeListener(
      _rememberScrollPosition,
    );

    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      color: const Color(0xFFFFD76A),
      backgroundColor: const Color(0xFF151923),
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
          // الترتيب ثابت:
          // الشعار → الترحيب → الصوت → صورة الشخص
          // ====================================================

          AppHeader(
            onProfileTap:
                widget.onProfile,
            onAudioTap:
                widget.onAudio,
          ),

          const SizedBox(height: 10),

          // ====================================================
          // ADMOB BANNER
          // مباشرة أسفل الهيدر
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
