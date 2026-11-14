
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// تمثيل الحركة في لعبة الشطرنج (مبسط)
class ChessMove {
  final String from; // e.g., "e2"
  final String to;   // e.g., "e4"
  ChessMove({required this.from, required this.to});
  Map<String, dynamic> toJson() => {'from': from, 'to': to};
  static ChessMove? fromJson(dynamic json) {
    if (json is Map) {
      final from = json['from'];
      final to = json['to'];
      if (from is String && to is String) {
        return ChessMove(from: from, to: to);
      }
    }
    return null;
  }
}

/// حالة لعبة الشطرنج (مبسطة جدًا)
class ChessGame {
  String fen; // صيغ وضعية الشطرنج القياسية (يمكن تحديثه بالحركات)
  bool whiteTurn;
  List<ChessMove> moves;

  ChessGame({
    required this.fen,
    this.whiteTurn = true,
    List<ChessMove>? moves,
  }) : moves = moves ?? [];

  /// أضف حركة جديدة (ضد الكمبيوتر أو لاعب آخر)
  void makeMove(ChessMove move) {
    // في تطبيق حقيقي: طبق القواعد وعدل fen. هنا مجرد تسجيل الحركة.
    moves.add(move);
    whiteTurn = !whiteTurn;
  }

  /// تحويل الحالة إلى JSON لحفظها
  Map<String, dynamic> toJson() => {
        'fen': fen,
        'whiteTurn': whiteTurn,
        'moves': moves.map((m) => m.toJson()).toList(),
      };
  static ChessGame? fromJson(dynamic json) {
    if (json is Map) {
      final fen = json['fen'];
      final whiteTurn = json['whiteTurn'];
      final movesJson = json['moves'];
      if (fen is String && whiteTurn is bool && movesJson is List) {
        final moves = <ChessMove>[];
        for (var mv in movesJson) {
          final move = ChessMove.fromJson(mv);
          if (move != null) moves.add(move);
        }
        return ChessGame(fen: fen, whiteTurn: whiteTurn, moves: moves);
      }
    }
    return null;
  }
}

/// حالة لعبة XO (Tic-Tac-Toe)
class XOGame {
  List<String> board; // 3x3 board, قيمها 'X', 'O' أو '' (فارغ)
  bool xTurn;
  XOGame({List<String>? board, this.xTurn = true})
      : board = board ?? List.filled(9, '');

  /// القيام بحركة على اللوحة
  bool makeMove(int index) {
    if (index < 0 || index >= 9 || board[index] != '') {
      return false;
    }
    board[index] = xTurn ? 'X' : 'O';
    xTurn = !xTurn;
    return true;
  }

  /// تحقق من الفائز أو التعادل
  String checkWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // صفوف
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // أعمدة
      [0, 4, 8], [2, 4, 6] // أقطار
    ];
    for (var line in lines) {
      final a = board[line[0]], b = board[line[1]], c = board[line[2]];
      if (a != '' && a == b && b == c) {
        return a; // 'X' أو 'O'
      }
    }
    if (board.contains('')) return ''; // لم ينتهي بعد
    return 'Draw';
  }

  Map<String, dynamic> toJson() => {
        'board': board,
        'xTurn': xTurn,
      };
  static XOGame? fromJson(dynamic json) {
    if (json is Map) {
      final board = json['board'];
      final xTurn = json['xTurn'];
      if (board is List && xTurn is bool && board.length == 9) {
        final strBoard = board.cast<String>();
        return XOGame(board: strBoard, xTurn: xTurn);
      }
    }
    return null;
  }
}

/// حالة لعبة الحجر/ورقة/مقص
class RPSGame {
  int playerScore, aiScore, rounds;
  RPSGame({this.playerScore = 0, this.aiScore = 0, this.rounds = 0});
  /// اللاعب يقوم برميه: 0=حجر, 1=ورقة, 2=مقص
  /// الكمبيوتر يختار عشوائيًا
  void playRound(int playerMove) {
    final aiMove = Random().nextInt(3);
    // قوانين RPS
    if (playerMove == aiMove) {
      // تعادل
    } else if ((playerMove + 1) % 3 == aiMove) {
      aiScore++;
    } else {
      playerScore++;
    }
    rounds++;
  }

  Map<String, dynamic> toJson() => {
        'playerScore': playerScore,
        'aiScore': aiScore,
        'rounds': rounds,
      };
  static RPSGame? fromJson(dynamic json) {
    if (json is Map) {
      final playerScore = json['playerScore'];
      final aiScore = json['aiScore'];
      final rounds = json['rounds'];
      if (playerScore is int && aiScore is int && rounds is int) {
        return RPSGame(playerScore: playerScore, aiScore: aiScore, rounds: rounds);
      }
    }
    return null;
  }
}

/// خدمة الألعاب الاجتماعية
class SocialGamesService {
  SocialGamesService._();
  static final SocialGamesService instance = SocialGamesService._();

  /// مفتاح التخزين المحلي لحفظ حالة الألعاب
  static const String _gamesKey = 'sa7bi_saved_games';

  /// إنشاء لعبة شطرنج جديدة (على الوضع المحلي ضد الذكاء الاصطناعي)
  Future<ChessGame> createLocalChess() async {
    // وضع شطرنج مبدئي قياسي (FEN)، مثلاً وضع البداية
    final game = ChessGame(fen: 'startpos');
    await _saveGame('chess', game.toJson());
    return game;
  }

  /// إنشاء أو انضمام إلى لعبة شطرنج أونلاين (طلب من الخادم)
  Future<ChessGame> createOnlineChess() async {
    // في الواقع: استدعاء API لإنشاء غرفة/مباراة على الخادم
    // هنا مجرد مثال:
    final game = ChessGame(fen: 'startpos');
    await _saveGame('chess_online', game.toJson());
    return game;
  }

  /// إنشاء لعبة XO جديدة محليًا
  Future<XOGame> createLocalXO() async {
    final game = XOGame();
    await _saveGame('xo', game.toJson());
    return game;
  }

  /// إنشاء/انضمام إلى لعبة XO أونلاين
  Future<XOGame> createOnlineXO() async {
    final game = XOGame();
    await _saveGame('xo_online', game.toJson());
    return game;
  }

  /// إنشاء لعبة RPS جديدة محليًا
  Future<RPSGame> createLocalRPS() async {
    final game = RPSGame();
    await _saveGame('rps', game.toJson());
    return game;
  }

  /// استرجاع حالة لعبة محفوظة محليًا إذا وجدت
  Future<dynamic> loadGame(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_gamesKey);
    if (jsonStr == null) return null;
    final allGames = jsonDecode(jsonStr) as Map<String, dynamic>;
    return allGames[key];
  }

  /// حفظ الحالة الحالية للعبة محليًا
  Future<void> _saveGame(String key, Map<String, dynamic> gameJson) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_gamesKey);
    final allGames = existing != null
        ? jsonDecode(existing) as Map<String, dynamic>
        : <String, dynamic>{};
    allGames[key] = gameJson;
    await prefs.setString(_gamesKey, jsonEncode(allGames));
  }
}
