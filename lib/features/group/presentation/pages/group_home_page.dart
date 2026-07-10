import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../care/domain/care_models.dart';
import '../../../care/presentation/providers/care_providers.dart';
import '../../../care/presentation/widgets/care_composer_sheet.dart';
import '../../../health/domain/health_formatters.dart';
import '../../../health/domain/health_models.dart';
import '../../../health/domain/health_repository.dart';
import '../../../health/presentation/pages/health_detail_page.dart';
import '../../../health/presentation/pages/health_record_entry_page.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../notification/presentation/pages/notification_settings_page.dart';
import '../../../notification/presentation/providers/notification_providers.dart';
import '../../domain/group_models.dart';
import '../providers/group_providers.dart';
import '../state/group_action_state.dart';

class GroupHomePage extends ConsumerWidget {
  const GroupHomePage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<GroupActionState>(groupActionControllerProvider, (before, next) {
      final message = next.errorMessage ?? next.successMessage;
      if (message == null ||
          message == before?.errorMessage ||
          message == before?.successMessage) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
    if (ref.watch(firebaseEnabledProvider)) {
      unawaited(
        ref
            .read(pushNotificationRegistrationServiceProvider)
            .activateForUser(user.id),
      );
    }

    final groupsAsync = ref.watch(userGroupsProvider(user.id));
    final selected = ref.watch(selectedGroupProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title:
            selected == null
                ? const Text('我的群组')
                : TextButton.icon(
                  onPressed: () => _showGroupSwitcher(context, ref, user.id),
                  icon: _GroupAvatar(name: selected.group.name, small: true),
                  label: Text(
                    selected.group.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  iconAlignment: IconAlignment.start,
                ),
        actions: [
          if (selected != null)
            IconButton(
              tooltip: '当前群组管理',
              onPressed:
                  () => _showGroupSettings(context, ref, user.id, selected),
              icon: const Icon(Icons.manage_accounts_rounded),
            ),
          IconButton(
            tooltip: '通知与隐私',
            onPressed: () {
              final groups =
                  ref.read(userGroupsProvider(user.id)).value ??
                  const <UserGroup>[];
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder:
                      (_) => NotificationSettingsPage(
                        userId: user.id,
                        groups: groups,
                      ),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: '退出登录',
            onPressed: () async {
              await ref
                  .read(pushNotificationRegistrationServiceProvider)
                  .deactivate();
              await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) => _RetryPanel(
              onRetry: () => ref.invalidate(userGroupsProvider(user.id)),
            ),
        data: (groups) {
          if (groups.isEmpty) return _NoGroupsView(user: user);
          if (selected == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _GroupDashboard(user: user, selected: selected);
        },
      ),
    );
  }

  Future<void> _showGroupSwitcher(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final groups =
        ref.read(userGroupsProvider(userId)).value ?? const <UserGroup>[];
    final selectedId = ref.read(selectedGroupProvider(userId))?.group.id;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '我的群组',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...groups.map(
                    (item) => ListTile(
                      leading: _GroupAvatar(name: item.group.name, small: true),
                      title: Text(item.group.name),
                      subtitle: Text(_roleLabel(item.membership.role)),
                      trailing:
                          item.group.id == selectedId
                              ? const Icon(Icons.check_rounded)
                              : null,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await ref
                            .read(groupActionControllerProvider.notifier)
                            .selectGroup(
                              userId: userId,
                              groupId: item.group.id,
                            );
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline_rounded),
                    title: const Text('创建群组'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      showDialog<void>(
                        context: context,
                        builder: (_) => _CreateGroupDialog(userId: userId),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: const Text('通过邀请码加入'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      showDialog<void>(
                        context: context,
                        builder: (_) => _JoinGroupDialog(userId: userId),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _showGroupSettings(
    BuildContext context,
    WidgetRef ref,
    String userId,
    UserGroup selected,
  ) async {
    final isOwner = selected.membership.role == GroupRole.owner;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '当前群组',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selected.group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (isOwner)
                    ListTile(
                      leading: const Icon(Icons.edit_note_rounded),
                      title: const _OneLineText('重命名群组'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showDialog<void>(
                          context: context,
                          builder:
                              (_) => _RenameGroupDialog(
                                userId: userId,
                                group: selected.group,
                              ),
                        );
                      },
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.drive_file_rename_outline),
                      title: const _OneLineText('设置群组备注'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showDialog<void>(
                          context: context,
                          builder:
                              (_) => _GroupDisplayNameDialog(
                                userId: userId,
                                group: selected.group,
                                currentName: selected.group.name,
                              ),
                        );
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: const _OneLineText('分享我的历史记录'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _showHistoryShareSheet(
                        context,
                        userId: userId,
                        groupId: selected.group.id,
                        groupName: selected.group.name,
                      );
                    },
                  ),
                  if (isOwner)
                    ListTile(
                      leading: const Icon(Icons.person_remove_alt_1_outlined),
                      title: const _OneLineText('移除群组成员'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showRemoveMemberSheet(
                          context,
                          groupId: selected.group.id,
                          requesterId: userId,
                        );
                      },
                    ),
                  if (isOwner)
                    ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: _OneLineText(
                        '解散群组',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showDialog<void>(
                          context: context,
                          builder:
                              (_) => _DissolveGroupDialog(
                                userId: userId,
                                group: selected.group,
                              ),
                        );
                      },
                    )
                  else
                    ListTile(
                      leading: Icon(
                        Icons.exit_to_app_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: _OneLineText(
                        '退出群组',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showDialog<void>(
                          context: context,
                          builder:
                              (_) => _LeaveGroupDialog(
                                userId: userId,
                                groupId: selected.group.id,
                              ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }
}

class _NoGroupsView extends StatelessWidget {
  const _NoGroupsView({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: colors.primaryContainer,
                child: const Icon(Icons.diversity_3_rounded, size: 52),
              ),
              const SizedBox(height: 24),
              Text(
                '先找到想一起陪伴的人',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '可以为重要的人创建不同群组；每个群组的成员和分享彼此隔离。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 26),
              _UserIdentityCard(user: user),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder: (_) => _CreateGroupDialog(userId: user.id),
                    ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('创建第一个群组'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    () => showDialog<void>(
                      context: context,
                      builder: (_) => _JoinGroupDialog(userId: user.id),
                    ),
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('我有邀请码'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupDashboard extends ConsumerWidget {
  const _GroupDashboard({required this.user, required this.selected});

  final AppUser user;
  final UserGroup selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      selectedGroupMembersProvider((
        groupId: selected.group.id,
        viewerId: user.id,
      )),
    );
    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _RetryPanel(
            onRetry:
                () => ref.invalidate(
                  selectedGroupMembersProvider((
                    groupId: selected.group.id,
                    viewerId: user.id,
                  )),
                ),
          ),
      data: (data) => _DashboardContent(user: user, snapshot: data),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.user, required this.snapshot});

  final AppUser user;
  final GroupSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = user.id;
    final myRecords = ref.watch(
      userHealthRecordsProvider((
        userId: userId,
        range: HealthRange.thirtyDays,
      )),
    );
    final sharedRecords = ref.watch(
      groupSharedRecordsProvider((
        groupId: snapshot.group.id,
        range: HealthRange.thirtyDays,
      )),
    );
    final careEvents = ref.watch(
      careEventsProvider((groupId: snapshot.group.id, viewerId: userId)),
    );
    final showReadStatus = ref
        .watch(notificationPreferencesProvider(userId))
        .maybeWhen(data: (value) => value.showReadStatus, orElse: () => true);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      children: [
        _GroupIntro(
          group: snapshot.group,
          memberCount: snapshot.members.length,
        ),
        const SizedBox(height: 10),
        _InviteCodeCard(
          selected: UserGroup(
            group: snapshot.group,
            membership: snapshot.members.firstWhere(
              (member) => member.userId == userId,
            ),
          ),
          userId: userId,
        ),
        const SizedBox(height: 10),
        _UserIdentityCard(user: user),
        const SizedBox(height: 22),
        Text(
          '我的健康记录',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        myRecords.when(
          loading: () => const LinearProgressIndicator(),
          error:
              (error, stackTrace) =>
                  const Card(child: ListTile(title: Text('暂时没有读取到我的记录'))),
          data:
              (records) => _MyHealthCard(
                latest: records.firstOrNull,
                onRecord:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => HealthRecordEntryPage(userId: userId),
                      ),
                    ),
                onTrend:
                    records.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => HealthDetailPage(
                                  userId: userId,
                                  displayName: '我',
                                  isSelf: true,
                                  groupId: snapshot.group.id,
                                ),
                          ),
                        ),
              ),
        ),
        const SizedBox(height: 12),
        _ExampleModuleCard(
          onOpen:
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const HealthExampleTrendPage(),
                ),
              ),
        ),
        const SizedBox(height: 22),
        Text(
          '群组近况',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '这里只显示成员主动分享给“${snapshot.group.name}”的记录。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        sharedRecords.when(
          loading: () => const LinearProgressIndicator(),
          error:
              (error, stackTrace) =>
                  const Card(child: ListTile(title: Text('暂时没有读取到群组近况'))),
          data: (records) {
            final latestByUser = <String, HealthRecord>{};
            for (final record in records) {
              latestByUser.putIfAbsent(record.ownerUserId, () => record);
            }
            final otherMembers =
                snapshot.members
                    .where((member) => member.userId != userId)
                    .toList();
            final visibleMembers = otherMembers.take(3).toList();
            if (otherMembers.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('邀请伙伴加入后，就可以在这里看到彼此主动分享的近况。'),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...visibleMembers.map(
                  (member) => _SharedUpdateCard(
                    name: snapshot.displayNameFor(member, userId),
                    record: latestByUser[member.userId],
                    onTrend:
                        latestByUser[member.userId] == null
                            ? null
                            : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => HealthDetailPage(
                                      userId: member.userId,
                                      displayName: snapshot.displayNameFor(
                                        member,
                                        userId,
                                      ),
                                      isSelf: false,
                                      groupId: snapshot.group.id,
                                    ),
                              ),
                            ),
                    onCare:
                        () => showCareComposer(
                          context: context,
                          groupId: snapshot.group.id,
                          fromUserId: userId,
                          toUserId: member.userId,
                          recipientName: snapshot.displayNameFor(
                            member,
                            userId,
                          ),
                          recordId: latestByUser[member.userId]?.id,
                        ),
                  ),
                ),
                if (otherMembers.length > visibleMembers.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '已显示 3 位成员近况，其余成员可在下方“群组成员”中查看。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          '最近的关心',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        careEvents.when(
          loading: () => const LinearProgressIndicator(),
          error:
              (error, stackTrace) =>
                  const Card(child: ListTile(title: Text('暂时没有读取到关心消息'))),
          data: (events) {
            if (events.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('这里还没有消息。想起谁时，送去一句问候就好。'),
                ),
              );
            }
            final visibleEvents = events.take(5).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...visibleEvents.map((event) {
                  final from =
                      snapshot.members
                          .where((member) => member.userId == event.fromUserId)
                          .firstOrNull;
                  final name =
                      from == null
                          ? '群组伙伴'
                          : snapshot.displayNameFor(from, userId);
                  return _CareEventCard(
                    event: event,
                    senderName: name,
                    isIncoming: event.toUserId == userId,
                    showReadStatus: showReadStatus,
                    onReply:
                        event.toUserId != userId
                            ? null
                            : () async {
                              await ref
                                  .read(careRepositoryProvider)
                                  .markRead(careId: event.id, viewerId: userId);
                              if (context.mounted) {
                                await showCareResponse(
                                  context: context,
                                  event: event,
                                );
                              }
                            },
                  );
                }),
                if (events.length > visibleEvents.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '已显示最近 5 条关心消息。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          '群组成员',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...snapshot.members.map(
          (member) => _MemberCard(
            member: member,
            name: snapshot.displayNameFor(member, userId),
            isSelf: member.userId == userId,
            onOpen:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => HealthDetailPage(
                          userId: member.userId,
                          displayName: snapshot.displayNameFor(member, userId),
                          isSelf: member.userId == userId,
                          groupId: snapshot.group.id,
                        ),
                  ),
                ),
            onEditAlias:
                member.userId == userId
                    ? null
                    : () => showDialog<void>(
                      context: context,
                      builder:
                          (_) => _AliasDialog(
                            groupId: snapshot.group.id,
                            fromUserId: userId,
                            toUserId: member.userId,
                            currentName: snapshot.displayNameFor(
                              member,
                              userId,
                            ),
                          ),
                    ),
            onCare:
                member.userId == userId
                    ? null
                    : () => showCareComposer(
                      context: context,
                      groupId: snapshot.group.id,
                      fromUserId: userId,
                      toUserId: member.userId,
                      recipientName: snapshot.displayNameFor(member, userId),
                    ),
          ),
        ),
      ],
    );
  }
}

class _ExampleModuleCard extends StatelessWidget {
  const _ExampleModuleCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.auto_graph_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: const Text(
          '示例模块',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('查看 90 个记录日的模拟数据，预览长期使用后的趋势效果。'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _UserIdentityCard extends StatelessWidget {
  const _UserIdentityCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: const Icon(Icons.manage_accounts_rounded),
        ),
        title: const Text(
          '账号与找回',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          _displayPhoneNumber(user.phoneNumber) == null
              ? '换手机时使用，点开查看或复制'
              : '手机号：${_displayPhoneNumber(user.phoneNumber)}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showUserIdentitySheet(context, user),
      ),
    );
  }
}

void _showUserIdentitySheet(BuildContext context, AppUser user) {
  final recoveryCode = user.recoveryCode;
  final displayPhone = _displayPhoneNumber(user.phoneNumber);
  final copyLines = <String>[
    if (displayPhone != null) '找回手机号：$displayPhone',
    '用户ID：${user.id}',
    if (recoveryCode != null && recoveryCode.isNotEmpty) '恢复码：$recoveryCode',
  ];
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '账号与找回',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text('手机号用于换手机找回数据；用户ID是系统内部稳定编号，一般不用记，但保留它能作为兜底。'),
                const SizedBox(height: 16),
                if (displayPhone != null)
                  _IdentityRow(label: '找回手机号', value: displayPhone),
                _IdentityRow(label: '用户ID', value: user.id),
                if (recoveryCode != null && recoveryCode.isNotEmpty)
                  _IdentityRow(label: '恢复码', value: recoveryCode),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: copyLines.join('\n')),
                    );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('账号找回信息已复制')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制找回信息'),
                ),
              ],
            ),
          ),
        ),
  );
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

String? _displayPhoneNumber(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final compact = value.replaceAll(RegExp(r'[\s()-]'), '');
  if (compact.startsWith('+86') && compact.length == 14) {
    return compact.substring(3);
  }
  if (compact.startsWith('86') && compact.length == 13) {
    return compact.substring(2);
  }
  return compact;
}

class _MyHealthCard extends StatelessWidget {
  const _MyHealthCard({
    required this.latest,
    required this.onRecord,
    required this.onTrend,
  });

  final HealthRecord? latest;
  final VoidCallback onRecord;
  final VoidCallback? onTrend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              latest == null
                  ? '最近还没有新的记录。下次测量时，再顺手记下来就好。'
                  : '${_shortDateTime(latest!.measuredAt)} · ${_metricsText(latest!)}',
            ),
            if (latest != null) ...[
              const SizedBox(height: 6),
              Text(
                latest!.sharedGroupIds.isEmpty
                    ? '仅自己可见'
                    : '已分享给 ${latest!.sharedGroupIds.length} 个群组',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 330;
                final buttons = <Widget>[
                  if (onTrend != null)
                    OutlinedButton(
                      onPressed: onTrend,
                      child: const Text(
                        '查看趋势',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: onRecord,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      latest == null ? '记录一下' : '再记一条',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ];
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < buttons.length; index++) ...[
                        if (index > 0) const SizedBox(height: 8),
                        buttons[index],
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    for (var index = 0; index < buttons.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      Expanded(child: buttons[index]),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCodeCard extends ConsumerWidget {
  const _InviteCodeCard({required this.selected, required this.userId});

  final UserGroup selected;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = selected.membership.canManageMembers;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.key_rounded)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '群组邀请码',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    selected.group.inviteCode,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    selected.group.inviteCodeExpiresAt == null
                        ? '复制给重要的人，他们可以用它加入这个群组。'
                        : '这个邀请码设置了有效期。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '复制邀请码',
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: selected.group.inviteCode),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('邀请码已复制')));
                }
              },
              icon: const Icon(Icons.copy_rounded),
            ),
            if (canManage)
              IconButton(
                tooltip: '换一个邀请码',
                onPressed: () async {
                  final code = await ref
                      .read(groupRepositoryProvider)
                      .regenerateInvite(
                        groupId: selected.group.id,
                        requesterId: userId,
                      );
                  ref.invalidate(userGroupsProvider(userId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('新邀请码是 $code，旧邀请码已作废')),
                    );
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _SharedUpdateCard extends StatelessWidget {
  const _SharedUpdateCard({
    required this.name,
    required this.record,
    required this.onTrend,
    required this.onCare,
  });

  final String name;
  final HealthRecord? record;
  final VoidCallback? onTrend;
  final VoidCallback onCare;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Text(name.characters.first)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          record == null
              ? '最近没有分享新的记录'
              : '${_shortDateTime(record!.measuredAt)} 更新了 ${_metricsText(record!)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '关心一下',
              onPressed: onCare,
              icon: const Icon(Icons.favorite_outline_rounded),
            ),
            if (onTrend != null)
              TextButton(onPressed: onTrend, child: const Text('趋势')),
          ],
        ),
      ),
    );
  }
}

class _CareEventCard extends StatelessWidget {
  const _CareEventCard({
    required this.event,
    required this.senderName,
    required this.isIncoming,
    required this.showReadStatus,
    required this.onReply,
  });

  final CareEvent event;
  final String senderName;
  final bool isIncoming;
  final bool showReadStatus;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          event.type == CareType.response
              ? Icons.chat_bubble_outline_rounded
              : Icons.favorite_outline_rounded,
        ),
        title: Text(
          isIncoming ? '$senderName：${event.message}' : '我：${event.message}',
        ),
        subtitle: Text(
          '${_shortDateTime(event.createdAt)}${event.isRead ? ' · 已读' : ''}',
        ),
        trailing:
            onReply == null
                ? null
                : TextButton(onPressed: onReply, child: const Text('回应')),
      ),
    );
  }
}

String _metricsText(HealthRecord record) {
  final values = <String>[];
  if (record.hasBloodPressure) {
    values.add(
      '血压 ${formatBloodPressure(systolic: record.systolic!, diastolic: record.diastolic!)}',
    );
  }
  if (record.bloodSugarFasting != null) {
    values.add('空腹血糖 ${record.bloodSugarFasting} mmol/L');
  }
  if (record.bloodSugarPostprandial != null) {
    values.add('餐后血糖 ${record.bloodSugarPostprandial} mmol/L');
  }
  if (record.hasBloodLipid) values.add('血脂');
  return values.join('、');
}

String _shortDateTime(DateTime value) =>
    '${value.month}月${value.day}日 '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

class _GroupIntro extends StatelessWidget {
  const _GroupIntro({required this.group, required this.memberCount});

  final Group group;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _GroupAvatar(name: group.name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  group.description.isEmpty
                      ? '$memberCount 位成员，在这里温柔地互相关心'
                      : group.description,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.name,
    required this.isSelf,
    required this.onOpen,
    required this.onEditAlias,
    required this.onCare,
  });

  final GroupMembership member;
  final String name;
  final bool isSelf;
  final VoidCallback onOpen;
  final VoidCallback? onEditAlias;
  final VoidCallback? onCare;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(isSelf ? '我' : name.characters.first),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(_roleLabel(member.role)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onCare != null)
              IconButton(
                tooltip: '关心一下',
                onPressed: onCare,
                icon: const Icon(Icons.favorite_outline_rounded),
              ),
            if (onEditAlias != null)
              IconButton(
                tooltip: '设置我看到的称呼',
                onPressed: onEditAlias,
                icon: const Icon(Icons.edit_outlined),
              ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _CreateGroupDialog extends ConsumerStatefulWidget {
  const _CreateGroupDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<_CreateGroupDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(groupActionControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('创建群组'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: '群组名称',
              hintText: '例如：我的小窝',
            ),
          ),
          TextField(
            controller: _description,
            maxLength: 60,
            decoration: const InputDecoration(labelText: '简单介绍（可选）'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed:
              loading
                  ? null
                  : () async {
                    final created = await ref
                        .read(groupActionControllerProvider.notifier)
                        .createGroup(
                          userId: widget.userId,
                          name: _name.text,
                          description: _description.text,
                        );
                    if (created && context.mounted) Navigator.of(context).pop();
                  },
          child: const Text('创建'),
        ),
      ],
    );
  }
}

class _RenameGroupDialog extends ConsumerStatefulWidget {
  const _RenameGroupDialog({required this.userId, required this.group});

  final String userId;
  final Group group;

  @override
  ConsumerState<_RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends ConsumerState<_RenameGroupDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.group.name,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(groupActionControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('重命名群组'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        decoration: const InputDecoration(labelText: '群组名称'),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const _OneLineText('取消'),
        ),
        FilledButton(
          onPressed:
              loading
                  ? null
                  : () async {
                    final saved = await ref
                        .read(groupActionControllerProvider.notifier)
                        .renameGroup(
                          groupId: widget.group.id,
                          requesterId: widget.userId,
                          name: _controller.text,
                        );
                    if (saved && context.mounted) Navigator.of(context).pop();
                  },
          child: const _OneLineText('保存'),
        ),
      ],
    );
  }
}

class _GroupDisplayNameDialog extends ConsumerStatefulWidget {
  const _GroupDisplayNameDialog({
    required this.userId,
    required this.group,
    required this.currentName,
  });

  final String userId;
  final Group group;
  final String currentName;

  @override
  ConsumerState<_GroupDisplayNameDialog> createState() =>
      _GroupDisplayNameDialogState();
}

class _GroupDisplayNameDialogState
    extends ConsumerState<_GroupDisplayNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(groupActionControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('设置群组备注'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('这个名称只影响你自己看到的显示，不会影响其他成员。'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(labelText: '显示名'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const _OneLineText('取消'),
        ),
        FilledButton(
          onPressed:
              loading
                  ? null
                  : () async {
                    final saved = await ref
                        .read(groupActionControllerProvider.notifier)
                        .setGroupDisplayName(
                          groupId: widget.group.id,
                          userId: widget.userId,
                          displayName: _controller.text,
                        );
                    if (saved && context.mounted) Navigator.of(context).pop();
                  },
          child: const _OneLineText('保存'),
        ),
      ],
    );
  }
}

class _LeaveGroupDialog extends ConsumerWidget {
  const _LeaveGroupDialog({required this.userId, required this.groupId});

  final String userId;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(groupActionControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('退出这个群组？'),
      content: const Text(
        '退出后，你将看不到这个群组里的近况和关心消息。\n'
        '你的健康记录不会被删除。',
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const _OneLineText('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed:
              loading
                  ? null
                  : () async {
                    final left = await ref
                        .read(groupActionControllerProvider.notifier)
                        .leaveGroup(userId: userId, groupId: groupId);
                    if (left && context.mounted) Navigator.of(context).pop();
                  },
          child: const _OneLineText('退出群组'),
        ),
      ],
    );
  }
}

class _DissolveGroupDialog extends ConsumerStatefulWidget {
  const _DissolveGroupDialog({required this.userId, required this.group});

  final String userId;
  final Group group;

  @override
  ConsumerState<_DissolveGroupDialog> createState() =>
      _DissolveGroupDialogState();
}

class _DissolveGroupDialogState extends ConsumerState<_DissolveGroupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(groupActionControllerProvider).isLoading;
    final confirmed = _controller.text.trim() == widget.group.name;
    return AlertDialog(
      title: const Text('解散这个群组？'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '解散后，所有成员都将不能再进入这个群组。\n'
            '成员自己的健康记录不会被删除。',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: '请输入群组名称以确认'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const _OneLineText('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed:
              loading || !confirmed
                  ? null
                  : () async {
                    final dissolved = await ref
                        .read(groupActionControllerProvider.notifier)
                        .dissolveGroup(
                          groupId: widget.group.id,
                          requesterId: widget.userId,
                        );
                    if (dissolved && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
          child: const _OneLineText('确认解散'),
        ),
      ],
    );
  }
}

class _HistoryShareSheet extends ConsumerStatefulWidget {
  const _HistoryShareSheet({
    required this.userId,
    required this.groupId,
    required this.groupName,
  });

  final String userId;
  final String groupId;
  final String groupName;

  @override
  ConsumerState<_HistoryShareSheet> createState() => _HistoryShareSheetState();
}

class _HistoryShareSheetState extends ConsumerState<_HistoryShareSheet> {
  HistoryShareRange _range = HistoryShareRange.sevenDays;
  DateTimeRange? _customRange;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(
      userHealthRecordsProvider((
        userId: widget.userId,
        range: HealthRange.all,
      )),
    );
    final records = recordsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <HealthRecord>[],
    );
    final effectiveDays =
        _customRange == null ? 0 : _effectiveDayCount(records, _customRange!);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '分享已有记录到“${widget.groupName}”',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _ShareRangeTile(
              value: HistoryShareRange.sevenDays,
              groupValue: _range,
              label: '最近 7 天',
              onChanged: _setRange,
            ),
            _ShareRangeTile(
              value: HistoryShareRange.thirtyDays,
              groupValue: _range,
              label: '最近 30 天',
              onChanged: _setRange,
            ),
            _ShareRangeTile(
              value: HistoryShareRange.ninetyEffectiveDays,
              groupValue: _range,
              label: '最近 90 个有效天数',
              onChanged: _setRange,
            ),
            _ShareRangeTile(
              value: HistoryShareRange.custom,
              groupValue: _range,
              onChanged: _setRange,
              title: const _OneLineText('自定义日期范围'),
              subtitle:
                  _customRange == null
                      ? const Text('选择开始和结束日期')
                      : _DateRangeSummary(
                        range: _customRange!,
                        effectiveDays: effectiveDays,
                      ),
              trailing: IconButton(
                tooltip: '选择日期范围',
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range_rounded),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '只会分享你自己的健康记录。\n'
              '这不会删除原始记录，也不会影响其他群组的分享设置。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 330;
                final cancel = OutlinedButton(
                  onPressed:
                      _sharing ? null : () => Navigator.of(context).pop(),
                  child: const _OneLineText('取消'),
                );
                final confirm = FilledButton(
                  onPressed:
                      _sharing ||
                              (_range == HistoryShareRange.custom &&
                                  _customRange == null)
                          ? null
                          : _share,
                  child:
                      _sharing
                          ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const _OneLineText('确认分享'),
                );
                if (stack) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [cancel, const SizedBox(height: 8), confirm],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: cancel),
                    const SizedBox(width: 10),
                    Expanded(child: confirm),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setRange(HistoryShareRange? value) {
    if (value == null) return;
    setState(() => _range = value);
    if (value == HistoryShareRange.custom && _customRange == null) {
      _pickDateRange();
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null && mounted) {
      setState(() {
        _range = HistoryShareRange.custom;
        _customRange = picked;
      });
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final result = await ref
          .read(healthRepositoryProvider)
          .shareHistoryRecords(
            ownerUserId: widget.userId,
            groupId: widget.groupId,
            range: _range,
            start: _customRange?.start,
            end: _customRange?.end,
          );
      ref.invalidate(
        groupSharedRecordsProvider((
          groupId: widget.groupId,
          range: HealthRange.thirtyDays,
        )),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_shareResultMessage(result, widget.groupName))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂时没有分享成功\n请检查网络后重试。')));
    }
  }
}

class _ShareRangeTile extends StatelessWidget {
  const _ShareRangeTile({
    required this.value,
    required this.groupValue,
    String? label,
    Widget? title,
    this.subtitle,
    this.trailing,
    required this.onChanged,
  }) : title = title ?? const SizedBox.shrink(),
       label = label ?? '';

  final HistoryShareRange value;
  final HistoryShareRange groupValue;
  final String label;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final ValueChanged<HistoryShareRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ListTile(
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: label.isEmpty ? title : _OneLineText(label),
      subtitle: subtitle,
      trailing: trailing,
      onTap: () => onChanged(value),
    );
  }
}

class _DateRangeSummary extends StatelessWidget {
  const _DateRangeSummary({required this.range, required this.effectiveDays});

  final DateTimeRange range;
  final int effectiveDays;

  @override
  Widget build(BuildContext context) {
    final dateText = '${_monthDay(range.start)} – ${_monthDay(range.end)}';
    final daysText = '$effectiveDays 个有效天数';
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 260) {
          return Text(
            '$dateText（$daysText）',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            Text(
              daysText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        );
      },
    );
  }
}

class _JoinGroupDialog extends ConsumerStatefulWidget {
  const _JoinGroupDialog({required this.userId});

  final String userId;

  @override
  ConsumerState<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends ConsumerState<_JoinGroupDialog> {
  final _code = TextEditingController();
  GroupInvitePreview? _preview;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(groupActionControllerProvider);
    return AlertDialog(
      title: const Text('通过邀请码加入'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            enabled: !state.isLoading && _preview == null,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: '邀请码',
              hintText: '例如 FAMILY1',
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_preview != null) ...[
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: _GroupAvatar(name: _preview!.name, small: true),
                title: Text(_preview!.name),
                subtitle: Text(
                  _preview!.description.isEmpty
                      ? '确认后加入这个群组'
                      : _preview!.description,
                ),
              ),
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (_preview == null)
          FilledButton(
            onPressed:
                state.isLoading || _code.text.trim().isEmpty
                    ? null
                    : () async {
                      final preview = await ref
                          .read(groupActionControllerProvider.notifier)
                          .previewInvite(_code.text);
                      if (mounted) setState(() => _preview = preview);
                    },
            child: const Text('检查邀请码'),
          )
        else
          FilledButton(
            onPressed:
                state.isLoading
                    ? null
                    : () async {
                      final preview = _preview!;
                      final promptContext = Navigator.of(context).context;
                      final joined = await ref
                          .read(groupActionControllerProvider.notifier)
                          .joinGroup(
                            userId: widget.userId,
                            inviteCode: _code.text,
                          );
                      if (joined && context.mounted) {
                        Navigator.of(context).pop();
                        await _showPostJoinHistoryPrompt(
                          promptContext,
                          widget.userId,
                          preview,
                        );
                      }
                    },
            child: const Text('确认加入'),
          ),
      ],
    );
  }
}

class _AliasDialog extends ConsumerStatefulWidget {
  const _AliasDialog({
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.currentName,
  });

  final String groupId;
  final String fromUserId;
  final String toUserId;
  final String currentName;

  @override
  ConsumerState<_AliasDialog> createState() => _AliasDialogState();
}

class _AliasDialogState extends ConsumerState<_AliasDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.currentName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('我怎么称呼 TA？'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 12,
        decoration: const InputDecoration(labelText: '群内称呼'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            final saved = await ref
                .read(groupActionControllerProvider.notifier)
                .setAlias(
                  groupId: widget.groupId,
                  fromUserId: widget.fromUserId,
                  toUserId: widget.toUserId,
                  nickname: _controller.text,
                );
            if (saved && context.mounted) Navigator.of(context).pop();
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.name, this.small = false});

  final String name;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: small ? 18 : 28,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      child: Text(
        name.characters.first,
        style: TextStyle(
          fontSize: small ? 14 : 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('重新读取群组'),
      ),
    );
  }
}

class _OneLineText extends StatelessWidget {
  const _OneLineText(this.data, {this.style});

  final String data;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

Future<void> _showHistoryShareSheet(
  BuildContext context, {
  required String userId,
  required String groupId,
  required String groupName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (_) => _HistoryShareSheet(
          userId: userId,
          groupId: groupId,
          groupName: groupName,
        ),
  );
}

Future<void> _showPostJoinHistoryPrompt(
  BuildContext context,
  String userId,
  GroupInvitePreview preview,
) async {
  await showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text(
            '已加入“${preview.name}”',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: const Text(
            '要把之前的健康记录也分享给这个群组吗？\n'
            '你可以只分享最近一段时间，也可以稍后再设置。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const _OneLineText('暂不分享'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showHistoryShareSheet(
                  context,
                  userId: userId,
                  groupId: preview.groupId,
                  groupName: preview.name,
                );
              },
              child: const _OneLineText('选择分享范围'),
            ),
          ],
        ),
  );
}

Future<void> _showRemoveMemberSheet(
  BuildContext context, {
  required String groupId,
  required String requesterId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder:
        (_) => _RemoveMemberSheet(groupId: groupId, requesterId: requesterId),
  );
}

class _RemoveMemberSheet extends ConsumerWidget {
  const _RemoveMemberSheet({required this.groupId, required this.requesterId});

  final String groupId;
  final String requesterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      selectedGroupMembersProvider((groupId: groupId, viewerId: requesterId)),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '移除群组成员',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text('移除后，对方将看不到这个群组里的近况和关心消息。对方自己的健康记录不会被删除。'),
            const SizedBox(height: 12),
            snapshot.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('暂时没有读取到成员列表'),
              data: (data) {
                final removable =
                    data.members
                        .where(
                          (member) =>
                              member.userId != requesterId &&
                              member.role != GroupRole.owner,
                        )
                        .toList();
                if (removable.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('当前没有可移除的普通成员。'),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView(
                    shrinkWrap: true,
                    children:
                        removable
                            .map(
                              (member) => ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    data
                                        .displayNameFor(member, requesterId)
                                        .characters
                                        .first,
                                  ),
                                ),
                                title: Text(
                                  data.displayNameFor(member, requesterId),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                                trailing: TextButton(
                                  onPressed:
                                      () => _confirmRemoveMember(
                                        context,
                                        ref,
                                        groupId: groupId,
                                        requesterId: requesterId,
                                        memberUserId: member.userId,
                                        memberName: data.displayNameFor(
                                          member,
                                          requesterId,
                                        ),
                                      ),
                                  child: const _OneLineText('移除'),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref, {
    required String groupId,
    required String requesterId,
    required String memberUserId,
    required String memberName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              '移除 $memberName？',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            content: const Text(
              '移除后，对方将不能再进入这个群组。\n'
              '对方自己的健康记录不会被删除。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const _OneLineText('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const _OneLineText('确认移除'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    final removed = await ref
        .read(groupActionControllerProvider.notifier)
        .removeMember(
          groupId: groupId,
          requesterId: requesterId,
          memberUserId: memberUserId,
        );
    if (removed) {
      ref.invalidate(
        selectedGroupMembersProvider((groupId: groupId, viewerId: requesterId)),
      );
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

String _shareResultMessage(HistoryShareResult result, String groupName) {
  if (result.shared == 0 && result.alreadyShared == 0) {
    return '没有找到可分享的历史记录\n之后记录新数据时，可以选择分享给这个群组。';
  }
  if (result.shared == 0) {
    return '这些记录之前已经分享过，无需重复处理。';
  }
  if (result.alreadyShared > 0) {
    return '已分享 ${result.shared} 条记录\n'
        '有 ${result.alreadyShared} 条记录之前已经分享过，无需重复处理。';
  }
  return '已分享 ${result.shared} 条记录到“$groupName”';
}

int _effectiveDayCount(List<HealthRecord> records, DateTimeRange range) {
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final endExclusive = DateTime(
    range.end.year,
    range.end.month,
    range.end.day,
  ).add(const Duration(days: 1));
  return records
      .where(
        (record) =>
            !record.measuredAt.isBefore(start) &&
            record.measuredAt.isBefore(endExclusive),
      )
      .map((record) => _dateKey(record.measuredAt))
      .toSet()
      .length;
}

String _dateKey(DateTime value) => '${value.year}-${value.month}-${value.day}';

String _monthDay(DateTime value) => '${value.month}月${value.day}日';

String _roleLabel(GroupRole role) => switch (role) {
  GroupRole.owner => '群主',
  GroupRole.admin => '管理员',
  GroupRole.member => '成员',
};
