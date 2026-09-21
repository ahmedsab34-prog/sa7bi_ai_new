import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ai_service.dart';

class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  State<ShortsFeedScreen> createState() =>
      _ShortsFeedScreenState();
}

class _ShortsFeedScreenState
    extends State<ShortsFeedScreen> {
  bool _loading = true;
  String _error = '';

  List<ShortVideoItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadShorts();
  }

  Future<void> _loadShorts() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    try {
      final result =
          await AiService.getShorts();

      if (!mounted) return;

      setState(() {
        _items = result;
        _loading = false;

        if (result.isEmpty) {
          _error =
              'لا توجد فيديوهات قصيرة متاحة حاليًا.';
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'تعذر تحميل الفيديوهات حاليًا.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            const Color(0xFF05070D),
        appBar: AppBar(
          backgroundColor:
              Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'ريلز صاحبي',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _loadShorts,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFFFFD76A),
              ),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFD76A),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return RefreshIndicator(
        color: const Color(0xFFFFD76A),
        onRefresh: _loadShorts,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            const Icon(
              Icons.video_library_outlined,
              color: Colors.white30,
              size: 60,
            ),
            const SizedBox(height: 18),
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 30,
              ),
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: ElevatedButton.icon(
                onPressed: _loadShorts,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'إعادة المحاولة',
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFFD76A),
      onRefresh: _loadShorts,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _items.length,
        itemBuilder: (
          context,
          index,
        ) {
          return _ShortItemCard(
            item: _items[index],
          );
        },
      ),
    );
  }
}

class _ShortItemCard
    extends StatelessWidget {
  final ShortVideoItem item;

  const _ShortItemCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackground(context),

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x33000000),
                Color(0x66000000),
                Color(0xE6000000),
              ],
              stops: [
                0.0,
                0.48,
                1.0,
              ],
            ),
          ),
        ),

        Positioned(
          right: 14,
          left: 14,
          bottom: 30,
          child: _buildInfo(context),
        ),

        Positioned(
          left: 12,
          bottom: 85,
          child: _buildActions(context),
        ),
      ],
    );
  }

  Widget _buildBackground(
    BuildContext context,
  ) {
    final videoUrl =
        item.videoUrl.trim();

    final thumbnail =
        item.thumbnail.trim();

    if (videoUrl.isEmpty) {
      return _thumbnail(thumbnail);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnail.isNotEmpty)
          _thumbnail(thumbnail)
        else
          Container(
            color:
                const Color(0xFF111522),
          ),

        Center(
          child: GestureDetector(
            onTap: () {
              _openVideo(
                context,
                videoUrl,
              );
            },
            child: Container(
              width: 76,
              height: 76,
              decoration:
                  const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xAA000000),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnail(String url) {
    if (url.isEmpty) {
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
      url,
      fit: BoxFit.cover,
      errorBuilder:
          (_, __, ___) {
        return Container(
          color:
              const Color(0xFF111522),
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

  Widget _buildInfo(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        if (item.creator
            .trim()
            .isNotEmpty)
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      LinearGradient(
                    colors: [
                      Color(0xFFFFD76A),
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
                  item.creator,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

        const SizedBox(height: 10),

        Text(
          item.title,
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),

        if (item.description
            .trim()
            .isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            item.description,
            maxLines: 3,
            overflow:
                TextOverflow.ellipsis,
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

  Widget _buildActions(
    BuildContext context,
  ) {
    return Column(
      children: [
        _ActionButton(
          icon:
              Icons.play_circle_fill_rounded,
          label: 'تشغيل',
          onTap: () {
            final url =
                item.videoUrl.trim();

            if (url.isEmpty) return;

            _openVideo(
              context,
              url,
            );
          },
        ),

        const SizedBox(height: 12),

        _ActionButton(
          icon: Icons.open_in_new_rounded,
          label: 'فتح',
          onTap: () {
            final url =
                item.videoUrl.trim();

            if (url.isEmpty) return;

            _openVideo(
              context,
              url,
            );
          },
        ),
      ],
    );
  }

  void _openVideo(
    BuildContext context,
    String url,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ShortVideoWebView(
          title: item.title,
          url: url,
        ),
      ),
    );
  }
}

class _ActionButton
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xAA10131C),
              border: Border.fromBorderSide(
                BorderSide(
                  color: Colors.white24,
                ),
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
    );
  }
}

class _ShortVideoWebView
    extends StatefulWidget {
  final String title;
  final String url;

  const _ShortVideoWebView({
    required this.title,
    required this.url,
  });

  @override
  State<_ShortVideoWebView> createState() =>
      _ShortVideoWebViewState();
}

class _ShortVideoWebViewState
    extends State<_ShortVideoWebView> {
  late final WebViewController
      _controller;

  int progress = 0;

  @override
  void initState() {
    super.initState();

    _controller =
        WebViewController()
          ..setJavaScriptMode(
            JavaScriptMode.unrestricted,
          )
          ..setBackgroundColor(
            Colors.black,
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (value) {
                if (!mounted) return;

                setState(() {
                  progress = value;
                });
              },
            ),
          )
          ..loadRequest(
            Uri.parse(widget.url),
          );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
          ),
          if (progress < 100)
            const LinearProgressIndicator(
              color: Color(0xFFFFD76A),
              backgroundColor:
                  Colors.transparent,
            ),
        ],
      ),
    );
  }
}
