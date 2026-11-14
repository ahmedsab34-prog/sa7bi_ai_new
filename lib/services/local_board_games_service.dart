import 'dart:convert';
import 'dart:math';

import 'package:chess/chess.dart' as chess;
import 'package:shared_preferences/shared_preferences.dart';

class LocalBoardGamesException implements Exception {
  const LocalBoardGamesException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'LocalBoardGamesException($code): $message';
}

class LocalBoardGameSession {
  const LocalBoardGameSession({
    required this.id,
    required this.game,
    required this.mode,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String game;
  final String mode;
  final Map<String, dynamic> state;
  final int createdAt;
  final int updatedAt;

  bool get isFinished => state['status'] == 'finished';

  String get gameTitle {
    switch (game) {
      case 'chess':
        return 'الشطرنج';
      case 'tic_tac_toe':
        return 'إكس أو';
      case 'rock_paper_scissors':
        return 'حجر ورقة مقص';
      default:
        return 'لعبة محلية';
    }
  }

  String get modeTitle =>
      mode == 'ai' ? 'ضد الكمبيوتر' : 'لاعبان على نفس الجهاز';

  factory LocalBoardGameSession.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'];

    if (json['id'] is! String ||
        json['game'] is! String ||
        json['mode'] is! String ||
        rawState is! Map ||
        json['createdAt'] is! int ||
        json['updatedAt'] is! int) {
      throw const LocalBoardGamesException(
        'INVALID_SAVED_GAME',
        'بيانات المباراة المحفوظة غير مكتملة.',
      );
    }

    return LocalBoardGameSession(
      id: json['id'] as String,
      game: json['game'] as String,
      mode: json['mode'] as String,
      state: Map<String, dynamic>.from(rawState),
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'game': game,
        'mode': mode,
        'state': state,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  LocalBoardGameSession copyWith({
    Map<String, dynamic>? state,
    int? updatedAt,
  }) {
    return LocalBoardGameSession(
      id: id,
      game: game,
      mode: mode,
      state: state ?? this.state,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// خدمة الألعاب المحلية.
///
/// لا تحتاج إلى حساب أو اتصال بالخادم.
/// تحفظ المباراة على الجهاز وتسمح باستكمالها بعد إغلاق التطبيق.
class LocalBoardGamesService {
  LocalBoardGamesService._();

  static final LocalBoardGamesService instance =
      LocalBoardGamesService._();

  static const String _storageKey = 'sa7bi_local_board_games_v1';

  static const Set<String> _supportedGames = {
    'chess',
    'tic_tac_toe',
    'rock_paper_scissors',
  };

  static const Set<String> _supportedModes = {
    'ai',
    'two_players',
  };

  static const List<List<int>> _xoLines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  final Random _random = Random.secure();

  Future<List<LocalBoardGameSession>> getGames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        throw const FormatException('Expected a list.');
      }

      final games = decoded
          .whereType<Map>()
          .map(
            (item) => LocalBoardGameSession.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      games.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

      return games;
    } catch (_) {
      throw const LocalBoardGamesException(
        'LOCAL_STORAGE_CORRUPT',
        'تعذر قراءة المباريات المحفوظة. لم نحذف البيانات الموجودة.',
      );
    }
  }

  Future<LocalBoardGameSession?> getGame(String sessionId) async {
    final games = await getGames();

    for (final game in games) {
      if (game.id == sessionId) return game;
    }

    return null;
  }

  Future<LocalBoardGameSession> createGame({
    required String game,
    required String mode,
  }) async {
    if (!_supportedGames.contains(game)) {
      throw const LocalBoardGamesException(
        'UNSUPPORTED_GAME',
        'اللعبة المختارة غير مدعومة محليًا.',
      );
    }

    if (!_supportedModes.contains(mode)) {
      throw const LocalBoardGamesException(
        'INVALID_GAME_MODE',
        'وضع اللعب المختار غير صحيح.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id =
        'local_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';

    final Map<String, dynamic> state;

    switch (game) {
      case 'chess':
        final engine = chess.Chess();

        state = {
          'fen': engine.fen,
          'pgn': engine.pgn(),
          'turn': 'w',
          'status': 'playing',
          'winner': null,
          'inCheck': false,
          'plyCount': 0,
        };

      case 'tic_tac_toe':
        state = {
          'board': List<String>.filled(9, ''),
          'turn': 'X',
          'winner': null,
          'status': 'playing',
          'moves': 0,
        };

      case 'rock_paper_scissors':
        state = {
          'scores': {
            'player1': 0,
            'player2': 0,
            'draws': 0,
          },
          'rounds': 0,
          'pendingChoice': null,
          'awaitingPlayer': 'player1',
          'lastChoices': null,
          'lastResult': null,
          'status': 'playing',
        };

      default:
        throw const LocalBoardGamesException(
          'UNSUPPORTED_GAME',
          'اللعبة غير مدعومة.',
        );
    }

    final session = LocalBoardGameSession(
      id: id,
      game: game,
      mode: mode,
      state: state,
      createdAt: now,
      updatedAt: now,
    );

    await _save(session);
    return session;
  }

  Future<LocalBoardGameSession> playChessMove({
    required String sessionId,
    required String from,
    required String to,
    String promotion = 'q',
  }) async {
    final session = await _requireGame(sessionId, 'chess');

    if (!RegExp(r'^[a-h][1-8]$').hasMatch(from) ||
        !RegExp(r'^[a-h][1-8]$').hasMatch(to)) {
      throw const LocalBoardGamesException(
        'INVALID_MOVE',
        'مربع البداية أو الوصول غير صحيح.',
      );
    }

    const promotions = {'q', 'r', 'b', 'n'};

    if (!promotions.contains(promotion.toLowerCase())) {
      throw const LocalBoardGamesException(
        'INVALID_PROMOTION',
        'اختيار ترقية البيدق غير صحيح.',
      );
    }

    final state = Map<String, dynamic>.from(session.state);

    if (state['status'] == 'finished') {
      throw const LocalBoardGamesException(
        'GAME_FINISHED',
        'المباراة انتهت بالفعل.',
      );
    }

    final engine = _restoreChessEngine(state);

    if (session.mode == 'ai' && engine.turn != chess.WHITE) {
      throw const LocalBoardGamesException(
        'NOT_YOUR_TURN',
        'استنى نقلة الكمبيوتر.',
      );
    }

    final moved = engine.move({
      'from': from,
      'to': to,
      'promotion': promotion.toLowerCase(),
    });

    if (!moved) {
      throw const LocalBoardGamesException(
        'ILLEGAL_CHESS_MOVE',
        'النقلة غير قانونية. اختار نقلة أخرى.',
      );
    }

    if (session.mode == 'ai' &&
        !engine.game_over &&
        engine.turn == chess.BLACK) {
      _playLocalChessAiMove(engine);
    }

    _writeChessState(state, engine);

    return _save(
      session.copyWith(
        state: state,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  chess.Chess _restoreChessEngine(Map<String, dynamic> state) {
    final engine = chess.Chess();

    final pgn = state['pgn'];
    final fen = state['fen'];

    bool loaded = false;

    if (pgn is String && pgn.trim().isNotEmpty) {
      loaded = engine.load_pgn(pgn);
    }

    if (!loaded) {
      if (fen is! String || !engine.load(fen)) {
        throw const LocalBoardGamesException(
          'INVALID_CHESS_POSITION',
          'وضع الشطرنج المحفوظ غير صالح.',
        );
      }
    }

    return engine;
  }

  void _playLocalChessAiMove(chess.Chess engine) {
    final legalMoves = engine
        .moves({'asObjects': true})
        .whereType<chess.Move>()
        .toList();

    if (legalMoves.isEmpty) return;

    // خصم محلي مبتدئ: يفضّل أسر القطع، وإلا يختار نقلة قانونية.
    legalMoves.sort(
      (a, b) => _capturedPieceValue(b.captured).compareTo(
        _capturedPieceValue(a.captured),
      ),
    );

    final bestCaptureValue =
        _capturedPieceValue(legalMoves.first.captured);

    final candidates = legalMoves
        .where(
          (move) =>
              _capturedPieceValue(move.captured) == bestCaptureValue,
        )
        .take(5)
        .toList();

    candidates.shuffle(_random);
    engine.move(candidates.first);
  }

  int _capturedPieceValue(chess.PieceType? piece) {
    if (piece == null) return 0;

    final name = piece.toString().toLowerCase();

    if (name.contains('queen')) return 9;
    if (name.contains('rook')) return 5;
    if (name.contains('bishop')) return 3;
    if (name.contains('knight')) return 3;
    if (name.contains('pawn')) return 1;

    return 0;
  }

  void _writeChessState(
    Map<String, dynamic> state,
    chess.Chess engine,
  ) {
    String status = 'playing';
    String? winner;

    if (engine.in_checkmate) {
      status = 'finished';
      winner = engine.turn == chess.WHITE ? 'black' : 'white';
    } else if (engine.in_draw || engine.in_stalemate) {
      status = 'finished';
      winner = 'draw';
    }

    state['fen'] = engine.fen;
    state['pgn'] = engine.pgn();
    state['turn'] = engine.turn == chess.WHITE ? 'w' : 'b';
    state['inCheck'] = engine.in_check;
    state['plyCount'] = engine.history.length;
    state['status'] = status;
    state['winner'] = winner;
  }

  Future<LocalBoardGameSession> playTicTacToeMove({
    required String sessionId,
    required int index,
  }) async {
    final session = await _requireGame(sessionId, 'tic_tac_toe');

    if (index < 0 || index >= 9) {
      throw const LocalBoardGamesException(
        'INVALID_MOVE',
        'المربع المحدد غير صحيح.',
      );
    }

    final state = Map<String, dynamic>.from(session.state);
    final board = List<String>.from(
      (state['board'] as List).map((value) => value.toString()),
    );

    if (state['status'] == 'finished') {
      throw const LocalBoardGamesException(
        'GAME_FINISHED',
        'المباراة انتهت بالفعل.',
      );
    }

    final turn = state['turn'] == 'O' ? 'O' : 'X';

    if (session.mode == 'ai' && turn != 'X') {
      throw const LocalBoardGamesException(
        'NOT_YOUR_TURN',
        'استنى نقلة الكمبيوتر.',
      );
    }

    if (board[index].isNotEmpty) {
      throw const LocalBoardGamesException(
        'INVALID_MOVE',
        'المربع ده مش فاضي.',
      );
    }

    board[index] = turn;

    String? winner = _getXOWinner(board);

    if (session.mode == 'ai' && winner == null) {
      final aiIndex = _bestXOMove(board);

      if (aiIndex != null) {
        board[aiIndex] = 'O';
      }

      winner = _getXOWinner(board);
      state['turn'] = 'X';
    } else if (winner == null) {
      state['turn'] = turn == 'X' ? 'O' : 'X';
    }

    state['board'] = board;
    state['moves'] = (state['moves'] as int? ?? 0) +
        (session.mode == 'ai' && winner == null ? 2 : 1);

    state['winner'] = winner;
    state['status'] = winner == null ? 'playing' : 'finished';

    return _save(
      session.copyWith(
        state: state,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  int? _bestXOMove(List<String> board) {
    var bestScore = -1000;
    final bestMoves = <int>[];

    for (var i = 0; i < board.length; i++) {
      if (board[i].isNotEmpty) continue;

      board[i] = 'O';
      final score = _minimaxXO(board, 'X', 0);
      board[i] = '';

      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(i);
      } else if (score == bestScore) {
        bestMoves.add(i);
      }
    }

    if (bestMoves.isEmpty) return null;

    return bestMoves[_random.nextInt(bestMoves.length)];
  }

  int _minimaxXO(
    List<String> board,
    String current,
    int depth,
  ) {
    final winner = _getXOWinner(board);

    if (winner == 'O') return 10 - depth;
    if (winner == 'X') return depth - 10;
    if (winner == 'Draw') return 0;

    if (current == 'O') {
      var best = -1000;

      for (var i = 0; i < board.length; i++) {
        if (board[i].isNotEmpty) continue;

        board[i] = 'O';
        final score = _minimaxXO(board, 'X', depth + 1);
        board[i] = '';

        if (score > best) best = score;
      }

      return best;
    }

    var best = 1000;

    for (var i = 0; i < board.length; i++) {
      if (board[i].isNotEmpty) continue;

      board[i] = 'X';
      final score = _minimaxXO(board, 'O', depth + 1);
      board[i] = '';

      if (score < best) best = score;
    }

    return best;
  }

  String? _getXOWinner(List<String> board) {
    for (final line in _xoLines) {
      final a = board[line[0]];
      final b = board[line[1]];
      final c = board[line[2]];

      if (a.isNotEmpty && a == b && b == c) {
        return a;
      }
    }

    if (board.every((cell) => cell.isNotEmpty)) {
      return 'Draw';
    }

    return null;
  }

  Future<LocalBoardGameSession> playRockPaperScissors({
    required String sessionId,
    required String choice,
  }) async {
    final session = await _requireGame(
      sessionId,
      'rock_paper_scissors',
    );

    const allowed = {'rock', 'paper', 'scissors'};

    if (!allowed.contains(choice)) {
      throw const LocalBoardGamesException(
        'INVALID_MOVE',
        'الاختيار غير صحيح.',
      );
    }

    final state = Map<String, dynamic>.from(session.state);

    if (session.mode == 'ai') {
      final aiChoice = _randomRPSChoice();

      _completeRPSRound(
        state,
        player1Choice: choice,
        player2Choice: aiChoice,
      );
    } else {
      final pending = state['pendingChoice'];

      if (pending is! String) {
        // نخفي اختيار اللاعب الأول حتى يختار اللاعب الثاني.
        state['pendingChoice'] = choice;
        state['awaitingPlayer'] = 'player2';
        state['lastChoices'] = null;
        state['lastResult'] = null;
      } else {
        _completeRPSRound(
          state,
          player1Choice: pending,
          player2Choice: choice,
        );

        state['pendingChoice'] = null;
        state['awaitingPlayer'] = 'player1';
      }
    }

    return _save(
      session.copyWith(
        state: state,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String _randomRPSChoice() {
    const choices = ['rock', 'paper', 'scissors'];
    return choices[_random.nextInt(choices.length)];
  }

  void _completeRPSRound(
    Map<String, dynamic> state, {
    required String player1Choice,
    required String player2Choice,
  }) {
    final scores = Map<String, dynamic>.from(
      state['scores'] as Map,
    );

    String result;

    if (player1Choice == player2Choice) {
      result = 'draw';
      scores['draws'] = (scores['draws'] as int? ?? 0) + 1;
    } else {
      final player1Wins =
          (player1Choice == 'rock' && player2Choice == 'scissors') ||
          (player1Choice == 'paper' && player2Choice == 'rock') ||
          (player1Choice == 'scissors' && player2Choice == 'paper');

      if (player1Wins) {
        result = 'player1';
        scores['player1'] = (scores['player1'] as int? ?? 0) + 1;
      } else {
        result = 'player2';
        scores['player2'] = (scores['player2'] as int? ?? 0) + 1;
      }
    }

    state['scores'] = scores;
    state['rounds'] = (state['rounds'] as int? ?? 0) + 1;
    state['lastChoices'] = {
      'player1': player1Choice,
      'player2': player2Choice,
    };
    state['lastResult'] = result;
    state['status'] = 'playing';
  }

  Future<LocalBoardGameSession> _requireGame(
    String sessionId,
    String expectedGame,
  ) async {
    final session = await getGame(sessionId);

    if (session == null) {
      throw const LocalBoardGamesException(
        'GAME_NOT_FOUND',
        'المباراة المحفوظة غير موجودة.',
      );
    }

    if (session.game != expectedGame) {
      throw const LocalBoardGamesException(
        'WRONG_GAME_TYPE',
        'نوع المباراة لا يطابق الحركة المطلوبة.',
      );
    }

    return session;
  }

  Future<LocalBoardGameSession> _save(
    LocalBoardGameSession session,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final games = await getGames();

    games.removeWhere((item) => item.id == session.id);
    games.add(session);

    final success = await prefs.setString(
      _storageKey,
      jsonEncode(games.map((item) => item.toJson()).toList()),
    );

    if (!success) {
      throw const LocalBoardGamesException(
        'SAVE_FAILED',
        'تعذر حفظ المباراة على الجهاز.',
      );
    }

    return session;
  }

  Future<void> deleteGame(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final games = await getGames();

    games.removeWhere((item) => item.id == sessionId);

    await prefs.setString(
      _storageKey,
      jsonEncode(games.map((item) => item.toJson()).toList()),
    );
  }
}
