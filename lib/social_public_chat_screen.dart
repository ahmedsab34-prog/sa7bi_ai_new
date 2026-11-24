import 'dart:async';

import 'package:flutter/material.dart';

import 'services/social_messaging_service.dart';
import 'widgets/sa7bi_hero_sticker_kit.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// الغرفة العامة الواحدة المشتركة بين مستخدمي صاحبي Connect.
/// التحديث كل 5 ثوانٍ باستخدام polling، وليس WebSocket.
class SocialPublicChatScreen extends StatefulWidget {
  const SocialPublicChatScreen({super.key});

  @override
  State<SocialPublicChatScreen> createState() =>
      _SocialPublicChatScreenState();
}

class _SocialPublicChatScreenState extends State<SocialPublicChatScreen> {
  final SocialMessagingService _service = SocialMessagingService.instance;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _pollTimer;
  List<SocialPublicMessage> _messages = [];

  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages(initial: true);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (mounted && !_refreshing && !_sending) {
          unawaited(_loadMessages(silent: true));
        }
      },
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({
    bool initial = false,
    bool silent = false,
  }) async {
    if (_refreshing) return;

    _refreshing = true;

    try {
      final incoming = await _service.getPublicMessages(limit: 50);

      if (!mounted) return;

      final merged = <String, SocialPublicMessage>{};

      for (final message in _messages) {
        if (message.id.isNotEmpty) {
          merged[message.id] = message;
        }
      }

      for (final message in incoming) {
        if (message.id.isNotEmpty) {
          merged[message.id] = message;
        }
      }

      final updated = merged.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        _messages = updated;
        _error = null;
        _loading = false;
      });

      if (initial || incoming.isNotEmpty) {
        _scrollToLatest();
      }
    } on SocialMessagingException catch (error) {
      if (!mounted || silent) return;

      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || silent) return;

      setState(() {
        _error = 'تعذر تحميل رسائل الشات العام. تحقق من الاتصال.';
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    await _sendContent(
      _composer.text,
      clearComposer: true,
    );
  }

  Future<void> _pickHeroSticker() async {
    if (_sending) return;

    final token = await Sa7biHeroStickerPicker.show(context);
    if (!mounted || token == null || token.trim().isEmpty) return;

    // Keep any draft text the user has already typed.
    await _sendContent(
      token,
      clearComposer: false,
    );
  }

  Future<void> _sendContent(
    String value, {
    required bool clearComposer,
  }) async {
    if (_sending) return;

    final text = value.trim();
    if (text.isEmpty) return;

    if (text.length > 3000) {
      setState(() {
        _error = 'الرسالة أطول من الحد المسموح، وهو 3000 حرف.';
      });
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final message = await _service.sendPublicMessage(text);

      if (!mounted) return;

      if (clearComposer) {
        _composer.clear();
      }

      setState(() {
        if (!_messages.any((item) => item.id == message.id)) {
          _messages = [..._messages, message];
        }
      });

      _scrollToLatest();
      unawaited(_loadMessages(silent: true));
    } on SocialMessagingException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذر إرسال الرسالة. حاول مرة أخرى.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _reportMessage(SocialPublicMessage message) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF172033),
            title: const Text(
              'الإبلاغ عن رسالة',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'اختار سبب الإبلاغ. سيتم تسجيل البلاغ للمراجعة، '
              'ولا يعني ذلك حذف الرسالة تلقائيًا.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, 'محتوى مسيء'),
                child: const Text('محتوى مسيء'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, 'إزعاج أو سبام'),
                child: const Text('إزعاج أو سبام'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, 'محتوى غير مناسب'),
                child: const Text('محتوى غير مناسب'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || reason == null) return;

    try {
      await _service.reportPublicMessage(
        messageId: message.id,
        reason: reason,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل بلاغك بنجاح.'),
        ),
      );
    } on SocialMessagingException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تسجيل البلاغ. حاول مرة أخرى.'),
        ),
      );
    }
  }

  String _timeLabel(int milliseconds) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Widget _buildMessage(SocialPublicMessage message) {
    final mine = message.isMine;

    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        decoration: BoxDecoration(
          color: mine
              ? const Color(0xFF203B5C)
              : const Color(0xFF172033),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: mine
                ? const Color(0x447FB4FF)
                : Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) ...[
              Text(
                message.username,
                style: const TextStyle(
                  color: Color(0xFFFFD76A),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Sa7biHeroChatStickerMessageView(
              messageText: message.text,
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(message.createdAt),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
                if (!mine) ...[
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 17,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white54,
                    ),
                    color: const Color(0xFF202B40),
                    onSelected: (_) => _reportMessage(message),
                    itemBuilder: (_) => const [
                      PopupMenuItem<String>(
                        value: 'report',
                        child: Text(
                          'الإبلاغ عن الرسالة',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1421),
          border: Border(
            top: BorderSide(color: Colors.white12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 4,
                maxLength: 3000,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة لكل أصحاب صاحبي...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFF172033),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'ملصقات HERO',
              child: Material(
                color: const Color(0xFF172033),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey<String>('public-chat-hero-stickers'),
                  onTap: _sending ? null : _pickHeroSticker,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: IgnorePointer(
                      child: Image.asset(
                        'assets/3d/hero_idle(3).gif',
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.smart_toy_rounded,
                          color: Color(0xFFFFD76A),
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'إرسال الرسالة',
              onPressed: _sending ? null : _send,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: Sa7biSubpageAppBar(
          title: 'الشات العام',
          subtitle: 'غرفة واحدة تجمع أصحاب صاحبي',
          actions: [
            IconButton(
              tooltip: 'تحديث الرسائل',
              onPressed: () => _loadMessages(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 7),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFF142438),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: const Color(0x447FB4FF),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.public_rounded,
                    color: Color(0xFF7FB4FF),
                    size: 21,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'رسائلك هنا تظهر لجميع مستخدمي الغرفة العامة. '
                      'تجنب مشاركة كلمات المرور أو البيانات الشخصية.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF51252C),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.forum_outlined,
                                  color: Colors.white30,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'لسه مفيش رسائل هنا',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'ابدأ أول رسالة وافتح الكلام مع أصحاب صاحبي.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () => _loadMessages(),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadMessages(),
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(
                              12,
                              10,
                              12,
                              14,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  _messages[_messages.length - 1 - index];
                              return _buildMessage(message);
                            },
                          ),
                        ),
            ),
          ],
        ),
        bottomNavigationBar: _buildComposer(),
      ),
    );
  }
}
