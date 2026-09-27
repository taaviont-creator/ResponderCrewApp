import 'package:flutter_test/flutter_test.dart';
import 'package:respondcrew_app/models/membership_model.dart';

void main() {
  group('MembershipRole', () {
    test('normalizes legacy admin to orgAdmin', () {
      expect(MembershipRole.normalize('admin'), MembershipRole.orgAdmin);
      expect(MembershipRole.isOrgAdmin('admin'), isTrue);
    });

    test('normalizes legacy boardMember to member', () {
      expect(MembershipRole.normalize('boardMember'), MembershipRole.member);
      expect(MembershipRole.isOrgAdmin('boardMember'), isFalse);
      expect(MembershipRole.isMember('boardMember'), isTrue);
    });

    test('unknown role never grants admin privileges', () {
      expect(MembershipRole.normalize('unexpected'), MembershipRole.member);
      expect(MembershipRole.isOrgAdmin('unexpected'), isFalse);
      expect(MembershipRole.isMember('unexpected'), isFalse);
    });
  });

  group('SeaRescueLevel', () {
    test('accepts only none, level1 and level2', () {
      expect(SeaRescueLevel.normalize(SeaRescueLevel.none), SeaRescueLevel.none);
      expect(
        SeaRescueLevel.normalize(SeaRescueLevel.level1),
        SeaRescueLevel.level1,
      );
      expect(
        SeaRescueLevel.normalize(SeaRescueLevel.level2),
        SeaRescueLevel.level2,
      );
    });

    test('unknown qualification defaults safely to none', () {
      expect(SeaRescueLevel.normalize('level3'), SeaRescueLevel.none);
      expect(SeaRescueLevel.normalize(null), SeaRescueLevel.none);
      expect(SeaRescueLevel.isLevel2('level3'), isFalse);
    });
  });

  group('MembershipModel', () {
    test('active member with level2 is recognized correctly', () {
      final membership = MembershipModel.fromMap(
        id: 'user_org',
        data: {
          'userId': 'user',
          'organizationId': 'org',
          'role': 'member',
          'seaRescueLevel': 'level2',
          'status': 'active',
          'isActive': true,
          'displayName': '  Mari Mere  ',
        },
      );

      expect(membership.isMember, isTrue);
      expect(membership.isOrgAdmin, isFalse);
      expect(membership.isSeaRescueLevel2, isTrue);
      expect(membership.safeDisplayName, 'Mari Mere');
    });

    test('removed membership is never treated as active', () {
      final membership = MembershipModel.fromMap(
        id: 'user_org',
        data: {
          'userId': 'user',
          'organizationId': 'org',
          'role': 'orgAdmin',
          'seaRescueLevel': 'level2',
          'status': 'removed',
          'isActive': false,
          'displayName': 'Admin',
        },
      );

      expect(membership.isMember, isFalse);
      expect(membership.isOrgAdmin, isFalse);
    });

    test('conflicting active markers fail closed', () {
      final inactiveStatus = MembershipModel.fromMap(
        id: 'a',
        data: {
          'userId': 'user',
          'organizationId': 'org',
          'role': 'member',
          'status': 'removed',
          'isActive': true,
        },
      );
      final inactiveFlag = MembershipModel.fromMap(
        id: 'b',
        data: {
          'userId': 'user',
          'organizationId': 'org',
          'role': 'member',
          'status': 'active',
          'isActive': false,
        },
      );

      expect(inactiveStatus.isActive, isFalse);
      expect(inactiveFlag.isActive, isFalse);
    });

    test('legacy commandId remains readable during migration', () {
      final membership = MembershipModel.fromMap(
        id: 'user_org',
        data: {
          'userId': 'user',
          'commandId': 'legacy-org',
          'role': 'member',
          'status': 'active',
          'isActive': true,
        },
      );

      expect(membership.organizationId, 'legacy-org');
      expect(membership.isMember, isTrue);
    });

    test('empty display name uses safe fallback', () {
      final membership = MembershipModel.fromMap(
        id: 'user_org',
        data: {
          'userId': 'user',
          'organizationId': 'org',
          'role': 'member',
          'status': 'active',
          'isActive': true,
          'displayName': '   ',
        },
      );

      expect(membership.safeDisplayName, MembershipModel.defaultDisplayName);
    });
  });
}
