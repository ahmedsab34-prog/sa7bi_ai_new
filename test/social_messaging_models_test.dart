
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/services/social_messaging_service.dart';

void main() {
  group('Social game invitation models', () {
    test('parses an incoming invitation and game title', () {
      final invitation = SocialGameInvitation.fromJson({
        'id': '12345678-1234-1234-1234-123456789abc',
        'sender': {'id': 'sender-id', 'username': 'PlayerOne'},
        'recipient': {'id': 'recipient-id', 'username': 'PlayerTwo'},
        'game': 'chess',
        'status': 'pending',
        'roomId': '87654321-4321-4321-4321-cba987654321',
        'inviteCode': 'A7BC23',
        'createdAt': 1760000000000,
        'expiresAt': 1760604800000,
        'direction': 'incoming',
      });

      expect(invitation.id, '12345678-1234-1234-1234-123456789abc');
      expect(invitation.sender.username, 'PlayerOne');
      expect(invitation.recipient.username, 'PlayerTwo');
      expect(invitation.gameTitle, 'الشطرنج');
      expect(invitation.statusLabel, 'في انتظار الرد');
      expect(invitation.inviteCode, 'A7BC23');
      expect(invitation.direction, 'incoming');
    });

    test('uses safe fallbacks for incomplete invitation JSON', () {
      final invitation = SocialGameInvitation.fromJson({
        'id': 'invite-id',
      });

      expect(invitation.sender.username, 'لاعب');
      expect(invitation.recipient.username, 'لاعب');
      expect(invitation.gameTitle, 'لعبة جماعية');
      expect(invitation.status, 'unknown');
      expect(invitation.inviteCode, isEmpty);
    });
  });

  group('Social conversation models', () {
    test('parses a conversation with unread count and last message', () {
      final conversation = SocialConversationSummary.fromJson({
        'id': 'conversation-id',
        'otherUser': {
          'id': 'other-user-id',
          'username': 'Friend',
        },
        'lastMessage': {
          'id': 'message-id',
          'senderId': 'other-user-id',
          'text': 'أهلًا!',
          'createdAt': 1760000000000,
        },
        'unreadCount': 3,
        'createdAt': 1759990000000,
        'updatedAt': 1760000000000,
      });

      expect(conversation.id, 'conversation-id');
      expect(conversation.otherUser.username, 'Friend');
      expect(conversation.lastMessage?.text, 'أهلًا!');
      expect(conversation.unreadCount, 3);
      expect(conversation.updatedAt, 1760000000000);
    });

    test('supports an empty conversation without a last message', () {
      final conversation = SocialConversationSummary.fromJson({
        'id': 'conversation-id',
        'otherUser': {'id': 'friend-id', 'username': 'Friend'},
      });

      expect(conversation.lastMessage, isNull);
      expect(conversation.unreadCount, 0);
      expect(conversation.otherUser.username, 'Friend');
    });
  });

  group('Private message models', () {
    test('parses message ownership and read receipt', () {
      final message = SocialPrivateMessage.fromJson({
        'id': 'message-id',
        'conversationId': 'conversation-id',
        'senderId': 'my-user-id',
        'text': 'رسالة خاصة',
        'createdAt': 1760000000000,
        'readAt': 1760000005000,
        'isMine': true,
      });

      expect(message.text, 'رسالة خاصة');
      expect(message.isMine, isTrue);
      expect(message.readAt, 1760000005000);
    });

    test('parses a message without a read receipt', () {
      final message = SocialPrivateMessage.fromJson({
        'id': 'message-id',
        'conversationId': 'conversation-id',
        'senderId': 'friend-id',
        'text': 'مرحبًا',
        'createdAt': 1760000000000,
        'readAt': null,
        'isMine': false,
      });

      expect(message.readAt, isNull);
      expect(message.isMine, isFalse);
      expect(message.senderId, 'friend-id');
    });
  });
}
