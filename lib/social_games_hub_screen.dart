
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/social_games_service.dart';

/// مركز الألعاب الجماعية.
/// حالة الغرفة والحركات تأتي من الخادم، وليست محفوظة محليًا فقط.
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

class _SocialGamesHubScreenState
    extends State<SocialGamesHubScreen> {
  final SocialGamesService _service = SocialGamesService.instance;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _inviteCode = TextEditingController();

  bool _registerMode = false;
  bool _busy = false;
  bool _initialized = false;
  String? _error;
  SocialGameUser? _user;
  List<SocialGameRoom> _rooms = [];

  static const Color _background = Color(0xFF080B13);
  static const Color _panel = Color(0xFF121A2A);
  static const Color _gold = Color(0xFFFFD76A);

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
        final user = await _service.getCurrentUser();
        if (!mounted) return;
        setState(() {
          _user = user;
          _initialized = true;
        });
        await _loadRooms();
        return;
      }
    } catch (_) {
      // الجلسة القديمة قد تكون انتهت؛ يمكن تسجيل الدخول مجددًا.
      await _service.logout();
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  Future<void> _authenticate() async {
    final username = _username.text.trim();
    final password = _password.text;

    if (username.isEmpty || password.isEmpty) {
      _showMessage('اكتب اسم المستخدم وكلمة المرور أولًا.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = _registerMode
          ? await _service.register(
              username: username,
              password: password,
            )
          : await _service.login(
              username: username,
              password: password,
            );

      if (!mounted) return;
      setState(() => _user = result.user);
      await _loadRooms();
      _showMessage('أهلًا ${result.user.username}!');
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadRooms() async {
    if (!_service.isSignedIn) return;

    try {
      final rooms = await _service.getMyRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendlyError(e));
      }
    }
  }

  Future<void> _createRoom(String game) async {
    await _runBusy(() async {
      final room = await _service.createRoom(game: game);
      if (!mounted) return;
      await _showInvite(room);
      await _loadRooms();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SocialGameRoomScreen(
            initialRoom: room,
            service: _service,
            onShareInvite: widget.onShareInvite,
          ),
        ),
      );
      await _loadRooms();
    });
  }

  Future<void> _joinRoom() async {
    final code = _inviteCode.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showMessage('اكتب رمز الدعوة.');
      return;
    }

    await _runBusy(() async {
      final room = await _service.joinRoom(inviteCode: code);
      if (!mounted) return;
      _inviteCode.clear();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SocialGameRoomScreen(
            initialRoom: room,
            service: _service,
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
          service: _service,
          onShareInvite: widget.onShareInvite,
        ),
      ),
    );
    await _loadRooms();
  }

  Future<void> _showInvite(SocialGameRoom room) async {
    final message = _service.buildInviteMessage(room);

    if (widget.onShareInvite != null) {
      widget.onShareInvite!(message);
      return;
    }

    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) {
      _showMessage('تم نسخ الدعوة. ابعتها لصاحبك في الشات.');
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await _service.logout();
    if (!mounted) return;
    setState(() {
      _user = null;
      _rooms = [];
      _password.clear();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is SocialGamesException) return error.message;
    return 'تعذر الاتصال بخدمة الألعاب. حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _panel,
          title: const Text(
            'الألعاب الجماعية',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          actions: [
            if (_user != null)
              IconButton(
                tooltip: 'تحديث المباريات',
                onPressed: _busy ? null : _loadRooms,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        body: !_initialized
            ? const Center(
                child: CircularProgressIndicator(color: _gold),
              )
            : _user == null
                ? _buildLogin()
                : _buildLobby(),
      ),
    );
  }

  Widget _buildLogin() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _HeroPanel(
          icon: Icons.sports_esports_rounded,
          title: 'العبوا مع بعض',
          subtitle:
              'أنشئ غرفة، ابعت رمز الدعوة لصاحبك، وكملوا المباراة حتى لو قفلت التطبيق.',
        ),
        const SizedBox(height: 20),
        _sectionTitle(_registerMode ? 'إنشاء حساب ألعاب' : 'تسجيل الدخول'),
        const SizedBox(height: 12),
        TextField(
          controller: _username,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'اسم المستخدم',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'كلمة المرور',
            prefixIcon: Icon(Icons.lock_outline_rounded),
            helperText: 'عند إنشاء حساب جديد: 10 أحرف على الأقل.',
          ),
          onSubmitted: (_) => _busy ? null : _authenticate(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _ErrorPanel(message: _error!),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _authenticate,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_rounded),
          label: Text(
            _busy
                ? 'جارٍ الاتصال...'
                : _registerMode
                    ? 'إنشاء الحساب'
                    : 'دخول',
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _registerMode = !_registerMode;
                    _error = null;
                  }),
          child: Text(
            _registerMode
                ? 'عندي حساب بالفعل — تسجيل الدخول'
                : 'مستخدم جديد؟ أنشئ حساب ألعاب',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'حساب الألعاب مستقل عن حسابات أخرى داخل التطبيق. '
          'استخدم كلمة مرور قوية ولا تكرر كلمة مرور حساب مهم.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildLobby() {
    return RefreshIndicator(
      color: _gold,
      onRefresh: _loadRooms,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _HeroPanel(
            icon: Icons.waving_hand_rounded,
            title: 'أهلًا ${_user!.username}',
            subtitle: 'اختار لعبة وأنشئ غرفة، أو ادخل برمز دعوة وصلك.',
            trailing: IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('اختار لعبة'),
          const SizedBox(height: 10),
          _GameChoiceCard(
            icon: Icons.grid_3x3_rounded,
            title: 'إكس أو',
            subtitle: 'مباراة سريعة بين لاعبين.',
            color: const Color(0xFF7FB4FF),
            onTap: _busy ? null : () => _createRoom('tic_tac_toe'),
          ),
          _GameChoiceCard(
            icon: Icons.back_hand_rounded,
            title: 'حجر ورقة مقص',
            subtitle: 'اختار حركتك وشوف نتيجة الجولة.',
            color: const Color(0xFFFFA77B),
            onTap: _busy
                ? null
                : () => _createRoom('rock_paper_scissors'),
          ),
          _GameChoiceCard(
            icon: Icons.grid_4x4_rounded,
            title: 'الشطرنج',
            subtitle: 'نقلات يتحقق الخادم من قانونيتها.',
            color: _gold,
            onTap: _busy ? null : () => _createRoom('chess'),
          ),
          const SizedBox(height: 18),
          _sectionTitle('الانضمام برمز دعوة'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inviteCode,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    hintText: 'مثال: A7BC23',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _joinRoom,
                child: const Text('انضمام'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorPanel(message: _error!),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _sectionTitle('مبارياتي')),
              Text(
                '${_rooms.length} مباراة',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_rooms.isEmpty)
            const _EmptyPanel(
              text: 'لسه مفيش مباريات محفوظة. أنشئ غرفة وابدأ اللعب!',
            )
          else
            for (final room in _rooms)
              _RoomListCard(
                room: room,
                onTap: () => _openRoom(room),
                onInvite: () => _showInvite(room),
              ),
          const SizedBox(height: 12),
          const Text(
            'المباريات تظهر هنا من الخادم بعد تسجيل الدخول. '
            'لو خدمة الخادم غير مفعّلة، ستظهر رسالة خطأ واضحة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      );
}

class SocialGameRoomScreen extends StatefulWidget {
  const SocialGameRoomScreen({
    super.key,
    required this.initialRoom,
    required this.service,
    this.onShareInvite,
  });

  final SocialGameRoom initialRoom;
  final SocialGamesService service;
  final ValueChanged<String>? onShareInvite;

  @override
  State<SocialGameRoomScreen> createState() =>
      _SocialGameRoomScreenState();
}

class _SocialGameRoomScreenState extends State<SocialGameRoomScreen> {
  late SocialGameRoom _room;
  Timer? _pollTimer;
  bool _loading = false;
  bool _sendingMove = false;
  String? _error;

  final TextEditingController _from = TextEditingController();
  final TextEditingController _to = TextEditingController();

  static const Color _background = Color(0xFF080B13);
  static const Color _panel = Color(0xFF121A2A);
  static const Color _gold = Color(0xFFFFD76A);

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
    if (_loading) return;
    _loading = true;

    try {
      final updated = await widget.service.getRoom(_room.id);
      if (mounted) {
        setState(() {
          _room = updated;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _error = _friendlyError(e));
      }
    } finally {
      _loading = false;
    }
  }

  String _friendlyError(Object error) {
    if (error is SocialGamesException) return error.message;
    return 'تعذر تحديث المباراة. تحقق من الاتصال.';
  }

  Future<void> _move(Future<SocialGameRoom> Function() action) async {
    if (_sendingMove || !_room.isPlaying) return;

    setState(() {
      _sendingMove = true;
      _error = null;
    });

    try {
      // لا نعرض نجاح الحركة قبل تأكيد الخادم.
      final updated = await action();
      if (!mounted) return;
      setState(() => _room = updated);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
      await _refresh(silent: true);
    } finally {
      if (mounted) setState(() => _sendingMove = false);
    }
  }

  Future<void> _shareInvite() async {
    final message = widget.service.buildInviteMessage(_room);
    if (widget.onShareInvite != null) {
      widget.onShareInvite!(message);
    } else {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نسخ نص الدعوة.')),
        );
      }
    }
  }

  Future<void> _changeStatus() async {
    try {
      final room = _room.isPaused
          ? await widget.service.resumeRoom(_room.id)
          : await widget.service.pauseRoom(_room.id);
      if (mounted) setState(() => _room = room);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _room.state;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _panel,
          title: Text(_room.gameTitle),
          actions: [
            IconButton(
              tooltip: 'تحديث الحالة',
              onPressed: () => _refresh(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'دعوة صديق',
              onPressed: _shareInvite,
              icon: const Icon(Icons.share_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroPanel(
              icon: Icons.groups_rounded,
              title: _room.statusLabel,
              subtitle: 'رمز الدعوة: ${_room.inviteCode}',
              trailing: IconButton(
                tooltip: 'نسخ الرمز',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _room.inviteCode),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ رمز الدعوة.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, color: _gold),
              ),
            ),
            const SizedBox(height: 14),
            _PlayersPanel(room: _room),
            const SizedBox(height: 16),
            if (_error != null) _ErrorPanel(message: _error!),
            if (_room.isWaiting)
              const _EmptyPanel(
                text: 'الغرفة جاهزة. ابعت رمز الدعوة لصاحبك وانتظر انضمامه.',
              )
            else if (_room.isPaused)
              const _EmptyPanel(
                text: 'المباراة متوقفة مؤقتًا. استأنفها للمتابعة.',
              )
            else if (_room.isFinished)
              const _EmptyPanel(
                text: 'انتهت المباراة. يمكنك مراجعة الحالة أو الرجوع لمبارياتك.',
              )
            else if (_room.game == 'tic_tac_toe')
              _buildTicTacToe(state)
            else if (_room.game == 'rock_paper_scissors')
              _buildRps(state)
            else if (_room.game == 'chess')
              _buildChess(state)
            else
              const _EmptyPanel(text: 'نوع اللعبة غير معروف.'),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _sendingMove ? null : _changeStatus,
              icon: Icon(
                _room.isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              label: Text(
                _room.isPaused ? 'استئناف المباراة' : 'إيقاف مؤقت',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تتحدث حالة الغرفة تلقائيًا كل عدة ثوانٍ. '
              'لو انقطع الاتصال، حدّث الشاشة وحاول مرة أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicTacToe(Map<String, dynamic> state) {
    final raw = state['board'];
    final board = raw is List
        ? raw.map((v) => v?.toString() ?? '').toList()
        : List<String>.filled(9, '');
    final next = state['next']?.toString() ?? 'X';
    final winner = state['winner']?.toString();
    final role = _room.myRole;

    return Column(
      children: [
        _StatusStrip(
          text: winner != null && winner.isNotEmpty
              ? 'الفائز: $winner'
              : 'الدور الحالي: $next',
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final value = board[index];
              final myMark = role == 'host' ? 'X' : 'O';
              final enabled = _room.isPlaying &&
                  winner == null &&
                  value.isEmpty &&
                  next == myMark &&
                  !_sendingMove;

              return Material(
                color: const Color(0xFF172033),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: enabled
                      ? () => _move(
                            () => widget.service.playTicTacToe(
                              roomId: _room.id,
                              index: index,
                            ),
                          )
                      : null,
                  child: Center(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: value == 'X'
                            ? const Color(0xFF7FB4FF)
                            : const Color(0xFFFFA77B),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRps(Map<String, dynamic> state) {
    final choices = state['choices'] is Map
        ? Map<String, dynamic>.from(state['choices'] as Map)
        : <String, dynamic>{};
    final result = state['lastResult'] ?? state['result'];
    final myChoice = choices[_room.myRole]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusStrip(
          text: result is Map
              ? 'نتيجة الجولة: ${result['winner'] ?? result['result'] ?? 'اكتملت'}'
              : 'اختار حركتك. ستظهر النتيجة بعد اختيار اللاعبين.',
        ),
        const SizedBox(height: 12),
        if (myChoice != null)
          Text(
            'اختيارك الحالي: $myChoice',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _RpsButton(
              label: '✊ حجر',
              onPressed: _room.isPlaying && !_sendingMove && myChoice == null
                  ? () => _move(
                        () => widget.service.playRockPaperScissors(
                          roomId: _room.id,
                          choice: 'rock',
                        ),
                      )
                  : null,
            ),
            _RpsButton(
              label: '✋ ورقة',
              onPressed: _room.isPlaying && !_sendingMove && myChoice == null
                  ? () => _move(
                        () => widget.service.playRockPaperScissors(
                          roomId: _room.id,
                          choice: 'paper',
                        ),
                      )
                  : null,
            ),
            _RpsButton(
              label: '✌️ مقص',
              onPressed: _room.isPlaying && !_sendingMove && myChoice == null
                  ? () => _move(
                        () => widget.service.playRockPaperScissors(
                          roomId: _room.id,
                          choice: 'scissors',
                        ),
                      )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'تتجدد الجولة وفق قواعد الخادم بعد اكتمال اختيارات اللاعبين.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildChess(Map<String, dynamic> state) {
    final fen = state['fen']?.toString() ?? '';
    final history = state['history'] is List
        ? (state['history'] as List).map((v) => v.toString()).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusStrip(
          text: state['checkmate'] == true
              ? 'كش مات'
              : state['check'] == true
                  ? 'كش'
                  : 'الشطرنج — النقلات يتحقق منها الخادم',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            fen.isEmpty ? 'لم تصل حالة اللوحة بعد.' : 'FEN: $fen',
            textDirection: TextDirection.ltr,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'أدخل مربع البداية والوصول (مثل e2 ثم e4). '
          'الخادم يرفض أي نقلة غير قانونية.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _from,
                textDirection: TextDirection.ltr,
                textCapitalization: TextCapitalization.none,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'من',
                  hintText: 'e2',
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _to,
                textDirection: TextDirection.ltr,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'إلى',
                  hintText: 'e4',
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _room.isPlaying && !_sendingMove
              ? () => _move(
                    () => widget.service.playChessMove(
                      roomId: _room.id,
                      from: _from.text.trim().toLowerCase(),
                      to: _to.text.trim().toLowerCase(),
                    ),
                  )
              : null,
          child: const Text('إرسال النقلة والتحقق منها'),
        ),
        if (history.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'سجل النقلات',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            history.join('  •  '),
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF253354), Color(0xFF111827)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _SocialColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: _SocialColors.gold, size: 28),
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
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _GameChoiceCard extends StatelessWidget {
  const _GameChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF121A2A),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Colors.white12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.white60, height: 1.35),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white60,
        ),
      ),
    );
  }
}

class _RoomListCard extends StatelessWidget {
  const _RoomListCard({
    required this.room,
    required this.onTap,
    required this.onInvite,
  });

  final SocialGameRoom room;
  final VoidCallback onTap;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF121A2A),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          room.gameTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${room.statusLabel} • ${room.inviteCode}',
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            if (room.isWaiting)
              IconButton(
                tooltip: 'دعوة صديق',
                onPressed: onInvite,
                icon: const Icon(Icons.share_rounded, color: _SocialColors.gold),
              ),
            const Icon(Icons.chevron_left_rounded, color: Colors.white60),
          ],
        ),
      ),
    );
  }
}

class _PlayersPanel extends StatelessWidget {
  const _PlayersPanel({required this.room});

  final SocialGameRoom room;

  @override
  Widget build(BuildContext context) {
    Widget player(String label, SocialGamePlayer? value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF121A2A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              const Icon(Icons.person_rounded, color: _SocialColors.gold),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                value?.username ?? 'في انتظار اللاعب',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (value != null && value.mark.isNotEmpty)
                Text(
                  value.mark,
                  style: const TextStyle(color: _SocialColors.gold),
                ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        player('صاحب الغرفة', room.host),
        const SizedBox(width: 8),
        player('اللاعب الثاني', room.guest),
      ],
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF202A40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _SocialColors.gold,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RpsButton extends StatelessWidget {
  const _RpsButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 17)),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF4A2028),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, height: 1.4),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF121A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, height: 1.5),
      ),
    );
  }
}

class _SocialColors {
  static const Color gold = Color(0xFFFFD76A);
}
