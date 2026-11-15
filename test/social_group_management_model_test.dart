import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/services/social_group_management_service.dart';

void main() {
  group('SocialManagedGroup', () {
    test('parses a private owner group correctly', () {
      final group = SocialManagedGroup.fromJson({
        'id': '11111111-1111-4111-8111-111111111111',
        'name': 'Family Circle',
        'description': 'Private family group',
        'ownerId': 'owner-1',
        'memberCount': 4,
        'isMember': true,
        'isPublic': false,
        'myRole': 'owner',
        'lastMessage': 'Welcome',
        'createdAt': 1000,
        'updatedAt': 2000,
      });

      expect(group.name, 'Family Circle');
      expect(group.isPublic, isFalse);
      expect(group.isMember, isTrue);
      expect(group.isOwner, isTrue);
      expect(group.isAdmin, isTrue);
      expect(group.memberCount, 4);
    });

    test('parses an admin group correctly', () {
      final group = SocialManagedGroup.fromJson({
        'id': '22222222-2222-4222-8222-222222222222',
        'name': 'Friends',
        'isPublic': false,
        'isMember': true,
        'myRole': 'admin',
        'memberCount': 3,
      });

      expect(group.isOwner, isFalse);
      expect(group.isAdmin, isTrue);
    });

    test('parses a regular member correctly', () {
      final group = SocialManagedGroup.fromJson({
        'id': '33333333-3333-4333-8333-333333333333',
        'name': 'Friends',
        'isPublic': false,
        'isMember': true,
        'myRole': 'member',
        'memberCount': 3,
      });

      expect(group.isOwner, isFalse);
      expect(group.isAdmin, isFalse);
    });

    test('converts a managed group to the existing public group model', () {
      final group = SocialManagedGroup.fromJson({
        'id': '44444444-4444-4444-8444-444444444444',
        'name': 'Chess',
        'description': 'Chess friends',
        'ownerId': 'owner-4',
        'memberCount': 8,
        'isMember': true,
        'isPublic': false,
        'myRole': 'owner',
        'lastMessage': 'Hello',
        'createdAt': 100,
        'updatedAt': 200,
      });

      final converted = group.toPublicGroup();

      expect(converted.id, group.id);
      expect(converted.name, group.name);
      expect(converted.memberCount, group.memberCount);
      expect(converted.isMember, isTrue);
    });
  });

  group('SocialManagedMember', () {
    test('parses member identity and role', () {
      final member = SocialManagedMember.fromJson({
        'userId': 'member-1',
        'username': 'Ahmed',
        'role': 'admin',
        'joinedAt': 123456,
      });

      expect(member.userId, 'member-1');
      expect(member.username, 'Ahmed');
      expect(member.role, 'admin');
      expect(member.joinedAt, 123456);
    });
  });

  group('SocialGroupInvite', () {
    test('parses invite code, expiry and usage limit', () {
      final invite = SocialGroupInvite.fromJson({
        'code': 'ABCD2345XY',
        'expiresAt': 987654321,
        'maxUses': 25,
      });

      expect(invite.code, 'ABCD2345XY');
      expect(invite.expiresAt, 987654321);
      expect(invite.maxUses, 25);
    });
  });
}
