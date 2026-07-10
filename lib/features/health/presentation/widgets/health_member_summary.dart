import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/health_formatters.dart';
import '../../domain/health_models.dart';
import '../pages/health_detail_page.dart';
import '../pages/health_record_entry_page.dart';
import '../providers/health_providers.dart';
import 'health_status_style.dart';

class HealthMemberSummary extends ConsumerWidget {
  const HealthMemberSummary({
    required this.familyId,
    required this.userId,
    required this.displayName,
    required this.isSelf,
    super.key,
  });

  final String familyId;
  final String userId;
  final String displayName;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(
      healthRecordsProvider((familyId: familyId, userId: userId, days: 30)),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 14),
          records.when(
            loading:
                () => const LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
            error: (error, stackTrace) => const Text('暂时没有读到健康记录'),
            data: (items) => _LatestMetrics(record: items.firstOrNull),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (context) => HealthDetailPage(
                                familyId: familyId,
                                userId: userId,
                                displayName: displayName,
                                isSelf: isSelf,
                              ),
                        ),
                      ),
                  icon: const Icon(Icons.show_chart_rounded),
                  label: const Text('查看趋势'),
                ),
              ),
              if (isSelf) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder:
                                (context) => HealthRecordEntryPage(
                                  familyId: familyId,
                                  userId: userId,
                                  displayName: displayName,
                                ),
                          ),
                        ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('录入数据'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LatestMetrics extends StatelessWidget {
  const _LatestMetrics({required this.record});

  final HealthRecord? record;

  @override
  Widget build(BuildContext context) {
    if (record == null) {
      return Row(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('还没有健康记录，从今天开始就很好。')),
        ],
      );
    }
    final metrics = <Widget>[];
    if (record!.hasBloodPressure) {
      metrics.add(
        _MetricChip(
          label:
              '血压 ${formatBloodPressure(systolic: record!.systolic!, diastolic: record!.diastolic!)}',
          level: record!.bloodPressureLevel!,
        ),
      );
    }
    final sugar = record!.bloodSugarFasting ?? record!.bloodSugarPostprandial;
    if (sugar != null) {
      metrics.add(
        _MetricChip(
          label: '血糖 ${sugar.toStringAsFixed(1)}',
          level:
              record!.bloodSugarFasting != null
                  ? record!.fastingSugarLevel!
                  : record!.postprandialSugarLevel!,
        ),
      );
    }
    if (record!.bloodLipid != null) {
      metrics.add(
        _MetricChip(
          label: '血脂 ${record!.bloodLipid!.toStringAsFixed(1)}',
          level: record!.bloodLipidLevel!,
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: metrics);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.level});

  final String label;
  final HealthLevel level;

  @override
  Widget build(BuildContext context) {
    final color = healthLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label · ${level.label}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
