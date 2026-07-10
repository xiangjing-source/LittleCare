import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/group_models.dart';
import '../../domain/group_repository.dart';
import '../state/group_action_controller.dart';
import '../state/group_action_state.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  throw UnimplementedError('GroupRepository must be overridden at startup.');
});

final userGroupsProvider = StreamProvider.family<List<UserGroup>, String>(
  (ref, userId) => ref.watch(groupRepositoryProvider).watchUserGroups(userId),
);

final selectedGroupIdProvider = StreamProvider.family<String?, String>(
  (ref, userId) =>
      ref.watch(groupRepositoryProvider).watchSelectedGroupId(userId),
);

final selectedGroupProvider = Provider.family<UserGroup?, String>((
  ref,
  userId,
) {
  final groups =
      ref.watch(userGroupsProvider(userId)).value ?? const <UserGroup>[];
  final selectedId = ref.watch(selectedGroupIdProvider(userId)).value;
  return groups.where((item) => item.group.id == selectedId).firstOrNull ??
      groups.firstOrNull;
});

final selectedGroupMembersProvider =
    StreamProvider.family<GroupSnapshot, ({String groupId, String viewerId})>(
      (ref, query) => ref
          .watch(groupRepositoryProvider)
          .watchGroup(groupId: query.groupId, viewerId: query.viewerId),
    );

final groupActionControllerProvider =
    NotifierProvider<GroupActionController, GroupActionState>(
      GroupActionController.new,
    );
