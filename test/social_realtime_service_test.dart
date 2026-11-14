import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/social_realtime_service.dart';

void main() {
  group('SocialRealtimeEvent', () {
    test('parses a message event and conversation ID', () {
      final event = SocialRealtimeEvent.fromJson({
        'type': 'message.created',
        'conversationId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'message': {
          'id': 'message-1',
          'conversationId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          'text': 'أهلًا',
        },
      });

      expect(event.type, 'message.created');
      expect(
        event.conversationId,
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      expect(event.data['message'], isA<Map>());
    });

    test('parses typing and presence values without guessing', () {
      final typingEvent = SocialRealtimeEvent.fromJson({
        'type': 'typing.changed',
        'conversationId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'isTyping': true,
      });
      final presenceEvent = SocialRealtimeEvent.fromJson({
        'type': 'presence.changed',
        'conversationId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'online': false,
      });

      expect(typingEvent.isTyping, isTrue);
      expect(typingEvent.isOnline, isNull);
      expect(presenceEvent.isOnline, isFalse);
      expect(presenceEvent.isTyping, isNull);
    });

    test('uses safe defaults for incomplete event payloads', () {
      final event = SocialRealtimeEvent.fromJson({
        'sentAt': 1760000000000,
      });

      expect(event.type, 'unknown');
      expect(event.conversationId, isNull);
      expect(event.isTyping, isNull);
      expect(event.isOnline, isNull);
    });
  });

  group('SocialRealtimeService validation', () {
    test('rejects an invalid conversation ID before network access', () async {
      await expectLater(
        SocialRealtimeService.instance.connect('not-a-conversation-id'),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        SocialRealtimeService.instance.activeConversationId,
        isNull,
      );
      expect(SocialRealtimeService.instance.isConnected, isFalse);
    });
  });
}
