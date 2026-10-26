
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'ai_service.dart';

class ShortsFeedScreen extends StatefulWidget {
  const ShortsFeedScreen({super.key});

  @override
  State<ShortsFeedScreen> createState() => _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  bool _loading = true;
  bool _refreshing = false;
  String _error = '';
  List<ShortVideoItem> _items = [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadShorts());
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
              : 'لم تصل فيديوهات جديدة؛ ما زالت الفيديوهات السابقة ظاهرة.';
        });
        return;
      }

      // تجاهل العناصر التي لا تحتوي على أي رابط صالح للعرض.
      final validItems = result.where((item) {
        final video = _validHttpUri(item.videoUrl);
        final thumbnail = _validHttpUri(item.thumbnail);
        return video != null || thumbnail != null;
      }).toList(growable: false);

      if (!mounted) return;

      if (validItems.isEmpty) {
        setState(() {
          _error = _items.isEmpty
              ? 'وصلت بيانات فيديوهات، لكن روابطها غير صالحة للعرض.'
              : 'روابط التحديث الجديد غير صالحة؛ ما زالت الفيديوهات السابقة ظاهرة.';
        });
        return;
      }

      setState(() {
        _items = validItems;
        _error = '';
      });
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
        appBar: AppBar(
          backgroundColor: const Color(0xFF090D17),
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
              tooltip: 'تحديث الفيديوهات',
              onPressed: _refreshing ? null : _loadShorts,
              icon: _refreshing
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFD76A),
                      ),
                    )
                  : const Icon(
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
    if (_loading && _items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFFFFD76A),
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
        color: const Color(0xFFFFD76A),
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
          color: const Color(0xFFFFD76A),
          onRefresh: _loadShorts,
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _items.length,
            itemBuilder: (context, index) {
              return _ShortItemCard(item: _items[index]);
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
                        color: Color(0xFFFFD76A),
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
              color: Color(0xFFFFD76A),
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

class _ShortItemCard extends StatelessWidget {
  final ShortVideoItem item;

  const _ShortItemCard({required this.item});

  Uri? _validHttpUri(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }

    return uri;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackground(context),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x33000000),
                Color(0x66000000),
                Color(0xE6000000),
              ],
              stops: [0.0, 0.48, 1.0],
            ),
          ),
        ),
        Positioned(
          right: 14,
          left: 14,
          bottom: 30,
          child: _buildInfo(),
        ),
        Positioned(
          left: 12,
          bottom: 85,
          child: _buildActions(context),
        ),
      ],
    );
  }

  Widget _buildBackground(BuildContext context) {
    final videoUri = _validHttpUri(item.videoUrl);
    final thumbnailUri = _validHttpUri(item.thumbnail);

    if (videoUri == null) {
      return _thumbnail(thumbnailUri?.toString() ?? '');
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _thumbnail(thumbnailUri?.toString() ?? ''),
        Center(
          child: Semantics(
            button: true,
            label: 'تشغيل ${item.title}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _openVideo(context, videoUri),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
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

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.creator.trim().isNotEmpty)
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
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
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Text(
          item.title.trim().isEmpty ? 'فيديو قصير' : item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        if (item.description.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            item.description,
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

  Widget _buildActions(BuildContext context) {
    final videoUri = _validHttpUri(item.videoUrl);

    return Column(
      children: [
        _ActionButton(
          icon: Icons.play_circle_fill_rounded,
          label: 'تشغيل',
          onTap: videoUri == null
              ? null
              : () => _openVideo(context, videoUri),
        ),
        const SizedBox(height: 12),
        _ActionButton(
          icon: Icons.open_in_new_rounded,
          label: 'فتح',
          onTap: videoUri == null
              ? null
              : () => _openVideo(context, videoUri),
        ),
      ],
    );
  }

  void _openVideo(BuildContext context, Uri uri) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ShortVideoWebView(
          title: item.title.trim().isEmpty ? 'ريلز صاحبي' : item.title,
          url: uri.toString(),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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

class _ShortVideoWebView extends StatefulWidget {
  final String title;
  final String url;

  const _ShortVideoWebView({
    required this.title,
    required this.url,
  });

  @override
  State<_ShortVideoWebView> createState() => _ShortVideoWebViewState();
}

class _ShortVideoWebViewState extends State<_ShortVideoWebView> {
  late final WebViewController _controller;

  int _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();

    final uri = Uri.tryParse(widget.url);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      _error = 'رابط الفيديو غير صالح.';
      _progress = 100;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _progress = 100;
              _error = null;
            });
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              _progress = 100;
              _error = 'تعذر فتح صفحة الفيديو. تحقق من الاتصال أو جرّب رابطًا آخر.';
            });
          },
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            if (target == null ||
                !target.hasAuthority ||
                (target.scheme != 'https' && target.scheme != 'http')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    unawaited(_loadInitialPage(uri));
  }

  Future<void> _loadInitialPage(Uri uri) async {
    try {
      await _controller.loadRequest(uri);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _progress = 100;
        _error = 'تعذر فتح رابط الفيديو.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'إعادة تحميل الفيديو',
            onPressed: () {
              setState(() {
                _error = null;
                _progress = 0;
              });
              unawaited(_controller.reload());
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFFFD76A),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_error == null)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.video_library_outlined,
                      color: Colors.white38,
                      size: 54,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _progress = 0;
                        });
                        unawaited(_controller.reload());
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          if (_error == null && _progress < 100)
            LinearProgressIndicator(
              value: _progress == 0 ? null : _progress / 100,
              color: const Color(0xFFFFD76A),
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}
