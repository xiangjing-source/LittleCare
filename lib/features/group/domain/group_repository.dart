import 'group_models.dart';

abstract interface class GroupRepository {
  Stream<List<UserGroup>> watchUserGroups(String userId);

  Stream<String?> watchSelectedGroupId(String userId);

  Stream<GroupSnapshot> watchGroup({
    required String groupId,
    required String viewerId,
  });

  Future<Group> createGroup({
    required String userId,
    required String name,
    String description,
  });

  Future<GroupInvitePreview> previewInvite(String inviteCode);

  Future<void> joinGroup({required String userId, required String inviteCode});

  Future<void> leaveGroup({required String userId, required String groupId});

  Future<void> removeMember({
    required String groupId,
    required String requesterId,
    required String memberUserId,
  });

  Future<void> renameGroup({
    required String groupId,
    required String requesterId,
    required String name,
  });

  Future<void> setGroupDisplayName({
    required String groupId,
    required String userId,
    String? displayName,
  });

  Future<void> dissolveGroup({
    required String groupId,
    required String requesterId,
  });

  Future<void> selectGroup({required String userId, required String groupId});

  Future<void> setAlias({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required String nickname,
  });

  Future<String> regenerateInvite({
    required String groupId,
    required String requesterId,
    DateTime? expiresAt,
  });
}
