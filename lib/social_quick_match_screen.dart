import 'dart:async';

import 'package:flutter/material.dart';

import 'services/social_community_service.dart';
import 'services/social_games_service.dart';
import 'social_ai_games_screen.dart';
import 'social_games_hub_screen.dart';

/// البحث عن لاعب حقيقي أولًا ثم التحويل التلقائي إلى صاحبي AI.
class SocialQuickMatchScreen extends StatefulWidget {
  const SocialQuickMatchScreen({super.key});

  @override
  State<SocialQuickMatchScreen> createState() => _SocialQuickMatchScreenState();
}

class _SocialQuickMatchScreenState extends State<SocialQuickMatchScreen> {
  final SocialCommunityService _community = SocialCommunityService.instance;
  final SocialGamesService _games = SocialGamesService.instance;

  Timer? _pollTimer;
  Timer? _clockTimer;
  SocialGameRoom? _room;
  DateTime? _searchDeadline;

  bool _loading = true;
  bool _busy = false;
  bool _polling = false;
  bool _openingRoom = false;
  String? _error;
  String? _pollNotice;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _pollTimer = null;
    _clockTimer = null;
  }

  Future<void> _initialize() async {
    try {
      await _community.refreshSession();
      await _games.initialize();
      if (_community.isSignedIn) {
        await _games.getCurrentUser();
      }
    } on SocialCommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر التحقق من حساب الألعاب.');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openLogin() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialGamesHubScreen(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _initialize();
  }

  Future<void> _startSearch(String game) async {
    if (_busy || _room != null) return;
    setState(() {
      _busy = true;
      _error = null;
      _pollNotice = null;
    });

    try {
      final result = await _community.quickMatch(game: game);
      if (!mounted) return;

      if (result.matched || result.room.isPlaying) {
        await _openResolvedRoom(result.room);
        return;
      }

      final wait = result.waitSeconds > 0 ? result.waitSeconds : 25;
      setState(() {
        _room = result.room;
        _secondsLeft = wait;
        _searchDeadline = DateTime.now().add(Duration(seconds: wait));
        _pollNotice = null;
      });
      _startTimers();
    } on SocialCommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر بدء البحث عن لاعب. تحقق من الاتصال.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startTimers() {
    _stopTimers();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = _searchDeadline;
      if (!mounted || deadline == null) return;
      final left = deadline.difference(DateTime.now()).inSeconds;
      if (left != _secondsLeft) {
        setState(() => _secondsLeft = left.clamp(0, 25).toInt());
      }
    });
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollRoom(),
    );
    unawaited(_pollRoom());
  }

  Future<void> _pollRoom() async {
    final current = _room;
    if (_polling || _openingRoom || current == null || !mounted) return;
    _polling = true;

    try {
      final latest = await _games.getRoom(current.id);
      if (!mounted) return;

      if (latest.state['aiOpponent'] == true) {
        await _openResolvedRoom(latest);
        return;
      }

      if (latest.isPlaying && latest.guest != null) {
        await _openResolvedRoom(latest);
        return;
      }

      if (latest.isFinished) {
        _stopTimers();
        setState(() {
          _room = null;
          _searchDeadline = null;
          _secondsLeft = 0;
          _error = 'انتهى البحث قبل بدء المباراة. ابدأ بحثًا جديدًا.';
        });
        return;
      }

      setState(() {
        _room = latest;
        _pollNotice = null;
      });
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _pollNotice = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _pollNotice = 'الاتصال ضعيف. سنحاول تحديث البحث تلقائيًا.');
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _openResolvedRoom(SocialGameRoom room) async {
    if (!mounted || _openingRoom) return;
    _openingRoom = true;
    _stopTimers();

    final isAi = room.state['aiOpponent'] == true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => isAi
              ? SocialAiGameRoomScreen(initialRoom: room)
              : SocialGameRoomScreen(initialRoom: room),
        ),
      );
    } finally {
      _openingRoom = false;
      if (mounted) {
        setState(() {
          _room = null;
          _searchDeadline = null;
          _secondsLeft = 0;
          _pollNotice = null;
        });
      }
    }
  }

  Future<void> _cancelSearch() async {
    final current = _room;
    if (current == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _community.cancelQuickMatch(current.id);
      _stopTimers();
      if (!mounted) return;
      setState(() {
        _room = null;
        _searchDeadline = null;
        _secondsLeft = 0;
        _pollNotice = null;
      });
    } on SocialCommunityException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        unawaited(_pollRoom());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إلغاء البحث بسبب مشكلة في الاتصال.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          title: const Text('العب مع لاعب أو صاحبي AI'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_community.isSignedIn
                ? _buildLoginRequired()
                : _room != null
                    ? _buildSearching()
                    : _buildGameChoices(),
      ),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_alt_rounded, size: 56, color: Color(0xFFFFD76A)),
            const SizedBox(height: 14),
            const Text(
              'سجّل الدخول إلى حساب الألعاب حتى نوصلك بلاعب حقيقي ونحفظ المباراة على حسابك.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.6),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openLogin,
              icon: const Icon(Icons.login_rounded),
              label: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameChoices() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _introCard(
          icon: Icons.groups_rounded,
          title: 'هنبحث لك عن لاعب حقيقي',
          description: 'لو مفيش لاعب متاح خلال 25 ثانية، نفس المباراة هتتحول تلقائيًا إلى مباراة ضد صاحبي AI.',
        ),
        const SizedBox(height: 16),
        if (_error != null) _messageCard(_error!, isError: true),
        _gameTile(
          icon: Icons.grid_3x3_rounded,
          title: 'إكس أو',
          subtitle: 'ابحث عن لاعب آخر، أو أكمل ضد صاحبي AI.',
          onTap: _busy ? null : () => _startSearch('tic_tac_toe'),
        ),
        _gameTile(
          icon: Icons.back_hand_rounded,
          title: 'حجر ورقة مقص',
          subtitle: 'منافسة سريعة وجولات متتابعة.',
          onTap: _busy ? null : () => _startSearch('rock_paper_scissors'),
        ),
        _gameTile(
          icon: Icons.grid_4x4_rounded,
          title: 'الشطرنج',
          subtitle: 'مباراة محفوظة ضد لاعب أو ضد صاحبي AI.',
          onTap: _busy ? null : () => _startSearch('chess'),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildSearching() {
    final room = _room!;
    final title = room.gameTitle;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _introCard(
          icon: Icons.people_alt_rounded,
          title: 'بنبحث لك عن لاعب في $title',
          description: 'سيتم تحويل المباراة تلقائيًا إلى صاحبي AI عند انتهاء المهلة، من غير ما تحتاج تبدأ من جديد.',
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 116,
            height: 116,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 116,
                  height: 116,
                  child: CircularProgressIndicator(
                    value: _secondsLeft <= 0 ? 1 : 1 - (_secondsLeft / 25),
                    strokeWidth: 7,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFFFD76A),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_secondsLeft',
                      style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900),
                    ),
                    const Text('ثانية', style: TextStyle(color: Colors.white60)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _messageCard(
          'رمز الغرفة ${room.inviteCode}. لو دخل لاعب آخر قبل انتهاء المهلة، هتلعبوا مع بعض. وإلا صاحبي AI هيدخل مكانه تلقائيًا.',
        ),
        if (_pollNotice != null) ...[
          const SizedBox(height: 10),
          _messageCard(_pollNotice!, isError: true),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          _messageCard(_error!, isError: true),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _busy ? null : _cancelSearch,
          icon: const Icon(Icons.close_rounded),
          label: const Text('إلغاء البحث'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _polling ? null : _pollRoom,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تحديث حالة البحث'),
        ),
      ],
    );
  }

  Widget _introCard({required IconData icon, required String title, required String description}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 34, color: const Color(0xFFFFD76A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 5),
                Text(description, style: const TextStyle(color: Colors.white70, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameTile({required IconData icon, required String title, required String subtitle, required VoidCallback? onTap}) {
    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        minVerticalPadding: 14,
        leading: CircleAvatar(
          backgroundColor: const Color(0x223F91FF),
          child: Icon(icon, color: const Color(0xFF7FB4FF)),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, height: 1.4)),
        trailing: const Icon(Icons.chevron_left_rounded, color: Colors.white54),
      ),
    );
  }

  Widget _messageCard(String message, {bool isError = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0x33D9534F) : const Color(0x221D9A78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isError ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Text(
        message,
        style: TextStyle(color: isError ? Colors.red[100] : Colors.white70, height: 1.5),
      ),
    );
  }
}
