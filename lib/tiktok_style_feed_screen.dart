import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'ai_service.dart';
import 'widgets/app_header.dart';

typedef ShortsLoader = Future<List<ShortVideoItem>> Function();

class TikTokStyleFeedScreen extends StatefulWidget {
  const TikTokStyleFeedScreen({
    super.key,
    this.onProfileTap,
    this.onAudioTap,
    this.shortsLoader,
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;
  final ShortsLoader? shortsLoader;

  @override
  State<TikTokStyleFeedScreen> createState() =>
      _TikTokStyleFeedScreenState();
}

class _TikTokStyleFeedScreenState
    extends State<TikTokStyleFeedScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();

  List<ShortVideoItem> _items = [];

  VideoPlayerController? _videoController;

  int _activeIndex = 0;
  int _videoGeneration = 0;

  bool _loading = true;
  bool _videoLoading = false;
  bool _videoFailed = false;
  bool _muted = false;
  bool _refreshing = false;
  bool _resumeAfterLifecycle = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadShorts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();

    final controller = _videoController;
    _videoController = null;

    if (controller != null) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _resumeAfterLifecycle = controller.value.isPlaying;
      unawaited(controller.pause());
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _resumeAfterLifecycle) {
      _resumeAfterLifecycle = false;
      unawaited(controller.play());
    }
  }

  Uri? _safeVideoUri(String value) {
    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      return null;
    }

    return uri;
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _stopVideo() async {
    _videoGeneration++;

    final previous = _videoController;
    _videoController = null;

    if (mounted) {
      setState(() {
        _videoLoading = false;
        _videoFailed = false;
      });
    }

    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {}
    }
  }

  Future<void> _loadShorts() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
      _loading = true;
      _error = null;
    });

    await _stopVideo();

    try {
      final loader = widget.shortsLoader;

      final loaded = await (
        loader == null
            ? AiService.getShorts()
            : loader()
      ).timeout(
        const Duration(seconds: 30),
      );

      final validItems = loaded
          .where(
            (item) =>
                item.videoUrl.trim().isNotEmpty &&
                _safeVideoUri(item.videoUrl) != null,
          )
          .toList(growable: false);

      if (!mounted) return;

      setState(() {
        _items = validItems;
        _activeIndex = 0;
        _loading = false;

        _error = validItems.isEmpty
            ? 'لا توجد مقاطع قصيرة متاحة حاليًا.'
            : null;
      });

      if (validItems.isNotEmpty) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }

        await _activateVideo(0);
      }
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تأخر تحميل المقاطع. حاول مرة أخرى.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل المقاطع القصيرة حاليًا.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _activateVideo(int index) async {
    if (!mounted ||
        index < 0 ||
        index >= _items.length) {
      return;
    }

    final item = _items[index];
    final uri = _safeVideoUri(item.videoUrl);

    final generation = ++_videoGeneration;

    final previous = _videoController;
    _videoController = null;

    setState(() {
      _activeIndex = index;
      _videoLoading = true;
      _videoFailed = false;
    });

    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {}
    }

    if (uri == null) {
      if (mounted && generation == _videoGeneration) {
        setState(() {
          _videoLoading = false;
          _videoFailed = true;
        });
      }
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: const {
        'Accept': '*/*',
      },
    );

    _videoController = controller;

    try {
      await controller.initialize().timeout(
        const Duration(seconds: 25),
      );

      if (!mounted ||
          generation != _videoGeneration ||
          !identical(_videoController, controller)) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();

      if (!mounted ||
          generation != _videoGeneration ||
          !identical(_videoController, controller)) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoLoading = false;
        _videoFailed = false;
      });
    } catch (_) {
      if (generation != _videoGeneration ||
          !identical(_videoController, controller)) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      _videoController = null;

      try {
        await controller.dispose();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _videoLoading = false;
          _videoFailed = true;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    if (!mounted ||
        index < 0 ||
        index >= _items.length) {
      return;
    }

    setState(() {
      _activeIndex = index;
    });

    unawaited(_activateVideo(index));
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }

      if (mounted) setState(() {});
    } catch (_) {
      _showMessage('تعذر التحكم في تشغيل الفيديو.');
    }
  }

  Future<void> _toggleMute() async {
    final controller = _videoController;

    setState(() {
      _muted = !_muted;
    });

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      await controller.setVolume(_muted ? 0 : 1);
    } catch (_) {
      _showMessage('تعذر تغيير مستوى الصوت.');
    }
  }

  Widget _videoSurface(int index) {
    final controller = _videoController;

    if (_activeIndex == index &&
        controller != null &&
        controller.value.isInitialized) {
      final size = controller.value.size;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayback,
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      );
    }

    if (_activeIndex == index && _videoLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF63E6FF),
        ),
      );
    }

    if (_activeIndex == index && _videoFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 44,
            ),
            const SizedBox(height: 10),
            const Text(
              'تعذر تشغيل هذا المقطع',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _activateVideo(index),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: Colors.white38,
        size: 60,
      ),
    );
  }

  Widget _buildVideoPage(
    ShortVideoItem item,
    int index,
  ) {
    final controller = _videoController;

    final playing = _activeIndex == index &&
        (controller?.value.isPlaying ?? false);

    final creator = item.creator.trim().isEmpty
        ? 'مقاطع قصيرة'
        : item.creator.trim();

    final description = item.description.trim();

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.thumbnail.trim().isNotEmpty &&
              _safeVideoUri(item.thumbnail) != null)
            Image.network(
              item.thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: Colors.black),
            ),

          _videoSurface(index),

          Positioned(
            top: 12,
            right: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                child: Text(
                  '${index + 1} / ${_items.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 10,
            bottom: 30,
            child: Column(
              children: [
                IconButton(
                  tooltip: _muted ? 'تشغيل الصوت' : 'كتم الصوت',
                  onPressed: _toggleMute,
                  icon: Icon(
                    _muted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                IconButton(
                  tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
                  onPressed: _togglePlayback,
                  icon: Icon(
                    playing
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 60,
            right: 14,
            bottom: 28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  10,
                  42,
                  10,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      creator,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF72D7FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.title.trim().isEmpty
                          ? 'مقطع قصير'
                          : item.title.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.4,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    const Row(
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: Color(0xFF72D7FF),
                          size: 14,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'مصدر المقاطع: MP3Quran',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_activeIndex == index &&
              !playing &&
              !_videoLoading &&
              !_videoFailed)
            const Center(
              child: Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white70,
                size: 64,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_library_outlined,
              color: Color(0xFF63E6FF),
              size: 58,
            ),
            const SizedBox(height: 14),
            const Text(
              'مفيش مقاطع قصيرة متاحة دلوقتي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'حاول تحديث المقاطع بعد قليل.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _refreshing ? null : _loadShorts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF63E6FF),
        ),
      );
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return PageView.builder(
      key: const ValueKey<String>('tiktok-style-short-feed'),
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _items.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return _buildVideoPage(
          _items[index],
          index,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                onProfileTap: widget.onProfileTap,
                onAudioTap: widget.onAudioTap,
              ),
              Container(
                height: 46,
                color: const Color(0xFF0E1421),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'مقاطع قصيرة • ستايل TikTok',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تحديث المقاطع',
                      onPressed: _refreshing ? null : _loadShorts,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF63E6FF),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }
}
