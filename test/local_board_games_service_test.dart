import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sa7bi_ai/services/local_board_games_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = LocalBoardGamesService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Local chess', () {
    test('creates a standard chess position without internet', () async {
      final game = await service.createGame(
        game: 'chess',
        mode: 'two_players',
      );

      expect(game.state['fen'], contains('rnbqkbnr'));
      expect(game.state['turn'], 'w');
      expect(game.state['status'], 'playing');
    });

    test('accepts a legal move and changes the turn', () async {
      final game = await service.createGame(
        game: 'chess',
        mode: 'two_players',
      );

      final updated = await service.playChessMove(
        sessionId: game.id,
        from: 'e2',
        to: 'e4',
      );

      expect(updated.state['turn'], 'b');
      expect(updated.state['plyCount'], 1);
      expect(updated.state['fen'], isA<String>());
    });

    test('rejects an illegal chess move', () async {
      final game = await service.createGame(
        game: 'chess',
        mode: 'two_players',
      );

      await expectLater(
        service.playChessMove(
          sessionId: game.id,
          from: 'e2',
          to: 'e5',
        ),
        throwsA(isA<LocalBoardGamesException>()),
      );
    });

    test('rejects an invalid promotion choice', () async {
      final game = await service.createGame(
        game: 'chess',
        mode: 'two_players',
      );

      await expectLater(
        service.playChessMove(
          sessionId: game.id,
          from: 'e2',
          to: 'e4',
          promotion: 'x',
        ),
        throwsA(isA<LocalBoardGamesException>()),
      );
    });

    test('local chess AI replies after the white move', () async {
      final game = await service.createGame(
        game: 'chess',
        mode: 'ai',
      );

      final updated = await service.playChessMove(
        sessionId: game.id,
        from: 'e2',
        to: 'e4',
      );

      expect(updated.state['turn'], 'w');
      expect(updated.state['plyCount'], 2);
      expect(updated.state['fen'], isA<String>());
    });

    test('detects checkmate in a two-player local game', () async {
      final game = await service.createGame(
        game: 'chess',
        mode: 'two_players',
      );

      const moves = [
        {'from': 'f2', 'to': 'f3'},
        {'from': 'e7', 'to': 'e5'},
        {'from': 'g2', 'to': 'g4'},
        {'from': 'd8', 'to': 'h4'},
      ];

      var updated = game;

      for (final move in moves) {
        updated = await service.playChessMove(
          sessionId: game.id,
          from: move['from']!,
          to: move['to']!,
        );
      }

      expect(updated.state['status'], 'finished');
      expect(updated.state['winner'], 'black');
      expect(updated.state['inCheck'], true);
    });
  });

  group('Local tic tac toe', () {
    test('AI makes a legal reply after the human move', () async {
      final game = await service.createGame(
        game: 'tic_tac_toe',
        mode: 'ai',
      );

      final updated = await service.playTicTacToeMove(
        sessionId: game.id,
        index: 0,
      );

      final board = List<String>.from(updated.state['board'] as List);

      expect(board.where((cell) => cell.isNotEmpty).length, 2);
      expect(board[0], 'X');
      expect(updated.state['turn'], 'X');
    });

    test('rejects playing in an occupied square', () async {
      final game = await service.createGame(
        game: 'tic_tac_toe',
        mode: 'two_players',
      );

      await service.playTicTacToeMove(
        sessionId: game.id,
        index: 4,
      );

      await expectLater(
        service.playTicTacToeMove(
          sessionId: game.id,
          index: 4,
        ),
        throwsA(isA<LocalBoardGamesException>()),
      );
    });

    test('detects a full-board draw in two-player mode', () async {
      final game = await service.createGame(
        game: 'tic_tac_toe',
        mode: 'two_players',
      );

      const moves = [0, 4, 8, 2, 6, 3, 1, 7, 5];

      var updated = game;

      for (final index in moves) {
        updated = await service.playTicTacToeMove(
          sessionId: game.id,
          index: index,
        );
      }

      expect(updated.state['status'], 'finished');
      expect(updated.state['winner'], 'Draw');
      expect(updated.state['moves'], 9);
    });
  });

  group('Local rock paper scissors', () {
    test('keeps the first local choice hidden until player two chooses',
        () async {
      final game = await service.createGame(
        game: 'rock_paper_scissors',
        mode: 'two_players',
      );

      final first = await service.playRockPaperScissors(
        sessionId: game.id,
        choice: 'rock',
      );

      expect(first.state['pendingChoice'], 'rock');
      expect(first.state['lastChoices'], isNull);
      expect(first.state['rounds'], 0);

      final second = await service.playRockPaperScissors(
        sessionId: game.id,
        choice: 'scissors',
      );

      expect(second.state['pendingChoice'], isNull);
      expect(second.state['rounds'], 1);
      expect(second.state['lastResult'], 'player1');

      final scores =
          Map<String, dynamic>.from(second.state['scores'] as Map);

      expect(scores['player1'], 1);
      expect(scores['player2'], 0);
    });

    test('AI completes an RPS round and updates the score', () async {
      final game = await service.createGame(
        game: 'rock_paper_scissors',
        mode: 'ai',
      );

      final updated = await service.playRockPaperScissors(
        sessionId: game.id,
        choice: 'paper',
      );

      final choices =
          Map<String, dynamic>.from(updated.state['lastChoices'] as Map);
      final scores =
          Map<String, dynamic>.from(updated.state['scores'] as Map);

      expect(updated.state['rounds'], 1);
      expect(choices['player1'], 'paper');
      expect(
        ['rock', 'paper', 'scissors'],
        contains(choices['player2']),
      );
      expect(updated.state['lastResult'], isA<String>());
      expect(
        (scores['player1'] as int) +
            (scores['player2'] as int) +
            (scores['draws'] as int),
        1,
      );
    });

    test('rejects an unsupported RPS choice', () async {
      final game = await service.createGame(
        game: 'rock_paper_scissors',
        mode: 'ai',
      );

      await expectLater(
        service.playRockPaperScissors(
          sessionId: game.id,
          choice: 'lizard',
        ),
        throwsA(isA<LocalBoardGamesException>()),
      );
    });
  });

  test('saves and restores a local chess game', () async {
    final game = await service.createGame(
      game: 'chess',
      mode: 'two_players',
    );

    await service.playChessMove(
      sessionId: game.id,
      from: 'e2',
      to: 'e4',
    );

    final restored = await service.getGame(game.id);

    expect(restored, isNotNull);
    expect(restored!.state['turn'], 'b');
    expect(restored.state['plyCount'], 1);
  });
}
