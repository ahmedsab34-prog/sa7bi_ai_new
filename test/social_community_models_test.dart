import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/services/social_community_service.dart';
import 'package:sa7bi_ai/services/social_games_service.dart';

void main() {
  group('Public social group models', () {
    test('parses a public group with membership and last message', () {
      final group = SocialPublicGroup.fromJson({
        'id': '11111111-1111-4111-8111-111111111111',
        'name': 'محبي الشطرنج',
        'description': 'مجموعة لعشاق الشطرنج',
        'ownerId': 'owner-id',
        'memberCount': 14,
        'isMember': true,
        'lastMessage': 'أهلًا بالجميع',
        'createdAt': 1760000000000,
        'updatedAt': 1760000005000,
      });

      expect(group.name, 'محبي الشطرنج');
      expect(group.memberCount, 14);
      expect(group.isMember, isTrue);
      expect(group.lastMessage, 'أهلًا بالجميع');
      expect(group.updatedAt, 1760000005000);
    });

    test('uses safe defaults for a partial group response', () {
      final group = SocialPublicGroup.fromJson({'id': 'group-id'});
      expect(group.name, 'مجموعة');
      expect(group.memberCount, 0);
      expect(group.isMember, isFalse);
      expect(group.description, isEmpty);
    });
  });

  group('Public group message models', () {
    test('parses sender, message body and ownership', () {
      final message = SocialGroupMessage.fromJson({
        'id': 'message-id',
        'groupId': 'group-id',
        'senderId': 'me',
        'username': 'PlayerOne',
        'text': 'رسالة جماعية',
        'createdAt': 1760000000000,
        'isMine': true,
      });

      expect(message.username, 'PlayerOne');
      expect(message.text, 'رسالة جماعية');
      expect(message.isMine, isTrue);
      expect(message.createdAt, 1760000000000);
    });

    test('uses safe defaults for incomplete message JSON', () {
      final message = SocialGroupMessage.fromJson({'id': 'message-id'});
      expect(message.username, 'لاعب');
      expect(message.text, isEmpty);
      expect(message.isMine, isFalse);
    });
  });

  test('AI game rooms retain the AI marker when decoded', () {
    final room = SocialGameRoom.fromJson({
      'id': '22222222-2222-4222-8222-222222222222',
      'inviteCode': 'AB2345',
      'game': 'tic_tac_toe',
      'status': 'playing',
      'myRole': 'host',
      'state': {'aiOpponent': true, 'board': ['', '', '', '', '', '', '', '', '']},
      'createdAt': 1760000000000,
      'updatedAt': 1760000000000,
      'guest': {'id': 'sa7bi-ai', 'username': 'صاحبي AI', 'mark': 'O'},
    });

    expect(room.state['aiOpponent'], isTrue);
    expect(room.guest?.username, 'صاحبي AI');
    expect(room.isPlaying, isTrue);
  });

  group('Quick matchmaking response', () {
    test('parses a player search that is still waiting', () {
      final result = SocialQuickMatchResult.fromJson({
        'ok': true,
        'matched': false,
        'aiFallback': false,
        'waitSeconds': 25,
        'reused': false,
        'room': {
          'id': '33333333-3333-4333-8333-333333333333',
          'inviteCode': 'AB2345',
          'game': 'chess',
          'status': 'waiting',
          'myRole': 'host',
          'state': {
            'matchmaking': true,
            'matchmakingStatus': 'searching',
          },
          'createdAt': 1760000000000,
          'updatedAt': 1760000000000,
        },
      });

      expect(result.matched, isFalse);
      expect(result.aiFallback, isFalse);
      expect(result.waitSeconds, 25);
      expect(result.room.isWaiting, isTrue);
      expect(result.room.state['matchmakingStatus'], 'searching');
    });

    test('parses an automatic AI fallback result', () {
      final result = SocialQuickMatchResult.fromJson({
        'ok': true,
        'matched': true,
        'aiFallback': true,
        'room': {
          'id': '44444444-4444-4444-8444-444444444444',
          'inviteCode': 'CD6789',
          'game': 'tic_tac_toe',
          'status': 'playing',
          'myRole': 'host',
          'state': {
            'aiOpponent': true,
            'matchmaking': true,
            'matchmakingStatus': 'ai_fallback',
          },
          'guest': {
            'id': 'sa7bi-ai',
            'username': 'صاحبي AI',
            'mark': 'O',
          },
        },
      });

      expect(result.matched, isTrue);
      expect(result.aiFallback, isTrue);
      expect(result.room.isPlaying, isTrue);
      expect(result.room.state['aiOpponent'], isTrue);
      expect(result.room.guest?.username, 'صاحبي AI');
    });
  });
}
