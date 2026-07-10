import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/group_failure.dart';
import '../../domain/group_models.dart';
import '../providers/group_providers.dart';
import 'group_action_state.dart';

class GroupActionController extends Notifier<GroupActionState> {
  @override
  GroupActionState build() => const GroupActionState();

  Future<bool> createGroup({
    required String userId,
    required String name,
    String description = '',
  }) => _run(
    () => ref
        .read(groupRepositoryProvider)
        .createGroup(userId: userId, name: name, description: description),
    successMessage: '群组已经准备好了',
  );

  Future<GroupInvitePreview?> previewInvite(String inviteCode) async {
    if (state.isLoading) return null;
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final result = await ref
          .read(groupRepositoryProvider)
          .previewInvite(inviteCode);
      state = const GroupActionState();
      return result;
    } catch (error) {
      state = GroupActionState(errorMessage: _message(error));
      return null;
    }
  }

  Future<bool> joinGroup({
    required String userId,
    required String inviteCode,
  }) => _run(
    () => ref
        .read(groupRepositoryProvider)
        .joinGroup(userId: userId, inviteCode: inviteCode),
    successMessage: '已经加入这个群组',
  );

  Future<bool> leaveGroup({required String userId, required String groupId}) =>
      _run(
        () => ref
            .read(groupRepositoryProvider)
            .leaveGroup(userId: userId, groupId: groupId),
        successMessage: '已经退出这个群组',
      );

  Future<bool> removeMember({
    required String groupId,
    required String requesterId,
    required String memberUserId,
  }) => _run(
    () => ref
        .read(groupRepositoryProvider)
        .removeMember(
          groupId: groupId,
          requesterId: requesterId,
          memberUserId: memberUserId,
        ),
    successMessage: '已将成员移出群组',
  );

  Future<bool> renameGroup({
    required String groupId,
    required String requesterId,
    required String name,
  }) => _run(
    () => ref
        .read(groupRepositoryProvider)
        .renameGroup(groupId: groupId, requesterId: requesterId, name: name),
    successMessage: '群组名称已更新',
  );

  Future<bool> setGroupDisplayName({
    required String groupId,
    required String userId,
    required String displayName,
  }) => _run(
    () => ref
        .read(groupRepositoryProvider)
        .setGroupDisplayName(
          groupId: groupId,
          userId: userId,
          displayName: displayName,
        ),
    successMessage: '群组显示名已保存',
  );

  Future<bool> dissolveGroup({
    required String groupId,
    required String requesterId,
  }) => _run(
    () => ref
        .read(groupRepositoryProvider)
        .dissolveGroup(groupId: groupId, requesterId: requesterId),
    successMessage: '群组已解散',
  );

  Future<bool> selectGroup({required String userId, required String groupId}) =>
      _run(
        () => ref
            .read(groupRepositoryProvider)
            .selectGroup(userId: userId, groupId: groupId),
        successMessage: '已经切换群组',
      );

  Future<bool> setAlias({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required String nickname,
  }) => _run(
    () => ref
        .read(groupRepositoryProvider)
        .setAlias(
          groupId: groupId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          nickname: nickname,
        ),
    successMessage: '称呼已经保存',
  );

  Future<bool> _run(
    Future<Object?> Function() action, {
    required String successMessage,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      await action();
      state = GroupActionState(successMessage: successMessage);
      return true;
    } catch (error) {
      state = GroupActionState(errorMessage: _message(error));
      return false;
    }
  }

  String _message(Object error) =>
      error is GroupFailure ? error.message : '暂时没有完成，请稍后再试';

  void clearMessage() => state = const GroupActionState();
}
