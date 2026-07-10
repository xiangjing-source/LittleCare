import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_copy.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../health/presentation/widgets/health_member_summary.dart';
import '../../domain/family_models.dart';
import '../providers/family_providers.dart';
import '../state/family_action_state.dart';

class FamilyPage extends ConsumerWidget {
  const FamilyPage({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<FamilyActionState>(familyActionControllerProvider, (
      before,
      next,
    ) {
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

    final familyId = ref.watch(currentFamilyIdProvider(user.id));
    final actionState = ref.watch(familyActionControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppCopy.appTitle),
        actions: [
          IconButton(
            tooltip: '群组使用说明',
            onPressed:
                () => showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => const _FamilyGuideSheet(),
                ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: '退出登录',
            onPressed:
                actionState.isLoading
                    ? null
                    : () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: familyId.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stackTrace) => _RetryPanel(
              message: '暂时没能读取群组信息',
              onRetry: () => ref.invalidate(currentFamilyIdProvider(user.id)),
            ),
        data:
            (id) =>
                id == null
                    ? _NoFamilyView(
                      userId: user.id,
                      isLoading: actionState.isLoading,
                    )
                    : _FamilyView(
                      familyId: id,
                      userId: user.id,
                      isLoading: actionState.isLoading,
                    ),
      ),
    );
  }
}

class _NoFamilyView extends ConsumerWidget {
  const _NoFamilyView({required this.userId, required this.isLoading});

  final String userId;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isDemo = !ref.watch(firebaseEnabledProvider);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Icon(Icons.family_restroom_rounded, size: 58),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '先和重要的人连接起来',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '第一次使用时，请选择创建新群组，或加入已有群组。',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed:
                    isLoading
                        ? null
                        : () => ref
                            .read(familyActionControllerProvider.notifier)
                            .createFamily(userId),
                icon:
                    isLoading
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.add_home_rounded),
                label: const Text('创建一个新群组'),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed:
                    isLoading
                        ? null
                        : () => showDialog<void>(
                          context: context,
                          builder:
                              (context) => _JoinFamilyDialog(
                                userId: userId,
                                showDemoCode: isDemo,
                              ),
                        ),
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('我有邀请码，加入群组'),
              ),
              const SizedBox(height: 16),
              Text(
                '每个账号目前只能加入一个群组；加入后，入口会变为群组主页。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinFamilyDialog extends ConsumerStatefulWidget {
  const _JoinFamilyDialog({required this.userId, required this.showDemoCode});

  final String userId;
  final bool showDemoCode;

  @override
  ConsumerState<_JoinFamilyDialog> createState() => _JoinFamilyDialogState();
}

class _JoinFamilyDialogState extends ConsumerState<_JoinFamilyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final joined = await ref
        .read(familyActionControllerProvider.notifier)
        .joinFamily(userId: widget.userId, inviteCode: _controller.text);
    if (joined && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(familyActionControllerProvider).isLoading;
    return AlertDialog(
      title: const Text(AppCopy.joinGroup),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _controller,
              enabled: !loading,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: '邀请码',
                hintText: '例如 AB12CD',
                counterText: '',
              ),
              validator:
                  (value) =>
                      value == null || value.trim().isEmpty ? '请输入邀请码' : null,
              onFieldSubmitted: (_) => _join(),
            ),
            if (widget.showDemoCode) ...[
              const SizedBox(height: 10),
              const Text('演示群组邀请码：FAMILY1'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: loading ? null : _join,
          child: const Text('加入'),
        ),
      ],
    );
  }
}

class _FamilyView extends ConsumerWidget {
  const _FamilyView({
    required this.familyId,
    required this.userId,
    required this.isLoading,
  });

  final String familyId;
  final String userId;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(
      familySnapshotProvider((familyId: familyId, viewerId: userId)),
    );
    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stackTrace) => _RetryPanel(
            message: '暂时没能读取群组成员',
            onRetry:
                () => ref.invalidate(
                  familySnapshotProvider((
                    familyId: familyId,
                    viewerId: userId,
                  )),
                ),
          ),
      data:
          (family) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _InviteCard(family: family.family),
              const SizedBox(height: 20),
              Text(
                '我的群组成员',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...family.members.map(
                (member) => _MemberCard(
                  family: family,
                  member: member,
                  viewerId: userId,
                  isLoading: isLoading,
                ),
              ),
            ],
          ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.family});

  final Family family;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.home_rounded, size: 38),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(AppCopy.groupInviteCode),
                  const SizedBox(height: 3),
                  SelectableText(
                    family.inviteCode,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '这是群组的固定邀请码，复制给重要的人即可加入',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '复制邀请码',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: family.inviteCode));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('邀请码已复制')));
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.family,
    required this.member,
    required this.viewerId,
    required this.isLoading,
  });

  final FamilySnapshot family;
  final FamilyMember member;
  final String viewerId;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = family.displayNameFor(member, viewerId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            leading: CircleAvatar(child: Text(displayName.characters.first)),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(member.role == FamilyRole.owner ? '群组创建者' : '群组成员'),
            trailing:
                member.userId == viewerId
                    ? const Icon(Icons.verified_rounded)
                    : IconButton(
                      tooltip: '修改称呼',
                      onPressed:
                          isLoading
                              ? null
                              : () => showDialog<void>(
                                context: context,
                                builder:
                                    (context) => _NicknameDialog(
                                      familyId: family.family.id,
                                      fromUserId: viewerId,
                                      member: member,
                                      initialValue: displayName,
                                    ),
                              ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
          ),
          HealthMemberSummary(
            familyId: family.family.id,
            userId: member.userId,
            displayName: displayName,
            isSelf: member.userId == viewerId,
          ),
        ],
      ),
    );
  }
}

class _NicknameDialog extends ConsumerStatefulWidget {
  const _NicknameDialog({
    required this.familyId,
    required this.fromUserId,
    required this.member,
    required this.initialValue,
  });

  final String familyId;
  final String fromUserId;
  final FamilyMember member;
  final String initialValue;

  @override
  ConsumerState<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends ConsumerState<_NicknameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await ref
        .read(familyActionControllerProvider.notifier)
        .setNickname(
          familyId: widget.familyId,
          fromUserId: widget.fromUserId,
          toUserId: widget.member.userId,
          nickname: _controller.text,
        );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(familyActionControllerProvider).isLoading;
    return AlertDialog(
      title: const Text('我怎么称呼 TA？'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          enabled: !loading,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(labelText: '群组内称呼'),
          validator: (value) {
            final length = value?.trim().length ?? 0;
            return length < 1 || length > 12 ? '请输入 1–12 个字符' : null;
          },
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: loading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: loading ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _RetryPanel extends StatelessWidget {
  const _RetryPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _FamilyGuideSheet extends StatelessWidget {
  const _FamilyGuideSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '如何和重要的人连接？',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            const _GuideStep(
              number: '1',
              title: '第一位成员创建群组',
              detail: '创建后会得到一个固定的群组邀请码。',
            ),
            const _GuideStep(
              number: '2',
              title: '其他成员选择“我有邀请码”',
              detail: '这个入口只在账号尚未加入群组时出现。',
            ),
            const _GuideStep(
              number: '3',
              title: '加入后共同查看健康趋势',
              detail: '每个账号目前只能属于一个群组，因此加入后不再重复显示入口。',
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 16, child: Text(number)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
