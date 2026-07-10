import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../group/domain/group_models.dart';
import '../../../group/presentation/providers/group_providers.dart';
import '../../domain/health_models.dart';
import '../providers/health_providers.dart';
import '../state/health_record_form_controller.dart';

class HealthRecordEntryPage extends ConsumerStatefulWidget {
  const HealthRecordEntryPage({
    required this.userId,
    this.familyId,
    this.displayName = '我',
    this.record,
    super.key,
  });

  final String userId;
  final String? familyId;
  final String displayName;
  final HealthRecord? record;

  @override
  ConsumerState<HealthRecordEntryPage> createState() =>
      _HealthRecordEntryPageState();
}

class _HealthRecordEntryPageState extends ConsumerState<HealthRecordEntryPage> {
  bool _shareSelectionTouched = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      final activeGroups =
          ref.read(userGroupsProvider(widget.userId)).value ??
          const <UserGroup>[];
      ref
          .read(healthRecordFormProvider.notifier)
          .reset(
            record: widget.record,
            defaultGroupIds:
                widget.record != null
                    ? const {}
                    : widget.familyId == null
                    ? activeGroups.map((item) => item.group.id).toSet()
                    : {widget.familyId!},
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(healthRecordFormProvider);
    final controller = ref.read(healthRecordFormProvider.notifier);
    final action = ref.watch(healthActionControllerProvider);
    final groups = ref.watch(userGroupsProvider(widget.userId));
    final editing = widget.record != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? '修改健康记录' : '记录我的健康'),
        actions: [
          if (editing)
            IconButton(
              tooltip: '删除记录',
              onPressed: action.isLoading ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _WarmHeader(editing: editing),
          const SizedBox(height: 18),
          Text(
            '今天想记录什么？',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChoice(
                label: '血压',
                icon: Icons.favorite_outline_rounded,
                selected: form.selectedMetrics.contains(
                  HealthMetricKind.bloodPressure,
                ),
                onSelected:
                    (value) => controller.toggleMetric(
                      HealthMetricKind.bloodPressure,
                      value,
                    ),
              ),
              _MetricChoice(
                label: '血糖',
                icon: Icons.water_drop_outlined,
                selected: form.selectedMetrics.contains(
                  HealthMetricKind.bloodSugar,
                ),
                onSelected:
                    (value) => controller.toggleMetric(
                      HealthMetricKind.bloodSugar,
                      value,
                    ),
              ),
              _MetricChoice(
                label: '血脂',
                icon: Icons.science_outlined,
                selected: form.selectedMetrics.contains(
                  HealthMetricKind.bloodLipid,
                ),
                onSelected:
                    (value) => controller.toggleMetric(
                      HealthMetricKind.bloodLipid,
                      value,
                    ),
              ),
            ],
          ),
          if (form.selectedMetrics.isEmpty) ...[
            const SizedBox(height: 14),
            const Text('可以只选一项，也可以一次记录多项。'),
          ],
          if (form.selectedMetrics.contains(
            HealthMetricKind.bloodPressure,
          )) ...[
            const SizedBox(height: 16),
            _InputCard(
              title: '血压',
              hint: '收缩压和舒张压需要一起填写',
              children: [
                _NumberField(
                  label: '收缩压（高压）',
                  unit: 'mmHg',
                  initialValue: form.systolic?.toString(),
                  decimal: false,
                  onChanged: controller.setSystolic,
                ),
                _NumberField(
                  label: '舒张压（低压）',
                  unit: 'mmHg',
                  initialValue: form.diastolic?.toString(),
                  decimal: false,
                  onChanged: controller.setDiastolic,
                ),
              ],
            ),
          ],
          if (form.selectedMetrics.contains(HealthMetricKind.bloodSugar)) ...[
            const SizedBox(height: 16),
            _InputCard(
              title: '血糖',
              hint: '两项可以独立记录',
              children: [
                _NumberField(
                  label: '空腹',
                  unit: 'mmol/L',
                  initialValue: _decimal(form.bloodSugarFasting),
                  onChanged: controller.setFasting,
                ),
                _NumberField(
                  label: '餐后 2 小时',
                  unit: 'mmol/L',
                  initialValue: _decimal(form.bloodSugarPostprandial),
                  onChanged: controller.setPostprandial,
                ),
              ],
            ),
          ],
          if (form.selectedMetrics.contains(HealthMetricKind.bloodLipid)) ...[
            const SizedBox(height: 16),
            _InputCard(
              title: '血脂',
              hint: '只填写实际测量的项目即可',
              children: [
                _NumberField(
                  label: '总胆固醇',
                  unit: 'mmol/L',
                  initialValue: _decimal(form.totalCholesterol),
                  onChanged: controller.setTotalCholesterol,
                ),
                _NumberField(
                  label: '甘油三酯',
                  unit: 'mmol/L',
                  initialValue: _decimal(form.triglycerides),
                  onChanged: controller.setTriglycerides,
                ),
                _NumberField(
                  label: '低密度脂蛋白',
                  unit: 'mmol/L',
                  initialValue: _decimal(form.ldlC),
                  onChanged: controller.setLdl,
                ),
                _NumberField(
                  label: '高密度脂蛋白',
                  unit: 'mmol/L',
                  initialValue: _decimal(form.hdlC),
                  onChanged: controller.setHdl,
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _TimeCard(
            measuredAt: form.measuredAt,
            onChanged: controller.setMeasuredAt,
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: form.note,
            maxLength: 120,
            minLines: 2,
            maxLines: 4,
            onChanged: controller.setNote,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              hintText: '例如：早餐前测量，昨晚睡得不错',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '谁可以看到这条记录？',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            form.sharedGroupIds.isEmpty ? '未选择群组时仅自己可见' : '默认分享给已有群组',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          groups.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => const Text('暂时没有读取到群组列表'),
            data: (items) {
              final defaultShareIds =
                  items.map((item) => item.group.id).toSet();
              if (!editing &&
                  !_shareSelectionTouched &&
                  defaultShareIds.isNotEmpty &&
                  !_sameIds(form.sharedGroupIds, defaultShareIds)) {
                Future<void>.microtask(
                  () => ref
                      .read(healthRecordFormProvider.notifier)
                      .setShares(defaultShareIds),
                );
              }
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('还没有可分享的群组，这条记录会先只保存给自己。'),
                );
              }
              return Column(
                children:
                    items
                        .map(
                          (item) => CheckboxListTile(
                            value: form.sharedGroupIds.contains(item.group.id),
                            onChanged: (value) {
                              _shareSelectionTouched = true;
                              controller.toggleShare(
                                item.group.id,
                                value ?? false,
                              );
                            },
                            title: Text(item.group.name),
                            subtitle: const Text('默认分享，可按需取消'),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
              );
            },
          ),
          if (form.validationErrors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      form.validationErrors
                          .map((message) => Text('• $message'))
                          .toList(),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: FilledButton.icon(
          onPressed: action.isLoading || !form.canSubmit ? null : _save,
          icon:
              action.isLoading
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.check_rounded),
          label: Text(editing ? '保存修改' : '帮我记下来'),
        ),
      ),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final formController = ref.read(healthRecordFormProvider.notifier);
    final errors = formController.validate(widget.userId);
    if (errors.isNotEmpty) return;
    final draft = formController.draft(widget.userId);
    if (draft.hasBloodPressure && draft.systolic! <= draft.diastolic!) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('确认血压数值'),
              content: const Text('高压通常高于低压，请确认是否填写正确。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('再检查一下'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确认保存'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;
    }
    final success =
        widget.record == null
            ? await ref
                .read(healthActionControllerProvider.notifier)
                .saveRecord(draft)
            : await ref
                .read(healthActionControllerProvider.notifier)
                .updateRecord(draft);
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已经帮你记下来了')));
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除这条记录？'),
            content: const Text('删除后，已分享给群组的内容也会一起消失。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('保留'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true || widget.record == null) return;
    final success = await ref
        .read(healthActionControllerProvider.notifier)
        .deleteRecord(recordId: widget.record!.id, ownerUserId: widget.userId);
    if (success && mounted) Navigator.of(context).pop();
  }
}

bool _sameIds(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

class _WarmHeader extends StatelessWidget {
  const _WarmHeader({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(editing ? '只修改你想调整的部分就好。' : '只记录这次真正测量的项目，其他内容可以留空。'),
          ),
        ],
      ),
    );
  }
}

class _MetricChoice extends StatelessWidget {
  const _MetricChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.title,
    required this.hint,
    required this.children,
  });

  final String title;
  final String hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ...children.expand((child) => [child, const SizedBox(height: 10)]),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.unit,
    required this.onChanged,
    this.initialValue,
    this.decimal = true,
  });

  final String label;
  final String unit;
  final String? initialValue;
  final bool decimal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'^\d*\.?\d{0,2}') : RegExp(r'^\d*'),
        ),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, suffixText: unit),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.measuredAt, required this.onChanged});

  final DateTime measuredAt;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule_rounded),
        title: const Text('测量时间'),
        subtitle: Text(
          '${localizations.formatShortDate(measuredAt)} '
          '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(measuredAt))}',
        ),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: measuredAt,
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            locale: const Locale('zh', 'CN'),
            helpText: '选择测量日期',
            cancelText: '取消',
            confirmText: '确定',
            fieldLabelText: '测量日期',
            fieldHintText: '年/月/日',
          );
          if (date == null || !context.mounted) return;
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(measuredAt),
            helpText: '选择测量时间',
            cancelText: '取消',
            confirmText: '确定',
          );
          if (time == null) return;
          onChanged(
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
          );
        },
      ),
    );
  }
}

String? _decimal(double? value) => value?.toString();
