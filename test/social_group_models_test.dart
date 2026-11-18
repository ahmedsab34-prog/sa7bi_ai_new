
import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/social_group_management_service.dart';

void main() {
  Matcher groupError(String code) {
    return isA<SocialGroupManagementException>().having(
      (error) => error.code,
      'error code',
      code,
    );
  }

  group('SocialManagedGroup model', () {
    test('parses owner permissions and group information', () {
      final group = SocialManagedGroup.fromJson({
        'id': '12345678-1234-1234-1234-123456789abc',
        'name': 'مجموعة الأصدقاء',
        'description': 'مجموعة خاصة',
        'ownerId': 'owner-1',
        'memberCount': 8,
        'isMember': true,
        'isPublic': false,
        'myRole': 'owner',
        'lastMessage': 'أهلًا بالجميع',
        'createdAt': 1760000000000,
        'updatedAt': 1760000005000,
      });

      expect(group.name, 'مجموعة الأصدقاء');
      expect(group.memberCount, 8);
      expect(group.isMember, isTrue);
      expect(group.isPublic, isFalse);
      expect(group.isOwner, isTrue);
      expect(group.isAdmin, isTrue);
      expect(group.lastMessage, 'أهلًا بالجميع');
    });

    test('recognizes an administrator but not an owner', () {
      final group = SocialManagedGroup.fromJson({
        'name': 'فريق اللعب',
        'myRole': 'admin',
      });

      expect(group.isOwner, isFalse);
      expect(group.isAdmin, isTrue);
    });

    test('recognizes a normal member', () {
      final group = SocialManagedGroup.fromJson({
        'name': 'الأصدقاء',
        'myRole': 'member',
      });

      expect(group.isOwner, isFalse);
      expect(group.isAdmin, isFalse);
    });

    test('converts a managed group to its public representation', () {
      final group = SocialManagedGroup.fromJson({
        'id': 'group-1',
        'name': 'مجموعة عامة',
        'description': 'وصف المجموعة',
        'ownerId': 'owner-1',
        'memberCount': 12,
        'isMember': true,
        'isPublic': true,
        'myRole': 'admin',
        'lastMessage': 'مرحبًا',
        'createdAt': 100,
        'updatedAt': 200,
      });

      final publicGroup = group.toPublicGroup();

      expect(publicGroup.id, group.id);
      expect(publicGroup.name, group.name);
      expect(publicGroup.memberCount, group.memberCount);
      expect(publicGroup.isMember, isTrue);
      expect(publicGroup.lastMessage, 'مرحبًا');
    });

    test('uses safe defaults for incomplete group responses', () {
      final group = SocialManagedGroup.fromJson({
        'id': 'group-2',
      });

      expect(group.name, 'مجموعة');
      expect(group.description, isEmpty);
      expect(group.memberCount, 0);
      expect(group.isMember, isFalse);
      expect(group.isPublic, isFalse);
      expect(group.myRole, 'member');
      expect(group.isAdmin, isFalse);
    });
  });

  group('SocialManagedMember model', () {
    test('parses member role and join date', () {
      final member = SocialManagedMember.fromJson({
        'userId': 'user-1',
        'username': 'PlayerOne',
        'role': 'admin',
        'joinedAt': 1760000000000,
      });

      expect(member.userId, 'user-1');
      expect(member.username, 'PlayerOne');
      expect(member.role, 'admin');
      expect(member.joinedAt, 1760000000000);
    });

    test('uses safe defaults for an incomplete member', () {
      final member = SocialManagedMember.fromJson({});

      expect(member.userId, isEmpty);
      expect(member.username, 'لاعب');
      expect(member.role, 'member');
      expect(member.joinedAt, 0);
    });
  });

  group('SocialGroupInvite model', () {
    test('parses invitation code and limits', () {
      final invite = SocialGroupInvite.fromJson({
        'code': 'AB23456789',
        'expiresAt': 1760604800000,
        'maxUses': 10,
      });

      expect(invite.code, 'AB23456789');
      expect(invite.expiresAt, 1760604800000);
      expect(invite.maxUses, 10);
    });
  });

  group('SocialGroupManagementService validation', () {
    final service = SocialGroupManagementService.instance;

    test('rejects a group name shorter than three characters', () async {
      await expectLater(
        service.createPrivateGroup(name: 'ab'),
        throwsA(groupError('INVALID_GROUP_NAME')),
      );
    });

    test('rejects a group name longer than forty characters', () async {
      final longName = List<String>.filled(41, 'a').join();

      await expectLater(
        service.createPrivateGroup(name: longName),
        throwsA(groupError('INVALID_GROUP_NAME')),
      );
    });

    test('rejects a description longer than 160 characters', () async {
      final longDescription = List<String>.filled(161, 'a').join();

      await expectLater(
        service.createPrivateGroup(
          name: 'مجموعة',
          description: longDescription,
        ),
        throwsA(groupError('INVALID_GROUP_DESCRIPTION')),
      );
    });

    test('rejects malformed group invitation codes', () async {
      await expectLater(
        service.joinByInviteCode('0000000000'),
        throwsA(groupError('GROUP_INVITE_INVALID')),
      );
    });

    test('rejects invalid group identifiers before network access', () async {
      await expectLater(
        service.createInvite('invalid-id'),
        throwsA(groupError('GROUP_NOT_FOUND')),
      );
    });
  });
}
