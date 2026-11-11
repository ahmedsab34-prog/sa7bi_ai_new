
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'monetization_config.dart';
import 'profile_screen.dart';
import 'secure_venting_screen.dart';
import 'service_config.dart';
import 'services/social_games_service.dart';
import 'services/social_guest_session_service.dart';
import 'services/social_messaging_service.dart';
import 'social_connections_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/app_header.dart';
import 'widgets/audio_center_with_header.dart';

/// تبويب الشات الرئيسي.
///
/// الرسائل: محادثات مباشرة بين المستخدمين الحقيقيين.
/// البحث: البحث عن حسابات صاحبي AI المسجلة.
/// الفضفضة: محادثة AI خاصة محمية بقفل الفضفضة.
///
/// لا يستخدم هذا التبويب محادثة AI العامة؛ مدخلها هو خلصانة AI.
class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  static const int _messagesMode = 0;
  static const int _searchMode = 1;
  static const int _ventingMode = 2;

  final SocialGamesService _games = SocialGamesService.instance;
  final SocialMessagingService _messaging =
      SocialMessagingService.instance;

  final TextEditingController _searchController =
      TextEditingController();

  Timer? _refreshTimer;
  Timer? _searchDebounce;

  int _selectedMode = _messagesMode;
  int _searchSequence = 0;

  bool _loading = true;
  bool _refreshing = false;
  bool _searching = false;
  bool _busy = false;

  String? _error;
  String? _searchError;
  String _myUsername = '';

  List<SocialConversationSummary> _conversations = [];
  List<SocialGameUser> _players = [];

  Widget? _privateVentingScreen;

  @override
  void initState() {
    super.initState();

    _initialize();

    // تحديث قائمة المحادثات دوريًا حتى تظهر الرسائل الجديدة
    // دون الحاجة إلى الخروج من التبويب والعودة إليه.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) {
        if (mounted && _selectedMode == _messagesMode) {
          unawaited(_refreshConversations(silent: true));
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // إنشاء أو استعادة حساب الضيف تلقائيًا.
      await SocialGuestSessionService.instance.ensureSession();

      await _games.initialize();
      await _messaging.refreshSession();

      // التحقق من الجلسة والحصول على اسم الحساب الحالي.
      final currentUser = await _games.getCurrentUser();

      final conversations = await _messaging.getConversations();

      if (!mounted) return;

      setState(() {
        _myUsername = currentUser.username;
        _conversations = conversations;
        _error = null;
        _loading = false;
      });
    } on SocialGamesException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on SocialMessagingException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'تعذر تجهيز الرسائل. تحقق من الإنترنت وحاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  Future<void> _refreshConversations({
    bool silent = false,
  }) async {
    if (_refreshing || !_messaging.isSignedIn) return;

    _refreshing = true;

    try {
      final conversations = await _messaging.getConversations();

      if (!mounted) return;

      setState(() {
        _conversations = conversations;
        _error = null;
      });
    } on SocialMessagingException catch (error) {
      if (!silent && mounted) {
        setState(() {
          _error = error.message;
        });
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() {
          _error = 'تعذر تحديث المحادثات. حاول مرة أخرى.';
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (profileContext) => ProfileScreen(
          onProfileTap: () {
            Navigator.of(profileContext).maybePop();
          },
          onAudio: _openAudioCenter,
        ),
      ),
    );
  }

  void _openAudioCenter() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudioCenterWithHeader(
          onProfileTap: _openProfile,
        ),
      ),
    );
  }

  void _selectMode(int mode) {
    if (mode == _selectedMode) {
      if (mode == _messagesMode) {
        unawaited(_refreshConversations());
      }
      return;
    }

    setState(() {
      if (mode == _ventingMode) {
        _privateVentingScreen ??= _createPrivateVentingScreen();
      }

      _selectedMode = mode;
    });

    if (mode == _messagesMode) {
      unawaited(_refreshConversations());
    }
  }

  // ============================================================
  // PRIVATE AI VENTING
  // ============================================================

  String _ventingContext() {
    for (final service in sa7biServices) {
      if (service.serviceKey == ServiceKeys.venting) {
        return service.aiRole;
      }
    }

    return '''
أنت مساعد فضفضة خاص في تطبيق صاحبي AI.
استمع للمستخدم باحترام وبدون أحكام.
ساعده على ترتيب أفكاره واختيار خطوات عملية.
لا تدّعي أنك طبيب أو معالج.
حافظ على خصوصية المحادثة ولا تطلب بيانات حساسة.
''';
  }

  Widget _createPrivateVentingScreen() {
    return SecureVentingScreen(
      child: ChatScreen(
        key: const ValueKey<String>('private-ai-venting-chat'),
        serviceKey: ServiceKeys.venting,
        serviceTitle: 'الفضفضة السرية',
        serviceContext: _ventingContext(),
        embedded: true,
        onProfileTap: _openProfile,
        onAudioTap: _openAudioCenter,
      ),
    );
  }

  // ============================================================
  // SEARCH USERS
  // ============================================================

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
      () => _searchUsers(query, sequence),
    );
  }

  Future<void> _searchUsers(
    String query,
    int sequence,
  ) async {
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
        _searchError = 'تعذر البحث عن المستخدمين. تحقق من الاتصال.';
      });
    }
  }

  Future<void> _startConversation(SocialGameUser player) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
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

      await _refreshConversations();
    } on SocialMessagingException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } on SocialGamesException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر فتح المحادثة. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN EXISTING CONVERSATION
  // ============================================================

  Future<void> _openConversation(
    SocialConversationSummary conversation,
  ) async {
    if (_busy) return;

    setState(() {
      _busy = true;
    });

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SocialPrivateChatScreen(
            conversationId: conversation.id,
            title: conversation.otherUser.username,
          ),
        ),
      );

      await _refreshConversations();
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر فتح المحادثة.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ============================================================
  // INVITE PEOPLE WHO DO NOT HAVE THE APP
  // ============================================================

  Future<void> _shareAppInvite() async {
    final username = _myUsername.trim();

    final usernameLine = username.isEmpty
        ? ''
        : '\nبعد تثبيت التطبيق ابحث عني باسم المستخدم: $username';

    final message = '''
تعالى نتواصل على صاحبي AI ❤️

حمّل التطبيق من هنا:
${MonetizationConfig.appDownloadUrl}
$usernameLine
''';

    try {
      await Share.share(
        message,
        subject: 'دعوة للانضمام إلى صاحبي AI',
      );
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر فتح قائمة المشاركة.');
      }
    }
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

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

  String _timeLabel(int milliseconds) {
    if (milliseconds <= 0) return '';

    final date =
        DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    final now = DateTime.now();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '$hour:$minute';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  String _initial(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return 'ص';

    return cleaned.characters.first;
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          AppHeader(
            onProfileTap: _openProfile,
            onAudioTap: _openAudioCenter,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: _buildModeSelector(),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedMode,
              children: [
                _buildConversations(),
                _buildDiscover(),
                _privateVentingScreen ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 43,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ChatModeButton(
              title: 'الرسائل',
              icon: Icons.chat_bubble_rounded,
              selected: _selectedMode == _messagesMode,
              onTap: () => _selectMode(_messagesMode),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ChatModeButton(
              title: 'بحث الأصدقاء',
              icon: Icons.person_search_rounded,
              selected: _selectedMode == _searchMode,
              onTap: () => _selectMode(_searchMode),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ChatModeButton(
              title: 'فضفضة سرية',
              icon: Icons.lock_rounded,
              selected: _selectedMode == _ventingMode,
              onTap: () => _selectMode(_ventingMode),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONVERSATION LIST
  // ============================================================

  Widget _buildConversations() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshConversations,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        children: [
          _buildConversationHeader(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _buildErrorCard(_error!),
          ],
          const SizedBox(height: 8),
          if (_conversations.isEmpty)
            _buildEmptyConversations()
          else
            for (final conversation in _conversations)
              _buildConversationTile(conversation),
          const SizedBox(height: 12),
          _buildPrivacyNotice(),
        ],
      ),
    );
  }

  Widget _buildConversationHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رسائلك',
                style: TextStyle(
                  color: Sa7biTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'تواصل مع أصحابك مباشرة',
                style: TextStyle(
                  color: Sa7biTheme.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'بحث عن صديق',
          onPressed: () => _selectMode(_searchMode),
          icon: const Icon(
            Icons.person_add_alt_1_rounded,
            color: Sa7biTheme.blueBright,
          ),
        ),
        IconButton(
          tooltip: 'تحديث المحادثات',
          onPressed: _refreshing
              ? null
              : () => _refreshConversations(),
          icon: const Icon(
            Icons.refresh_rounded,
            color: Sa7biTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildConversationTile(
    SocialConversationSummary conversation,
  ) {
    final username = conversation.otherUser.username;
    final lastMessage = conversation.lastMessage;
    final preview = lastMessage == null ||
            lastMessage.text.trim().isEmpty
        ? 'ابدأ المحادثة'
        : lastMessage.text.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _busy ? null : () => _openConversation(conversation),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 10,
            ),
            child: Row(
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: Sa7biTheme.brandGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Sa7biTheme.blue.withValues(alpha: 0.14),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _initial(username),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Sa7biTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Sa7biTheme.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _timeLabel(
                        lastMessage?.createdAt ??
                            conversation.updatedAt,
                      ),
                      style: const TextStyle(
                        color: Sa7biTheme.textMuted,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (conversation.unreadCount > 0)
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 19,
                          minHeight: 19,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Sa7biTheme.blue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : conversation.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyConversations() {
    return Container(
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.forum_outlined,
            color: Sa7biTheme.blueBright,
            size: 42,
          ),
          const SizedBox(height: 10),
          const Text(
            'لسه مفيش محادثات',
            style: TextStyle(
              color: Sa7biTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ابحث عن صاحب عنده التطبيق وابدأوا الكلام مباشرة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => _selectMode(_searchMode),
            icon: const Icon(Icons.person_search_rounded),
            label: const Text('ابحث عن أصحاب'),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Sa7biTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Sa7biTheme.textMuted,
            size: 17,
          ),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'الرسائل الفردية محفوظة على الخادم ومحمية بصلاحيات الحسابين. '
              'التشفير من طرف إلى طرف غير متوفر في النسخة الحالية.',
              style: TextStyle(
                color: Sa7biTheme.textSecondary,
                fontSize: 9.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISCOVER USERS AND INVITE NEW PEOPLE
  // ============================================================

  Widget _buildDiscover() {
    final query = _searchController.text.trim();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        const Text(
          'اكتشف أصحابك',
          style: TextStyle(
            color: Sa7biTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ابحث باسم المستخدم لبدء محادثة مباشرة.',
          style: TextStyle(
            color: Sa7biTheme.textSecondary,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 13),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textDirection: TextDirection.rtl,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          style: const TextStyle(
            color: Sa7biTheme.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: 'اكتب اسم المستخدم...',
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
            fillColor: Sa7biTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: Sa7biTheme.border,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildInviteBanner(),
        const SizedBox(height: 13),
        if (_searching)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_searchError != null)
          _buildErrorCard(_searchError!)
        else if (query.length < 2)
          _buildSearchHint()
        else if (_players.isEmpty)
          _buildNoSearchResults()
        else
          for (final player in _players)
            _buildPlayerTile(player),
      ],
    );
  }

  Widget _buildInviteBanner() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: Sa7biTheme.premiumGradient,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: Sa7biTheme.blue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Sa7biTheme.blueBright,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صاحبك مش عنده التطبيق؟',
                  style: TextStyle(
                    color: Sa7biTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'ابعت له رابط التحميل من أي تطبيق مشاركة.',
                  style: TextStyle(
                    color: Sa7biTheme.textSecondary,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'دعوة صديق',
            onPressed: _shareAppInvite,
            icon: const Icon(
              Icons.share_rounded,
              color: Sa7biTheme.blueBright,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHint() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: const Text(
        'اكتب حرفين على الأقل للبحث عن حساب مسجل في صاحبي AI. '
        'ولو الشخص مش عنده التطبيق، استخدم زر الدعوة وأرسل له رابط التحميل.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Sa7biTheme.textSecondary,
          fontSize: 10.5,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: const Text(
        'لم يتم العثور على حساب بهذا الاسم. '
        'تأكد من اسم المستخدم أو أرسل لصاحبك رابط التطبيق.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Sa7biTheme.textSecondary,
          fontSize: 10.5,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildPlayerTile(SocialGameUser player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Sa7biTheme.blue.withValues(alpha: 0.16),
          child: Text(
            _initial(player.username),
            style: const TextStyle(
              color: Sa7biTheme.blueBright,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          player.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Sa7biTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text(
          'حساب على صاحبي AI',
          style: TextStyle(
            color: Sa7biTheme.textSecondary,
            fontSize: 9,
          ),
        ),
        trailing: FilledButton.tonalIcon(
          onPressed: _busy ? null : () => _startConversation(player),
          icon: const Icon(
            Icons.chat_rounded,
            size: 15,
          ),
          label: const Text(
            'مراسلة',
            style: TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Sa7biTheme.danger.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Sa7biTheme.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Sa7biTheme.textPrimary,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
          IconButton(
            tooltip: 'إعادة المحاولة',
            onPressed: _initialize,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Sa7biTheme.blueBright,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatModeButton extends StatelessWidget {
  const _ChatModeButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? Sa7biTheme.blue.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected
                    ? Sa7biTheme.blue.withValues(alpha: 0.7)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? Sa7biTheme.blueBright
                      : Sa7biTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Sa7biTheme.textPrimary
                          : Sa7biTheme.textSecondary,
                      fontSize: 9.5,
                      fontWeight: selected
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
