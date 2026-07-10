import 'package:family_health_monitor/features/health/data/demo_health_repository.dart';
import 'package:family_health_monitor/features/health/domain/health_formatters.dart';
import 'package:family_health_monitor/features/health/domain/health_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats blood pressure as systolic over diastolic with unit', () {
    expect(formatBloodPressure(systolic: 150, diastolic: 100), '150/100 mmHg');
  });

  group('HealthRecordDraft validation', () {
    HealthRecordDraft draft({
      int? systolic,
      int? diastolic,
      double? fasting,
      double? postprandial,
      double? totalCholesterol,
      double? triglycerides,
      double? ldl,
      double? hdl,
    }) => HealthRecordDraft(
      ownerUserId: 'me',
      measuredAt: DateTime(2026, 7, 2),
      systolic: systolic,
      diastolic: diastolic,
      bloodSugarFasting: fasting,
      bloodSugarPostprandial: postprandial,
      totalCholesterol: totalCholesterol,
      triglycerides: triglycerides,
      ldlC: ldl,
      hdlC: hdl,
    );

    test('fasting sugar alone can be saved', () {
      expect(draft(fasting: 5.8).validate(), isEmpty);
    });

    test('postprandial sugar alone can be saved', () {
      expect(draft(postprandial: 7.2).validate(), isEmpty);
    });

    test('one blood pressure value is rejected', () {
      expect(draft(systolic: 120).validate(), contains('请同时填写收缩压和舒张压'));
    });

    test('both blood pressure values can be saved', () {
      expect(draft(systolic: 120, diastolic: 80).validate(), isEmpty);
    });

    test('an empty record is rejected', () {
      expect(draft().validate(), contains('至少记录一项测量数据'));
    });

    test('each lipid sub-value can be recorded independently', () {
      expect(draft(triglycerides: 1.3).validate(), isEmpty);
      expect(draft(ldl: 2.7).validate(), isEmpty);
      expect(draft(hdl: 1.2).validate(), isEmpty);
      expect(draft(totalCholesterol: 4.8).validate(), isEmpty);
    });
  });

  group('record sharing and ownership', () {
    test('private records do not enter a group feed', () async {
      final repository = DemoHealthRepository(initialState: '{"records":[]}');
      await repository.saveRecord(
        HealthRecordDraft(
          ownerUserId: 'me',
          measuredAt: DateTime.now(),
          bloodSugarFasting: 5.8,
        ),
      );

      expect(
        await repository
            .watchGroupSharedRecords(groupId: 'group-a', range: HealthRange.all)
            .first,
        isEmpty,
      );
    });

    test('one record can be shared to multiple isolated groups', () async {
      final repository = DemoHealthRepository(initialState: '{"records":[]}');
      final record = await repository.saveRecord(
        HealthRecordDraft(
          ownerUserId: 'me',
          measuredAt: DateTime.now(),
          bloodSugarPostprandial: 7.4,
          sharedGroupIds: const {'group-a', 'group-b'},
        ),
      );

      expect(
        await repository
            .watchGroupSharedRecords(groupId: 'group-a', range: HealthRange.all)
            .first,
        hasLength(1),
      );
      expect(
        await repository
            .watchGroupSharedRecords(groupId: 'group-c', range: HealthRange.all)
            .first,
        isEmpty,
      );

      await repository.setRecordShares(
        recordId: record.id,
        ownerUserId: 'me',
        groupIds: const {'group-b'},
      );
      expect(
        await repository
            .watchGroupSharedRecords(groupId: 'group-a', range: HealthRange.all)
            .first,
        isEmpty,
      );
    });

    test('missing values remain null instead of becoming zero', () async {
      final repository = DemoHealthRepository(initialState: '{"records":[]}');
      final record = await repository.saveRecord(
        HealthRecordDraft(
          ownerUserId: 'me',
          measuredAt: DateTime.now(),
          bloodSugarFasting: 5.8,
        ),
      );

      expect(record.systolic, isNull);
      expect(record.totalCholesterol, isNull);
      expect(record.triglycerides, isNull);
    });
  });
}
