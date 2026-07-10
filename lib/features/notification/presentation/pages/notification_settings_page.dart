import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../group/domain/group_models.dart';
import '../../domain/notification_models.dart';
import '../providers/notification_providers.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({
    required this.userId,
    required this.groups,
    super.key,
  });

  final String userId;
  final List<UserGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider(userId));
    return Scaffold(
      appBar: AppBar(title: const Text('通知与隐私')),
      body: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(child: Text('暂时没有读取到设置')),
        data:
            (value) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                const _PrivacyCard(),
                const SizedBox(height: 18),
                Text(
                  '通知偏好',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                SwitchListTile(
                  value: value.careNotificationsEnabled,
                  title: const Text('关心与回复'),
                  subtitle: const Text('有人送来关心或回复时，手机系统通知我'),
                  onChanged:
                      (enabled) => _save(
                        ref,
                        value.copyWith(careNotificationsEnabled: enabled),
                      ),
                ),
                SwitchListTile(
                  value: value.healthNotificationsEnabled,
                  title: const Text('群组健康记录更新'),
                  subtitle: const Text('成员主动分享健康记录到群组时通知我'),
                  onChanged:
                      (enabled) => _save(
                        ref,
                        value.copyWith(healthNotificationsEnabled: enabled),
                      ),
                ),
                SwitchListTile(
                  value: value.measurementRemindersEnabled,
                  title: const Text('我设置的测量提醒'),
                  subtitle: const Text('关闭后不会催促记录'),
                  onChanged:
                      (enabled) => _save(
                        ref,
                        value.copyWith(measurementRemindersEnabled: enabled),
                      ),
                ),
                SwitchListTile(
                  value: value.showReadStatus,
                  title: const Text('显示已读状态'),
                  subtitle: const Text('开启后，对方能看到你是否读过关心消息'),
                  onChanged:
                      (enabled) =>
                          _save(ref, value.copyWith(showReadStatus: enabled)),
                ),
                const Divider(),
                SwitchListTile(
                  value: value.quietHoursEnabled,
                  title: const Text('夜间免打扰'),
                  subtitle: Text(
                    '${value.quietHoursStart}–${value.quietHoursEnd}',
                  ),
                  onChanged:
                      (enabled) => _save(
                        ref,
                        value.copyWith(quietHoursEnabled: enabled),
                      ),
                ),
                if (value.quietHoursEnabled)
                  ListTile(
                    leading: const Icon(Icons.bedtime_outlined),
                    title: const Text('调整免打扰时段'),
                    subtitle: Text(
                      '${value.quietHoursStart}–${value.quietHoursEnd}',
                    ),
                    onTap: () => _pickQuietHours(context, ref, value),
                  ),
                const SizedBox(height: 18),
                Text(
                  '群组静音',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text('静音只影响通知，不会退出群组或改变健康分享。'),
                const SizedBox(height: 8),
                if (groups.isEmpty)
                  const Text('加入群组后，可以在这里分别设置静音。')
                else
                  ...groups.map(
                    (item) => SwitchListTile(
                      value: value.mutedGroupIds.contains(item.group.id),
                      title: Text(item.group.name),
                      onChanged: (muted) {
                        final ids = {...value.mutedGroupIds};
                        muted
                            ? ids.add(item.group.id)
                            : ids.remove(item.group.id);
                        _save(ref, value.copyWith(mutedGroupIds: ids));
                      },
                    ),
                  ),
              ],
            ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref, NotificationPreferences preferences) async {
    await ref
        .read(notificationPreferencesRepositoryProvider)
        .savePreferences(preferences);
  }

  Future<void> _pickQuietHours(
    BuildContext context,
    WidgetRef ref,
    NotificationPreferences preferences,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: _parseTime(preferences.quietHoursStart),
      helpText: '免打扰开始时间',
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: _parseTime(preferences.quietHoursEnd),
      helpText: '免打扰结束时间',
    );
    if (end == null) return;
    await _save(
      ref,
      preferences.copyWith(
        quietHoursStart: _formatTime(start),
        quietHoursEnd: _formatTime(end),
      ),
    );
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 22,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined),
              SizedBox(width: 8),
              Text('你的记录由你决定', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(height: 8),
          Text('健康记录属于创建者。群主不能修改成员记录，未主动分享的数据不会出现在群组近况中。'),
          SizedBox(height: 6),
          Text('普通查看不会生成“谁看过我”的通知，也没有关心排行榜或连续打卡。'),
        ],
      ),
    );
  }
}
