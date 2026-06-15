class PlatformRole {
  static const user = 'user';
  static const platformAdmin = 'platformAdmin';

  static const _legacyPlatformOwner = 'platformOwner';
  static const values = {
    user,
    platformAdmin,
  };

  static String normalize(Object? value) {
    if (value == platformAdmin || value == _legacyPlatformOwner) {
      return platformAdmin;
    }
    return user;
  }

  static bool isPlatformAdmin(Object? value) {
    return normalize(value) == platformAdmin;
  }
}

class MembershipRole {
  static const member = 'member';
  static const orgAdmin = 'orgAdmin';

  static const _legacyAdmin = 'admin';
  static const _legacyBoardMember = 'boardMember';

  static const values = {
    member,
    orgAdmin,
  };

  static String normalize(Object? value) {
    if (value == orgAdmin || value == _legacyAdmin) {
      return orgAdmin;
    }
    if (value == member || value == _legacyBoardMember) {
      return member;
    }
    return member;
  }

  static bool isOrgAdmin(Object? value) {
    return normalize(value) == orgAdmin;
  }

  static bool isMember(Object? value) {
    return value == member ||
        value == orgAdmin ||
        value == _legacyAdmin ||
        value == _legacyBoardMember;
  }
}

class SeaRescueLevel {
  static const none = 'none';
  static const level1 = 'level1';
  static const level2 = 'level2';

  static const values = {
    none,
    level1,
    level2,
  };

  static String normalize(Object? value) {
    if (value is String && values.contains(value)) return value;
    return none;
  }

  static bool isLevel1(Object? value) {
    return normalize(value) == level1;
  }

  static bool isLevel2(Object? value) {
    return normalize(value) == level2;
  }
}

class MembershipModel {
  const MembershipModel({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.role,
    required this.seaRescueLevel,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String organizationId;
  final String role;
  final String seaRescueLevel;
  final bool isActive;

  factory MembershipModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return MembershipModel(
      id: id,
      userId: _stringValue(data['userId']),
      organizationId: _stringValue(
        data['organizationId'] ?? data['commandId'],
      ),
      role: MembershipRole.normalize(data['role']),
      seaRescueLevel: SeaRescueLevel.normalize(data['seaRescueLevel']),
      isActive: _isActiveMembership(data),
    );
  }

  bool get isMember => isActive && MembershipRole.isMember(role);
  bool get isOrgAdmin => isActive && MembershipRole.isOrgAdmin(role);
  bool get isSeaRescueLevel1 => SeaRescueLevel.isLevel1(seaRescueLevel);
  bool get isSeaRescueLevel2 => SeaRescueLevel.isLevel2(seaRescueLevel);

  static String _stringValue(Object? value) {
    return value is String ? value.trim() : '';
  }

  static bool _isActiveMembership(Map<String, dynamic> data) {
    final hasActiveMarker =
        data['status'] == 'active' || data['isActive'] == true;
    final statusIsActive =
        !data.containsKey('status') || data['status'] == 'active';
    final flagIsActive =
        !data.containsKey('isActive') || data['isActive'] == true;
    return hasActiveMarker && statusIsActive && flagIsActive;
  }
}
