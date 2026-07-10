enum FamilyRole { owner, member }

class Family {
  const Family({
    required this.id,
    required this.inviteCode,
    required this.ownerId,
    required this.createdAt,
  });

  final String id;
  final String inviteCode;
  final String ownerId;
  final DateTime createdAt;
}

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.role,
    required this.defaultName,
    required this.joinedAt,
  });

  final String userId;
  final FamilyRole role;
  final String defaultName;
  final DateTime joinedAt;
}

class FamilySnapshot {
  const FamilySnapshot({
    required this.family,
    required this.members,
    this.nicknames = const {},
  });

  final Family family;
  final List<FamilyMember> members;
  final Map<String, String> nicknames;

  String displayNameFor(FamilyMember member, String viewerId) {
    if (member.userId == viewerId) return '我';
    return nicknames[member.userId] ?? member.defaultName;
  }
}
