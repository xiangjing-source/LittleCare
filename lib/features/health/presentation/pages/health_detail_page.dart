import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../domain/health_formatters.dart';
import '../../domain/health_models.dart';
import '../../services/health_reference_service.dart';
import '../../services/health_status_service.dart';
import '../providers/health_providers.dart';
import '../widgets/health_status_style.dart';
import 'health_record_entry_page.dart';

class HealthDetailPage extends ConsumerStatefulWidget {
  const HealthDetailPage({
    required this.userId,
    required this.displayName,
    required this.isSelf,
    this.groupId,
    this.familyId,
    super.key,
  });

  final String userId;
  final String displayName;
  final bool isSelf;
  final String? groupId;
  final String? familyId;

  String? get effectiveGroupId => groupId ?? familyId;

  @override
  ConsumerState<HealthDetailPage> createState() => _HealthDetailPageState();
}

class _HealthDetailPageState extends ConsumerState<HealthDetailPage> {
  HealthRange _range = HealthRange.sevenDays;
  DateTime? _customStart;
  DateTime? _customEnd;

  bool get _usingCustomRange => _customStart != null && _customEnd != null;

  @override
  Widget build(BuildContext context) {
    final records =
        widget.isSelf
            ? ref.watch(
              userHealthRecordsProvider((
                userId: widget.userId,
                range: HealthRange.all,
              )),
            )
            : ref.watch(
              groupSharedRecordsProvider((
                groupId: widget.effectiveGroupId ?? '',
                range: HealthRange.all,
              )),
            );
    return Scaffold(
      appBar: AppBar(
        title: _OneLineText(
          widget.isSelf ? '我的健康' : '${widget.displayName}的分享',
        ),
      ),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(child: Text('暂时没有读取到趋势数据')),
        data: (items) {
          final visible =
              widget.isSelf
                  ? items
                  : items
                      .where((record) => record.ownerUserId == widget.userId)
                      .toList();
          final rangeRecords = _filterBySelectedRange(visible);
          final effectiveDays = _effectiveDayCount(rangeRecords);
          final rangeLabel =
              _usingCustomRange
                  ? _customRangeLabel(rangeRecords)
                  : _range.label;
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 110),
            children: [
              _StatusOverview(records: rangeRecords, rangeLabel: rangeLabel),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<HealthRange>(
                  segments:
                      HealthRange.values
                          .map(
                            (range) => ButtonSegment(
                              value: range,
                              label: Text(range.label),
                            ),
                          )
                          .toList(),
                  selected: {_range},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _range = selection.single;
                      _customStart = null;
                      _customEnd = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              _CustomRangeBar(
                start: _customStart,
                end: _customEnd,
                effectiveDays: _usingCustomRange ? effectiveDays : null,
                onPick: _pickCustomRange,
                onClear:
                    _usingCustomRange
                        ? () => setState(() {
                          _customStart = null;
                          _customEnd = null;
                        })
                        : null,
              ),
              const SizedBox(height: 8),
              Text(
                '当前范围：$rangeLabel。左右滑动图表，轻触或拖动定位日期并查看当天明细。',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              _InteractiveTrendCard(
                title: '血压趋势',
                yAxisLabel: '血压',
                unit: 'mmHg',
                records: rangeRecords,
                range: _range,
                usingCustomRange: _usingCustomRange,
                series: [
                  _ChartSeries(
                    label: '收缩压',
                    color: const Color(0xFFB75252),
                    reference: HealthReferenceService.systolic,
                    valueOf: (record) => record.systolic?.toDouble(),
                    levelOf:
                        (value) => HealthStatusService.bloodPressure(
                          value.round(),
                          70,
                        ),
                  ),
                  _ChartSeries(
                    label: '舒张压',
                    color: const Color(0xFF59669A),
                    reference: HealthReferenceService.diastolic,
                    valueOf: (record) => record.diastolic?.toDouble(),
                    levelOf:
                        (value) => HealthStatusService.bloodPressure(
                          110,
                          value.round(),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InteractiveTrendCard(
                title: '血糖趋势',
                yAxisLabel: '血糖',
                unit: 'mmol/L',
                records: rangeRecords,
                range: _range,
                usingCustomRange: _usingCustomRange,
                series: [
                  _ChartSeries(
                    label: '空腹',
                    color: const Color(0xFF3F7D65),
                    reference: HealthReferenceService.fastingSugar,
                    valueOf: (record) => record.bloodSugarFasting,
                    levelOf: HealthStatusService.fastingSugar,
                  ),
                  _ChartSeries(
                    label: '餐后 2 小时',
                    color: const Color(0xFFC87935),
                    reference: HealthReferenceService.postprandialSugar,
                    valueOf: (record) => record.bloodSugarPostprandial,
                    levelOf: HealthStatusService.postprandialSugar,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InteractiveTrendCard(
                title: '血脂趋势',
                yAxisLabel: '血脂',
                unit: 'mmol/L',
                records: rangeRecords,
                range: _range,
                usingCustomRange: _usingCustomRange,
                series: [
                  _ChartSeries(
                    label: '总胆固醇',
                    color: const Color(0xFF8B5F9E),
                    reference: HealthReferenceService.totalCholesterol,
                    valueOf: (record) => record.totalCholesterol,
                    levelOf: HealthStatusService.totalCholesterol,
                  ),
                  _ChartSeries(
                    label: '甘油三酯',
                    color: const Color(0xFFD18A45),
                    reference: HealthReferenceService.triglycerides,
                    valueOf: (record) => record.triglycerides,
                    levelOf: HealthStatusService.triglycerides,
                  ),
                  _ChartSeries(
                    label: '低密度脂蛋白',
                    color: const Color(0xFF4E78A0),
                    reference: HealthReferenceService.ldl,
                    valueOf: (record) => record.ldlC,
                    levelOf: HealthStatusService.ldl,
                  ),
                  _ChartSeries(
                    label: '高密度脂蛋白',
                    color: const Color(0xFF4D8F72),
                    reference: HealthReferenceService.hdl,
                    valueOf: (record) => record.hdlC,
                    levelOf: HealthStatusService.hdl,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '记录明细',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (rangeRecords.isEmpty)
                const _EmptyRecords()
              else if ((_range == HealthRange.sevenDays ||
                      _range == HealthRange.thirtyDays) &&
                  !_usingCustomRange)
                ...rangeRecords.map(
                  (record) => _RecordCard(
                    record: record,
                    onEdit:
                        widget.isSelf
                            ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => HealthRecordEntryPage(
                                      userId: widget.userId,
                                      record: record,
                                    ),
                              ),
                            )
                            : null,
                  ),
                )
              else
                _RecordCalendar(
                  records: rangeRecords,
                  onOpen:
                      widget.isSelf
                          ? (record) => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => HealthRecordEntryPage(
                                    userId: widget.userId,
                                    record: record,
                                  ),
                            ),
                          )
                          : null,
                ),
              const SizedBox(height: 16),
              const Text(
                '本应用用于记录和分享健康数据，不能替代专业医疗诊断。',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
      floatingActionButton:
          widget.isSelf
              ? FloatingActionButton.extended(
                onPressed:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => HealthRecordEntryPage(userId: widget.userId),
                      ),
                    ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('记录数据'),
              )
              : null,
    );
  }

  List<HealthRecord> _filterBySelectedRange(List<HealthRecord> records) {
    final start = _customStart;
    final end = _customEnd;
    if (start == null || end == null) {
      if (_range == HealthRange.all) return records;
      final days = _range.days;
      if (days == null) return records;
      final now = DateTime.now();
      final startDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: days - 1));
      return records
          .where((record) => !record.measuredAt.isBefore(startDay))
          .toList();
    }
    final startDay = DateTime(start.year, start.month, start.day);
    final endExclusive = DateTime(end.year, end.month, end.day + 1);
    return records
        .where(
          (record) =>
              !record.measuredAt.isBefore(startDay) &&
              record.measuredAt.isBefore(endExclusive),
        )
        .toList();
  }

  int _effectiveDayCount(List<HealthRecord> records) {
    return {
      for (final record in records)
        DateTime(
          record.measuredAt.year,
          record.measuredAt.month,
          record.measuredAt.day,
        ),
    }.length;
  }

  String _customRangeLabel(List<HealthRecord> records) {
    final start = _customStart;
    final end = _customEnd;
    if (start == null || end == null) return _range.label;
    return '${start.month}/${start.day} - ${end.month}/${end.day}'
        '（${_effectiveDayCount(records)} 个有效天数）';
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange:
          _usingCustomRange
              ? DateTimeRange(start: _customStart!, end: _customEnd!)
              : DateTimeRange(
                start: now.subtract(const Duration(days: 29)),
                end: now,
              ),
      helpText: '选择趋势图区间',
      cancelText: '取消',
      confirmText: '确定',
      saveText: '确定',
      fieldStartLabelText: '开始日期',
      fieldEndLabelText: '结束日期',
      errorInvalidRangeText: '结束日期不能早于开始日期',
      errorFormatText: '请输入正确日期',
      errorInvalidText: '日期不可用',
    );
    if (picked == null || !mounted) return;
    final pickedRecords = _filterByRangeDates(_allVisibleRecords(), picked);
    final effectiveDays = _effectiveDayCount(pickedRecords);
    if (effectiveDays > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自定义趋势图区间最多 90 个有效天数，请缩短范围。')),
      );
      return;
    }
    setState(() {
      _customStart = picked.start;
      _customEnd = picked.end;
      _range =
          effectiveDays <= 7
              ? HealthRange.sevenDays
              : effectiveDays <= 30
              ? HealthRange.thirtyDays
              : HealthRange.ninetyDays;
    });
  }

  List<HealthRecord> _allVisibleRecords() {
    final records =
        widget.isSelf
            ? ref.read(
              userHealthRecordsProvider((
                userId: widget.userId,
                range: HealthRange.all,
              )),
            )
            : ref.read(
              groupSharedRecordsProvider((
                groupId: widget.effectiveGroupId ?? '',
                range: HealthRange.all,
              )),
            );
    return records.maybeWhen(
      data:
          (items) =>
              widget.isSelf
                  ? items
                  : items
                      .where((record) => record.ownerUserId == widget.userId)
                      .toList(),
      orElse: () => const [],
    );
  }

  List<HealthRecord> _filterByRangeDates(
    List<HealthRecord> records,
    DateTimeRange range,
  ) {
    final startDay = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final endExclusive = DateTime(
      range.end.year,
      range.end.month,
      range.end.day + 1,
    );
    return records
        .where(
          (record) =>
              !record.measuredAt.isBefore(startDay) &&
              record.measuredAt.isBefore(endExclusive),
        )
        .toList();
  }
}

class HealthExampleTrendPage extends StatelessWidget {
  const HealthExampleTrendPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const _OneLineText('示例模块')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 110),
          children: [
            const _ExampleTrendSection(),
            const SizedBox(height: 16),
            const Text(
              '以上为演示数据，仅用于预览连续记录后的趋势效果，不会写入用户真实健康记录。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOverview extends StatelessWidget {
  const _StatusOverview({required this.records, required this.rangeLabel});

  final List<HealthRecord> records;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final record = records.firstOrNull;
    final level = record?.overallLevel;
    final summary = HealthReferenceService.summarize(records);
    final color =
        level == null
            ? Theme.of(context).colorScheme.outline
            : healthLevelColor(level);
    final title = switch (level) {
      HealthLevel.normal => '最近记录在常见范围内',
      HealthLevel.elevated => '最近几次记录有些变化',
      HealthLevel.risk => '有一项数据建议稍后复测',
      null => '这里还没有趋势数据',
    };
    final compactMessage =
        level == null
            ? summary.message(rangeLabel)
            : '${summary.message(rangeLabel)}\n若持续变化或感到不适，可以咨询专业人员。';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Icon(Icons.favorite_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            compactMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (summary.categories.any((item) => item.totalCount > 0)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children:
                  summary.categories
                      .map(
                        (item) => Chip(
                          avatar: Icon(
                            item.abnormalCount == 0
                                ? Icons.check_circle_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 16,
                          ),
                          label: Text(
                            item.ratioText,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 4),
            Text(
              '比例说明：1/3 表示 3 项里有 1 项在常见范围内。',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
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

class _ResponsiveRangeLabel extends StatelessWidget {
  const _ResponsiveRangeLabel({
    required this.rangeText,
    required this.effectiveDays,
  });

  final String rangeText;
  final int? effectiveDays;

  @override
  Widget build(BuildContext context) {
    if (effectiveDays == null) return _OneLineText(rangeText);
    final full = '$rangeText（$effectiveDays 个有效天数）';
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 360) return _OneLineText(full);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _OneLineText(rangeText),
            _OneLineText(
              '$effectiveDays 个有效天数',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _DateAxisLabel {
  const _DateAxisLabel({required this.index, required this.text});

  final int index;
  final String text;
}

List<_DateAxisLabel> _buildDateAxisLabels({
  required List<_TrendPoint> chartDays,
  required double visibleStartIndex,
  required double visibleEndIndex,
  required double chartWidth,
}) {
  if (chartDays.isEmpty) return const [];
  final start = visibleStartIndex.floor().clamp(0, chartDays.length - 1);
  final end = visibleEndIndex.ceil().clamp(0, chartDays.length - 1);
  if (start == end) {
    final date = chartDays[start].measuredAt;
    return [_DateAxisLabel(index: start, text: '${date.month}/${date.day}')];
  }
  final visibleCount = math.max(1, end - start + 1);
  final target = math.max(2, (chartWidth / 82).floor());
  final step = math.max(1, (visibleCount / target).ceil());
  final labels = <int>{start, end};
  for (var index = start; index <= end; index += step) {
    labels.add(index);
  }
  return [
    for (final index in (labels.toList()..sort()))
      _DateAxisLabel(
        index: index,
        text:
            '${chartDays[index].measuredAt.month}/${chartDays[index].measuredAt.day}',
      ),
  ];
}

class _ChartViewportController extends ChangeNotifier {
  _ChartViewportController({required this.compact});

  final bool compact;
  int _dayCount = 0;
  HealthRange? _range;
  double visibleStartIndex = 0;
  double visibleEndIndex = 0;
  int minVisibleDays = 4;
  int maxVisibleDays = 30;

  void configure({required int dayCount, required HealthRange range}) {
    if (_dayCount == dayCount && _range == range && dayCount > 0) return;
    _dayCount = dayCount;
    _range = range;
    if (dayCount <= 0) {
      visibleStartIndex = 0;
      visibleEndIndex = 0;
      return;
    }
    maxVisibleDays = dayCount;
    final preferred = switch (range) {
      HealthRange.sevenDays => dayCount,
      HealthRange.thirtyDays => math.min(dayCount, 18),
      HealthRange.ninetyDays => math.min(dayCount, 24),
      HealthRange.all => math.min(dayCount, 30),
    };
    final window = preferred.clamp(
      minVisibleDays,
      math.max(minVisibleDays, dayCount),
    );
    visibleEndIndex = (dayCount - 1).toDouble();
    visibleStartIndex = math.max(0, visibleEndIndex - window + 1);
  }

  double get visibleDays => visibleEndIndex - visibleStartIndex + 1;

  void pan(double dayDelta) {
    if (_dayCount <= 1) return;
    final window = visibleDays;
    visibleStartIndex = (visibleStartIndex + dayDelta).clamp(
      0.0,
      math.max(0.0, _dayCount - window),
    );
    visibleEndIndex = visibleStartIndex + window - 1;
    notifyListeners();
  }

  void zoom(double scale, double focalIndex) {
    if (_dayCount <= 1 || scale <= 0) return;
    final oldWindow = visibleDays;
    final newWindow = (oldWindow / scale).clamp(
      minVisibleDays.toDouble(),
      _dayCount.toDouble(),
    );
    final focalRatio =
        oldWindow <= 1 ? 0.5 : ((focalIndex - visibleStartIndex) / oldWindow);
    visibleStartIndex = (focalIndex - newWindow * focalRatio).clamp(
      0.0,
      math.max(0.0, _dayCount - newWindow),
    );
    visibleEndIndex = visibleStartIndex + newWindow - 1;
    notifyListeners();
  }

  void reset(HealthRange range) {
    _range = null;
    configure(dayCount: _dayCount, range: range);
    notifyListeners();
  }

  double indexForDx(double dx, double width) {
    const left = 48.0;
    const right = 16.0;
    final plotWidth = math.max(1.0, width - left - right);
    final fraction = ((dx - left) / plotWidth).clamp(0.0, 1.0);
    return visibleStartIndex + fraction * math.max(1.0, visibleDays - 1);
  }

  double xForIndex(int index, double width) {
    const left = 48.0;
    const right = 16.0;
    final plotWidth = math.max(1.0, width - left - right);
    final fraction =
        visibleDays <= 1
            ? 0.0
            : (index - visibleStartIndex) / (visibleDays - 1);
    return left + plotWidth * fraction;
  }

  bool isVisible(int index) =>
      index >= visibleStartIndex.floor() && index <= visibleEndIndex.ceil();
}

class _CustomRangeBar extends StatelessWidget {
  const _CustomRangeBar({
    required this.start,
    required this.end,
    required this.effectiveDays,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? start;
  final DateTime? end;
  final int? effectiveDays;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final rangeText =
        start == null || end == null
            ? '自定义区间'
            : '${start!.month}/${start!.day} - ${end!.month}/${end!.day}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder:
              (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: math.max(160, constraints.maxWidth),
                    ),
                    child: OutlinedButton.icon(
                      onPressed: onPick,
                      icon: const Icon(Icons.date_range_rounded),
                      label: _ResponsiveRangeLabel(
                        rangeText: rangeText,
                        effectiveDays: effectiveDays,
                      ),
                    ),
                  ),
                  if (onClear != null)
                    TextButton(
                      onPressed: onClear,
                      child: const _OneLineText('恢复预设'),
                    ),
                ],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '最多选择 90 个有效天数；同一天多次记录只计为 1 天。',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ExampleTrendSection extends StatelessWidget {
  const _ExampleTrendSection();

  @override
  Widget build(BuildContext context) {
    final records = _exampleRecords();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '示例模块',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '90 个记录日模拟数据，预览长期趋势。',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InteractiveTrendCard(
              title: '示例血压趋势',
              yAxisLabel: '血压',
              unit: 'mmHg',
              records: records,
              range: HealthRange.ninetyDays,
              usingCustomRange: false,
              series: [
                _ChartSeries(
                  label: '收缩压',
                  color: const Color(0xFFB75252),
                  reference: HealthReferenceService.systolic,
                  valueOf: (record) => record.systolic?.toDouble(),
                  levelOf:
                      (value) =>
                          HealthStatusService.bloodPressure(value.round(), 70),
                ),
                _ChartSeries(
                  label: '舒张压',
                  color: const Color(0xFF59669A),
                  reference: HealthReferenceService.diastolic,
                  valueOf: (record) => record.diastolic?.toDouble(),
                  levelOf:
                      (value) =>
                          HealthStatusService.bloodPressure(110, value.round()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InteractiveTrendCard(
              title: '示例血糖趋势',
              yAxisLabel: '血糖',
              unit: 'mmol/L',
              records: records,
              range: HealthRange.ninetyDays,
              usingCustomRange: false,
              series: [
                _ChartSeries(
                  label: '空腹',
                  color: const Color(0xFF3F7D65),
                  reference: HealthReferenceService.fastingSugar,
                  valueOf: (record) => record.bloodSugarFasting,
                  levelOf: HealthStatusService.fastingSugar,
                ),
                _ChartSeries(
                  label: '餐后 2 小时',
                  color: const Color(0xFFC87935),
                  reference: HealthReferenceService.postprandialSugar,
                  valueOf: (record) => record.bloodSugarPostprandial,
                  levelOf: HealthStatusService.postprandialSugar,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InteractiveTrendCard(
              title: '示例血脂趋势',
              yAxisLabel: '血脂',
              unit: 'mmol/L',
              records: records,
              range: HealthRange.ninetyDays,
              usingCustomRange: false,
              series: [
                _ChartSeries(
                  label: '总胆固醇',
                  color: const Color(0xFF8B5F9E),
                  reference: HealthReferenceService.totalCholesterol,
                  valueOf: (record) => record.totalCholesterol,
                  levelOf: HealthStatusService.totalCholesterol,
                ),
                _ChartSeries(
                  label: '甘油三酯',
                  color: const Color(0xFFD18A45),
                  reference: HealthReferenceService.triglycerides,
                  valueOf: (record) => record.triglycerides,
                  levelOf: HealthStatusService.triglycerides,
                ),
                _ChartSeries(
                  label: '低密度脂蛋白',
                  color: const Color(0xFF4E78A0),
                  reference: HealthReferenceService.ldl,
                  valueOf: (record) => record.ldlC,
                  levelOf: HealthStatusService.ldl,
                ),
                _ChartSeries(
                  label: '高密度脂蛋白',
                  color: const Color(0xFF4D8F72),
                  reference: HealthReferenceService.hdl,
                  valueOf: (record) => record.hdlC,
                  levelOf: HealthStatusService.hdl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartSeries {
  const _ChartSeries({
    required this.label,
    required this.color,
    required this.reference,
    required this.valueOf,
    required this.levelOf,
  });

  final String label;
  final Color color;
  final HealthReferenceRange reference;
  final double? Function(HealthRecord record) valueOf;
  final HealthLevel Function(double value) levelOf;
}

class _InteractiveTrendCard extends StatefulWidget {
  const _InteractiveTrendCard({
    required this.title,
    required this.yAxisLabel,
    required this.unit,
    required this.records,
    required this.range,
    required this.usingCustomRange,
    required this.series,
    this.compactLandscape = false,
  });

  final String title;
  final String yAxisLabel;
  final String unit;
  final List<HealthRecord> records;
  final HealthRange range;
  final bool usingCustomRange;
  final List<_ChartSeries> series;
  final bool compactLandscape;

  @override
  State<_InteractiveTrendCard> createState() => _InteractiveTrendCardState();
}

class _InteractiveTrendCardState extends State<_InteractiveTrendCard> {
  int? _selectedIndex;
  late Set<String> _visibleLabels;
  late final _ChartViewportController _viewportController;
  bool _showReference = true;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _visibleLabels = widget.series.map((item) => item.label).toSet();
    _viewportController = _ChartViewportController(
      compact: widget.compactLandscape,
    );
  }

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _InteractiveTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentLabels = widget.series.map((item) => item.label).toSet();
    _visibleLabels = _visibleLabels.intersection(currentLabels);
    if (_visibleLabels.isEmpty) _visibleLabels = currentLabels;
  }

  @override
  Widget build(BuildContext context) {
    final visibleSeries =
        widget.series
            .where((series) => _visibleLabels.contains(series.label))
            .toList();
    final records = _buildTrendPoints(
      records: widget.records,
      series: visibleSeries,
      range: widget.range,
      usingCustomRange: widget.usingCustomRange,
    );
    _viewportController.configure(
      dayCount: records.length,
      range: widget.range,
    );
    final compact = widget.compactLandscape;
    final cardPadding =
        compact
            ? const EdgeInsets.fromLTRB(8, 6, 8, 6)
            : const EdgeInsets.fromLTRB(8, 10, 8, 12);
    final chipVisualDensity =
        compact ? VisualDensity.compact : VisualDensity.standard;
    final chipPadding =
        compact
            ? const EdgeInsets.symmetric(horizontal: 6)
            : const EdgeInsets.symmetric(horizontal: 8);
    final titleText =
        compact ? '${widget.title} / ${widget.unit}' : widget.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
      ),
      child: Padding(
        padding: cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titleText,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 14 : null,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!widget.compactLandscape)
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton.filledTonal(
                        tooltip: _zoomed ? '显示完整范围' : '放大局部查看',
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            records.length < 2
                                ? null
                                : () => setState(() {
                                  if (_zoomed) {
                                    _viewportController.reset(widget.range);
                                  } else {
                                    _viewportController.zoom(
                                      1.45,
                                      _viewportController.visibleEndIndex,
                                    );
                                  }
                                  _zoomed = !_zoomed;
                                  _selectedIndex = null;
                                }),
                        icon: Icon(
                          _zoomed
                              ? Icons.zoom_out_map_rounded
                              : Icons.zoom_in_rounded,
                          size: 18,
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            records.isEmpty
                                ? null
                                : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) => _LandscapeTrendPage(
                                          title: widget.title,
                                          yAxisLabel: widget.yAxisLabel,
                                          unit: widget.unit,
                                          records: widget.records,
                                          range: widget.range,
                                          usingCustomRange:
                                              widget.usingCustomRange,
                                          series: widget.series,
                                        ),
                                  ),
                                ),
                        icon: const Icon(
                          Icons.screen_rotation_rounded,
                          size: 18,
                        ),
                        label: const _OneLineText('横置'),
                      ),
                    ],
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 2),
              Text(
                '单位：${widget.unit}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            SizedBox(height: compact ? 6 : 8),
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 4 : 8,
              children: [
                for (final series in widget.series)
                  FilterChip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: chipVisualDensity,
                    labelPadding: chipPadding,
                    selected: _visibleLabels.contains(series.label),
                    avatar: Icon(Icons.circle, size: 12, color: series.color),
                    label: _OneLineText(series.label),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _visibleLabels.add(series.label);
                        } else if (_visibleLabels.length > 1) {
                          _visibleLabels.remove(series.label);
                        }
                        _selectedIndex = null;
                      });
                    },
                  ),
                FilterChip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: chipVisualDensity,
                  labelPadding: chipPadding,
                  selected: _showReference,
                  avatar: Icon(
                    Icons.straighten_rounded,
                    size: compact ? 14 : 18,
                  ),
                  label: const _OneLineText('参考范围'),
                  onSelected:
                      (selected) => setState(() => _showReference = selected),
                ),
              ],
            ),
            if (_showReference && !widget.compactLandscape) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children:
                    visibleSeries
                        .map(
                          (series) => Text(
                            '${series.label}：${series.reference.description}',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                        .toList(),
              ),
            ],
            SizedBox(height: compact ? 8 : 12),
            if (compact)
              Expanded(
                child: _TrendChartViewport(
                  records: records,
                  visibleSeries: visibleSeries,
                  allSeries: widget.series,
                  selectedIndex: _selectedIndex,
                  showReference: _showReference,
                  unit: widget.unit,
                  compact: true,
                  viewportController: _viewportController,
                  onSelect: (index) => setState(() => _selectedIndex = index),
                  tooltipLeft:
                      (selected, width) => _tooltipLeft(selected, width),
                  onCloseTooltip: () => setState(() => _selectedIndex = null),
                  onOpenDetails:
                      (selected) =>
                          _showTrendPointRecords(context, records[selected]),
                ),
              )
            else
              _TrendChartViewport(
                records: records,
                visibleSeries: visibleSeries,
                allSeries: widget.series,
                selectedIndex: _selectedIndex,
                showReference: _showReference,
                unit: widget.unit,
                compact: false,
                viewportController: _viewportController,
                onSelect: (index) => setState(() => _selectedIndex = index),
                tooltipLeft: (selected, width) => _tooltipLeft(selected, width),
                onCloseTooltip: () => setState(() => _selectedIndex = null),
                onOpenDetails:
                    (selected) =>
                        _showTrendPointRecords(context, records[selected]),
              ),
          ],
        ),
      ),
    );
  }

  double _tooltipLeft(int index, double width) {
    final x = _viewportController.xForIndex(index, width);
    return (x - 119).clamp(0.0, math.max(0.0, width - 238));
  }

  Future<void> _showTrendPointRecords(BuildContext context, _TrendPoint point) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              shrinkWrap: true,
              children: [
                Text(
                  '${_dateLabel(point.measuredAt)}记录',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  '共 ${point.records.length} 次。图上的点按异常优先选择，下面保留全部真实记录。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                ...point.records.map(
                  (record) => _RecordCard(record: record, onEdit: null),
                ),
              ],
            ),
          ),
    );
  }
}

class _LandscapeTrendPage extends StatefulWidget {
  const _LandscapeTrendPage({
    required this.title,
    required this.yAxisLabel,
    required this.unit,
    required this.records,
    required this.range,
    required this.usingCustomRange,
    required this.series,
  });

  final String title;
  final String yAxisLabel;
  final String unit;
  final List<HealthRecord> records;
  final HealthRange range;
  final bool usingCustomRange;
  final List<_ChartSeries> series;

  @override
  State<_LandscapeTrendPage> createState() => _LandscapeTrendPageState();
}

class _LandscapeTrendPageState extends State<_LandscapeTrendPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        titleSpacing: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SizedBox.expand(
            child: _InteractiveTrendCard(
              title: widget.title,
              yAxisLabel: widget.yAxisLabel,
              unit: widget.unit,
              records: widget.records,
              range: widget.range,
              usingCustomRange: widget.usingCustomRange,
              series: widget.series,
              compactLandscape: true,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendChartViewport extends StatelessWidget {
  const _TrendChartViewport({
    required this.records,
    required this.visibleSeries,
    required this.allSeries,
    required this.selectedIndex,
    required this.showReference,
    required this.unit,
    required this.compact,
    required this.viewportController,
    required this.onSelect,
    required this.tooltipLeft,
    required this.onCloseTooltip,
    required this.onOpenDetails,
  });

  final List<_TrendPoint> records;
  final List<_ChartSeries> visibleSeries;
  final List<_ChartSeries> allSeries;
  final int? selectedIndex;
  final bool showReference;
  final String unit;
  final bool compact;
  final _ChartViewportController viewportController;
  final ValueChanged<int> onSelect;
  final double Function(int selected, double width) tooltipLeft;
  final VoidCallback onCloseTooltip;
  final void Function(int selected) onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final chart =
        records.isEmpty
            ? Center(
              child: Text(
                '这里还没有趋势数据。\n下次测量时，顺手记下来就好。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
            : LayoutBuilder(
              builder: (context, constraints) {
                final height =
                    compact ? math.max(160.0, constraints.maxHeight) : 250.0;
                final width = constraints.maxWidth;
                var lastScale = 1.0;
                var lastFocalIndex = viewportController.visibleEndIndex;
                return AnimatedBuilder(
                  animation: viewportController,
                  builder: (context, _) {
                    return SizedBox(
                      width: width,
                      height: height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          final index = viewportController
                              .indexForDx(details.localPosition.dx, width)
                              .round()
                              .clamp(0, records.length - 1);
                          onSelect(index);
                        },
                        onScaleStart: (details) {
                          lastScale = 1;
                          lastFocalIndex = viewportController.indexForDx(
                            details.localFocalPoint.dx,
                            width,
                          );
                        },
                        onScaleUpdate: (details) {
                          if (details.pointerCount > 1) {
                            final scaleDelta = details.scale / lastScale;
                            viewportController.zoom(scaleDelta, lastFocalIndex);
                            lastScale = details.scale;
                          } else {
                            final plotWidth = math.max(1.0, width - 64);
                            final dayDelta =
                                -details.focalPointDelta.dx /
                                plotWidth *
                                viewportController.visibleDays;
                            viewportController.pan(dayDelta);
                          }
                          final index = viewportController
                              .indexForDx(details.localFocalPoint.dx, width)
                              .round()
                              .clamp(0, records.length - 1);
                          onSelect(index);
                        },
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: Size(width, height),
                              painter: _TrendPainter(
                                records: records,
                                series: visibleSeries,
                                selectedIndex: selectedIndex,
                                showReference: showReference,
                                compact: compact,
                                visibleStartIndex:
                                    viewportController.visibleStartIndex,
                                visibleEndIndex:
                                    viewportController.visibleEndIndex,
                              ),
                            ),
                            if (selectedIndex case final selected?
                                when viewportController.isVisible(selected))
                              _Tooltip(
                                record: records[selected],
                                series: visibleSeries,
                                unit: unit,
                                left: tooltipLeft(selected, width),
                                onClose: onCloseTooltip,
                                onOpenDetails: () => onOpenDetails(selected),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );

    final legend = Wrap(
      spacing: compact ? 12 : 16,
      runSpacing: compact ? 4 : 8,
      children: [
        for (var index = 0; index < allSeries.length; index++)
          if (visibleSeries.any(
            (series) => series.label == allSeries[index].label,
          ))
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  index.isEven ? Icons.circle : Icons.square,
                  size: compact ? 9 : 11,
                  color: allSeries[index].color,
                ),
                const SizedBox(width: 5),
                Text(
                  allSeries[index].label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: compact ? Theme.of(context).textTheme.bodySmall : null,
                ),
              ],
            ),
      ],
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: chart), const SizedBox(height: 6), legend],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: records.isEmpty ? 150 : 250, child: chart),
        const SizedBox(height: 8),
        legend,
      ],
    );
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.record,
    required this.series,
    required this.unit,
    required this.left,
    required this.onClose,
    required this.onOpenDetails,
  });

  final _TrendPoint record;
  final List<_ChartSeries> series;
  final String unit;
  final double left;
  final VoidCallback onClose;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: 4,
      width: 238,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.records.length > 1
                          ? '${_dateLabel(record.measuredAt)} · ${record.records.length} 次'
                          : _fullDateTime(record.records.first.measuredAt),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    ..._tooltipLines()
                        .take(8)
                        .map(
                          (line) => Text(
                            line,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    if (_tooltipLines().length > 8)
                      Text(
                        '还有 ${_tooltipLines().length - 8} 条，点下方查看全部',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    if (record.records.length > 1)
                      Text(
                        '点位按异常优先；当天全部记录可查看。',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    TextButton.icon(
                      onPressed: onOpenDetails,
                      icon: const Icon(Icons.list_alt_rounded, size: 16),
                      label: const _OneLineText('查看当天明细'),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _tooltipLines() {
    final lines = <String>[];
    final sorted = [...record.records]
      ..sort((left, right) => left.measuredAt.compareTo(right.measuredAt));
    for (final healthRecord in sorted) {
      final parts = <String>[];
      for (final item in series) {
        final value = item.valueOf(healthRecord);
        if (value != null) {
          parts.add('${item.label}：${value.toStringAsFixed(1)} $unit');
        }
      }
      if (parts.isNotEmpty) {
        lines.add(
          '${_timeLabel(healthRecord.measuredAt)}  ${parts.join('  ')}',
        );
      }
    }
    return lines;
  }
}

class _TrendPoint {
  const _TrendPoint({
    required this.measuredAt,
    required this.records,
    required this.values,
  });

  final DateTime measuredAt;
  final List<HealthRecord> records;
  final Map<String, _TrendValue> values;
}

class _TrendValue {
  const _TrendValue({required this.value, required this.record});

  final double value;
  final HealthRecord record;
}

List<_TrendPoint> _buildTrendPoints({
  required List<HealthRecord> records,
  required List<_ChartSeries> series,
  required HealthRange range,
  required bool usingCustomRange,
}) {
  final usable =
      records
          .where((record) => series.any((item) => item.valueOf(record) != null))
          .toList()
        ..sort((left, right) => left.measuredAt.compareTo(right.measuredAt));
  if (usable.isEmpty) return const [];
  final shouldGroupByMonth =
      !usingCustomRange && range == HealthRange.all && usable.length > 90;
  final groups = <DateTime, List<HealthRecord>>{};
  for (final record in usable) {
    final key =
        shouldGroupByMonth
            ? DateTime(record.measuredAt.year, record.measuredAt.month)
            : DateTime(
              record.measuredAt.year,
              record.measuredAt.month,
              record.measuredAt.day,
            );
    groups.putIfAbsent(key, () => []).add(record);
  }
  final keys = groups.keys.toList()..sort();
  return [
    for (final key in keys)
      _TrendPoint(
        measuredAt: key,
        records:
            groups[key]!..sort(
              (left, right) => left.measuredAt.compareTo(right.measuredAt),
            ),
        values: {
          for (final item in series)
            if (_pickRepresentative(groups[key]!, item) case final selected?)
              item.label: selected,
        },
      ),
  ].where((point) => point.values.isNotEmpty).toList();
}

_TrendValue? _pickRepresentative(
  List<HealthRecord> records,
  _ChartSeries series,
) {
  _TrendValue? selected;
  double? selectedScore;
  for (final record in records) {
    final value = series.valueOf(record);
    if (value == null) continue;
    final score = _riskScore(series, value);
    if (selected == null ||
        score > selectedScore! ||
        score == selectedScore &&
            record.measuredAt.isAfter(selected.record.measuredAt)) {
      selected = _TrendValue(value: value, record: record);
      selectedScore = score;
    }
  }
  return selected;
}

double _riskScore(_ChartSeries series, double value) {
  final level = series.levelOf(value);
  final levelWeight = switch (level) {
    HealthLevel.normal => 0.0,
    HealthLevel.elevated => 1000.0,
    HealthLevel.risk => 2000.0,
  };
  final range = math.max(0.1, series.reference.max - series.reference.min);
  final deviation =
      value < series.reference.min
          ? (series.reference.min - value) / range
          : value > series.reference.max
          ? (value - series.reference.max) / range
          : 0.0;
  return levelWeight + deviation;
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.records,
    required this.series,
    required this.selectedIndex,
    required this.showReference,
    required this.compact,
    required this.visibleStartIndex,
    required this.visibleEndIndex,
  });

  final List<_TrendPoint> records;
  final List<_ChartSeries> series;
  final int? selectedIndex;
  final bool showReference;
  final bool compact;
  final double visibleStartIndex;
  final double visibleEndIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0;
    const right = 16.0;
    final top = compact ? 12.0 : 18.0;
    final bottom = compact ? 42.0 : 42.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final all = <double>[
      for (final record in records)
        for (final item in series)
          if (record.values[item.label] case final selected?) selected.value,
      if (showReference) ...[
        for (final item in series) item.reference.min,
        for (final item in series) item.reference.max,
      ],
    ];
    if (all.isEmpty) return;
    var minValue = all.reduce(math.min);
    var maxValue = all.reduce(math.max);
    final baseRange = math.max(1.0, maxValue - minValue);
    minValue = math.max(0, minValue - baseRange * 0.15);
    maxValue += baseRange * 0.15;

    final grid =
        Paint()
          ..color = const Color(0xFFE7DEDA)
          ..strokeWidth = 1;
    for (var line = 0; line < 4; line++) {
      final y = plot.top + plot.height * line / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final value = maxValue - (maxValue - minValue) * line / 3;
      _paintText(
        canvas,
        value.toStringAsFixed(1),
        Offset(0, y - 7),
        const TextStyle(fontSize: 10, color: Color(0xFF675F5C)),
      );
    }

    if (showReference) {
      final normalFill =
          Paint()
            ..color = const Color(0xFF6FAF8A).withValues(alpha: 0.10)
            ..style = PaintingStyle.fill;
      final normalBorder =
          Paint()
            ..color = const Color(0xFF6FAF8A).withValues(alpha: 0.36)
            ..strokeWidth = 1;
      for (final item in series) {
        final minY =
            plot.bottom -
            (item.reference.min - minValue) /
                (maxValue - minValue) *
                plot.height;
        final maxY =
            plot.bottom -
            (item.reference.max - minValue) /
                (maxValue - minValue) *
                plot.height;
        final band = Rect.fromLTRB(
          plot.left,
          maxY.clamp(plot.top, plot.bottom),
          plot.right,
          minY.clamp(plot.top, plot.bottom),
        );
        canvas.drawRect(band, normalFill);
        canvas.drawLine(
          Offset(plot.left, band.top),
          Offset(plot.right, band.top),
          normalBorder,
        );
        canvas.drawLine(
          Offset(plot.left, band.bottom),
          Offset(plot.right, band.bottom),
          normalBorder,
        );
      }
    }

    if (selectedIndex != null && _isVisibleIndex(selectedIndex!)) {
      final x = _x(selectedIndex!, plot);
      _drawDashedLine(
        canvas,
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = const Color(0xFF7D706C)
          ..strokeWidth = 1.2,
      );
      final point = records[selectedIndex!];
      _paintText(
        canvas,
        '${point.measuredAt.month}/${point.measuredAt.day}',
        Offset((x - 18).clamp(plot.left, plot.right - 36), plot.bottom + 24),
        const TextStyle(
          fontSize: 11,
          color: Color(0xFF514845),
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final startIndex = visibleStartIndex.floor().clamp(0, records.length - 1);
    final endIndex = visibleEndIndex.ceil().clamp(0, records.length - 1);
    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final item = series[seriesIndex];
      final line =
          Paint()
            ..color = item.color
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
      final dot = Paint()..color = item.color;
      final path = Path();
      var drawing = false;
      for (var index = startIndex; index <= endIndex; index++) {
        final selectedValue = records[index].values[item.label];
        if (selectedValue == null) {
          drawing = false;
          continue;
        }
        final value = selectedValue.value;
        final point = Offset(
          _x(index, plot),
          plot.bottom -
              (value - minValue) / (maxValue - minValue) * plot.height,
        );
        drawing
            ? path.lineTo(point.dx, point.dy)
            : path.moveTo(point.dx, point.dy);
        drawing = true;
        final selected = selectedIndex == index;
        if (seriesIndex.isEven) {
          canvas.drawCircle(point, selected ? 6 : 3.5, dot);
        } else {
          final radius = selected ? 5.5 : 3.3;
          canvas.drawRect(
            Rect.fromCenter(
              center: point,
              width: radius * 2,
              height: radius * 2,
            ),
            dot,
          );
        }
      }
      canvas.drawPath(path, line);
    }

    final axisLabels = _buildDateAxisLabels(
      chartDays: records,
      visibleStartIndex: visibleStartIndex,
      visibleEndIndex: visibleEndIndex,
      chartWidth: plot.width,
    );
    for (final label in axisLabels) {
      _paintText(
        canvas,
        label.text,
        Offset(_x(label.index, plot) - 14, plot.bottom + 10),
        const TextStyle(fontSize: 10, color: Color(0xFF675F5C)),
      );
    }
  }

  double _x(int index, Rect plot) =>
      plot.left +
      plot.width *
          ((index - visibleStartIndex) /
              math.max(1.0, visibleEndIndex - visibleStartIndex));

  bool _isVisibleIndex(int index) =>
      index >= visibleStartIndex.floor() && index <= visibleEndIndex.ceil();

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (end - start).distance;
    final direction = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final from = start + direction * distance;
      final to = start + direction * math.min(distance + dash, total);
      canvas.drawLine(from, to, paint);
      distance += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.records != records ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.showReference != showReference ||
      oldDelegate.compact != compact ||
      oldDelegate.visibleStartIndex != visibleStartIndex ||
      oldDelegate.visibleEndIndex != visibleEndIndex;
}

class _RecordCalendar extends StatelessWidget {
  const _RecordCalendar({required this.records, required this.onOpen});

  final List<HealthRecord> records;
  final ValueChanged<HealthRecord>? onOpen;

  @override
  Widget build(BuildContext context) {
    final months = <DateTime, List<HealthRecord>>{};
    for (final record in records) {
      final month = DateTime(record.measuredAt.year, record.measuredAt.month);
      months.putIfAbsent(month, () => []).add(record);
    }
    final monthKeys =
        months.keys.toList()..sort((left, right) => right.compareTo(left));
    return Column(
      children: [
        for (final month in monthKeys)
          _MonthRecordCard(
            month: month,
            records:
                months[month]!..sort(
                  (left, right) => right.measuredAt.compareTo(left.measuredAt),
                ),
            onOpen: onOpen,
          ),
      ],
    );
  }
}

class _MonthRecordCard extends StatelessWidget {
  const _MonthRecordCard({
    required this.month,
    required this.records,
    required this.onOpen,
  });

  final DateTime month;
  final List<HealthRecord> records;
  final ValueChanged<HealthRecord>? onOpen;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month).weekday;
    final byDay = <int, List<HealthRecord>>{};
    for (final record in records) {
      byDay.putIfAbsent(record.measuredAt.day, () => []).add(record);
    }
    final totalMetrics = HealthReferenceService.summarize(records).metricCount;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${month.year}年${month.month}月',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '本月记录 ${records.length} 次 · 共 $totalMetrics 项指标',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children:
                  const ['一', '二', '三', '四', '五', '六', '日']
                      .map(
                        (label) => Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.textScalerOf(context).scale(1.0);
                final cellWidth = (constraints.maxWidth - 36) / 7;
                final cellHeight = math.max(
                  44.0,
                  cellWidth * 0.92 + textScale * 8,
                );
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ((firstWeekday - 1 + daysInMonth + 6) ~/ 7) * 7,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    mainAxisExtent: cellHeight,
                  ),
                  itemBuilder: (context, index) {
                    final day = index - firstWeekday + 2;
                    if (day < 1 || day > daysInMonth) return const SizedBox();
                    final dayRecords = byDay[day] ?? const <HealthRecord>[];
                    final hasRecords = dayRecords.isNotEmpty;
                    final hasAbnormal = dayRecords.any(
                      (record) => record.overallLevel != HealthLevel.normal,
                    );
                    final color =
                        hasAbnormal
                            ? const Color(0xFFB34646)
                            : Theme.of(context).colorScheme.primary;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap:
                          hasRecords
                              ? () => _showDayRecords(context, day, dayRecords)
                              : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              hasRecords
                                  ? color.withValues(alpha: 0.12)
                                  : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              hasRecords
                                  ? Border.all(
                                    color: color.withValues(alpha: 0.35),
                                  )
                                  : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$day',
                              maxLines: 1,
                              style: TextStyle(
                                fontWeight:
                                    hasRecords
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                color: hasRecords ? color : null,
                              ),
                            ),
                            if (hasRecords) ...[
                              const SizedBox(height: 3),
                              Container(
                                width: dayRecords.length > 1 ? 22 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            Text('点击有记录的日期查看详情', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _showDayRecords(
    BuildContext context,
    int day,
    List<HealthRecord> dayRecords,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              shrinkWrap: true,
              children: [
                Text(
                  '${month.month}月$day日记录',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...dayRecords.map(
                  (record) => _RecordCard(
                    record: record,
                    onEdit:
                        onOpen == null
                            ? null
                            : () {
                              Navigator.of(context).pop();
                              onOpen!(record);
                            },
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onEdit});

  final HealthRecord record;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final color = healthLevelColor(record.overallLevel);
    final metricLines = <String>[];
    if (record.hasBloodPressure) {
      metricLines.add(
        '血压 ${formatBloodPressure(systolic: record.systolic!, diastolic: record.diastolic!)}',
      );
    }
    final bloodSugar = <String>[];
    if (record.bloodSugarFasting != null) {
      bloodSugar.add('空腹 ${record.bloodSugarFasting}');
    }
    if (record.bloodSugarPostprandial != null) {
      bloodSugar.add('餐后 ${record.bloodSugarPostprandial}');
    }
    if (bloodSugar.isNotEmpty) {
      metricLines.add('血糖 ${bloodSugar.join(' · ')}');
    }
    final bloodLipids = <String>[];
    if (record.totalCholesterol != null) {
      bloodLipids.add('总胆固醇 ${record.totalCholesterol}');
    }
    if (record.triglycerides != null) {
      bloodLipids.add('甘油三酯 ${record.triglycerides}');
    }
    if (record.ldlC != null) bloodLipids.add('LDL ${record.ldlC}');
    if (record.hdlC != null) bloodLipids.add('HDL ${record.hdlC}');
    if (bloodLipids.isNotEmpty) {
      metricLines.add('血脂 ${bloodLipids.join(' · ')}');
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text(
            '${record.measuredAt.day}',
            style: TextStyle(color: color),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              metricLines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(line),
                    ),
                  )
                  .toList(),
        ),
        subtitle: Text(
          record.note.isEmpty ? _fullDateTime(record.measuredAt) : record.note,
        ),
        trailing: onEdit == null ? null : const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('这里还没有趋势数据。\n下次测量时，顺手记下来就好。', textAlign: TextAlign.center),
      ),
    );
  }
}

List<HealthRecord> _exampleRecords() {
  final end = DateTime(2026, 7, 2, 8, 0);
  final records = <HealthRecord>[];
  for (var i = 89; i >= 0; i--) {
    final index = 89 - i;
    final day = end.subtract(Duration(days: i));
    records.add(_exampleRecord(day, index));
    if (index % 13 == 0) {
      records.add(
        _exampleRecord(day.add(const Duration(hours: 10)), index + 900),
      );
    }
  }
  return records;
}

HealthRecord _exampleRecord(DateTime day, int index) {
  final wave = math.sin(index / 8);
  final smallerWave = math.cos(index / 11);
  final normalizedIndex = index % 900;
  final extraRisk = index >= 900 ? 1.0 : 0.0;
  final pressureBump =
      normalizedIndex > 58 ? (normalizedIndex - 58) * 0.75 : 0.0;
  final sugarBump = normalizedIndex > 42 && normalizedIndex < 68 ? 1.25 : 0.0;
  final lipidBump = normalizedIndex > 64 ? (normalizedIndex - 64) * 0.035 : 0.0;
  return HealthRecord(
    id: 'example-$index',
    ownerUserId: 'example-user',
    measuredAt: day,
    systolic: (116 + wave * 7 + pressureBump + extraRisk * 12).round(),
    diastolic:
        (74 + smallerWave * 4 + pressureBump * 0.35 + extraRisk * 6).round(),
    bloodSugarFasting: double.parse(
      (5.4 + wave * 0.35 + sugarBump * 0.35 + extraRisk * 0.6).toStringAsFixed(
        1,
      ),
    ),
    bloodSugarPostprandial: double.parse(
      (7.0 + smallerWave * 0.6 + sugarBump + extraRisk * 1.1).toStringAsFixed(
        1,
      ),
    ),
    totalCholesterol: double.parse(
      (4.4 + wave * 0.25 + lipidBump + extraRisk * 0.5).toStringAsFixed(1),
    ),
    triglycerides: double.parse(
      (1.25 + smallerWave * 0.18 + lipidBump * 0.6).toStringAsFixed(1),
    ),
    ldlC: double.parse((2.45 + lipidBump * 0.8).toStringAsFixed(1)),
    hdlC: double.parse((1.25 - lipidBump * 0.08).toStringAsFixed(1)),
    note: index % 17 == 0 ? '示例：当天状态波动，建议结合饮食和运动观察。' : '',
  );
}

String _fullDateTime(DateTime value) =>
    '${value.month}月${value.day}日 '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _dateLabel(DateTime value) => '${value.month}月${value.day}日';

String _timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
