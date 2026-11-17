import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'services/social_community_service.dart';
import 'services/social_group_management_service.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';
import 'widgets/social_connect_attachment_controls.dart';
import 'widgets/social_connect_attachment_message.dart';

class SocialPrivateGroupsScreen extends StatefulWidget {
  const SocialPrivateGroupsScreen({super.key});

  @override
  State<SocialPrivateGroupsScreen> createState() =>
      _SocialPrivateGroupsScreenState();
}

class _SocialPrivateGroupsScreenState extends State<SocialPrivateGroupsScreen> {
  final SocialGroupManagementService _service =
      SocialGroupManagementService.instance;

  List<SocialManagedGroup> _groups = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGroups());
  }

  Future<void> _loadGroups() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      await _service.refreshSession();
      final groups = await _service.getMyGroups();
      if (!mounted) return;
      setState(() {
        _groups = groups.where((group) => !group.isPublic).toList();
        _loading = false;
      });
    } on SocialGroupManagementException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل مجموعاتك الخاصة. حاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on SocialGroupManagementException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إكمال العملية. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createPrivateGroup() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final values = await showDialog<(String, String)?>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إنشاء مجموعة خاصة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'اسم المجموعة'),
              ),
              TextField(
                controller: descriptionController,
                maxLength: 160,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف اختياري'),
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
      final group = await _service.createPrivateGroup(
        name: values.$1,
        description: values.$2,
      );
      await _loadGroups();
      if (!mounted) return;
      await _openChat(group);
    });
  }

  Future<void> _joinByCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('الانضمام برمز دعوة'),
          content: TextField(
            controller: controller,
            maxLength: 10,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'مثال: ABCD2345XY',
              labelText: 'رمز المجموعة',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                controller.text.trim(),
              ),
              child: const Text('انضمام'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (code == null || !mounted) return;

    await _run(() async {
      final group = await _service.joinByInviteCode(code);
      await _loadGroups();
      if (!mounted) return;
      await _openChat(group);
    });
  }

  Future<void> _shareInvite(SocialManagedGroup group) async {
    await _run(() async {
      final invite = await _service.createInvite(group.id);
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        invite.expiresAt,
      ).toLocal();
      final formatted =
          '${expiry.day.toString().padLeft(2, '0')}/'
          '${expiry.month.toString().padLeft(2, '0')}/'
          '${expiry.year}';
      await Share.share(
        'دعوة للانضمام إلى مجموعة خاصة في صاحبي Connect\n'
        'اسم المجموعة: ${group.name}\n'
        'رمز الدعوة: ${invite.code}\n'
        'ينتهي الرمز يوم $formatted، وصالح لأول ${invite.maxUses} استخدامًا.\n'
        'افتح صاحبي Connect ثم مجموعاتي الخاصة واختر الانضمام برمز دعوة.',
      );
    });
  }

  Future<void> _openChat(SocialManagedGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SocialPrivateGroupChatScreen(group: group),
      ),
    );
    await _loadGroups();
  }

  Future<void> _openMembers(SocialManagedGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SocialPrivateGroupMembersScreen(group: group),
      ),
    );
    await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: Sa7biSubpageAppBar(
          title: 'مجموعاتي الخاصة',
          actions: [
            IconButton(
              tooltip: 'انضمام برمز دعوة',
              onPressed: _busy ? null : _joinByCode,
              icon: const Icon(Icons.key_rounded),
            ),
            IconButton(
              tooltip: 'إنشاء مجموعة خاصة',
              onPressed: _busy ? null : _createPrivateGroup,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadGroups,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            children: [
              const _PrivateGroupsNotice(),
              const SizedBox(height: 12),
              if (_error != null) _PrivateGroupError(message: _error!),
              if (_loading && _groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 38),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 34),
                  child: Text(
                    'لسه ما انضمّتش لأي مجموعة خاصة. أنشئ مجموعة أو أدخل رمز دعوة من صاحبك.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, height: 1.6),
                  ),
                )
              else
                for (final group in _groups)
                  Card(
                    color: const Color(0xFF111827),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: _busy ? null : () => _openChat(group),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0x22FFD76A),
                              child: Icon(
                                Icons.lock_rounded,
                                color: Color(0xFFFFD76A),
                              ),
                            ),
                            title: Text(
                              group.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${group.memberCount} عضو • ${_roleLabel(group.myRole)}'
                              '${group.description.isEmpty ? '' : '\n${group.description}'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                height: 1.45,
                                fontSize: 10,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white60,
                            ),
                          ),
                          const Divider(color: Colors.white12, height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed:
                                      _busy ? null : () => _shareInvite(group),
                                  icon: const Icon(Icons.share_rounded, size: 17),
                                  label: const Text('دعوة'),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed:
                                      _busy ? null : () => _openMembers(group),
                                  icon: const Icon(
                                    Icons.people_alt_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('الأعضاء'),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed:
                                      _busy ? null : () => _openChat(group),
                                  icon: const Icon(
                                    Icons.forum_rounded,
                                    size: 17,
                                  ),
                                  label: const Text('المحادثة'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _createPrivateGroup,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('إنشاء مجموعة خاصة'),
              ),
              const SizedBox(height: 7),
              OutlinedButton.icon(
                onPressed: _busy ? null : _joinByCode,
                icon: const Icon(Icons.key_rounded),
                label: const Text('الانضمام برمز دعوة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'owner':
      return 'مالك المجموعة';
    case 'admin':
      return 'مشرف';
    default:
      return 'عضو';
  }
}

class SocialPrivateGroupChatScreen extends StatefulWidget {
  const SocialPrivateGroupChatScreen({
    super.key,
    required this.group,
  });

  final SocialManagedGroup group;

  @override
  State<SocialPrivateGroupChatScreen> createState() =>
      _SocialPrivateGroupChatScreenState();
}

class _SocialPrivateGroupChatScreenState
    extends State<SocialPrivateGroupChatScreen> {
  final SocialCommunityService _community = SocialCommunityService.instance;
  final SocialGroupManagementService _management =
      SocialGroupManagementService.instance;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  Timer? _poll;
  List<SocialGroupMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _inviteBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMessages());
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_sending && mounted) unawaited(_loadMessages(silent: true));
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
      final messages = await _community.getMessages(widget.group.id);
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
        _error = 'تعذر تحديث رسائل المجموعة الخاصة.';
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
      final message = await _community.sendGroupMessage(
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
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } on SocialCommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إرسال الرسالة.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareInvite() async {
    if (_inviteBusy) return;
    setState(() => _inviteBusy = true);
    try {
      final invite = await _management.createInvite(widget.group.id);
      await Share.share(
        'دعوة لمجموعة خاصة: ${widget.group.name}\n'
        'رمز الانضمام: ${invite.code}\n'
        'افتح صاحبي Connect ثم مجموعاتي الخاصة ثم الانضمام برمز دعوة.',
      );
    } on SocialGroupManagementException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('تعذرت مشاركة رمز الدعوة.');
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, textDirection: TextDirection.rtl)),
    );
  }

  String _time(int milliseconds) {
    if (milliseconds <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openMembers() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SocialPrivateGroupMembersScreen(group: widget.group),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      Navigator.of(context).pop(true);
    } else {
      await _loadMessages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: Sa7biSubpageAppBar(
          title: widget.group.name,
          subtitle: '${widget.group.memberCount} عضو • مجموعة خاصة',
          actions: [
            IconButton(
              tooltip: 'رمز دعوة',
              onPressed: _inviteBusy ? null : _shareInvite,
              icon: _inviteBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_rounded),
            ),
            IconButton(
              tooltip: 'الأعضاء والإدارة',
              onPressed: _openMembers,
              icon: const Icon(Icons.people_alt_rounded),
            ),
          ],
        ),
        body: Column(
          children: [
            const _PrivateGroupsNotice(
              text:
                  'هذه مجموعة خاصة. لا يستطيع غير الأعضاء قراءة الرسائل. الرسائل ليست مشفرة من طرف إلى طرف.',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 0),
                child: _PrivateGroupError(message: _error!),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'ابدأ المحادثة برسالة ترحيب.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message =
                                _messages[_messages.length - 1 - index];
                            return Align(
                              alignment: message.isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 310),
                                margin: const EdgeInsets.only(bottom: 9),
                                padding:
                                    const EdgeInsets.fromLTRB(12, 8, 12, 7),
                                decoration: BoxDecoration(
                                  color: message.isMine
                                      ? const Color(0xFF19476A)
                                      : const Color(0xFF172033),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!message.isMine)
                                      Text(
                                        message.username,
                                        style: const TextStyle(
                                          color: Color(0xFFFFD76A),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    SocialConnectAttachmentMessageView(
                                      messageText: message.text,
                                    ),
                                    Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Text(
                                        _time(message.createdAt),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 9,
                                        ),
                                      ),
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
                    SocialConnectAttachmentControls(
                      scopeType: 'group',
                      scopeId: widget.group.id,
                      onMessageSent: () =>
                          unawaited(_loadMessages(silent: true)),
                    ),
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
                          hintText: 'اكتب رسالة للمجموعة الخاصة...',
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
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
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

class SocialPrivateGroupMembersScreen extends StatefulWidget {
  const SocialPrivateGroupMembersScreen({
    super.key,
    required this.group,
  });

  final SocialManagedGroup group;

  @override
  State<SocialPrivateGroupMembersScreen> createState() =>
      _SocialPrivateGroupMembersScreenState();
}

class _SocialPrivateGroupMembersScreenState
    extends State<SocialPrivateGroupMembersScreen> {
  final SocialGroupManagementService _service =
      SocialGroupManagementService.instance;

  List<SocialManagedMember> _members = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _isOwner => widget.group.myRole == 'owner';
  bool get _canManage => _isOwner || widget.group.myRole == 'admin';

  @override
  void initState() {
    super.initState();
    unawaited(_loadMembers());
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _service.getMembers(widget.group.id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
        _error = null;
      });
    } on SocialGroupManagementException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل أعضاء المجموعة.';
        _loading = false;
      });
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('تأكيد'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _loadMembers();
    } on SocialGroupManagementException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إكمال إدارة العضوية.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAdmin(SocialManagedMember member) async {
    final makeAdmin = member.role != 'admin';
    final action = makeAdmin ? 'تعيين مشرف' : 'إلغاء صلاحية المشرف';
    if (!await _confirm(
      action,
      'هل تريد ${makeAdmin ? 'تعيين' : 'إلغاء'} صلاحية المشرف لهذا العضو؟',
    )) {
      return;
    }
    await _run(() => _service.setAdmin(
          groupId: widget.group.id,
          userId: member.userId,
          isAdmin: makeAdmin,
        ));
  }

  Future<void> _removeMember(SocialManagedMember member) async {
    if (!await _confirm(
      'إزالة عضو',
      'هل تريد إزالة ${member.username} من المجموعة؟',
    )) {
      return;
    }
    await _run(() => _service.removeMember(
          groupId: widget.group.id,
          userId: member.userId,
        ));
  }

  Future<void> _leaveGroup() async {
    if (!await _confirm(
      'مغادرة المجموعة',
      'لن تستطيع قراءة الرسائل بعد المغادرة إلا إذا انضممت مجددًا بدعوة.',
    )) {
      return;
    }
    await _run(() async {
      await _service.leaveGroup(widget.group.id);
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  Future<void> _deleteGroup() async {
    if (!await _confirm(
      'حذف المجموعة نهائيًا',
      'سيتم حذف المجموعة ورسائلها ودعواتها لكل الأعضاء. لا يمكن التراجع.',
    )) {
      return;
    }
    await _run(() async {
      await _service.deleteGroup(widget.group.id);
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: Sa7biSubpageAppBar(
          title: 'أعضاء المجموعة',
          subtitle: widget.group.name,
          actions: [
            IconButton(
              tooltip: 'تحديث الأعضاء',
              onPressed: _busy ? null : _loadMembers,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (_error != null) _PrivateGroupError(message: _error!),
                  for (final member in _members)
                    Card(
                      color: const Color(0xFF111827),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: member.role == 'owner'
                              ? const Color(0x33FFD76A)
                              : const Color(0x223F91FF),
                          child: Icon(
                            member.role == 'owner'
                                ? Icons.workspace_premium_rounded
                                : member.role == 'admin'
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.person_rounded,
                            color: member.role == 'owner'
                                ? const Color(0xFFFFD76A)
                                : const Color(0xFF7FB4FF),
                          ),
                        ),
                        title: Text(
                          member.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          _roleLabel(member.role),
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: member.role == 'owner' || !_canManage
                            ? null
                            : PopupMenuButton<String>(
                                enabled: !_busy,
                                onSelected: (value) {
                                  if (value == 'admin' && _isOwner) {
                                    _toggleAdmin(member);
                                  } else if (value == 'remove') {
                                    _removeMember(member);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (_isOwner)
                                    PopupMenuItem(
                                      value: 'admin',
                                      child: Text(
                                        member.role == 'admin'
                                            ? 'إلغاء المشرف'
                                            : 'تعيين مشرف',
                                      ),
                                    ),
                                  if (_isOwner || member.role == 'member')
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Text('إزالة من المجموعة'),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_isOwner)
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _deleteGroup,
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('حذف المجموعة نهائيًا'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _leaveGroup,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('مغادرة المجموعة'),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PrivateGroupsNotice extends StatelessWidget {
  const _PrivateGroupsNotice({this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF171F2F),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0x33FFD76A)),
      ),
      child: Text(
        text ??
            'المجموعة الخاصة لا تظهر في دليل المجموعات العامة. الانضمام يحتاج رمز دعوة صالحًا، والرسائل متاحة للأعضاء فقط.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          height: 1.6,
        ),
      ),
    );
  }
}

class _PrivateGroupError extends StatelessWidget {
  const _PrivateGroupError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4A2028),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}
