import 'health_level.dart';
import '../services/health_status_service.dart';

export 'health_level.dart';

enum HealthMetricKind { bloodPressure, bloodSugar, bloodLipid }

enum HealthRange {
  sevenDays(7, '7 天'),
  thirtyDays(30, '30 天'),
  ninetyDays(90, '90 天'),
  all(null, '全部');

  const HealthRange(this.days, this.label);
  final int? days;
  final String label;
}

class HealthRecord {
  HealthRecord({
    required this.id,
    String? ownerUserId,
    String? userId,
    DateTime? measuredAt,
    DateTime? recordedAt,
    this.systolic,
    this.diastolic,
    this.bloodSugarFasting,
    this.bloodSugarPostprandial,
    double? totalCholesterol,
    double? bloodLipid,
    this.triglycerides,
    this.ldlC,
    this.hdlC,
    this.note = '',
    this.sharedGroupIds = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : assert(ownerUserId != null || userId != null),
       assert(measuredAt != null || recordedAt != null),
       ownerUserId = ownerUserId ?? userId!,
       measuredAt = measuredAt ?? recordedAt!,
       totalCholesterol = totalCholesterol ?? bloodLipid,
       createdAt = createdAt ?? measuredAt ?? recordedAt!,
       updatedAt = updatedAt ?? measuredAt ?? recordedAt!;

  final String id;
  final String ownerUserId;
  final DateTime measuredAt;
  final int? systolic;
  final int? diastolic;
  final double? bloodSugarFasting;
  final double? bloodSugarPostprandial;
  final double? totalCholesterol;
  final double? triglycerides;
  final double? ldlC;
  final double? hdlC;
  final String note;
  final Set<String> sharedGroupIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get userId => ownerUserId;
  DateTime get recordedAt => measuredAt;
  double? get bloodLipid => totalCholesterol;

  bool get hasBloodPressure => systolic != null && diastolic != null;
  bool get hasBloodSugar =>
      bloodSugarFasting != null || bloodSugarPostprandial != null;
  bool get hasBloodLipid =>
      totalCholesterol != null ||
      triglycerides != null ||
      ldlC != null ||
      hdlC != null;
  bool get hasAnyMeasurement =>
      hasBloodPressure || hasBloodSugar || hasBloodLipid;

  HealthLevel? get bloodPressureLevel =>
      hasBloodPressure
          ? HealthStatusService.bloodPressure(systolic!, diastolic!)
          : null;
  HealthLevel? get fastingSugarLevel =>
      bloodSugarFasting == null
          ? null
          : HealthStatusService.fastingSugar(bloodSugarFasting!);
  HealthLevel? get postprandialSugarLevel =>
      bloodSugarPostprandial == null
          ? null
          : HealthStatusService.postprandialSugar(bloodSugarPostprandial!);
  HealthLevel? get bloodLipidLevel =>
      totalCholesterol == null
          ? null
          : HealthStatusService.totalCholesterol(totalCholesterol!);

  HealthLevel get overallLevel => HealthStatusService.overall([
    bloodPressureLevel,
    fastingSugarLevel,
    postprandialSugarLevel,
    totalCholesterol == null
        ? null
        : HealthStatusService.totalCholesterol(totalCholesterol!),
    triglycerides == null
        ? null
        : HealthStatusService.triglycerides(triglycerides!),
    ldlC == null ? null : HealthStatusService.ldl(ldlC!),
    hdlC == null ? null : HealthStatusService.hdl(hdlC!),
  ]);
}

class HealthRecordDraft {
  HealthRecordDraft({
    String? ownerUserId,
    String? userId,
    DateTime? measuredAt,
    DateTime? recordedAt,
    this.recordId,
    this.systolic,
    this.diastolic,
    this.bloodSugarFasting,
    this.bloodSugarPostprandial,
    double? totalCholesterol,
    double? bloodLipid,
    this.triglycerides,
    this.ldlC,
    this.hdlC,
    this.note = '',
    this.sharedGroupIds = const {},
  }) : assert(ownerUserId != null || userId != null),
       assert(measuredAt != null || recordedAt != null),
       ownerUserId = ownerUserId ?? userId!,
       measuredAt = measuredAt ?? recordedAt!,
       totalCholesterol = totalCholesterol ?? bloodLipid;

  final String? recordId;
  final String ownerUserId;
  final DateTime measuredAt;
  final int? systolic;
  final int? diastolic;
  final double? bloodSugarFasting;
  final double? bloodSugarPostprandial;
  final double? totalCholesterol;
  final double? triglycerides;
  final double? ldlC;
  final double? hdlC;
  final String note;
  final Set<String> sharedGroupIds;

  String get userId => ownerUserId;
  DateTime get recordedAt => measuredAt;
  double? get bloodLipid => totalCholesterol;

  bool get hasPartialBloodPressure => (systolic == null) != (diastolic == null);
  bool get hasBloodPressure => systolic != null && diastolic != null;
  bool get hasAnyMeasurement =>
      hasBloodPressure ||
      bloodSugarFasting != null ||
      bloodSugarPostprandial != null ||
      totalCholesterol != null ||
      triglycerides != null ||
      ldlC != null ||
      hdlC != null;

  List<String> validate() {
    final errors = <String>[];
    if (hasPartialBloodPressure) {
      errors.add('请同时填写收缩压和舒张压');
    }
    final numericValues = <String, num?>{
      '收缩压': systolic,
      '舒张压': diastolic,
      '空腹血糖': bloodSugarFasting,
      '餐后 2 小时血糖': bloodSugarPostprandial,
      '总胆固醇': totalCholesterol,
      '甘油三酯': triglycerides,
      '低密度脂蛋白胆固醇': ldlC,
      '高密度脂蛋白胆固醇': hdlC,
    };
    for (final entry in numericValues.entries) {
      if (entry.value != null &&
          (entry.value! <= 0 || !entry.value!.toDouble().isFinite)) {
        errors.add('请输入有效的${entry.key}数值');
      }
    }
    if (!hasAnyMeasurement) errors.add('至少记录一项测量数据');
    if (note.trim().length > 120) errors.add('备注请控制在 120 个字符以内');
    return errors;
  }

  bool get isValid => validate().isEmpty;
}

class RecordShare {
  const RecordShare({
    required this.id,
    required this.recordId,
    required this.ownerUserId,
    required this.groupId,
    required this.sharedAt,
  });

  final String id;
  final String recordId;
  final String ownerUserId;
  final String groupId;
  final DateTime sharedAt;
}

/// Compatibility facade for existing callers; thresholds live in one service.
abstract final class HealthStatus {
  static HealthLevel bloodPressure(int systolic, int diastolic) =>
      HealthStatusService.bloodPressure(systolic, diastolic);
  static HealthLevel fastingSugar(double value) =>
      HealthStatusService.fastingSugar(value);
  static HealthLevel postprandialSugar(double value) =>
      HealthStatusService.postprandialSugar(value);
  static HealthLevel bloodLipid(double value) =>
      HealthStatusService.totalCholesterol(value);
}
