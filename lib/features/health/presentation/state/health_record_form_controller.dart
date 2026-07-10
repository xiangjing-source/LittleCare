import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/health_models.dart';
import 'health_record_form_state.dart';

final healthRecordFormProvider =
    NotifierProvider<HealthRecordFormController, HealthRecordFormState>(
      HealthRecordFormController.new,
    );

class HealthRecordFormController extends Notifier<HealthRecordFormState> {
  @override
  HealthRecordFormState build() =>
      HealthRecordFormState(measuredAt: DateTime.now());

  void reset({HealthRecord? record, Set<String> defaultGroupIds = const {}}) {
    if (record == null) {
      state = HealthRecordFormState(
        measuredAt: DateTime.now(),
        sharedGroupIds: defaultGroupIds,
      );
      return;
    }
    state = HealthRecordFormState(
      recordId: record.id,
      selectedMetrics: {
        if (record.hasBloodPressure) HealthMetricKind.bloodPressure,
        if (record.hasBloodSugar) HealthMetricKind.bloodSugar,
        if (record.hasBloodLipid) HealthMetricKind.bloodLipid,
      },
      measuredAt: record.measuredAt,
      systolic: record.systolic,
      diastolic: record.diastolic,
      bloodSugarFasting: record.bloodSugarFasting,
      bloodSugarPostprandial: record.bloodSugarPostprandial,
      totalCholesterol: record.totalCholesterol,
      triglycerides: record.triglycerides,
      ldlC: record.ldlC,
      hdlC: record.hdlC,
      note: record.note,
      sharedGroupIds: record.sharedGroupIds,
    );
  }

  void toggleMetric(HealthMetricKind metric, bool selected) {
    final metrics = {...state.selectedMetrics};
    selected ? metrics.add(metric) : metrics.remove(metric);
    var next = state.copyWith(
      selectedMetrics: metrics,
      validationErrors: const [],
    );
    if (!selected) {
      next = switch (metric) {
        HealthMetricKind.bloodPressure => next.copyWith(
          clearSystolic: true,
          clearDiastolic: true,
        ),
        HealthMetricKind.bloodSugar => next.copyWith(
          clearFasting: true,
          clearPostprandial: true,
        ),
        HealthMetricKind.bloodLipid => next.copyWith(
          clearTotalCholesterol: true,
          clearTriglycerides: true,
          clearLdl: true,
          clearHdl: true,
        ),
      };
    }
    state = next;
  }

  void setSystolic(String value) =>
      state = state.copyWith(
        systolic: int.tryParse(value),
        clearSystolic: value.trim().isEmpty,
      );
  void setDiastolic(String value) =>
      state = state.copyWith(
        diastolic: int.tryParse(value),
        clearDiastolic: value.trim().isEmpty,
      );
  void setFasting(String value) =>
      state = state.copyWith(
        bloodSugarFasting: double.tryParse(value),
        clearFasting: value.trim().isEmpty,
      );
  void setPostprandial(String value) =>
      state = state.copyWith(
        bloodSugarPostprandial: double.tryParse(value),
        clearPostprandial: value.trim().isEmpty,
      );
  void setTotalCholesterol(String value) =>
      state = state.copyWith(
        totalCholesterol: double.tryParse(value),
        clearTotalCholesterol: value.trim().isEmpty,
      );
  void setTriglycerides(String value) =>
      state = state.copyWith(
        triglycerides: double.tryParse(value),
        clearTriglycerides: value.trim().isEmpty,
      );
  void setLdl(String value) =>
      state = state.copyWith(
        ldlC: double.tryParse(value),
        clearLdl: value.trim().isEmpty,
      );
  void setHdl(String value) =>
      state = state.copyWith(
        hdlC: double.tryParse(value),
        clearHdl: value.trim().isEmpty,
      );
  void setNote(String value) => state = state.copyWith(note: value);
  void setMeasuredAt(DateTime value) =>
      state = state.copyWith(measuredAt: value);

  void toggleShare(String groupId, bool selected) {
    final groups = {...state.sharedGroupIds};
    selected ? groups.add(groupId) : groups.remove(groupId);
    state = state.copyWith(sharedGroupIds: groups);
  }

  void setShares(Set<String> groupIds) {
    state = state.copyWith(sharedGroupIds: groupIds);
  }

  HealthRecordDraft draft(String ownerUserId) => HealthRecordDraft(
    recordId: state.recordId,
    ownerUserId: ownerUserId,
    measuredAt: state.measuredAt,
    systolic: state.systolic,
    diastolic: state.diastolic,
    bloodSugarFasting: state.bloodSugarFasting,
    bloodSugarPostprandial: state.bloodSugarPostprandial,
    totalCholesterol: state.totalCholesterol,
    triglycerides: state.triglycerides,
    ldlC: state.ldlC,
    hdlC: state.hdlC,
    note: state.note,
    sharedGroupIds: state.sharedGroupIds,
  );

  List<String> validate(String ownerUserId) {
    final errors = draft(ownerUserId).validate();
    state = state.copyWith(validationErrors: errors);
    return errors;
  }
}
