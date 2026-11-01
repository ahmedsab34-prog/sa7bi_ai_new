import 'dart:async';

import 'package:flutter/material.dart';

import 'services/social_community_service.dart';
import 'services/social_games_service.dart';
import 'social_games_hub_screen.dart';

class SocialGroupsScreen extends StatefulWidget {
  const SocialGroupsScreen({super.key});

  @override
  State<SocialGroupsScreen> createState() => _SocialGroupsScreenState();
}

class _SocialGroupsScreenState extends State<SocialGroupsScreen> {
  final SocialCommunityService _community = SocialCommunityService.instance;
  final SocialGamesService _games = SocialGamesService.instance;

  List<SocialPublicGroup> _groups = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _community.refreshSession();
      if (_community.isSignedIn) {
        await _games.initialize();
        await _games.getCurrentUser();
        await _loadGroups();
      }
    } on SocialCommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل المجموعات. حاول مرة أخرى.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadGroups() async {
    final groups = await _community.getGroups();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
      _error = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on SocialCommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'حدث خطأ غير متوقع. تحقق من الاتصال وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SocialGamesHubScreen()),
    );
    await _initialize();
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final values = await showDialog<(String, String)?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إنشاء مجموعة عامة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 40,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المجموعة',
                  hintText: 'مثال: محبي الشطرنج',
                ),
              ),
              TextField(
                controller: descriptionController,
                maxLength: 160,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'وصف مختصر (اختياري)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                (nameController.text, descriptionController.text),
              ),
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (values == null || !mounted) return;

    await _run(() async {
      final group = await _community.createGroup(
        name: values.$1,
        description: values.$2,
      );
      await _loadGroups();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SocialGroupChatScreen(group: group),
        ),
      );
      await _loadGroups();
    });
  }

  Future<void> _openGroup(SocialPublicGroup group) async {
    await _run(() async {
      final joined = group.isMember
          ? group
          : await _community.joinGroup(group.id);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SocialGroupChatScreen(group: joined),
        ),
      );
      await _loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          title: const Text('المجموعات العامة'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _busy || _loading ? null : () => _run(_loadGroups),
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'إنشاء مجموعة',
              onPressed: !_community.isSignedIn || _busy ? null : _createGroup,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_community.isSignedIn
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups_rounded, size: 52, color: Color(0xFFFFD76A)),
                          const SizedBox(height: 12),
                          const Text(
                            'سجّل الدخول إلى حساب الألعاب حتى تنضم للمجموعات أو تنشئ مجموعة جديدة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, height: 1.5),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _openLogin,
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('تسجيل الدخول'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadGroups,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      children: [
                        const _GroupsIntro(),
                        const SizedBox(height: 12),
                        if (_error != null) _CommunityError(message: _error!),
                        if (_groups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Text(
                              'لا توجد مجموعات بعد. أنشئ أول مجموعة عامة وابدأ دعوة الناس للانضمام.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60, height: 1.5),
                            ),
                          )
                        else
                          for (final group in _groups)
                            Card(
                              color: const Color(0xFF111827),
                              margin: const EdgeInsets.only(bottom: 9),
                              child: ListTile(
                                onTap: _busy ? null : () => _openGroup(group),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0x223F91FF),
                                  child: Icon(
                                    group.isMember ? Icons.groups_rounded : Icons.public_rounded,
                                    color: const Color(0xFF7FB4FF),
                                  ),
                                ),
                                title: Text(
                                  group.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  [
                                    if (group.description.isNotEmpty) group.description,
                                    '${group.memberCount} عضو',
                                    if (group.lastMessage.isNotEmpty) group.lastMessage,
                                  ].join(' • '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60, height: 1.4),
                                ),
                                trailing: group.isMember
                                    ? const Icon(Icons.chevron_left_rounded, color: Colors.white60)
                                    : const Text('انضمام', style: TextStyle(color: Color(0xFFFFD76A), fontWeight: FontWeight.w800)),
                              ),
                            ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _busy ? null : _createGroup,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إنشاء مجموعة جديدة'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class SocialGroupChatScreen extends StatefulWidget {
  const SocialGroupChatScreen({super.key, required this.group});

  final SocialPublicGroup group;

  @override
  State<SocialGroupChatScreen> createState() => _SocialGroupChatScreenState();
}

class _SocialGroupChatScreenState extends State<SocialGroupChatScreen> {
  final SocialCommunityService _service = SocialCommunityService.instance;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _poll;
  List<SocialGroupMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_sending) _loadMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final messages = await _service.getMessages(widget.group.id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
        _loading = false;
      });
    } on SocialCommunityException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحديث رسائل المجموعة.';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await _service.sendGroupMessage(
        groupId: widget.group.id,
        text: text,
      );
      if (!mounted) return;
      _composer.clear();
      setState(() {
        if (!_messages.any((item) => item.id == message.id)) {
          _messages = [..._messages, message];
        }
      });
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } on SocialCommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إرسال الرسالة. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(int milliseconds) {
    if (milliseconds <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.group.name, style: const TextStyle(fontSize: 16)),
              Text('${widget.group.memberCount} عضو', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
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
            const _CommunityNotice(
              text: 'هذه مجموعة عامة. الرسائل يراها الأعضاء، وليست مشفرة من طرف إلى طرف. تجنب مشاركة كلمات المرور أو البيانات الحساسة.',
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: _CommunityError(message: _error!),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text('ابدأ المحادثة برسالة ترحيب.', style: TextStyle(color: Colors.white54)),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[_messages.length - 1 - index];
                            return Align(
                              alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 310),
                                margin: const EdgeInsets.only(bottom: 9),
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
                                decoration: BoxDecoration(
                                  color: message.isMine ? const Color(0xFF19476A) : const Color(0xFF172033),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!message.isMine)
                                      Text(message.username, style: const TextStyle(color: Color(0xFFFFD76A), fontSize: 11, fontWeight: FontWeight.w800)),
                                    Text(message.text, style: const TextStyle(color: Colors.white, height: 1.4)),
                                    Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Text(_time(message.createdAt), style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 3000,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: 'اكتب رسالة للمجموعة...',
                          filled: true,
                          fillColor: Color(0xFF151D2C),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 7),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsIntro extends StatelessWidget {
  const _GroupsIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          Icon(Icons.public_rounded, color: Color(0xFF7FB4FF), size: 30),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'اكتشف مجموعات عامة، انضم للمناقشات، أو أنشئ مجتمعًا حول اهتماماتك.',
              style: TextStyle(color: Colors.white70, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityNotice extends StatelessWidget {
  const _CommunityNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: const Color(0xFF172033),
      child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
    );
  }
}

class _CommunityError extends StatelessWidget {
  const _CommunityError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4A2028),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white)),
    );
  }
}
