import '../../domain/health_models.dart';

class HealthRecordFormState {
  HealthRecordFormState({
    required this.measuredAt,
    this.recordId,
    this.selectedMetrics = const {},
    this.systolic,
    this.diastolic,
    this.bloodSugarFasting,
    this.bloodSugarPostprandial,
    this.totalCholesterol,
    this.triglycerides,
    this.ldlC,
    this.hdlC,
    this.note = '',
    this.sharedGroupIds = const {},
    this.validationErrors = const [],
  });

  final String? recordId;
  final Set<HealthMetricKind> selectedMetrics;
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
  final List<String> validationErrors;

  bool get hasAnyValue =>
      (systolic != null && diastolic != null) ||
      bloodSugarFasting != null ||
      bloodSugarPostprandial != null ||
      totalCholesterol != null ||
      triglycerides != null ||
      ldlC != null ||
      hdlC != null;

  bool get hasPartialBloodPressure => (systolic == null) != (diastolic == null);

  bool get canSubmit => hasAnyValue && !hasPartialBloodPressure;

  HealthRecordFormState copyWith({
    String? recordId,
    Set<HealthMetricKind>? selectedMetrics,
    DateTime? measuredAt,
    int? systolic,
    int? diastolic,
    double? bloodSugarFasting,
    double? bloodSugarPostprandial,
    double? totalCholesterol,
    double? triglycerides,
    double? ldlC,
    double? hdlC,
    String? note,
    Set<String>? sharedGroupIds,
    List<String>? validationErrors,
    bool clearSystolic = false,
    bool clearDiastolic = false,
    bool clearFasting = false,
    bool clearPostprandial = false,
    bool clearTotalCholesterol = false,
    bool clearTriglycerides = false,
    bool clearLdl = false,
    bool clearHdl = false,
  }) => HealthRecordFormState(
    recordId: recordId ?? this.recordId,
    selectedMetrics: selectedMetrics ?? this.selectedMetrics,
    measuredAt: measuredAt ?? this.measuredAt,
    systolic: clearSystolic ? null : systolic ?? this.systolic,
    diastolic: clearDiastolic ? null : diastolic ?? this.diastolic,
    bloodSugarFasting:
        clearFasting ? null : bloodSugarFasting ?? this.bloodSugarFasting,
    bloodSugarPostprandial:
        clearPostprandial
            ? null
            : bloodSugarPostprandial ?? this.bloodSugarPostprandial,
    totalCholesterol:
        clearTotalCholesterol
            ? null
            : totalCholesterol ?? this.totalCholesterol,
    triglycerides:
        clearTriglycerides ? null : triglycerides ?? this.triglycerides,
    ldlC: clearLdl ? null : ldlC ?? this.ldlC,
    hdlC: clearHdl ? null : hdlC ?? this.hdlC,
    note: note ?? this.note,
    sharedGroupIds: sharedGroupIds ?? this.sharedGroupIds,
    validationErrors: validationErrors ?? this.validationErrors,
  );
}
