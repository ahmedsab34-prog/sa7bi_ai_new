
import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/social_games_service.dart';

void main() {
  group('SocialGameUser model', () {
    test('parses player identity and creation timestamp', () {
      final user = SocialGameUser.fromJson({
        'id': 'player-123',
        'username': 'HeroPlayer',
        'createdAt': 1760000000000,
      });

      expect(user.id, 'player-123');
      expect(user.username, 'HeroPlayer');
      expect(user.createdAt, 1760000000000);
    });

    test('supports legacy timestamp field', () {
      final user = SocialGameUser.fromJson({
        'id': 'player-456',
        'username': 'Friend',
        'created_at': 1760000000000,
      });

      expect(user.createdAt, 1760000000000);
    });

    test('uses safe defaults for incomplete player data', () {
      final user = SocialGameUser.fromJson({});

      expect(user.id, isEmpty);
      expect(user.username, 'لاعب');
      expect(user.createdAt, isNull);
    });
  });

  group('SocialGamePlayer model', () {
    test('parses player mark and username', () {
      final player = SocialGamePlayer.fromJson({
        'id': 'player-1',
        'username': 'Ahmed',
        'mark': 'X',
      });

      expect(player.id, 'player-1');
      expect(player.username, 'Ahmed');
      expect(player.mark, 'X');
    });
  });

  group('SocialGameRoom model', () {
    test('parses a waiting chess room', () {
      final room = SocialGameRoom.fromJson({
        'id': '12345678-1234-1234-1234-123456789abc',
        'inviteCode': 'AB2345',
        'game': 'chess',
        'status': 'waiting',
        'myRole': 'host',
        'state': {
          'fen': 'start',
          'turn': 'white',
        },
        'createdAt': 1760000000000,
        'updatedAt': 1760000005000,
        'host': {
          'id': 'host-id',
          'username': 'Host',
          'mark': 'white',
        },
      });

      expect(room.gameTitle, 'الشطرنج');
      expect(room.isWaiting, isTrue);
      expect(room.isPlaying, isFalse);
      expect(room.statusLabel, 'في انتظار لاعب');
      expect(room.inviteCode, 'AB2345');
      expect(room.state['turn'], 'white');
      expect(room.host?.username, 'Host');
      expect(room.createdAt, 1760000000000);
    });

    test('recognizes all supported game titles', () {
      const expectedTitles = {
        'chess': 'الشطرنج',
        'tic_tac_toe': 'إكس أو',
        'rock_paper_scissors': 'حجر ورقة مقص',
      };

      for (final entry in expectedTitles.entries) {
        final room = SocialGameRoom.fromJson({
          'game': entry.key,
        });

        expect(room.gameTitle, entry.value);
      }
    });

    test('recognizes playing, paused and finished states', () {
      final playing = SocialGameRoom.fromJson({
        'status': 'playing',
      });
      final paused = SocialGameRoom.fromJson({
        'status': 'paused',
      });
      final finished = SocialGameRoom.fromJson({
        'status': 'finished',
      });

      expect(playing.isPlaying, isTrue);
      expect(playing.statusLabel, 'مباراة جارية');

      expect(paused.isPaused, isTrue);
      expect(paused.statusLabel, 'متوقفة مؤقتًا');

      expect(finished.isFinished, isTrue);
      expect(finished.statusLabel, 'انتهت المباراة');
    });

    test('uses safe defaults for malformed room fields', () {
      final room = SocialGameRoom.fromJson({
        'id': 123,
        'state': 'invalid',
      });

      expect(room.id, isEmpty);
      expect(room.status, 'unknown');
      expect(room.state, isEmpty);
      expect(room.host, isNull);
      expect(room.guest, isNull);
    });
  });

  group('SocialGamesService input validation', () {
    final service = SocialGamesService.instance;

    test('rejects an invalid room identifier before network access', () {
      expectLater(
        service.getRoom('not-a-valid-room'),
        throwsA(
          isA<SocialGamesException>().having(
            (error) => error.code,
            'error code',
            'INVALID_ROOM_ID',
          ),
        ),
      );
    });

    test('rejects an invalid tic-tac-toe cell before network access', () {
      expectLater(
        service.playTicTacToe(
          roomId: '12345678-1234-1234-1234-123456789abc',
          index: 9,
        ),
        throwsA(
          isA<SocialGamesException>().having(
            (error) => error.code,
            'error code',
            'INVALID_MOVE',
          ),
        ),
      );
    });
  });
}
