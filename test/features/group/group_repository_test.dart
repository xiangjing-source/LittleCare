import 'package:family_health_monitor/features/group/data/demo_group_repository.dart';
import 'package:family_health_monitor/features/group/domain/group_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoGroupRepository', () {
    test('one user can create and switch between multiple groups', () async {
      final repository = DemoGroupRepository();
      final first = await repository.createGroup(
        userId: 'user-a',
        name: '我的小窝',
      );
      final second = await repository.createGroup(
        userId: 'user-a',
        name: '减脂搭子',
      );

      final groups = await repository.watchUserGroups('user-a').first;
      expect(
        groups.map((item) => item.group.id),
        containsAll([first.id, second.id]),
      );

      await repository.selectGroup(userId: 'user-a', groupId: first.id);
      expect(await repository.watchSelectedGroupId('user-a').first, first.id);
    });

    test('invite is previewed before another user joins', () async {
      final repository = DemoGroupRepository();
      final group = await repository.createGroup(
        userId: 'owner',
        name: '大学室友',
        description: '偶尔聊聊近况',
      );

      final preview = await repository.previewInvite(group.inviteCode);
      expect(preview.name, '大学室友');

      await repository.joinGroup(
        userId: 'friend',
        inviteCode: group.inviteCode,
      );
      expect(await repository.watchUserGroups('friend').first, hasLength(1));
    });

    test('groups are isolated from non-members and after leaving', () async {
      final repository = DemoGroupRepository();
      final privateGroup = await repository.createGroup(
        userId: 'owner',
        name: '只属于 A 的群组',
      );
      final sharedGroup = await repository.createGroup(
        userId: 'owner',
        name: '共同群组',
      );
      await repository.joinGroup(
        userId: 'member',
        inviteCode: sharedGroup.inviteCode,
      );

      expect(
        repository
            .watchGroup(groupId: privateGroup.id, viewerId: 'member')
            .first,
        throwsA(isA<GroupFailure>()),
      );

      await repository.leaveGroup(userId: 'member', groupId: sharedGroup.id);
      expect(
        repository
            .watchGroup(groupId: sharedGroup.id, viewerId: 'member')
            .first,
        throwsA(isA<GroupFailure>()),
      );
    });
  });
}
