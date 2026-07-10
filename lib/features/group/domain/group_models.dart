enum GroupRole { owner, admin, member }

enum MembershipStatus { active, pending, removed, left }

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.inviteCode,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.avatarUrl,
    this.inviteCodeExpiresAt,
    this.schemaVersion = 2,
  });

  final String id;
  final String name;
  final String description;
  final String? avatarUrl;
  final String createdBy;
  final String inviteCode;
  final DateTime? inviteCodeExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  bool get inviteExpired =>
      inviteCodeExpiresAt != null &&
      inviteCodeExpiresAt!.isBefore(DateTime.now());
}

class GroupMembership {
  const GroupMembership({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.updatedAt,
    this.displayNameInGroup,
    this.displayNameOverride,
  });

  final String id;
  final String groupId;
  final String userId;
  final GroupRole role;
  final MembershipStatus status;
  final String? displayNameInGroup;
  final String? displayNameOverride;
  final DateTime joinedAt;
  final DateTime updatedAt;

  bool get isActive => status == MembershipStatus.active;
  bool get canManageMembers =>
      role == GroupRole.owner || role == GroupRole.admin;
}

class UserGroup {
  const UserGroup({required this.group, required this.membership});

  final Group group;
  final GroupMembership membership;
}

class GroupSnapshot {
  const GroupSnapshot({
    required this.group,
    required this.members,
    this.aliases = const {},
    this.profileNames = const {},
  });

  final Group group;
  final List<GroupMembership> members;
  final Map<String, String> aliases;
  final Map<String, String> profileNames;

  String displayNameFor(GroupMembership member, String viewerId) {
    if (member.userId == viewerId) return '我';
    return aliases[member.userId] ??
        profileNames[member.userId] ??
        _fallbackDisplayName(member.displayNameInGroup) ??
        '群组成员';
  }

  String? _fallbackDisplayName(String? value) {
    if (value == null || value == '群组创建者' || value == '新成员') return null;
    return value;
  }
}

class GroupInvitePreview {
  const GroupInvitePreview({
    required this.groupId,
    required this.name,
    this.description = '',
  });

  final String groupId;
  final String name;
  final String description;
}
