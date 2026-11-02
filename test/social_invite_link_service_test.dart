
import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/social_invite_link_service.dart';

void main() {
  group('Social invite links', () {
    test('builds a custom app URI from a valid six-character code', () {
      final uri =
          SocialInviteLinkService.buildGameInviteUri('ab12cd');

      expect(uri.toString(), 'sa7bi://game/invite?code=AB12CD');
    });

    test('extracts a valid invite code from an incoming URI', () {
      final code = SocialInviteLinkService.extractInviteCode(
        Uri.parse('sa7bi://game/invite?code=Q7W8E9'),
      );

      expect(code, 'Q7W8E9');
    });

    test('rejects unrelated schemes, hosts, and paths', () {
      expect(
        SocialInviteLinkService.extractInviteCode(
          Uri.parse('https://example.com/game/invite?code=Q7W8E9'),
        ),
        isNull,
      );

      expect(
        SocialInviteLinkService.extractInviteCode(
          Uri.parse('sa7bi://other/invite?code=Q7W8E9'),
        ),
        isNull,
      );

      expect(
        SocialInviteLinkService.extractInviteCode(
          Uri.parse('sa7bi://game/profile?code=Q7W8E9'),
        ),
        isNull,
      );
    });

    test('rejects malformed or incomplete invite codes', () {
      for (final value in <String>['', 'ABC12', 'ABC1234', 'AB?123']) {
        expect(
          SocialInviteLinkService.extractInviteCode(
            Uri(
              scheme: 'sa7bi',
              host: 'game',
              path: '/invite',
              queryParameters: <String, String>{'code': value},
            ),
          ),
          isNull,
        );
      }
    });
  });
}
