import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/social_invite_link_service.dart';

void main() {
  group('SocialInviteLinkService', () {
    test('builds and extracts verified HTTPS game links', () {
      final uri = SocialInviteLinkService.buildGameInviteUri('ab12cd');

      expect(uri.scheme, 'https');
      expect(uri.host, SocialInviteLinkService.webHost);
      expect(uri.path, SocialInviteLinkService.webGameInvitePath);
      expect(
        SocialInviteLinkService.extractInviteCode(uri),
        'AB12CD',
      );
    });

    test('continues to accept legacy custom game links', () {
      final uri =
          SocialInviteLinkService.buildLegacyGameInviteUri('AB12CD');

      expect(
        SocialInviteLinkService.extractInviteCode(uri),
        'AB12CD',
      );
    });

    test('rejects game links from unrelated hosts and malformed codes', () {
      expect(
        SocialInviteLinkService.extractInviteCode(
          Uri.parse(
            'https://example.com/game/invite?code=AB12CD',
          ),
        ),
        isNull,
      );

      expect(
        SocialInviteLinkService.extractInviteCode(
          Uri.parse(
            'https://${SocialInviteLinkService.webHost}/game/invite?code=bad',
          ),
        ),
        isNull,
      );
    });

    test('builds and extracts verified HTTPS group links', () {
      const groupId = '123e4567-e89b-12d3-a456-426614174000';

      final uri =
          SocialInviteLinkService.buildGroupInviteUri(groupId);

      expect(uri.scheme, 'https');
      expect(uri.path, SocialInviteLinkService.webGroupInvitePath);
      expect(
        SocialInviteLinkService.extractGroupInviteId(uri),
        groupId,
      );
    });

    test('continues to accept legacy group links', () {
      const groupId = '123e4567-e89b-12d3-a456-426614174000';

      final uri =
          SocialInviteLinkService.buildLegacyGroupInviteUri(groupId);

      expect(
        SocialInviteLinkService.extractGroupInviteId(uri),
        groupId,
      );
    });

    test('rejects malformed group identifiers', () {
      expect(
        SocialInviteLinkService.extractGroupInviteId(
          Uri.parse(
            'https://${SocialInviteLinkService.webHost}/groups/invite?groupId=bad',
          ),
        ),
        isNull,
      );
    });
  });
}
