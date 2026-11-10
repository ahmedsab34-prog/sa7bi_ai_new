import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'ai_service.dart';
import 'widgets/app_header.dart';

class ShortsFeedScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;

  const ShortsFeedScreen({
    super.key,
    this.onProfileTap,
    this.onAudioTap,
  });

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  static const String _cacheKey = 'sa7bi_shorts_feed_cache_v1';
  bool _loading = true;
  bool _refreshing = false;
  String _error = '';

  int _activeIndex = 0;

  List<ShortVideoItem> _items = [];

  @override
  void initState() {
    super.initState();
    unawaited(_initializeShorts());
  }

  Future<void> _initializeShorts() async {
    await _loadCachedShorts();
    if (!mounted) return;
    await _loadShorts();
  }

  Future<void> _loadCachedShorts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson == null || cachedJson.trim().isEmpty) return;

      final decoded = jsonDecode(cachedJson);
      if (decoded is! List) return;

      final cachedItems = <ShortVideoItem>[];
      for (final raw in decoded) {
        if (raw is! Map) continue;

        final item = ShortVideoItem(
          id: raw['id']?.toString() ?? '',
          title: raw['title']?.toString() ?? '',
          creator: raw['creator']?.toString() ?? '',
          videoUrl: raw['videoUrl']?.toString() ?? '',
          thumbnail: raw['thumbnail']?.toString() ?? '',
          description: raw['description']?.toString() ?? '',
        );

        if (item.title.trim().isEmpty ||
            _validHttpUri(item.videoUrl) == null) {
          continue;
        }

        cachedItems.add(item);
      }

      if (!mounted || cachedItems.isEmpty) return;

      setState(() {
        _items = cachedItems;
        _activeIndex = 0;
        _loading = false;
        _error =
            'تم عرض قائمة الريلز المحفوظة. تشغيل الفيديو نفسه يحتاج اتصالًا بالإنترنت.';
      });
    } catch (_) {
      // فساد بيانات الكاش لا يمنع محاولة جلب القائمة من الإنترنت.
    }
  }

  Future<void> _saveCachedShorts(List<ShortVideoItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final playableItems = items.where((item) {
        return _validHttpUri(item.videoUrl) != null;
      }).toList(growable: false);

      final encoded = jsonEncode(
        playableItems.map((item) {
          return <String, String>{
            'id': item.id,
            'title': item.title,
            'creator': item.creator,
            'videoUrl': item.videoUrl,
            'thumbnail': item.thumbnail,
            'description': item.description,
          };
        }).toList(growable: false),
      );

      await prefs.setString(_cacheKey, encoded);
    } catch (_) {
      // تعذر حفظ القائمة لا يمنع عرض الفيديوهات الحالية.
    }
  }

  Future<void> _loadShorts() async {
    if (_refreshing || !mounted) return;

    setState(() {
      _refreshing = true;
      if (_items.isEmpty) _loading = true;
      _error = '';
    });

    try {
      final result = await AiService.getShorts().timeout(
        const Duration(seconds: 25),
      );

      if (!mounted) return;

      if (result.isEmpty) {
        setState(() {
          _error = _items.isEmpty
              ? 'لا توجد فيديوهات قصيرة متاحة حاليًا. اسحب الشاشة للتحديث أو حاول مرة أخرى.'
              : 'لم تصل فيديوهات جديدة؛ احتفظنا بالفيديوهات السابقة.';
        });
        return;
      }

      // الصورة المصغرة وحدها لا تعني وجود فيديو قابل للتشغيل.
      final validItems = result.where((item) {
        return _validHttpUri(item.videoUrl) != null;
      }).toList(growable: false);

      if (!mounted) return;

      if (validItems.isEmpty) {
        setState(() {
          _error = _items.isEmpty
              ? 'وصلت بيانات فيديوهات، لكن روابطها غير صالحة للعرض.'
              : 'روابط التحديث الجديد غير صالحة؛ احتفظنا بالفيديوهات السابقة.';
        });
        return;
      }

      setState(() {
        _items = validItems;
        _activeIndex = 0;
        _error = '';
      });
      unawaited(_saveCachedShorts(validItems));
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error = _items.isEmpty
            ? 'تأخر تحميل الفيديوهات بسبب بطء الاتصال. حاول مرة أخرى.'
            : 'الاتصال بطيء؛ احتفظنا بالفيديوهات السابقة.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = _items.isEmpty
            ? 'تعذر تحميل الفيديوهات حاليًا. تحقق من الإنترنت ثم أعد المحاولة.'
            : 'تعذر تحديث الفيديوهات؛ ما زالت الفيديوهات السابقة ظاهرة.';
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

  Uri? _validHttpUri(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    return uri;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF05070D),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  10,
                  4,
                  10,
                  2,
                ),
                child: AppHeader(
                  onProfileTap: widget.onProfileTap,
                  onAudioTap: widget.onAudioTap,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  14,
                  0,
                  8,
                  3,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'ريلز صاحبي',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تحديث الفيديوهات',
                      onPressed: _refreshing ? null : _loadShorts,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF67E8F9),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              color: Color(0xFF67E8F9),
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

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF67E8F9),
            ),
            SizedBox(height: 14),
            Text(
              'جاري تحميل الفيديوهات...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF67E8F9),
        onRefresh: _loadShorts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 130),
            const Icon(
              Icons.video_library_outlined,
              color: Colors.white30,
              size: 62,
            ),
            const SizedBox(height: 18),
            Text(
              _error.isEmpty
                  ? 'لا توجد فيديوهات قصيرة متاحة حاليًا.'
                  : _error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.7,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _refreshing ? null : _loadShorts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: const Color(0xFF67E8F9),
          onRefresh: _loadShorts,
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            onPageChanged: (index) {
              setState(() => _activeIndex = index);
            },
            itemBuilder: (context, index) {
              return _ShortItemCard(
                key: ValueKey<String>(
                  '$index:${_items[index].videoUrl}',
                ),
                item: _items[index],
                active: index == _activeIndex,
              );
            },
          ),
        ),
        if (_error.isNotEmpty)
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Material(
              color: const Color(0xEE182333),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
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
                        _error,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 30,
                        minHeight: 30,
                      ),
                      onPressed: _refreshing ? null : _loadShorts,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF67E8F9),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_refreshing && _items.isNotEmpty)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: Color(0xFF67E8F9),
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

class _ShortItemCard extends StatefulWidget {
  const _ShortItemCard({
    super.key,
    required this.item,
    required this.active,
  });

  final ShortVideoItem item;
  final bool active;

  @override
  State<_ShortItemCard> createState() => _ShortItemCardState();
}

class _ShortItemCardState extends State<_ShortItemCard> {
  VideoPlayerController? _controller;
  VoidCallback? _controllerListener;

  int _generation = 0;

  bool _loadingVideo = false;
  bool _isPlaying = false;

  String? _playbackError;

  Uri? _validHttpUri(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);

    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    return uri;
  }

  @override
  void initState() {
    super.initState();

    if (widget.active) {
      unawaited(_startVideo());
    }
  }

  @override
  void didUpdateWidget(covariant _ShortItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sourceChanged =
        oldWidget.item.videoUrl != widget.item.videoUrl;

    if (sourceChanged) {
      if (widget.active) {
        unawaited(_startVideo());
      } else {
        unawaited(_stopVideo());
      }
      return;
    }

    if (oldWidget.active != widget.active) {
      if (widget.active) {
        unawaited(_startVideo());
      } else {
        unawaited(_stopVideo());
      }
    }
  }

  Future<void> _startVideo() async {
    final generation = ++_generation;

    final previous = _controller;
    final previousListener = _controllerListener;

    _controller = null;
    _controllerListener = null;

    if (previous != null) {
      if (previousListener != null) {
        previous.removeListener(previousListener);
      }

      try {
        await previous.pause();
      } catch (_) {}

      try {
        await previous.dispose();
      } catch (_) {}
    }

    if (!mounted ||
        !widget.active ||
        generation != _generation) {
      return;
    }

    final uri = _validHttpUri(widget.item.videoUrl);

    if (uri == null) {
      setState(() {
        _loadingVideo = false;
        _isPlaying = false;
        _playbackError = null;
      });
      return;
    }

    setState(() {
      _loadingVideo = true;
      _isPlaying = false;
      _playbackError = null;
    });

    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
      ),
    );

    _controller = controller;

    void listener() {
      if (!mounted ||
          generation != _generation ||
          !identical(_controller, controller)) {
        return;
      }

      final value = controller.value;

      if (value.hasError) {
        setState(() {
          _loadingVideo = false;
          _isPlaying = false;
          _playbackError = 'تعذر تشغيل الفيديو من المصدر الحالي.';
        });
        return;
      }

      if (value.isInitialized) {
        final nextPlaying = value.isPlaying;

        if (_loadingVideo || _isPlaying != nextPlaying) {
          setState(() {
            _loadingVideo = false;
            _isPlaying = nextPlaying;
          });
        }
      }
    }

    _controllerListener = listener;
    controller.addListener(listener);

    try {
      await controller.initialize().timeout(
        const Duration(seconds: 20),
      );

      if (!mounted ||
          !widget.active ||
          generation != _generation ||
          !identical(_controller, controller)) {
        controller.removeListener(listener);
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.play();

      if (!mounted ||
          generation != _generation ||
          !identical(_controller, controller)) {
        return;
      }

      setState(() {
        _loadingVideo = false;
        _isPlaying = true;
        _playbackError = null;
      });
    } on TimeoutException {
      if (!mounted || generation != _generation) return;

      setState(() {
        _loadingVideo = false;
        _isPlaying = false;
        _playbackError = 'تأخر تشغيل الفيديو بسبب بطء الاتصال.';
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;

      setState(() {
        _loadingVideo = false;
        _isPlaying = false;
        _playbackError = 'لم يتمكن مشغل الفيديو من فتح هذا الرابط.';
      });
    }
  }

  Future<void> _stopVideo() async {
    final generation = ++_generation;

    final controller = _controller;
    final listener = _controllerListener;

    _controller = null;
    _controllerListener = null;

    if (controller != null) {
      if (listener != null) {
        controller.removeListener(listener);
      }

      try {
        await controller.pause();
      } catch (_) {}

      try {
        await controller.dispose();
      } catch (_) {}
    }

    if (!mounted || generation != _generation) return;

    setState(() {
      _loadingVideo = false;
      _isPlaying = false;
    });
  }

  Future<void> _togglePlayback() async {
    if (!widget.active) return;

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      await _startVideo();
      return;
    }

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _playbackError = 'تعذر تغيير حالة تشغيل الفيديو.';
      });
    }
  }

  Future<void> _openExternal() async {
    final uri = _validHttpUri(widget.item.videoUrl);
    if (uri == null) return;

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح رابط الفيديو خارج التطبيق.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح رابط الفيديو.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _generation++;

    final controller = _controller;
    final listener = _controllerListener;

    if (controller != null) {
      if (listener != null) {
        controller.removeListener(listener);
      }

      unawaited(controller.dispose());
    }

    _controller = null;
    _controllerListener = null;

    super.dispose();
  }

  Widget _buildThumbnail() {
    final uri = _validHttpUri(widget.item.thumbnail);

    if (uri == null) {
      return Container(
        color: const Color(0xFF111522),
        child: const Center(
          child: Icon(
            Icons.video_library_rounded,
            color: Colors.white24,
            size: 80,
          ),
        ),
      );
    }

    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFF111522),
          child: const Center(
            child: Icon(
              Icons.video_library_rounded,
              color: Colors.white24,
              size: 80,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedia() {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return _buildThumbnail();
    }

    final size = controller.value.size;

    if (size.width <= 0 || size.height <= 0) {
      return _buildThumbnail();
    }

    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    final creator = widget.item.creator.trim();
    final title = widget.item.title.trim();
    final description = widget.item.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (creator.isNotEmpty)
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF67E8F9),
                      Color(0xFFB45CFF),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.black,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  creator,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 9),
        Text(
          title.isEmpty ? 'فيديو قصير' : title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    final videoUri = _validHttpUri(widget.item.videoUrl);

    return Column(
      children: [
        _ActionButton(
          icon: _isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          label: _isPlaying ? 'إيقاف' : 'تشغيل',
          onTap: videoUri == null ? null : _togglePlayback,
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.open_in_new_rounded,
          label: 'فتح',
          onTap: videoUri == null ? null : _openExternal,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final canShowProgress =
        controller != null && controller.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlayback,
          child: _buildMedia(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x22000000),
                Color(0x33000000),
                Color(0xDD000000),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Positioned(
          right: 14,
          left: 14,
          bottom: 34,
          child: _buildInfo(),
        ),
        Positioned(
          left: 12,
          bottom: 95,
          child: _buildActions(),
        ),
        if (_loadingVideo)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF67E8F9),
                ),
              ),
            ),
          ),
        if (_playbackError != null)
          Positioned(
            top: 18,
            left: 16,
            right: 16,
            child: Material(
              color: const Color(0xDD182333),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF67E8F9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _playbackError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إعادة التشغيل',
                      onPressed: widget.active
                          ? () => unawaited(_startVideo())
                          : null,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF67E8F9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (canShowProgress)
          Positioned(
            bottom: 7,
            left: 14,
            right: 14,
            child: VideoProgressIndicator(
              controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF67E8F9),
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xAA10131C),
                  border: Border.fromBorderSide(
                    BorderSide(color: Colors.white24),
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
