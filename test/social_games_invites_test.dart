
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/services/social_games_service.dart';

void main() {
  group('Social games player invitations', () {
    test(
      'rejects player search queries shorter than two characters',
      () async {
        final service = SocialGamesService.instance;

        expect(
          await service.searchUsers(''),
          isEmpty,
        );

        expect(
          await service.searchUsers(' a '),
          isEmpty,
        );

        expect(
          await service.searchUsers(' '),
          isEmpty,
        );
      },
    );

    test(
      'parses player search results correctly',
      () {
        final user = SocialGameUser.fromJson({
          'id': 'player-123',
          'username': 'AhmedPlayer',
          'createdAt': 1760000000000,
        });

        expect(user.id, 'player-123');
        expect(user.username, 'AhmedPlayer');
        expect(user.createdAt, 1760000000000);
      },
    );

    test(
      'uses a safe fallback when the username is missing',
      () {
        final user = SocialGameUser.fromJson({
          'id': 'player-456',
        });

        expect(user.id, 'player-456');
        expect(user.username, 'لاعب');
      },
    );

    test(
      'parses a new invitation room correctly',
      () {
        final room = SocialGameRoom.fromJson({
          'id': '12345678-1234-1234-1234-123456789abc',
          'inviteCode': 'A7BC23',
          'game': 'tic_tac_toe',
          'status': 'waiting',
          'myRole': 'host',
          'state': {
            'board': ['', '', '', '', '', '', '', '', ''],
            'next': 'X',
          },
          'createdAt': 1760000000000,
          'updatedAt': 1760000000000,
        });

        expect(
          room.id,
          '12345678-1234-1234-1234-123456789abc',
        );

        expect(room.inviteCode, 'A7BC23');
        expect(room.game, 'tic_tac_toe');
        expect(room.status, 'waiting');
        expect(room.myRole, 'host');
        expect(room.isWaiting, isTrue);
      },
    );

    test(
      'builds an invitation message containing the game and code',
      () {
        final room = SocialGameRoom.fromJson({
          'id': '12345678-1234-1234-1234-123456789abc',
          'inviteCode': 'A7BC23',
          'game': 'chess',
          'status': 'waiting',
          'myRole': 'host',
          'state': {
            'fen': 'start',
          },
          'createdAt': 1760000000000,
          'updatedAt': 1760000000000,
        });

        final message =
            SocialGamesService.instance.buildInviteMessage(room);

        expect(message, contains('الشطرنج'));
        expect(message, contains('A7BC23'));
        expect(message, contains('صاحبي AI'));
      },
    );

    test(
      'does not confuse a waiting room with an active game',
      () {
        final room = SocialGameRoom.fromJson({
          'id': '12345678-1234-1234-1234-123456789abc',
          'inviteCode': 'A7BC23',
          'game': 'chess',
          'status': 'waiting',
          'myRole': 'host',
          'state': {},
          'createdAt': 1760000000000,
          'updatedAt': 1760000000000,
        });

        expect(room.isWaiting, isTrue);
        expect(room.isPlaying, isFalse);
        expect(room.isPaused, isFalse);
        expect(room.isFinished, isFalse);
      },
    );
  });
}
