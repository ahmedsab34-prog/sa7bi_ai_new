import 'package:flutter/material.dart';

import 'services/local_board_games_service.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/sa7bi_chess_board.dart';

class LocalBoardGamesScreen extends StatefulWidget {
  const LocalBoardGamesScreen({super.key});

  @override
  State<LocalBoardGamesScreen> createState() =>
      _LocalBoardGamesScreenState();
}

class _LocalBoardGamesScreenState
    extends State<LocalBoardGamesScreen> {
  final LocalBoardGamesService _service =
      LocalBoardGamesService.instance;

  List<LocalBoardGameSession> _sessions = [];
  LocalBoardGameSession? _active;

  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final games = await _service.getGames();

      if (!mounted) return;

      setState(() {
        _sessions = games;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _createGame(String game, String mode) async {
    await _run(() async {
      final session = await _service.createGame(
        game: game,
        mode: mode,
      );

      if (!mounted) return;
      setState(() => _active = session);
      await _loadSessions();
    });
  }

  Future<void> _resumeGame(String id) async {
    await _run(() async {
      final session = await _service.getGame(id);

      if (session == null) {
        throw const LocalBoardGamesException(
          'GAME_NOT_FOUND',
          'المباراة لم تعد موجودة.',
        );
      }

      if (!mounted) return;
      setState(() => _active = session);
    });
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
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _playChess(String from, String to) async {
    final session = _active;
    if (session == null) return;

    await _run(() async {
      final updated = await _service.playChessMove(
        sessionId: session.id,
        from: from,
        to: to,
      );

      if (!mounted) return;
      setState(() => _active = updated);
      await _loadSessions();
    });
  }

  Future<void> _playXO(int index) async {
    final session = _active;
    if (session == null) return;

    await _run(() async {
      final updated = await _service.playTicTacToeMove(
        sessionId: session.id,
        index: index,
      );

      if (!mounted) return;
      setState(() => _active = updated);
      await _loadSessions();
    });
  }

  Future<void> _playRPS(String choice) async {
    final session = _active;
    if (session == null) return;

    await _run(() async {
      final updated = await _service.playRockPaperScissors(
        sessionId: session.id,
        choice: choice,
      );

      if (!mounted) return;
      setState(() => _active = updated);
      await _loadSessions();
    });
  }

  Future<void> _deleteGame(String id) async {
    await _run(() async {
      await _service.deleteGame(id);
      await _loadSessions();
    });
  }

  void _showLobby() {
    setState(() {
      _active = null;
      _error = null;
    });
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: AppBar(
          title: Text(
            active == null ? 'الألعاب بدون إنترنت' : active.gameTitle,
          ),
          backgroundColor: Sa7biTheme.background,
          actions: [
            if (active != null)
              IconButton(
                tooltip: 'قائمة الألعاب',
                onPressed: _busy ? null : _showLobby,
                icon: const Icon(Icons.grid_view_rounded),
              ),
            IconButton(
              tooltip: 'تحديث',
              onPressed: _busy ? null : _loadSessions,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : active == null
                ? _buildLobby()
                : _buildActiveGame(active),
      ),
    );
  }

  Widget _buildLobby() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: Sa7biTheme.premiumGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Sa7biTheme.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'العب في أي وقت',
                style: TextStyle(
                  color: Sa7biTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'الألعاب دي تعمل بدون إنترنت أو حساب. تقدر تلعب ضد الكمبيوتر أو مع شخص بجانبك، وتكمل المباراة المحفوظة بعدين.',
                style: TextStyle(
                  color: Sa7biTheme.textSecondary,
                  height: 1.6,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        _gameCard(
          game: 'chess',
          title: 'الشطرنج',
          description:
              'قواعد شطرنج قانونية، كش وكش مات وتبييت وترقية البيدق.',
          icon: Icons.grid_4x4_rounded,
        ),
        _gameCard(
          game: 'tic_tac_toe',
          title: 'إكس أو',
          description:
              'تحدَّ الكمبيوتر أو العب مع لاعب آخر على نفس الجهاز.',
          icon: Icons.grid_3x3_rounded,
        ),
        _gameCard(
          game: 'rock_paper_scissors',
          title: 'حجر ورقة مقص',
          description:
              'جولات متتالية ونتيجة محفوظة، ضد الكمبيوتر أو لاعب آخر.',
          icon: Icons.back_hand_rounded,
        ),
        const SizedBox(height: 19),
        const Text(
          'مبارياتك المحفوظة',
          style: TextStyle(
            color: Sa7biTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        if (_sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'لسه ما بدأتش أي مباراة محلية.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Sa7biTheme.textSecondary),
            ),
          )
        else
          for (final session in _sessions)
            Card(
              color: Sa7biTheme.surface,
              child: ListTile(
                onTap: _busy ? null : () => _resumeGame(session.id),
                leading: const Icon(
                  Icons.save_rounded,
                  color: Sa7biTheme.cyan,
                ),
                title: Text(
                  session.gameTitle,
                  style: const TextStyle(
                    color: Sa7biTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${session.modeTitle} • ${session.isFinished ? 'انتهت' : 'مستمرة'}',
                  style: const TextStyle(
                    color: Sa7biTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'حذف المباراة المحفوظة',
                  onPressed:
                      _busy ? null : () => _deleteGame(session.id),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Sa7biTheme.danger,
                  ),
                ),
              ),
            ),
        if (_error != null) _errorPanel(_error!),
      ],
    );
  }

  Widget _gameCard({
    required String game,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      color: Sa7biTheme.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Sa7biTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Sa7biTheme.cyan, size: 27),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Sa7biTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              description,
              style: const TextStyle(
                color: Sa7biTheme.textSecondary,
                fontSize: 10,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => _createGame(game, 'ai'),
                  icon: const Icon(Icons.smart_toy_rounded),
                  label: const Text('ضد الكمبيوتر'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _createGame(game, 'two_players'),
                  icon: const Icon(Icons.people_alt_rounded),
                  label: const Text('لاعبان على نفس الجهاز'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveGame(LocalBoardGameSession session) {
    final state = session.state;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _statusCard(session),
        const SizedBox(height: 13),
        if (_error != null) _errorPanel(_error!),
        if (session.game == 'chess') _buildChess(session),
        if (session.game == 'tic_tac_toe') _buildXO(session),
        if (session.game == 'rock_paper_scissors') _buildRPS(session),
        const SizedBox(height: 15),
        if (session.isFinished)
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _createGame(session.game, session.mode),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('مباراة جديدة'),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(14),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _statusCard(LocalBoardGameSession session) {
    final state = session.state;
    String subtitle;

    if (session.isFinished) {
      subtitle = _finishMessage(session);
    } else if (session.game == 'chess') {
      final turn = state['turn'] == 'b' ? 'الأسود' : 'الأبيض';
      subtitle = 'الدور الحالي: $turn • ${session.modeTitle}';
    } else if (session.game == 'tic_tac_toe') {
      subtitle = 'الدور الحالي: ${state['turn'] ?? 'X'}';
    } else if (state['pendingChoice'] is String) {
      subtitle = 'سلّم الجهاز للاعب الثاني ليختار حركته.';
    } else {
      subtitle = 'اختار حركتك لبدء الجولة التالية.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: Column(
        children: [
          Text(
            session.gameTitle,
            style: const TextStyle(
              color: Sa7biTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChess(LocalBoardGameSession session) {
    final fen = session.state['fen'];
    final turn = session.state['turn'] == 'b' ? 'b' : 'w';

    if (fen is! String || fen.isEmpty) {
      return _errorPanel('تعذر تحميل وضع الشطرنج المحفوظ.');
    }

    if (session.isFinished) {
      return _errorPanel(_finishMessage(session));
    }

    final bottomSide = session.mode == 'two_players' && turn == 'b'
        ? Sa7biChessSide.black
        : Sa7biChessSide.white;

    final enabled = !_busy &&
        (session.mode == 'two_players' || turn == 'w');

    return Column(
      children: [
        if (session.mode == 'two_players')
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'لعب محلي بين لاعبين. مرر الجهاز للاعب صاحب الدور.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Sa7biTheme.cyan, fontSize: 11),
            ),
          ),
        if (session.state['inCheck'] == true)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'كش!',
              style: TextStyle(
                color: Sa7biTheme.danger,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ),
        Sa7biChessBoard(
          fen: fen,
          bottomSide: bottomSide,
          enabled: enabled,
          onMove: _playChess,
        ),
      ],
    );
  }

  Widget _buildXO(LocalBoardGameSession session) {
    final rawBoard = session.state['board'];
    final board = rawBoard is List
        ? List<String>.generate(
            9,
            (i) => i < rawBoard.length ? rawBoard[i].toString() : '',
          )
        : List<String>.filled(9, '');

    final turn = session.state['turn'] == 'O' ? 'O' : 'X';

    return Column(
      children: [
        Text(
          session.mode == 'ai'
              ? 'أنت X والكمبيوتر O'
              : 'اللاعب الأول X • اللاعب الثاني O',
          style: const TextStyle(
            color: Sa7biTheme.cyan,
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
            return Material(
              color: Sa7biTheme.surface,
              borderRadius: BorderRadius.circular(13),
              child: InkWell(
                onTap: _busy ||
                        session.isFinished ||
                        mark.isNotEmpty ||
                        (session.mode == 'ai' && turn != 'X')
                    ? null
                    : () => _playXO(index),
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Sa7biTheme.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    mark,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: mark == 'X'
                          ? Sa7biTheme.cyan
                          : Sa7biTheme.violet,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRPS(LocalBoardGameSession session) {
    final state = session.state;
    final scores = state['scores'] is Map
        ? Map<String, dynamic>.from(state['scores'] as Map)
        : <String, dynamic>{};

    final pending = state['pendingChoice'] is String;
    final lastChoices = state['lastChoices'] is Map
        ? Map<String, dynamic>.from(state['lastChoices'] as Map)
        : null;

    return Column(
      children: [
        Text(
          'النتيجة: ${scores['player1'] ?? 0} • ${scores['player2'] ?? 0} • التعادل ${scores['draws'] ?? 0}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Sa7biTheme.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (pending)
          const Text(
            'اختيار اللاعب الأول محفوظ ومخفي. سلّم الجهاز للاعب الثاني.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.cyan,
              fontSize: 12,
              height: 1.5,
            ),
          )
        else
          Text(
            session.mode == 'ai'
                ? 'اختار حركتك ضد الكمبيوتر'
                : 'دور اللاعب الأول',
            style: const TextStyle(color: Sa7biTheme.textSecondary),
          ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _rpsButton('rock', '✊ حجر', session),
            _rpsButton('paper', '✋ ورقة', session),
            _rpsButton('scissors', '✌️ مقص', session),
          ],
        ),
        if (lastChoices != null) ...[
          const SizedBox(height: 16),
          Text(
            'اللاعب الأول: ${_rpsLabel(lastChoices['player1'])}',
            style: const TextStyle(color: Sa7biTheme.textPrimary),
          ),
          Text(
            session.mode == 'ai'
                ? 'الكمبيوتر: ${_rpsLabel(lastChoices['player2'])}'
                : 'اللاعب الثاني: ${_rpsLabel(lastChoices['player2'])}',
            style: const TextStyle(color: Sa7biTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _rpsResultLabel(state['lastResult']),
            style: const TextStyle(
              color: Sa7biTheme.cyan,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ],
    );
  }

  Widget _rpsButton(
    String choice,
    String label,
    LocalBoardGameSession session,
  ) {
    return FilledButton.tonal(
      onPressed: _busy || session.isFinished
          ? null
          : () => _playRPS(choice),
      child: Text(label),
    );
  }

  String _rpsLabel(dynamic choice) {
    switch (choice) {
      case 'rock':
        return '✊ حجر';
      case 'paper':
        return '✋ ورقة';
      case 'scissors':
        return '✌️ مقص';
      default:
        return '—';
    }
  }

  String _rpsResultLabel(dynamic result) {
    switch (result) {
      case 'player1':
        return 'اللاعب الأول فاز بالجولة';
      case 'player2':
        return 'اللاعب الثاني فاز بالجولة';
      case 'draw':
        return 'تعادل';
      default:
        return '';
    }
  }

  String _finishMessage(LocalBoardGameSession session) {
    final winner = session.state['winner'];

    if (session.game == 'chess') {
      if (winner == 'white') return 'الأبيض فاز بالشطرنج.';
      if (winner == 'black') return 'الأسود فاز بالشطرنج.';
      return 'انتهت مباراة الشطرنج بالتعادل.';
    }

    if (session.game == 'tic_tac_toe') {
      if (winner == 'X') return 'اللاعب X فاز!';
      if (winner == 'O') return 'اللاعب O فاز!';
      return 'انتهت مباراة إكس أو بالتعادل.';
    }

    return 'المباراة المحلية محفوظة.';
  }

  Widget _errorPanel(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Sa7biTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Sa7biTheme.danger),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Sa7biTheme.textPrimary,
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }
}
