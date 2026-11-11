
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'services/social_reels_service.dart';
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
  State<ShortsFeedScreen> createState() =>
      _ShortsFeedScreenState();
}

class _ShortsFeedScreenState extends State<ShortsFeedScreen> {
  final SocialReelsService _service =
      SocialReelsService.instance;

  final ImagePicker _picker = ImagePicker();

  final PageController _pageController = PageController();

  List<SocialReel> _reels = [];

  VideoPlayerController? _videoController;

  String? _activeReelId;

  int _activeIndex = 0;

  bool _loading = true;
  bool _refreshing = false;
  bool _uploading = false;
  bool _videoLoading = false;
  bool _videoFailed = false;

  final Set<String> _busyLikes = {};
  final Set<String> _busyFollows = {};

  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadFeed());
  }

  @override
  void dispose() {
    _pageController.dispose();

    final controller = _videoController;
    _videoController = null;

    if (controller != null) {
      unawaited(controller.dispose());
    }

    super.dispose();
  }

  void _message(String text) {
    if (!mounted || text.trim().isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _loadFeed({
    bool silent = false,
  }) async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
      if (_reels.isEmpty) _loading = true;
      _error = '';
    });

    try {
      await _service.initialize();

      final items = await _service
          .loadFeed(limit: 30)
          .timeout(const Duration(seconds: 35));

      if (!mounted) return;

      final oldActiveId = _activeReelId;

      setState(() {
        _reels = items;
        _loading = false;
        _error = '';
      });

      if (items.isEmpty) {
        await _stopVideo();
        return;
      }

      var nextIndex = 0;

      if (oldActiveId != null) {
        final oldIndex = items.indexWhere(
          (item) => item.id == oldActiveId,
        );

        if (oldIndex >= 0) {
          nextIndex = oldIndex;
        }
      }

      _activeIndex = nextIndex;

      if (_pageController.hasClients) {
        _pageController.jumpToPage(nextIndex);
      }

      await _activateVideo(nextIndex);
    } on SocialReelsException catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تأخر تحميل الريلز. تحقق من الإنترنت.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الريلز حاليًا.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _stopVideo() async {
    final previous = _videoController;

    _videoController = null;
    _activeReelId = null;

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

  Future<void> _activateVideo(int index) async {
    if (!mounted ||
        index < 0 ||
        index >= _reels.length) {
      return;
    }

    final reel = _reels[index];

    if (reel.videoUrl.trim().isEmpty) {
      await _stopVideo();

      if (mounted) {
        setState(() {
          _videoFailed = true;
        });
      }

      return;
    }

    if (_activeReelId == reel.id &&
        _videoController != null) {
      return;
    }

    final previous = _videoController;

    _videoController = null;
    _activeReelId = reel.id;

    if (mounted) {
      setState(() {
        _videoLoading = true;
        _videoFailed = false;
      });
    }

    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {}
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(reel.videoUrl),
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
          !identical(_videoController, controller) ||
          _activeReelId != reel.id) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.setVolume(1);
      await controller.play();

      if (!mounted ||
          !identical(_videoController, controller)) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoLoading = false;
        _videoFailed = false;
      });
    } catch (_) {
      if (!mounted ||
          !identical(_videoController, controller)) {
        try {
          await controller.dispose();
        } catch (_) {}
        return;
      }

      setState(() {
        _videoLoading = false;
        _videoFailed = true;
      });
    }
  }

  void _onPageChanged(int index) {
    if (!mounted || index < 0 || index >= _reels.length) {
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
      _message('تعذر التحكم في تشغيل الفيديو.');
    }
  }

  Future<String?> _askCaption() async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'وصف الفيديو',
              textDirection: TextDirection.rtl,
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 220,
              maxLines: 3,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'اكتب وصفًا قصيرًا للفيديو',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(null),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext)
                    .pop(controller.text.trim()),
                child: const Text('متابعة'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _pickAndUploadReel() async {
    if (_uploading) return;

    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );

      if (file == null || !mounted) return;

      final length = await file.length();

      if (length <= 0) {
        _message('الفيديو فارغ.');
        return;
      }

      if (length > SocialReelsService.maximumVideoBytes) {
        _message('حجم الفيديو أكبر من 50 ميجابايت.');
        return;
      }

      final caption = await _askCaption();

      if (caption == null || !mounted) return;

      setState(() {
        _uploading = true;
      });

      await _stopVideo();

      final uploaded = await _service.uploadReel(
        file: file,
        caption: caption,
      );

      if (!mounted) return;

      setState(() {
        _uploading = false;
        _error = '';
      });

      _message('تم رفع الريل ونشره بنجاح ✅');

      await _loadFeed(silent: true);

      final index = _reels.indexWhere(
        (item) => item.id == uploaded.id,
      );

      if (index >= 0 && _pageController.hasClients) {
        _pageController.jumpToPage(index);
        _onPageChanged(index);
      }
    } on SocialReelsException catch (error) {
      if (!mounted) return;

      setState(() {
        _uploading = false;
      });

      _message(error.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _uploading = false;
      });

      _message(
        'تعذر رفع الفيديو. حدّث صفحة الريلز أولًا قبل إعادة المحاولة.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  void _replaceReel(
    String reelId,
    SocialReel Function(SocialReel) update,
  ) {
    if (!mounted) return;

    final index = _reels.indexWhere(
      (item) => item.id == reelId,
    );

    if (index < 0) return;

    setState(() {
      _reels[index] = update(_reels[index]);
    });
  }

  Future<void> _toggleLike(SocialReel reel) async {
    if (_busyLikes.contains(reel.id)) return;

    setState(() {
      _busyLikes.add(reel.id);
    });

    try {
      if (reel.likedByMe) {
        await _service.unlikeReel(reel.id);

        _replaceReel(
          reel.id,
          (item) => item.copyWith(
            likedByMe: false,
            likesCount: (item.likesCount - 1).clamp(
              0,
              1 << 30,
            ),
          ),
        );
      } else {
        await _service.likeReel(reel.id);

        _replaceReel(
          reel.id,
          (item) => item.copyWith(
            likedByMe: true,
            likesCount: item.likesCount + 1,
          ),
        );
      }
    } on SocialReelsException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('تعذر تسجيل الإعجاب.');
    } finally {
      if (mounted) {
        setState(() {
          _busyLikes.remove(reel.id);
        });
      }
    }
  }

  Future<void> _toggleFollow(SocialReel reel) async {
    if (reel.isMine ||
        _busyFollows.contains(reel.ownerId)) {
      return;
    }

    setState(() {
      _busyFollows.add(reel.ownerId);
    });

    try {
      if (reel.followedByMe) {
        await _service.unfollowUser(reel.ownerId);
      } else {
        await _service.followUser(reel.ownerId);
      }

      _replaceReel(
        reel.id,
        (item) => item.copyWith(
          followedByMe: !reel.followedByMe,
        ),
      );
    } on SocialReelsException catch (error) {
      _message(error.message);
    } catch (_) {
      _message('تعذرت متابعة صاحب الفيديو.');
    } finally {
      if (mounted) {
        setState(() {
          _busyFollows.remove(reel.ownerId);
        });
      }
    }
  }

  Future<void> _openComments(SocialReel reel) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121725),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (_) => _ReelCommentsSheet(
        reelId: reel.id,
      ),
    );

    if (!mounted) return;

    await _loadFeed(silent: true);
  }

  Widget _buildVideoSurface(SocialReel reel) {
    final controller = _videoController;

    if (_activeReelId == reel.id &&
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

    if (_videoLoading && _activeReelId == reel.id) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF63E6FF),
        ),
      );
    }

    if (_videoFailed && _activeReelId == reel.id) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white70,
              size: 42,
            ),
            const SizedBox(height: 8),
            const Text(
              'تعذر تشغيل الفيديو',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _activateVideo(_activeIndex),
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
        size: 55,
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
    bool busy = false,
  }) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 9,
          horizontal: 5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                icon,
                color: color,
                size: 27,
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelPage(
    SocialReel reel,
    int index,
  ) {
    final playing = _activeReelId == reel.id &&
        (_videoController?.value.isPlaying ?? false);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoSurface(reel),

          Positioned(
            top: 12,
            right: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Text(
                  '${index + 1} / ${_reels.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            right: 10,
            bottom: 25,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionButton(
                  icon: reel.likedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: reel.likesCount.toString(),
                  color: reel.likedByMe
                      ? Colors.pinkAccent
                      : Colors.white,
                  busy: _busyLikes.contains(reel.id),
                  onTap: () => _toggleLike(reel),
                ),
                _actionButton(
                  icon: Icons.mode_comment_outlined,
                  label: reel.commentsCount.toString(),
                  onTap: () => _openComments(reel),
                ),
                if (!reel.isMine)
                  _actionButton(
                    icon: reel.followedByMe
                        ? Icons.person_remove_alt_1_rounded
                        : Icons.person_add_alt_1_rounded,
                    label: reel.followedByMe
                        ? 'متابَع'
                        : 'متابعة',
                    busy: _busyFollows.contains(reel.ownerId),
                    onTap: () => _toggleFollow(reel),
                  ),
              ],
            ),
          ),

          Positioned(
            left: 78,
            right: 13,
            bottom: 34,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  8,
                  35,
                  8,
                  8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(0xFF202B43),
                          child: Icon(
                            Icons.person_rounded,
                            color: Color(0xFF63E6FF),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reel.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (reel.caption.trim().isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        reel.caption,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_done_outlined,
                          color: Color(0xFF63E6FF),
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'ريلز المجتمع',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        if (_activeReelId == reel.id)
                          Icon(
                            playing
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_activeReelId == reel.id &&
              controllerIsPlaying(reel.id) == false &&
              !_videoLoading &&
              !_videoFailed)
            Center(
              child: Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 64,
              ),
            ),
        ],
      ),
    );
  }

  bool controllerIsPlaying(String reelId) {
    return _activeReelId == reelId &&
        (_videoController?.value.isPlaying ?? false);
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
              size: 62,
            ),
            const SizedBox(height: 14),
            const Text(
              'لسه مفيش ريلز منشورة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ارفع أول فيديو ليك وشاركه مع مجتمع صاحبي AI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  _uploading ? null : _pickAndUploadReel,
              icon: const Icon(Icons.add_rounded),
              label: const Text('رفع أول Reel'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _refreshing ? null : _loadFeed,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحديث'),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _reels.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF63E6FF),
        ),
      );
    }

    if (_reels.isEmpty) {
      return _buildEmptyState();
    }

    return PageView.builder(
      key: const ValueKey<String>('social-reels-page-view'),
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _reels.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return _buildReelPage(
          _reels[index],
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
                        'ريلز المجتمع',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تحديث الريلز',
                      onPressed:
                          _refreshing ? null : _loadFeed,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF63E6FF),
                      ),
                    ),
                    IconButton(
                      tooltip: 'رفع فيديو',
                      onPressed:
                          _uploading ? null : _pickAndUploadReel,
                      icon: _uploading
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.add_box_rounded,
                              color: Color(0xFFFF4D8D),
                            ),
                    ),
                  ],
                ),
              ),
              if (_uploading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: Color(0xFFFF4D8D),
                ),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelCommentsSheet extends StatefulWidget {
  const _ReelCommentsSheet({
    required this.reelId,
  });

  final String reelId;

  @override
  State<_ReelCommentsSheet> createState() =>
      _ReelCommentsSheetState();
}

class _ReelCommentsSheetState
    extends State<_ReelCommentsSheet> {
  final SocialReelsService _service =
      SocialReelsService.instance;

  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  List<SocialReelComment> _comments = [];

  bool _loading = true;
  bool _sending = false;

  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadComments());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final comments =
          await _service.loadComments(widget.reelId);

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _loading = false;
      });
    } on SocialReelsException catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'تعذر تحميل التعليقات.';
      });
    }
  }

  Future<void> _sendComment() async {
    if (_sending) return;

    final text = _controller.text.trim();

    if (text.isEmpty) return;

    setState(() {
      _sending = true;
    });

    try {
      final comment = await _service.addComment(
        reelId: widget.reelId,
        text: text,
      );

      if (!mounted) return;

      setState(() {
        _comments = [..._comments, comment];
        _controller.clear();
        _sending = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    } on SocialReelsException catch (error) {
      if (!mounted) return;

      setState(() {
        _sending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _sending = false;
      });
    }
  }

  Widget _buildComment(SocialReelComment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFF202B43),
            child: Icon(
              Icons.person_rounded,
              color: Color(0xFF63E6FF),
              size: 19,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (comment.isMine)
            const Icon(
              Icons.verified_user_outlined,
              color: Colors.white24,
              size: 16,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: bottomInset,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'التعليقات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تحديث التعليقات',
                      onPressed: _loading ? null : _loadComments,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF63E6FF),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(
                color: Colors.white12,
                height: 1,
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              _error.isNotEmpty
                                  ? _error
                                  : 'لا توجد تعليقات حتى الآن.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white60,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _comments.length,
                            itemBuilder: (context, index) {
                              return _buildComment(
                                _comments[index],
                              );
                            },
                          ),
              ),
              const Divider(
                color: Colors.white12,
                height: 1,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  9,
                  12,
                  10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 1000,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'اكتب تعليقك...',
                          filled: true,
                          fillColor: const Color(0xFF202638),
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed:
                          _sending ? null : _sendComment,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
