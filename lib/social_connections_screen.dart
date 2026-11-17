import 'dart:async';

import 'package:flutter/material.dart';

import 'models/social_sticker.dart';
import 'services/social_games_service.dart';
import 'services/social_messaging_service.dart';
import 'services/social_realtime_service.dart';
import 'social_games_hub_screen.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';
import 'widgets/social_sticker_kit.dart';
import 'widgets/social_connect_attachment_controls.dart';
import 'widgets/social_connect_attachment_message.dart';

class SocialConnectionsScreen extends StatefulWidget {
  const SocialConnectionsScreen({super.key});

  @override
  State<SocialConnectionsScreen> createState() => _SocialConnectionsScreenState();
}

class _SocialConnectionsScreenState extends State<SocialConnectionsScreen> {
  final SocialGamesService _games = SocialGamesService.instance;
  final SocialMessagingService _messaging = SocialMessagingService.instance;
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;

  bool _loading = true;
  bool _busy = false;
  bool _searching = false;

  String? _error;
  String? _searchError;

  String _game = 'tic_tac_toe';
  int _searchSequence = 0;

  List<SocialGameInvitation> _incoming = [];
  List<SocialGameInvitation> _outgoing = [];
  List<SocialConversationSummary> _conversations = [];
  List<SocialGameUser> _players = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      await _games.initialize();
      await _messaging.refreshSession();

      if (!_games.isSignedIn || !_messaging.isSignedIn) {
        throw const SocialMessagingException(
          'AUTH_REQUIRED',
          'سجّل الدخول من مركز الألعاب أولًا.',
        );
      }

      await _games.getCurrentUser();
      await _refreshAll();
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SocialMessagingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل صاحبي كونكت. تحقق من الاتصال.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAccountLogin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialGamesHubScreen(),
      ),
    );

    if (mounted) await _initialize();
  }

  Future<void> _refreshAll() async {
    final incoming = await _messaging.getInvitations(box: 'inbox');
    final outgoing = await _messaging.getInvitations(box: 'outbox');
    final conversations = await _messaging.getConversations();

    if (!mounted) return;

    setState(() {
      _incoming = incoming;
      _outgoing = outgoing;
      _conversations = conversations;
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
    } on SocialMessagingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();

    final query = value.trim();
    final sequence = ++_searchSequence;

    if (query.length < 2) {
      setState(() {
        _players = [];
        _searchError = null;
        _searching = false;
      });
      return;
    }

    setState(() {
      _players = [];
      _searchError = null;
      _searching = true;
    });

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () async {
        try {
          final results = await _games.searchUsers(query);

          if (!mounted || sequence != _searchSequence) return;

          setState(() {
            _players = results;
            _searching = false;
            _searchError = null;
          });
        } on SocialGamesException catch (error) {
          if (!mounted || sequence != _searchSequence) return;

          setState(() {
            _players = [];
            _searching = false;
            _searchError = error.message;
          });
        } catch (_) {
          if (!mounted || sequence != _searchSequence) return;

          setState(() {
            _players = [];
            _searching = false;
            _searchError = 'تعذر البحث عن اللاعبين. تحقق من الاتصال.';
          });
        }
      },
    );
  }

  Future<void> _invitePlayer(SocialGameUser player) async {
    await _run(() async {
      final invitation = await _messaging.createGameInvitation(
        recipientUserId: player.id,
        game: _game,
      );

      await _refreshAll();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال دعوة ${invitation.gameTitle} إلى ${player.username}.',
          ),
        ),
      );
    });
  }

  Future<void> _startConversation(SocialGameUser player) async {
    await _run(() async {
      final conversationId =
          await _messaging.createConversation(player.id);

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SocialPrivateChatScreen(
            conversationId: conversationId,
            title: player.username,
          ),
        ),
      );

      await _refreshAll();
    });
  }

  Future<void> _respond(
    SocialGameInvitation invitation, {
    required bool accept,
  }) async {
    await _run(() async {
      final roomId = await _messaging.respondToInvitation(
        invitationId: invitation.id,
        accept: accept,
      );

      await _refreshAll();

      if (accept && roomId != null && mounted) {
        await _openRoom(roomId);
      } else if (mounted && !accept) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض الدعوة.')),
        );
      }
    });
  }

  Future<void> _openRoom(String roomId) async {
    final room = await _games.getRoom(roomId);

    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SocialGameRoomScreen(initialRoom: room),
      ),
    );

    await _refreshAll();
  }

  Future<void> _openConversation(
    SocialConversationSummary conversation,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SocialPrivateChatScreen(
          conversationId: conversation.id,
          title: conversation.otherUser.username,
        ),
      ),
    );

    await _refreshAll();
  }

  Widget _buildPlayerFinder() {
    final query = _searchController.text.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.person_search_rounded,
                color: Color(0xFFFFD76A),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ابحث عن صاحبك',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'ابحث عن لاعب لبدء محادثة خاصة أو إرسال دعوة للعب.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _game,
            isExpanded: true,
            dropdownColor: const Color(0xFF172033),
            decoration: const InputDecoration(
              labelText: 'اللعبة',
              filled: true,
              fillColor: Color(0xFF151D2C),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(
                value: 'tic_tac_toe',
                child: Text('إكس أو'),
              ),
              DropdownMenuItem(
                value: 'rock_paper_scissors',
                child: Text('حجر ورقة مقص'),
              ),
              DropdownMenuItem(
                value: 'chess',
                child: Text('الشطرنج'),
              ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _game = value);
                    }
                  },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'اكتب اسم اللاعب...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchSequence++;
                        _searchController.clear();

                        setState(() {
                          _players = [];
                          _searchError = null;
                          _searching = false;
                        });
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFF151D2C),
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          if (_searching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_searchError != null)
            _ConnectErrorBox(message: _searchError!)
          else if (query.length < 2)
            const Text(
              'اكتب حرفين على الأقل لبدء البحث.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            )
          else if (_players.isEmpty)
            const Text(
              'لم يتم العثور على لاعبين بهذا الاسم.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            )
          else
            for (final player in _players)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF172033),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 17,
                      backgroundColor: Color(0x22FFD76A),
                      child: Icon(
                        Icons.person_rounded,
                        color: Color(0xFFFFD76A),
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        player.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'مراسلة',
                      visualDensity: VisualDensity.compact,
                      onPressed: _busy
                          ? null
                          : () => _startConversation(player),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF7FB4FF),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _busy
                          ? null
                          : () => _invitePlayer(player),
                      child: const Text('دعوة'),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildInvitationTab({required bool inbox}) {
    final invitations = inbox ? _incoming : _outgoing;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          if (inbox) ...[
            _buildPlayerFinder(),
            const SizedBox(height: 14),
          ],
          if (_error != null) ...[
            _ConnectErrorBox(message: _error!),
            const SizedBox(height: 10),
          ],
          if (invitations.isEmpty)
            const _ConnectEmptyBox(
              icon: Icons.mail_outline_rounded,
              text: 'لا توجد دعوات هنا حتى الآن.',
            )
          else
            for (final invitation in invitations)
              _InvitationCard(
                invitation: invitation,
                inbox: inbox,
                busy: _busy,
                onAccept: () => _respond(invitation, accept: true),
                onDecline: () => _respond(invitation, accept: false),
                onOpenRoom: invitation.roomId.isEmpty
                    ? null
                    : () => _run(
                          () => _openRoom(invitation.roomId),
                        ),
              ),
        ],
      ),
    );
  }

  Widget _buildConversationsTab() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          const _ConnectNoticeBox(
            text:
                'المحادثات متاحة للحسابين المشاركين فقط. الرسائل محفوظة على الخادم، ولا تدعم هذه النسخة التشفير من طرف إلى طرف.',
          ),
          const SizedBox(height: 12),
          if (_error != null) _ConnectErrorBox(message: _error!),
          if (_conversations.isEmpty)
            const _ConnectEmptyBox(
              icon: Icons.forum_outlined,
              text: 'لا توجد محادثات بعد. ابحث عن لاعب وابدأ مراسلته.',
            )
          else
            for (final conversation in _conversations)
              _ConversationCard(
                conversation: conversation,
                onTap: () => _openConversation(conversation),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: const Color(0xFF080B13),
          appBar: Sa7biSubpageAppBar(
            title: 'صاحبي كونكت',
            actions: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: _busy || _loading
                    ? null
                    : () => _run(_refreshAll),
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'الحساب',
                onPressed: _openAccountLogin,
                icon: const Icon(Icons.person_outline_rounded),
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                  icon: Icon(Icons.mark_email_unread_outlined),
                  text: 'واردة',
                ),
                Tab(
                  icon: Icon(Icons.send_outlined),
                  text: 'صادرة',
                ),
                Tab(
                  icon: Icon(Icons.forum_outlined),
                  text: 'المحادثات',
                ),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _buildInvitationTab(inbox: true),
                    _buildInvitationTab(inbox: false),
                    _buildConversationsTab(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.inbox,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenRoom,
  });

  final SocialGameInvitation invitation;
  final bool inbox;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final person =
        inbox ? invitation.sender.username : invitation.recipient.username;

    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sports_esports_rounded,
                  color: Color(0xFFFFD76A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    invitation.gameTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  invitation.statusLabel,
                  style: TextStyle(
                    color: invitation.status == 'pending'
                        ? const Color(0xFFFFD76A)
                        : Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              inbox ? 'دعوة من $person' : 'أرسلت الدعوة إلى $person',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 5),
            Text(
              'رمز المباراة: ${invitation.inviteCode.isEmpty ? 'غير متاح' : invitation.inviteCode}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            if (inbox && invitation.status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onAccept,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('قبول واللعب'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onDecline,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('رفض'),
                  ),
                ],
              ),
            ] else if (invitation.status == 'accepted' &&
                onOpenRoom != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : onOpenRoom,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('فتح المباراة'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
  });

  final SocialConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lastText = conversation.lastMessage?.text ?? '';
    final lastSticker = Sa7biSticker.tryParse(lastText);
    final preview = lastSticker != null
        ? 'استيكر من صاحبي'
        : lastText.isEmpty
            ? 'ابدأ المحادثة الآن'
            : lastText;

    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          backgroundColor: Color(0x222F9BFF),
          child: Icon(
            Icons.person_rounded,
            color: Color(0xFF7FB4FF),
          ),
        ),
        title: Text(
          conversation.otherUser.username,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: conversation.unreadCount > 0
            ? CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFFFD76A),
                child: Text(
                  conversation.unreadCount > 99
                      ? '99+'
                      : '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white54,
              ),
      ),
    );
  }
}

class SocialPrivateChatScreen extends StatefulWidget {
  const SocialPrivateChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;

  @override
  State<SocialPrivateChatScreen> createState() =>
      _SocialPrivateChatScreenState();
}

class _SocialPrivateChatScreenState extends State<SocialPrivateChatScreen> {
  final SocialMessagingService _service = SocialMessagingService.instance;
  final SocialRealtimeService _realtime = SocialRealtimeService.instance;
  final TextEditingController _composer = TextEditingController();

  Timer? _refreshTimer;
  Timer? _typingStopTimer;
  StreamSubscription<SocialRealtimeEvent>? _realtimeSubscription;

  List<SocialPrivateMessage> _messages = [];

  bool _loading = true;
  bool _refreshing = false;
  bool _sending = false;
  bool _realtimeConnected = false;
  bool _peerOnline = false;
  bool _peerTyping = false;
  bool _typingSent = false;

  String? _error;

  DateTime _lastSuccessfulSync =
      DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    _realtimeSubscription = _realtime.events.listen(_onRealtimeEvent);

    _loadMessages();
    unawaited(_connectRealtime());

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        final shouldPoll = !_realtimeConnected ||
            DateTime.now().difference(_lastSuccessfulSync) >=
                const Duration(seconds: 30);

        if (shouldPoll) {
          _loadMessages(silent: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _typingStopTimer?.cancel();
    _realtimeSubscription?.cancel();

    if (_typingSent) {
      _realtime.setTyping(false);
      _typingSent = false;
    }

    unawaited(_realtime.disconnect());

    _composer.dispose();
    super.dispose();
  }

  Future<void> _connectRealtime() async {
    try {
      await _realtime.connect(widget.conversationId);
    } catch (_) {
      if (mounted) {
        setState(() => _realtimeConnected = false);
      }
    }
  }

  void _onRealtimeEvent(SocialRealtimeEvent event) {
    final eventConversationId = event.conversationId;
    final nestedMessage = event.data['message'];
    final nestedConversationId = nestedMessage is Map
        ? nestedMessage['conversationId']
        : null;

    final relevantConversationId = eventConversationId ??
        (nestedConversationId is String ? nestedConversationId : null);

    if (relevantConversationId != null &&
        relevantConversationId != widget.conversationId) {
      return;
    }

    switch (event.type) {
      case 'connection.ready':
      case 'transport.connected':
        if (mounted) {
          setState(() => _realtimeConnected = true);
        }
        unawaited(_loadMessages(silent: true));
        break;

      case 'transport.disconnected':
      case 'transport.connection_error':
      case 'transport.send_error':
        if (mounted) {
          setState(() {
            _realtimeConnected = false;
            _peerTyping = false;
          });
        }
        break;

      case 'presence.changed':
        if (mounted) {
          setState(() {
            _peerOnline = event.isOnline ?? false;
          });
        }
        break;

      case 'typing.changed':
        if (mounted) {
          setState(() {
            _peerTyping = event.isTyping ?? false;
          });
        }
        break;

      case 'message.created':
      case 'message.read':
        unawaited(_loadMessages(silent: true));
        break;
    }
  }

  void _onComposerChanged(String value) {
    _typingStopTimer?.cancel();

    if (value.trim().isEmpty) {
      _stopTyping();
      return;
    }

    if (!_typingSent) {
      _typingSent = true;
      _realtime.setTyping(true);
    }

    _typingStopTimer = Timer(
      const Duration(seconds: 2),
      _stopTyping,
    );
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    _typingStopTimer = null;

    if (!_typingSent) return;

    _typingSent = false;
    _realtime.setTyping(false);
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_refreshing) return;

    _refreshing = true;

    try {
      final messages = await _service.getMessages(widget.conversationId);
      await _service.markConversationRead(widget.conversationId);

      _lastSuccessfulSync = DateTime.now();

      if (!mounted) return;

      setState(() {
        _messages = messages;
        _error = null;
        _loading = false;
      });
    } on SocialMessagingException catch (error) {
      if (!mounted || silent) return;

      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || silent) return;

      setState(() {
        _error = 'تعذر تحميل الرسائل. تحقق من الاتصال.';
        _loading = false;
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _send() async {
    if (_sending) return;

    final text = _composer.text.trim();
    if (text.isEmpty) return;

    _stopTyping();

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final message = await _service.sendMessage(
        conversationId: widget.conversationId,
        text: text,
      );

      if (!mounted) return;

      _composer.clear();

      setState(() {
        _messages = [..._messages, message];
      });

      await _service.markConversationRead(widget.conversationId);
    } on SocialMessagingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إرسال الرسالة. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openStickerPicker() async {
    _stopTyping();

    final sticker = await Sa7biStickerPicker.show(context);

    if (!mounted || sticker == null) return;

    await _sendSticker(sticker);
  }

  Future<void> _sendSticker(Sa7biSticker sticker) async {
    if (_sending) return;

    _stopTyping();

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final message = await _service.sendMessage(
        conversationId: widget.conversationId,
        text: sticker.toMessageText(),
      );

      if (!mounted) return;

      setState(() {
        _messages = [..._messages, message];
      });

      await _service.markConversationRead(widget.conversationId);
    } on SocialMessagingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إرسال الاستيكر. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _timeLabel(int milliseconds) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Widget _buildMessage(SocialPrivateMessage message) {
    final sticker = Sa7biSticker.tryParse(message.text);

    return Align(
      alignment:
          message.isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: message.isMine
              ? const Color(0xFF203B5C)
              : const Color(0xFF172033),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sticker != null)
              Sa7biStickerMessageView(sticker: sticker)
            else
              SocialConnectAttachmentMessageView(
                messageText: message.text,
              ),
            const SizedBox(height: 4),
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
                if (message.isMine) ...[
                  const SizedBox(width: 5),
                  Icon(
                    message.readAt == null
                        ? Icons.check_rounded
                        : Icons.done_all_rounded,
                    size: 13,
                    color: message.readAt == null
                        ? Colors.white38
                        : const Color(0xFF7FB4FF),
                  ),
                ],
              ],
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
          title: widget.title,
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
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 9, 12, 5),
              child: _ConnectNoticeBox(
                text:
                    'هذه محادثة خاصة بين الحسابين المشاركين. الرسائل محفوظة على الخادم وليست مشفرة من طرف إلى طرف في هذه النسخة.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _peerTyping
                        ? Icons.more_horiz_rounded
                        : _peerOnline
                            ? Icons.circle
                            : Icons.sync_rounded,
                    size: 11,
                    color: _peerTyping || _peerOnline
                        ? const Color(0xFF57D99A)
                        : _realtimeConnected
                            ? const Color(0xFF7FB4FF)
                            : Colors.white38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _peerTyping
                        ? 'يكتب الآن...'
                        : _peerOnline
                            ? 'متصل الآن'
                            : _realtimeConnected
                                ? 'الاتصال اللحظي نشط'
                                : 'المزامنة الاحتياطية نشطة',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: _ConnectErrorBox(message: _error!),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'ابدأ المحادثة برسالة لطيفة أو استيكر من صاحبي.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.builder(
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
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SocialConnectAttachmentControls(
                  scopeType: 'conversation',
                  scopeId: widget.conversationId,
                  onMessageSent: () =>
                      unawaited(_loadMessages(silent: true)),
                ),
                IconButton(
                  tooltip: 'استيكرات صاحبي',
                  onPressed: _sending ? null : _openStickerPicker,
                  icon: const Icon(
                    Icons.emoji_emotions_rounded,
                    color: Color(0xFFFFD76A),
                    size: 27,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _composer,
                    onChanged: _onComposerChanged,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك...',
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectErrorBox extends StatelessWidget {
  const _ConnectErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF51252C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _ConnectNoticeBox extends StatelessWidget {
  const _ConnectNoticeBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151D2C),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          height: 1.45,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ConnectEmptyBox extends StatelessWidget {
  const _ConnectEmptyBox({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, color: Colors.white30, size: 42),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
