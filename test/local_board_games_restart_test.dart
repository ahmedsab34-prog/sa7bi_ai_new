
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sa7bi_ai/services/local_board_games_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = LocalBoardGamesService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'restores chess, tic-tac-toe and RPS games after storage reinitialization',
    () async {
      // Create and play a local chess game.
      final chessGame = await service.createGame(
        game: 'chess',
        mode: 'two_players',
      );

      await service.playChessMove(
        sessionId: chessGame.id,
        from: 'e2',
        to: 'e4',
      );

      // Create and play a local tic-tac-toe game.
      final xoGame = await service.createGame(
        game: 'tic_tac_toe',
        mode: 'two_players',
      );

      await service.playTicTacToeMove(
        sessionId: xoGame.id,
        index: 0,
      );

      // Save the first hidden choice in a local RPS game.
      final rpsGame = await service.createGame(
        game: 'rock_paper_scissors',
        mode: 'two_players',
      );

      await service.playRockPaperScissors(
        sessionId: rpsGame.id,
        choice: 'rock',
      );

      // Preserve the actual stored data, then reinitialize the
      // SharedPreferences test storage as if the app had restarted.
      final preferences = await SharedPreferences.getInstance();
      final savedJson = preferences.getString(
        'sa7bi_local_board_games_v1',
      );

      expect(savedJson, isNotNull);

      SharedPreferences.setMockInitialValues({
        'sa7bi_local_board_games_v1': savedJson!,
      });

      // Read the saved games again from the reinitialized storage.
      final restoredGames = await service.getGames();

      expect(restoredGames.length, 3);

      final restoredById = {
        for (final game in restoredGames) game.id: game,
      };

      // Chess state must survive.
      final restoredChess = restoredById[chessGame.id];

      expect(restoredChess, isNotNull);
      expect(restoredChess!.state['turn'], 'b');
      expect(restoredChess.state['plyCount'], 1);

      // Tic-tac-toe state must survive.
      final restoredXO = restoredById[xoGame.id];

      expect(restoredXO, isNotNull);
      expect(restoredXO!.state['board'][0], 'X');
      expect(restoredXO.state['turn'], 'O');

      // The hidden first RPS choice must survive too.
      final restoredRPS = restoredById[rpsGame.id];

      expect(restoredRPS, isNotNull);
      expect(restoredRPS!.state['pendingChoice'], 'rock');
      expect(restoredRPS.state['rounds'], 0);
    },
  );
}
