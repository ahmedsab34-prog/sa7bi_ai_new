
import 'dart:async';

import 'package:flutter/material.dart';

import 'services/social_games_service.dart';

class SocialGamesHubScreen extends StatefulWidget {
  const SocialGamesHubScreen({
    super.key,
    this.onShareInvite,
  });

  final ValueChanged<String>? onShareInvite;

  @override
  State<SocialGamesHubScreen> createState() =>
      _SocialGamesHubScreenState();
}

class _SocialGamesHubScreenState extends State<SocialGamesHubScreen> {
  final SocialGamesService _service = SocialGamesService.instance;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _inviteCode = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _register = false;
  String? _error;
  List<SocialGameRoom> _rooms = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      if (_service.isSignedIn) {
        await _service.getCurrentUser();
        await _loadRooms();
      }
    } catch (_) {
      await _service.logout();
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _run(
    Future<void> Function() action,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } on SocialGamesException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'حصل خطأ غير متوقع. تحقق من الاتصال وحاول مرة أخرى.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authenticate() async {
    await _run(() async {
      final username = _username.text.trim();
      final password = _password.text;

      if (username.isEmpty || password.isEmpty) {
        throw const SocialGamesException(
          'INVALID_CREDENTIALS',
          'اكتب اسم المستخدم وكلمة المرور.',
        );
      }

      if (_register) {
        await _service.register(
          username: username,
          password: password,
        );
      } else {
        await _service.login(
          username: username,
          password: password,
        );
      }

      await _loadRooms();
    });
  }

  Future<void> _loadRooms() async {
    final rooms = await _service.getMyRooms();
    if (!mounted) return;

    setState(() {
      _rooms = rooms;
      _loading = false;
    });
  }

  Future<void> _createRoom(String game) async {
    await _run(() async {
      final room = await _service.createRoom(game: game);
      if (!mounted) return;

      await _loadRooms();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SocialGameRoomScreen(
            initialRoom: room,
            onShareInvite: widget.onShareInvite,
          ),
        ),
      );

      await _loadRooms();
    });
  }

  Future<void> _joinRoom() async {
    await _run(() async {
      final code = _inviteCode.text.trim().toUpperCase();
      if (code.isEmpty) {
        throw const SocialGamesException(
          'INVALID_INVITE_CODE',
          'اكتب رمز الدعوة أولًا.',
        );
      }

      final room = await _service.joinRoom(inviteCode: code);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SocialGameRoomScreen(
            initialRoom: room,
            onShareInvite: widget.onShareInvite,
          ),
        ),
      );

      await _loadRooms();
    });
  }

  Future<void> _openRoom(SocialGameRoom room) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SocialGameRoomScreen(
          initialRoom: room,
          onShareInvite: widget.onShareInvite,
        ),
      ),
    );
    await _loadRooms();
  }

  Future<void> _logout() async {
    await _run(() async {
      await _service.logout();
      if (!mounted) return;

      setState(() {
        _rooms = [];
        _username.clear();
        _password.clear();
      });
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
          title: const Text('الألعاب الجماعية'),
          actions: [
            if (_service.isSignedIn)
              IconButton(
                tooltip: 'تحديث المباريات',
                onPressed: _busy ? null : () => _run(_loadRooms),
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_service.isSignedIn
                ? _buildLogin()
                : _buildLobby(),
      ),
    );
  }

  Widget _buildLogin() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _HubIntro(
          title: 'العب مع أصحابك',
          description:
              'أنشئ حساب ألعاب، وادعُ صديقك برمز المباراة. '
              'تحتاج إلى اتصال بالإنترنت.',
        ),
        const SizedBox(height: 20),
        _field(
          controller: _username,
          label: 'اسم المستخدم',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _password,
          label: 'كلمة المرور',
          icon: Icons.lock_outline_rounded,
          obscure: true,
        ),
        const SizedBox(height: 14),
        if (_error != null) _ErrorPanel(message: _error!),
        FilledButton.icon(
          onPressed: _busy ? null : _authenticate,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _register
                      ? Icons.person_add_alt_1_rounded
                      : Icons.login_rounded,
                ),
          label: Text(
            _busy
                ? 'جارٍ الاتصال...'
                : _register
                    ? 'إنشاء حساب ألعاب'
                    : 'تسجيل الدخول',
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _register = !_register;
                    _error = null;
                  }),
          child: Text(
            _register
                ? 'لديك حساب بالفعل؟ سجّل الدخول'
                : 'ليس لديك حساب؟ أنشئ حسابًا',
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'إنشاء الحساب يتطلب اسم مستخدم من 3 إلى 24 حرفًا '
          'وكلمة مرور من 10 أحرف على الأقل.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLobby() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _HubIntro(
          title: 'اختار لعبتك',
          description:
              'أنشئ غرفة وشارك رمزها مع صديقك، أو انضم إلى غرفة '
              'أنشأها لاعب آخر.',
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _ErrorPanel(message: _error!),
          const SizedBox(height: 12),
        ],
        const Text(
          'إنشاء مباراة جديدة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _GameChoice(
          icon: Icons.grid_3x3_rounded,
          title: 'إكس أو',
          description: 'مباراة سريعة بين لاعبين.',
          onTap: _busy ? null : () => _createRoom('tic_tac_toe'),
        ),
        _GameChoice(
          icon: Icons.back_hand_rounded,
          title: 'حجر ورقة مقص',
          description: 'اختار حركتك وتحدَّ صديقك.',
          onTap: _busy
              ? null
              : () => _createRoom('rock_paper_scissors'),
        ),
        _GameChoice(
          icon: Icons.grid_4x4_rounded,
          title: 'الشطرنج',
          description: 'أنشئ مباراة شطرنج مع لاعب آخر.',
          onTap: _busy ? null : () => _createRoom('chess'),
        ),
        const SizedBox(height: 20),
        const Text(
          'الانضمام برمز دعوة',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inviteCode,
                textCapitalization: TextCapitalization.characters,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: 'مثال: A7BC23',
                  filled: true,
                  fillColor: Color(0xFF151D2C),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _joinRoom,
              child: const Text('انضمام'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'مبارياتي المحفوظة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _busy ? null : () => _run(_loadRooms),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (_rooms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'لا توجد مباريات مرتبطة بحسابك حتى الآن.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          for (final room in _rooms)
            Card(
              color: const Color(0xFF111827),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22FFD76A),
                  child: Icon(
                    Icons.sports_esports_rounded,
                    color: Color(0xFFFFD76A),
                  ),
                ),
                title: Text(
                  room.gameTitle,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${room.statusLabel} • الرمز ${room.inviteCode}',
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white70,
                ),
                onTap: () => _openRoom(room),
              ),
            ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF151D2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}

class SocialGameRoomScreen extends StatefulWidget {
  const SocialGameRoomScreen({
    super.key,
    required this.initialRoom,
    this.onShareInvite,
  });

  final SocialGameRoom initialRoom;
  final ValueChanged<String>? onShareInvite;

  @override
  State<SocialGameRoomScreen> createState() =>
      _SocialGameRoomScreenState();
}

class _SocialGameRoomScreenState extends State<SocialGameRoomScreen> {
  final SocialGamesService _service = SocialGamesService.instance;
  final TextEditingController _from = TextEditingController(text: 'e2');
  final TextEditingController _to = TextEditingController(text: 'e4');

  late SocialGameRoom _room;
  Timer? _pollTimer;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_busy) return;

    try {
      final latest = await _service.getRoom(_room.id);
      if (!mounted) return;
      setState(() {
        _room = latest;
        if (!silent) _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = e is SocialGamesException
            ? e.message
            : 'تعذر تحديث المباراة.';
      });
    }
  }

  Future<void> _move(
    Future<SocialGameRoom> Function() action,
  ) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final updated = await action();
      if (!mounted) return;

      setState(() => _room = updated);
    } on SocialGamesException catch (e) {
      if (mounted) setState(() => _error = e.message);
      await _refresh(silent: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'تعذر إرسال الحركة. حدّث المباراة قبل المحاولة مرة أخرى.';
        });
      }
      await _refresh(silent: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _shareInvite() {
    final message = _service.buildInviteMessage(_room);
    final callback = widget.onShareInvite;

    if (callback != null) {
      callback(message);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح المشاركة من هذه الشاشة.'),
        ),
      );
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
          title: Text(_room.gameTitle),
          actions: [
            IconButton(
              tooltip: 'مشاركة الدعوة',
              onPressed: _shareInvite,
              icon: const Icon(Icons.share_rounded),
            ),
            IconButton(
              tooltip: 'تحديث المباراة',
              onPressed: _busy ? null : () => _refresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HubIntro(
              title: _room.statusLabel,
              description:
                  'رمز الدعوة: ${_room.inviteCode}\n'
                  'احتفظ بالرمز للعودة إلى المباراة أو مشاركة الدعوة.',
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              _ErrorPanel(message: _error!),
              const SizedBox(height: 12),
            ],
            if (_room.isWaiting)
              const _NoticePanel(
                message:
                    'المباراة تنتظر لاعبًا آخر. شارك رمز الدعوة مع صديقك.',
              ),
            if (_room.isPaused)
              const _NoticePanel(
                message: 'المباراة متوقفة مؤقتًا.',
              ),
            if (_room.isPlaying) _buildGame(),
            if (_room.isFinished)
              const _NoticePanel(
                message: 'انتهت المباراة. يمكنك الرجوع إلى قائمة المباريات.',
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _refresh(),
              icon: const Icon(Icons.sync_rounded),
              label: const Text('مزامنة حالة المباراة'),
            ),
            if (_room.isPlaying)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _move(
                          () => _service.pauseRoom(_room.id),
                        ),
                icon: const Icon(Icons.pause_rounded),
                label: const Text('إيقاف مؤقت'),
              ),
            if (_room.isPaused)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _move(
                          () => _service.resumeRoom(_room.id),
                        ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('استئناف المباراة'),
              ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
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
        return const _NoticePanel(
          message: 'نوع اللعبة غير معروف في هذه النسخة.',
        );
    }
  }

  Widget _buildTicTacToe() {
    final rawBoard = _room.state['board'];
    final board = rawBoard is List
        ? List<String>.generate(
            9,
            (i) => i < rawBoard.length && rawBoard[i] is String
                ? rawBoard[i] as String
                : '',
          )
        : List<String>.filled(9, '');

    final winner = _room.state['winner'];
    final next = _room.state['next'];

    return Column(
      children: [
        Text(
          winner == null
              ? 'الدور الحالي: ${next ?? 'X'}'
              : 'انتهت الجولة: $winner',
          style: const TextStyle(
            color: Color(0xFFFFD76A),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
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
              onTap: _busy ||
                      !_room.isPlaying ||
                      winner != null ||
                      mark.isNotEmpty
                  ? null
                  : () => _move(
                        () => _service.playTicTacToe(
                          roomId: _room.id,
                          index: index,
                        ),
                      ),
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
                    color: mark == 'X'
                        ? const Color(0xFF7FB4FF)
                        : const Color(0xFFFFA77B),
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
    final choices = _room.state['choices'];
    final myChoice = choices is Map
        ? choices[_room.myRole]
        : null;
    final result = _room.state['lastResult'] ??
        _room.state['result'];

    return Column(
      children: [
        const Text(
          'اختار حركة الجولة',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _rpsButton('rock', '✊ حجر', myChoice),
            _rpsButton('paper', '✋ ورقة', myChoice),
            _rpsButton('scissors', '✌️ مقص', myChoice),
          ],
        ),
        const SizedBox(height: 12),
        if (myChoice != null)
          const Text(
            'تم تسجيل اختيارك. انتظر اختيار اللاعب الآخر.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        if (result != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'نتيجة الجولة: $result',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFD76A)),
            ),
          ),
      ],
    );
  }

  Widget _rpsButton(String choice, String label, dynamic myChoice) {
    return FilledButton.tonal(
      onPressed: _busy ||
              !_room.isPlaying ||
              myChoice != null
          ? null
          : () => _move(
                () => _service.playRockPaperScissors(
                  roomId: _room.id,
                  choice: choice,
                ),
              ),
      child: Text(label, style: const TextStyle(fontSize: 17)),
    );
  }

  Widget _buildChess() {
    final fen = _room.state['fen'];
    final turn = _room.state['turn'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _NoticePanel(
          message:
              'إدخال النقلة هنا بالإحداثيات. مثال: من e2 إلى e4. '
              'الخادم يتحقق من قانونية الحركة.',
        ),
        const SizedBox(height: 12),
        Text(
          'الدور: ${turn == 'w' ? 'الأبيض' : 'الأسود'}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFD76A)),
        ),
        const SizedBox(height: 8),
        if (fen is String)
          SelectableText(
            'FEN: $fen',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _from,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'من',
                  hintText: 'e2',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _to,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'إلى',
                  hintText: 'e4',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || !_room.isPlaying
              ? null
              : () {
                  final from = _from.text.trim().toLowerCase();
                  final to = _to.text.trim().toLowerCase();

                  _move(
                    () => _service.playChessMove(
                      roomId: _room.id,
                      from: from,
                      to: to,
                    ),
                  );
                },
          child: const Text('إرسال النقلة'),
        ),
      ],
    );
  }
}

class _HubIntro extends StatelessWidget {
  const _HubIntro({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF202A45), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sports_esports_rounded,
            size: 34,
            color: Color(0xFFFFD76A),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameChoice extends StatelessWidget {
  const _GameChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFFFFD76A), size: 30),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF51252C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class _NoticePanel extends StatelessWidget {
  const _NoticePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF151D2C),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          height: 1.5,
        ),
      ),
    );
  }
}
