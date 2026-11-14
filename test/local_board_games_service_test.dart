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
  });

  test('saves and restores a local game', () async {
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
