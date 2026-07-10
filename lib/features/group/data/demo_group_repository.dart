import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../../core/storage/demo_storage_contract.dart';
import '../domain/group_failure.dart';
import '../domain/group_models.dart';
import '../domain/group_repository.dart';

class DemoGroupRepository implements GroupRepository {
  DemoGroupRepository({
    DemoStorage? storage,
    String? initialState,
    String? legacyFamilyState,
  }) : _storage = storage {
    _seedDemoGroup();
    if (initialState != null) {
      _restore(initialState);
    } else if (legacyFamilyState != null) {
      _migrateLegacyFamilies(legacyFamilyState);
    }
  }

  static const storageKey = 'demo_group_state_v2';
  static const _demoGroupId = 'demo-group';
  static const _inviteCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final DemoStorage? _storage;
  final Random _random = Random();
  final Map<String, Group> _groups = {};
  final Map<String, GroupMembership> _memberships = {};
  final Map<String, String?> _selectedByUser = {};
  final Map<String, Map<String, String>> _aliasesByViewerAndGroup = {};
  final StreamController<String> _userUpdates = StreamController.broadcast();
  final StreamController<String> _groupUpdates = StreamController.broadcast();

  void _seedDemoGroup() {
    if (_groups.containsKey(_demoGroupId)) return;
    final createdAt = DateTime.now().subtract(const Duration(days: 30));
    _groups[_demoGroupId] = Group(
      id: _demoGroupId,
      name: '温暖小组',
      description: '演示用的健康互助群组',
      createdBy: 'demo-mom',
      inviteCode: 'FAMILY1',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final membership = GroupMembership(
      id: _membershipId(_demoGroupId, 'demo-mom'),
      groupId: _demoGroupId,
      userId: 'demo-mom',
      role: GroupRole.owner,
      status: MembershipStatus.active,
      displayNameInGroup: '群组创建者',
      joinedAt: createdAt,
      updatedAt: createdAt,
    );
    _memberships[membership.id] = membership;
    final demoUserMembership = GroupMembership(
      id: _membershipId(_demoGroupId, 'demo-user'),
      groupId: _demoGroupId,
      userId: 'demo-user',
      role: GroupRole.member,
      status: MembershipStatus.active,
      displayNameInGroup: '我',
      joinedAt: createdAt.add(const Duration(days: 1)),
      updatedAt: createdAt.add(const Duration(days: 1)),
    );
    _memberships[demoUserMembership.id] = demoUserMembership;
    _selectedByUser['demo-user'] = _demoGroupId;
  }

  @override
  Stream<List<UserGroup>> watchUserGroups(String userId) async* {
    yield _userGroups(userId);
    yield* _userUpdates.stream
        .where((updatedUserId) => updatedUserId == userId)
        .map((_) => _userGroups(userId));
  }

  List<UserGroup> _userGroups(String userId) {
    final result = <UserGroup>[];
    for (final membership in _memberships.values) {
      if (membership.userId != userId || !membership.isActive) continue;
      final group = _groups[membership.groupId];
      if (group != null) {
        result.add(UserGroup(group: group, membership: membership));
      }
    }
    result.sort(
      (left, right) => right.group.updatedAt.compareTo(left.group.updatedAt),
    );
    return List.unmodifiable(result);
  }

  @override
  Stream<String?> watchSelectedGroupId(String userId) async* {
    yield _validSelectedGroup(userId);
    yield* _userUpdates.stream
        .where((updatedUserId) => updatedUserId == userId)
        .map((_) => _validSelectedGroup(userId));
  }

  String? _validSelectedGroup(String userId) {
    final groups = _userGroups(userId);
    if (groups.isEmpty) return null;
    final selected = _selectedByUser[userId];
    if (selected != null && groups.any((item) => item.group.id == selected)) {
      return selected;
    }
    final fallback = groups.first.group.id;
    _selectedByUser[userId] = fallback;
    return fallback;
  }

  @override
  Stream<GroupSnapshot> watchGroup({
    required String groupId,
    required String viewerId,
  }) async* {
    yield _snapshot(groupId, viewerId);
    yield* _groupUpdates.stream
        .where((updatedGroupId) => updatedGroupId == groupId)
        .map((_) => _snapshot(groupId, viewerId));
  }

  GroupSnapshot _snapshot(String groupId, String viewerId) {
    _requireActiveMembership(groupId, viewerId);
    final group = _groups[groupId];
    if (group == null) {
      throw const GroupFailure('这个群组已经不存在了', code: 'not-found');
    }
    final members =
        _memberships.values
            .where((item) => item.groupId == groupId && item.isActive)
            .toList()
          ..sort((left, right) {
            final roleOrder = {
              GroupRole.owner: 0,
              GroupRole.admin: 1,
              GroupRole.member: 2,
            };
            final byRole = roleOrder[left.role]!.compareTo(
              roleOrder[right.role]!,
            );
            return byRole == 0
                ? left.joinedAt.compareTo(right.joinedAt)
                : byRole;
          });
    return GroupSnapshot(
      group: group,
      members: List.unmodifiable(members),
      aliases: Map.unmodifiable(
        _aliasesByViewerAndGroup[_aliasBucket(groupId, viewerId)] ?? const {},
      ),
    );
  }

  @override
  Future<Group> createGroup({
    required String userId,
    required String name,
    String description = '',
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 24) {
      throw const GroupFailure('群组名称请输入 1–24 个字符', code: 'bad-name');
    }
    final now = DateTime.now();
    final id = 'group-${now.microsecondsSinceEpoch}';
    final group = Group(
      id: id,
      name: normalizedName,
      description: description.trim(),
      createdBy: userId,
      inviteCode: _newInviteCode(),
      createdAt: now,
      updatedAt: now,
    );
    _groups[id] = group;
    final membership = GroupMembership(
      id: _membershipId(id, userId),
      groupId: id,
      userId: userId,
      role: GroupRole.owner,
      status: MembershipStatus.active,
      displayNameInGroup: '群组创建者',
      joinedAt: now,
      updatedAt: now,
    );
    _memberships[membership.id] = membership;
    _selectedByUser[userId] = id;
    await _persist();
    _notifyGroupAndUser(id, userId);
    return group;
  }

  @override
  Future<GroupInvitePreview> previewInvite(String inviteCode) async {
    final group = _groupForInvite(inviteCode);
    return GroupInvitePreview(
      groupId: group.id,
      name: group.name,
      description: group.description,
    );
  }

  @override
  Future<void> joinGroup({
    required String userId,
    required String inviteCode,
  }) async {
    final group = _groupForInvite(inviteCode);
    final id = _membershipId(group.id, userId);
    final existing = _memberships[id];
    if (existing?.isActive == true) {
      _selectedByUser[userId] = group.id;
      await _persist();
      _userUpdates.add(userId);
      return;
    }
    final now = DateTime.now();
    _memberships[id] = GroupMembership(
      id: id,
      groupId: group.id,
      userId: userId,
      role: GroupRole.member,
      status: MembershipStatus.active,
      displayNameInGroup: '新成员',
      joinedAt: now,
      updatedAt: now,
    );
    _selectedByUser[userId] = group.id;
    if (group.id == _demoGroupId) {
      _aliasesByViewerAndGroup.putIfAbsent(
            _aliasBucket(group.id, userId),
            () => {},
          )['demo-mom'] =
          '伙伴';
    }
    await _persist();
    _notifyGroupAndUser(group.id, userId);
  }

  Group _groupForInvite(String inviteCode) {
    final normalized = inviteCode.trim().toUpperCase();
    final group =
        _groups.values
            .where(
              (item) => item.inviteCode == normalized && !item.inviteExpired,
            )
            .firstOrNull;
    if (group == null) {
      throw const GroupFailure('没有找到有效的邀请码，请检查后再试', code: 'bad-code');
    }
    return group;
  }

  @override
  Future<void> leaveGroup({
    required String userId,
    required String groupId,
  }) async {
    final membership = _requireActiveMembership(groupId, userId);
    if (membership.role == GroupRole.owner) {
      throw const GroupFailure('群主需要先转让群组，才能退出', code: 'owner-cannot-leave');
    }
    _memberships[membership.id] = GroupMembership(
      id: membership.id,
      groupId: membership.groupId,
      userId: membership.userId,
      role: membership.role,
      status: MembershipStatus.left,
      displayNameInGroup: membership.displayNameInGroup,
      displayNameOverride: membership.displayNameOverride,
      joinedAt: membership.joinedAt,
      updatedAt: DateTime.now(),
    );
    if (_selectedByUser[userId] == groupId) _selectedByUser[userId] = null;
    await _persist();
    _notifyGroupAndUser(groupId, userId);
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String requesterId,
    required String memberUserId,
  }) async {
    if (requesterId == memberUserId) {
      throw const GroupFailure('不能移除自己', code: 'cannot-remove-self');
    }
    final requester = _requireActiveMembership(groupId, requesterId);
    if (requester.role != GroupRole.owner) {
      throw const GroupFailure('只有创建者可以移除成员', code: 'forbidden');
    }
    final member = _requireActiveMembership(groupId, memberUserId);
    if (member.role == GroupRole.owner) {
      throw const GroupFailure('不能移除群组创建者', code: 'cannot-remove-owner');
    }
    _memberships[member.id] = GroupMembership(
      id: member.id,
      groupId: member.groupId,
      userId: member.userId,
      role: member.role,
      status: MembershipStatus.removed,
      displayNameInGroup: member.displayNameInGroup,
      displayNameOverride: member.displayNameOverride,
      joinedAt: member.joinedAt,
      updatedAt: DateTime.now(),
    );
    if (_selectedByUser[memberUserId] == groupId) {
      _selectedByUser[memberUserId] = null;
    }
    await _persist();
    _notifyGroupAndUser(groupId, memberUserId);
  }

  @override
  Future<void> renameGroup({
    required String groupId,
    required String requesterId,
    required String name,
  }) async {
    final membership = _requireActiveMembership(groupId, requesterId);
    if (membership.role != GroupRole.owner) {
      throw const GroupFailure('只有创建者可以重命名群组', code: 'forbidden');
    }
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const GroupFailure('群组名称不能为空', code: 'bad-name');
    }
    final current = _groups[groupId]!;
    _groups[groupId] = Group(
      id: current.id,
      name: normalized,
      description: current.description,
      avatarUrl: current.avatarUrl,
      createdBy: current.createdBy,
      inviteCode: current.inviteCode,
      inviteCodeExpiresAt: current.inviteCodeExpiresAt,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    await _persist();
    _groupUpdates.add(groupId);
  }

  @override
  Future<void> setGroupDisplayName({
    required String groupId,
    required String userId,
    String? displayName,
  }) async {
    final membership = _requireActiveMembership(groupId, userId);
    final normalized = displayName?.trim();
    _memberships[membership.id] = GroupMembership(
      id: membership.id,
      groupId: membership.groupId,
      userId: membership.userId,
      role: membership.role,
      status: membership.status,
      displayNameInGroup: membership.displayNameInGroup,
      displayNameOverride:
          normalized == null || normalized.isEmpty ? null : normalized,
      joinedAt: membership.joinedAt,
      updatedAt: DateTime.now(),
    );
    await _persist();
    _notifyGroupAndUser(groupId, userId);
  }

  @override
  Future<void> dissolveGroup({
    required String groupId,
    required String requesterId,
  }) async {
    final membership = _requireActiveMembership(groupId, requesterId);
    if (membership.role != GroupRole.owner) {
      throw const GroupFailure('只有创建者可以解散群组', code: 'forbidden');
    }
    _groups.remove(groupId);
    for (final member in _memberships.values.where(
      (item) => item.groupId == groupId,
    )) {
      _selectedByUser[member.userId] = null;
    }
    _memberships.removeWhere((_, item) => item.groupId == groupId);
    await _persist();
    _groupUpdates.add(groupId);
  }

  @override
  Future<void> selectGroup({
    required String userId,
    required String groupId,
  }) async {
    _requireActiveMembership(groupId, userId);
    _selectedByUser[userId] = groupId;
    await _persist();
    _userUpdates.add(userId);
  }

  @override
  Future<void> setAlias({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required String nickname,
  }) async {
    _requireActiveMembership(groupId, fromUserId);
    _requireActiveMembership(groupId, toUserId);
    final normalized = nickname.trim();
    if (normalized.isEmpty || normalized.length > 12) {
      throw const GroupFailure('称呼请输入 1–12 个字符', code: 'bad-alias');
    }
    _aliasesByViewerAndGroup.putIfAbsent(
          _aliasBucket(groupId, fromUserId),
          () => {},
        )[toUserId] =
        normalized;
    await _persist();
    _groupUpdates.add(groupId);
  }

  @override
  Future<String> regenerateInvite({
    required String groupId,
    required String requesterId,
    DateTime? expiresAt,
  }) async {
    final membership = _requireActiveMembership(groupId, requesterId);
    if (!membership.canManageMembers) {
      throw const GroupFailure('只有群主或管理员可以更新邀请码', code: 'forbidden');
    }
    final current = _groups[groupId]!;
    final updated = Group(
      id: current.id,
      name: current.name,
      description: current.description,
      avatarUrl: current.avatarUrl,
      createdBy: current.createdBy,
      inviteCode: _newInviteCode(),
      inviteCodeExpiresAt: expiresAt,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    _groups[groupId] = updated;
    await _persist();
    _groupUpdates.add(groupId);
    return updated.inviteCode;
  }

  GroupMembership _requireActiveMembership(String groupId, String userId) {
    final membership = _memberships[_membershipId(groupId, userId)];
    if (membership == null || !membership.isActive) {
      throw const GroupFailure('你已不在这个群组中', code: 'not-member');
    }
    return membership;
  }

  void _notifyGroupAndUser(String groupId, String userId) {
    _groupUpdates.add(groupId);
    _userUpdates.add(userId);
    for (final membership in _memberships.values) {
      if (membership.groupId == groupId && membership.isActive) {
        _userUpdates.add(membership.userId);
      }
    }
  }

  String _newInviteCode() {
    for (var attempt = 0; attempt < 20; attempt++) {
      final code =
          List.generate(
            6,
            (_) => _inviteCharacters[_random.nextInt(_inviteCharacters.length)],
          ).join();
      if (_groups.values.every((group) => group.inviteCode != code)) {
        return code;
      }
    }
    return DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase()
        .substring(0, 6);
  }

  static String _membershipId(String groupId, String userId) =>
      '${groupId}_$userId';
  static String _aliasBucket(String groupId, String viewerId) =>
      '$groupId::$viewerId';

  Future<void> _persist() async {
    await _storage?.setString(storageKey, exportState());
  }

  String exportState() => jsonEncode({
    'schema_version': 2,
    'selected_by_user': _selectedByUser,
    'groups': _groups.values.map(_groupToJson).toList(),
    'memberships': _memberships.values.map(_membershipToJson).toList(),
    'aliases': _aliasesByViewerAndGroup,
  });

  void _restore(String encoded) {
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      _groups.clear();
      _memberships.clear();
      for (final item in (data['groups'] as List<dynamic>? ?? const [])) {
        final group = _groupFromJson(Map<String, dynamic>.from(item as Map));
        _groups[group.id] = group;
      }
      for (final item in (data['memberships'] as List<dynamic>? ?? const [])) {
        final membership = _membershipFromJson(
          Map<String, dynamic>.from(item as Map),
        );
        _memberships[membership.id] = membership;
      }
      _selectedByUser.addAll(
        Map<String, dynamic>.from(
          data['selected_by_user'] as Map? ?? const {},
        ).map((key, value) => MapEntry(key, value as String?)),
      );
      final aliases = Map<String, dynamic>.from(
        data['aliases'] as Map? ?? const {},
      );
      for (final entry in aliases.entries) {
        _aliasesByViewerAndGroup[entry.key] = Map<String, String>.from(
          entry.value as Map,
        );
      }
      _seedDemoGroup();
    } catch (_) {
      _groups.clear();
      _memberships.clear();
      _selectedByUser.clear();
      _aliasesByViewerAndGroup.clear();
      _seedDemoGroup();
    }
  }

  void _migrateLegacyFamilies(String encoded) {
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      for (final raw in (data['families'] as List<dynamic>? ?? const [])) {
        final item = Map<String, dynamic>.from(raw as Map);
        final legacy = Map<String, dynamic>.from(item['family'] as Map);
        final groupId = legacy['id'] as String;
        final createdAt = DateTime.parse(legacy['created_at'] as String);
        _groups[groupId] = Group(
          id: groupId,
          name: '我的群组',
          description: '由旧版群组数据迁移',
          createdBy: legacy['owner_id'] as String,
          inviteCode: legacy['invite_code'] as String,
          createdAt: createdAt,
          updatedAt: createdAt,
        );
        for (final rawMember
            in (item['members'] as List<dynamic>? ?? const [])) {
          final member = Map<String, dynamic>.from(rawMember as Map);
          final userId = member['user_id'] as String;
          final joinedAt = DateTime.parse(member['joined_at'] as String);
          final membership = GroupMembership(
            id: _membershipId(groupId, userId),
            groupId: groupId,
            userId: userId,
            role:
                member['role'] == 'owner' ? GroupRole.owner : GroupRole.member,
            status: MembershipStatus.active,
            displayNameInGroup: member['default_name'] as String?,
            joinedAt: joinedAt,
            updatedAt: joinedAt,
          );
          _memberships[membership.id] = membership;
        }
      }
      final selected = Map<String, dynamic>.from(
        data['family_ids'] as Map? ?? const {},
      );
      _selectedByUser.addAll(
        selected.map((key, value) => MapEntry(key, value as String?)),
      );
      final nicknames = Map<String, dynamic>.from(
        data['nicknames'] as Map? ?? const {},
      );
      for (final entry in nicknames.entries) {
        final groupId = _selectedByUser[entry.key];
        if (groupId != null) {
          _aliasesByViewerAndGroup[_aliasBucket(
            groupId,
            entry.key,
          )] = Map<String, String>.from(entry.value as Map);
        }
      }
      _seedDemoGroup();
      unawaited(_persist());
    } catch (_) {
      _seedDemoGroup();
    }
  }

  static Map<String, dynamic> _groupToJson(Group group) => {
    'id': group.id,
    'name': group.name,
    'description': group.description,
    'avatar_url': group.avatarUrl,
    'created_by': group.createdBy,
    'invite_code': group.inviteCode,
    'invite_code_expires_at': group.inviteCodeExpiresAt?.toIso8601String(),
    'created_at': group.createdAt.toIso8601String(),
    'updated_at': group.updatedAt.toIso8601String(),
    'schema_version': group.schemaVersion,
  };

  static Group _groupFromJson(Map<String, dynamic> data) => Group(
    id: data['id'] as String,
    name: data['name'] as String,
    description: data['description'] as String? ?? '',
    avatarUrl: data['avatar_url'] as String?,
    createdBy: data['created_by'] as String,
    inviteCode: data['invite_code'] as String,
    inviteCodeExpiresAt:
        data['invite_code_expires_at'] == null
            ? null
            : DateTime.parse(data['invite_code_expires_at'] as String),
    createdAt: DateTime.parse(data['created_at'] as String),
    updatedAt: DateTime.parse(data['updated_at'] as String),
    schemaVersion: data['schema_version'] as int? ?? 2,
  );

  static Map<String, dynamic> _membershipToJson(GroupMembership membership) => {
    'id': membership.id,
    'group_id': membership.groupId,
    'user_id': membership.userId,
    'role': membership.role.name,
    'status': membership.status.name,
    'display_name_in_group': membership.displayNameInGroup,
    'display_name_override': membership.displayNameOverride,
    'joined_at': membership.joinedAt.toIso8601String(),
    'updated_at': membership.updatedAt.toIso8601String(),
  };

  static GroupMembership _membershipFromJson(Map<String, dynamic> data) =>
      GroupMembership(
        id: data['id'] as String,
        groupId: data['group_id'] as String,
        userId: data['user_id'] as String,
        role: GroupRole.values.byName(data['role'] as String),
        status: MembershipStatus.values.byName(data['status'] as String),
        displayNameInGroup: data['display_name_in_group'] as String?,
        displayNameOverride: data['display_name_override'] as String?,
        joinedAt: DateTime.parse(data['joined_at'] as String),
        updatedAt: DateTime.parse(data['updated_at'] as String),
      );
}
