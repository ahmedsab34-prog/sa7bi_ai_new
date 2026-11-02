import 'dart:async';

import 'package:flutter/material.dart';

import 'services/social_community_service.dart';
import 'services/social_games_service.dart';
import 'social_games_hub_screen.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

class SocialAiGamesScreen extends StatefulWidget {
  const SocialAiGamesScreen({super.key});

  @override
  State<SocialAiGamesScreen> createState() => _SocialAiGamesScreenState();
}

class _SocialAiGamesScreenState extends State<SocialAiGamesScreen> {
  final SocialCommunityService _community = SocialCommunityService.instance;
  final SocialGamesService _games = SocialGamesService.instance;
  List<SocialGameRoom> _rooms = const [];
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
      await _games.initialize();
      if (_community.isSignedIn) {
        await _games.getCurrentUser();
        await _loadRooms();
      }
    } on SocialCommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل مباريات الذكاء الاصطناعي.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRooms() async {
    final rooms = await _games.getMyRooms();
    if (!mounted) return;
    setState(() {
      _rooms = rooms.where((room) => room.state['aiOpponent'] == true).toList(growable: false);
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

  Future<void> _createAiRoom(String game) async {
    await _run(() async {
      final room = await _community.createAiRoom(game: game);
      if (!mounted) return;
      await _loadRooms();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => SocialAiGameRoomScreen(initialRoom: room)),
      );
      await _loadRooms();
    });
  }

  Future<void> _openRoom(SocialGameRoom room) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SocialAiGameRoomScreen(initialRoom: room)),
    );
    await _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: Sa7biSubpageAppBar(
          title: 'العب مع صاحبي AI',
          actions: [
            IconButton(
              tooltip: 'تحديث المباريات',
              onPressed: _busy || _loading ? null : () => _run(_loadRooms),
              icon: const Icon(Icons.refresh_rounded),
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
                          const Icon(Icons.smart_toy_rounded, size: 54, color: Color(0xFFFFD76A)),
                          const SizedBox(height: 12),
                          const Text(
                            'سجّل الدخول إلى حساب الألعاب حتى نحفظ مبارياتك وتقدر ترجع لها بعدين.',
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
                : ListView(
                    padding: const EdgeInsets.all(15),
                    children: [
                      const _AiIntro(),
                      const SizedBox(height: 16),
                      if (_error != null) _AiError(message: _error!),
                      const Text('اختار اللعبة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 9),
                      _AiGameChoice(
                        icon: Icons.grid_3x3_rounded,
                        title: 'إكس أو ضد الذكاء الاصطناعي',
                        description: 'الذكاء الاصطناعي يلعب بعد كل نقلة لك ويحاول منعك من الفوز.',
                        onTap: _busy ? null : () => _createAiRoom('tic_tac_toe'),
                      ),
                      _AiGameChoice(
                        icon: Icons.back_hand_rounded,
                        title: 'حجر ورقة مقص',
                        description: 'جولات متتالية ونتيجة محفوظة لكل جولة.',
                        onTap: _busy ? null : () => _createAiRoom('rock_paper_scissors'),
                      ),
                      _AiGameChoice(
                        icon: Icons.grid_4x4_rounded,
                        title: 'الشطرنج ضد الذكاء الاصطناعي',
                        description: 'مباراة شطرنج محفوظة. أنت الأبيض وصاحبي AI الأسود.',
                        onTap: _busy ? null : () => _createAiRoom('chess'),
                      ),
                      const SizedBox(height: 18),
                      const Text('مبارياتك المحفوظة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (_rooms.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('لا توجد مباراة محفوظة حتى الآن.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                        )
                      else
                        for (final room in _rooms)
                          Card(
                            color: const Color(0xFF111827),
                            child: ListTile(
                              onTap: () => _openRoom(room),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0x223F91FF),
                                child: Icon(Icons.smart_toy_rounded, color: Color(0xFF7FB4FF)),
                              ),
                              title: Text(room.gameTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              subtitle: Text(room.statusLabel, style: const TextStyle(color: Colors.white60)),
                              trailing: const Icon(Icons.chevron_left_rounded, color: Colors.white54),
                            ),
                          ),
                    ],
                  ),
      ),
    );
  }
}

class SocialAiGameRoomScreen extends StatefulWidget {
  const SocialAiGameRoomScreen({super.key, required this.initialRoom});
  final SocialGameRoom initialRoom;

  @override
  State<SocialAiGameRoomScreen> createState() => _SocialAiGameRoomScreenState();
}

class _SocialAiGameRoomScreenState extends State<SocialAiGameRoomScreen> {
  final SocialGamesService _games = SocialGamesService.instance;
  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();
  Timer? _poll;
  late SocialGameRoom _room;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_busy && mounted && !_room.isPaused && !_room.isFinished) {
        _refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_busy) return;
    try {
      final latest = await _games.getRoom(_room.id);
      if (!mounted) return;
      setState(() {
        _room = latest;
        if (!silent) _error = null;
      });
    } on SocialGamesException catch (error) {
      if (!mounted || silent) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => _error = 'تعذر تحديث المباراة.');
    }
  }

  Future<void> _move(Future<SocialGameRoom> Function() action) async {
    if (_busy || !_room.isPlaying) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _room = updated);
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تنفيذ الحركة. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(bool pause) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = pause
          ? await _games.pauseRoom(_room.id)
          : await _games.resumeRoom(_room.id);
      if (mounted) setState(() => _room = updated);
    } on SocialGamesException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تغيير حالة المباراة.');
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
        appBar: Sa7biSubpageAppBar(
          title: _room.gameTitle,
          actions: [
            IconButton(
              tooltip: 'مزامنة',
              onPressed: _busy ? null : () => _refresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            const _AiNotice(text: 'خصمك في هذه المباراة هو صاحبي AI. يتم حفظ الحالة على الخادم ويمكنك الرجوع للمباراة من قائمة مبارياتك.'),
            const SizedBox(height: 12),
            if (_error != null) _AiError(message: _error!),
            _AiNotice(text: 'الحالة: ${_room.statusLabel} • اللاعب: ${_room.host?.username ?? 'أنت'} • الخصم: صاحبي AI'),
            const SizedBox(height: 14),
            if (_room.isPaused)
              const _AiNotice(text: 'المباراة متوقفة مؤقتًا. اضغط استئناف للمتابعة.'),
            if (_room.isFinished)
              _AiNotice(text: _finishText()),
            if (_room.isPlaying) _buildGame(),
            const SizedBox(height: 14),
            if (_room.isPlaying)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _changeStatus(true),
                icon: const Icon(Icons.pause_rounded),
                label: const Text('إيقاف مؤقت'),
              ),
            if (_room.isPaused)
              FilledButton.icon(
                onPressed: _busy ? null : () => _changeStatus(false),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('استئناف المباراة'),
              ),
            if (_busy) const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  String _finishText() {
    if (_room.game == 'tic_tac_toe') {
      final winner = _room.state['winner'];
      if (winner == 'X') return 'مبروك! فزت على صاحبي AI.';
      if (winner == 'O') return 'صاحبي AI فاز هذه المرة. جرّب جولة أخرى.';
      return 'انتهت المباراة بالتعادل.';
    }
    if (_room.game == 'chess') {
      return _room.state['winnerUserId'] == 'sa7bi-ai'
          ? 'صاحبي AI فاز بالشطرنج.'
          : 'انتهت مباراة الشطرنج.';
    }
    return 'تم حفظ نتيجة الجولة. يمكنك بدء جولة جديدة من القائمة.';
  }

  Widget _buildGame() {
    switch (_room.game) {
      case 'tic_tac_toe':
        return _buildTicTacToe();
      case 'rock_paper_scissors':
        return _buildRps();
      case 'chess':
        return _buildChess();
      default:
        return const _AiNotice(text: 'اللعبة غير مدعومة.');
    }
  }

  Widget _buildTicTacToe() {
    final rawBoard = _room.state['board'];
    final board = rawBoard is List
        ? List<String>.generate(
            9,
            (index) => index < rawBoard.length && rawBoard[index] is String
                ? rawBoard[index] as String
                : '',
          )
        : List<String>.filled(9, '');
    final winner = _room.state['winner'];
    return Column(
      children: [
        const Text('أنت X وصاحبي AI هو O', style: TextStyle(color: Color(0xFFFFD76A), fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final mark = board[index];
            return InkWell(
              onTap: _busy || winner != null || mark.isNotEmpty
                  ? null
                  : () => _move(() => _games.playTicTacToe(roomId: _room.id, index: index)),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF172033),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                alignment: Alignment.center,
                child: Text(
                  mark,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: mark == 'X' ? const Color(0xFF7FB4FF) : const Color(0xFFFFA77B),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRps() {
    final result = _room.state['lastResult'];
    final botChoice = _room.state['lastBotChoice'];
    final scores = _room.state['scores'];
    final scoreMap = scores is Map ? scores : const {};
    final icons = {'rock': '✊ حجر', 'paper': '✋ ورقة', 'scissors': '✌️ مقص'};
    return Column(
      children: [
        const Text('اختار حركتك في الجولة التالية', style: TextStyle(color: Colors.white, fontSize: 17)),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _rpsButton('rock', '✊ حجر'),
            _rpsButton('paper', '✋ ورقة'),
            _rpsButton('scissors', '✌️ مقص'),
          ],
        ),
        if (result is String) ...[
          const SizedBox(height: 16),
          Text(result, style: const TextStyle(color: Color(0xFFFFD76A), fontSize: 17, fontWeight: FontWeight.w800)),
          if (botChoice is String)
            Text('اختيار صاحبي AI: ${icons[botChoice] ?? botChoice}', style: const TextStyle(color: Colors.white70)),
        ],
        const SizedBox(height: 12),
        Text(
          'النتيجة — أنت: ${scoreMap['host'] ?? 0} • صاحبي AI: ${scoreMap['guest'] ?? 0} • تعادل: ${scoreMap['draws'] ?? 0}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _rpsButton(String choice, String label) {
    return FilledButton.tonal(
      onPressed: _busy ? null : () => _move(
        () => _games.playRockPaperScissors(roomId: _room.id, choice: choice),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }

  Widget _buildChess() {
    final fen = _room.state['fen'];
    final turn = _room.state['turn'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AiNotice(text: 'أنت تلعب بالأبيض. صاحبي AI يلعب بالأسود. اكتب إحداثيات النقلة مثل e2 إلى e4.'),
        const SizedBox(height: 9),
        Text('الدور: ${turn == 'w' ? 'الأبيض — أنت' : 'الأسود — صاحبي AI'}', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFD76A))),
        if (fen is String) ...[
          const SizedBox(height: 8),
          SelectableText('FEN: $fen', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _from,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'من', hintText: 'e2', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: TextField(
                controller: _to,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'إلى', hintText: 'e4', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _busy || turn != 'w'
              ? null
              : () => _move(() => _games.playChessMove(
                    roomId: _room.id,
                    from: _from.text.trim().toLowerCase(),
                    to: _to.text.trim().toLowerCase(),
                  )),
          child: const Text('إرسال النقلة'),
        ),
      ],
    );
  }
}

class _AiIntro extends StatelessWidget {
  const _AiIntro();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: Color(0xFFFFD76A), size: 30),
            SizedBox(width: 10),
            Expanded(child: Text('لو لم تجد لاعبًا متاحًا، ابدأ مباراة مباشرة مع صاحبي AI. كل نقلة تُحفظ ويمكن استكمالها لاحقًا.', style: TextStyle(color: Colors.white70, height: 1.5))),
          ],
        ),
      );
}

class _AiGameChoice extends StatelessWidget {
  const _AiGameChoice({required this.icon, required this.title, required this.description, required this.onTap});
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF111827),
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(backgroundColor: const Color(0x223F91FF), child: Icon(icon, color: const Color(0xFF7FB4FF))),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          subtitle: Text(description, style: const TextStyle(color: Colors.white60, height: 1.4)),
          trailing: const Icon(Icons.chevron_left_rounded, color: Colors.white54),
        ),
      );
}

class _AiNotice extends StatelessWidget {
  const _AiNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: const Color(0xFF172033), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(color: Colors.white70, height: 1.45)),
      );
}

class _AiError extends StatelessWidget {
  const _AiError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFF4A2028), borderRadius: BorderRadius.circular(12)),
        child: Text(message, style: const TextStyle(color: Colors.white)),
      );
}
