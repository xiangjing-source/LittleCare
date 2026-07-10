import '../domain/health_models.dart';
import 'health_status_service.dart';

class HealthReferenceRange {
  const HealthReferenceRange({
    required this.label,
    required this.min,
    required this.max,
    required this.unit,
    required this.description,
  });

  final String label;
  final double min;
  final double max;
  final String unit;
  final String description;
}

class HealthMetricReference {
  const HealthMetricReference({
    required this.label,
    required this.range,
    required this.valueOf,
    required this.levelOf,
  });

  final String label;
  final HealthReferenceRange range;
  final double? Function(HealthRecord record) valueOf;
  final HealthLevel Function(double value) levelOf;
}

class HealthRangeSummary {
  const HealthRangeSummary({
    required this.recordCount,
    required this.metricCount,
    required this.normalCount,
    required this.abnormalCount,
    required this.categories,
  });

  final int recordCount;
  final int metricCount;
  final int normalCount;
  final int abnormalCount;
  final List<HealthCategorySummary> categories;

  String message(String rangeLabel) {
    if (recordCount == 0) {
      return '$rangeLabel内还没有记录。记录几次后，这里会显示正常和异常次数。';
    }
    return '$rangeLabel内共记录 $recordCount 次，包含 $metricCount 项指标；'
        '常见范围内 $normalCount 项，需留意 $abnormalCount 项。';
  }
}

class HealthCategorySummary {
  const HealthCategorySummary({
    required this.label,
    required this.normalCount,
    required this.totalCount,
  });

  final String label;
  final int normalCount;
  final int totalCount;

  int get abnormalCount => totalCount - normalCount;
  String get ratioText =>
      totalCount == 0 ? '$label：暂无' : '$label：$normalCount/$totalCount';
}

abstract final class HealthReferenceService {
  static const systolic = HealthReferenceRange(
    label: '收缩压',
    min: 90,
    max: 119,
    unit: 'mmHg',
    description: '常见参考范围：90–119 mmHg',
  );

  static const diastolic = HealthReferenceRange(
    label: '舒张压',
    min: 60,
    max: 79,
    unit: 'mmHg',
    description: '常见参考范围：60–79 mmHg',
  );

  static const fastingSugar = HealthReferenceRange(
    label: '空腹血糖',
    min: 3.9,
    max: 6.1,
    unit: 'mmol/L',
    description: '常见参考范围：3.9–6.1 mmol/L',
  );

  static const postprandialSugar = HealthReferenceRange(
    label: '餐后 2 小时血糖',
    min: 3.9,
    max: 7.8,
    unit: 'mmol/L',
    description: '常见参考范围：3.9–7.8 mmol/L',
  );

  static const totalCholesterol = HealthReferenceRange(
    label: '总胆固醇',
    min: 3.0,
    max: 5.2,
    unit: 'mmol/L',
    description: '常见参考范围：3.0–5.2 mmol/L',
  );

  static const triglycerides = HealthReferenceRange(
    label: '甘油三酯',
    min: 0,
    max: 1.7,
    unit: 'mmol/L',
    description: '常见参考范围：≤1.7 mmol/L',
  );

  static const ldl = HealthReferenceRange(
    label: '低密度脂蛋白',
    min: 0,
    max: 3.4,
    unit: 'mmol/L',
    description: '常见参考范围：≤3.4 mmol/L',
  );

  static const hdl = HealthReferenceRange(
    label: '高密度脂蛋白',
    min: 1.0,
    max: 2.2,
    unit: 'mmol/L',
    description: '常见参考范围：≥1.0 mmol/L',
  );

  static List<HealthMetricReference> get metrics => [
    HealthMetricReference(
      label: systolic.label,
      range: systolic,
      valueOf: (record) => record.systolic?.toDouble(),
      levelOf: (value) => HealthStatusService.bloodPressure(value.round(), 70),
    ),
    HealthMetricReference(
      label: diastolic.label,
      range: diastolic,
      valueOf: (record) => record.diastolic?.toDouble(),
      levelOf: (value) => HealthStatusService.bloodPressure(110, value.round()),
    ),
    HealthMetricReference(
      label: fastingSugar.label,
      range: fastingSugar,
      valueOf: (record) => record.bloodSugarFasting,
      levelOf: HealthStatusService.fastingSugar,
    ),
    HealthMetricReference(
      label: postprandialSugar.label,
      range: postprandialSugar,
      valueOf: (record) => record.bloodSugarPostprandial,
      levelOf: HealthStatusService.postprandialSugar,
    ),
    HealthMetricReference(
      label: totalCholesterol.label,
      range: totalCholesterol,
      valueOf: (record) => record.totalCholesterol,
      levelOf: HealthStatusService.totalCholesterol,
    ),
    HealthMetricReference(
      label: triglycerides.label,
      range: triglycerides,
      valueOf: (record) => record.triglycerides,
      levelOf: HealthStatusService.triglycerides,
    ),
    HealthMetricReference(
      label: ldl.label,
      range: ldl,
      valueOf: (record) => record.ldlC,
      levelOf: HealthStatusService.ldl,
    ),
    HealthMetricReference(
      label: hdl.label,
      range: hdl,
      valueOf: (record) => record.hdlC,
      levelOf: HealthStatusService.hdl,
    ),
  ];

  static HealthRangeSummary summarize(Iterable<HealthRecord> records) {
    var recordCount = 0;
    var metricCount = 0;
    var normalCount = 0;
    var abnormalCount = 0;
    var pressureNormal = 0;
    var pressureTotal = 0;
    var sugarNormal = 0;
    var sugarTotal = 0;
    var lipidNormal = 0;
    var lipidTotal = 0;
    for (final record in records) {
      recordCount++;
      if (record.hasBloodPressure) {
        pressureTotal++;
        metricCount++;
        if (record.bloodPressureLevel == HealthLevel.normal) {
          normalCount++;
          pressureNormal++;
        } else {
          abnormalCount++;
        }
      }
      final sugarValues = <({double value, HealthLevel level})>[
        if (record.bloodSugarFasting != null)
          (
            value: record.bloodSugarFasting!,
            level: HealthStatusService.fastingSugar(record.bloodSugarFasting!),
          ),
        if (record.bloodSugarPostprandial != null)
          (
            value: record.bloodSugarPostprandial!,
            level: HealthStatusService.postprandialSugar(
              record.bloodSugarPostprandial!,
            ),
          ),
      ];
      for (final item in sugarValues) {
        sugarTotal++;
        metricCount++;
        if (item.level == HealthLevel.normal) {
          normalCount++;
          sugarNormal++;
        } else {
          abnormalCount++;
        }
      }
      final lipidValues = <({double value, HealthLevel level})>[
        if (record.totalCholesterol != null)
          (
            value: record.totalCholesterol!,
            level: HealthStatusService.totalCholesterol(
              record.totalCholesterol!,
            ),
          ),
        if (record.triglycerides != null)
          (
            value: record.triglycerides!,
            level: HealthStatusService.triglycerides(record.triglycerides!),
          ),
        if (record.ldlC != null)
          (value: record.ldlC!, level: HealthStatusService.ldl(record.ldlC!)),
        if (record.hdlC != null)
          (value: record.hdlC!, level: HealthStatusService.hdl(record.hdlC!)),
      ];
      for (final item in lipidValues) {
        lipidTotal++;
        metricCount++;
        if (item.level == HealthLevel.normal) {
          normalCount++;
          lipidNormal++;
        } else {
          abnormalCount++;
        }
      }
    }
    return HealthRangeSummary(
      recordCount: recordCount,
      metricCount: metricCount,
      normalCount: normalCount,
      abnormalCount: abnormalCount,
      categories: [
        HealthCategorySummary(
          label: '血压',
          normalCount: pressureNormal,
          totalCount: pressureTotal,
        ),
        HealthCategorySummary(
          label: '血糖',
          normalCount: sugarNormal,
          totalCount: sugarTotal,
        ),
        HealthCategorySummary(
          label: '血脂',
          normalCount: lipidNormal,
          totalCount: lipidTotal,
        ),
      ],
    );
  }
}
