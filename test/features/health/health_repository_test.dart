import 'package:family_health_monitor/features/health/data/demo_health_repository.dart';
import 'package:family_health_monitor/features/health/domain/health_failure.dart';
import 'package:family_health_monitor/features/health/domain/health_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HealthStatus', () {
    test('classifies blood pressure using the guide thresholds', () {
      expect(HealthStatus.bloodPressure(119, 79), HealthLevel.normal);
      expect(HealthStatus.bloodPressure(120, 80), HealthLevel.elevated);
      expect(HealthStatus.bloodPressure(140, 90), HealthLevel.risk);
    });

    test('classifies fasting and postprandial blood sugar', () {
      expect(HealthStatus.fastingSugar(5.6), HealthLevel.normal);
      expect(HealthStatus.fastingSugar(6.5), HealthLevel.elevated);
      expect(HealthStatus.fastingSugar(7.0), HealthLevel.risk);
      expect(HealthStatus.postprandialSugar(7.8), HealthLevel.normal);
      expect(HealthStatus.postprandialSugar(8.6), HealthLevel.elevated);
      expect(HealthStatus.postprandialSugar(11.1), HealthLevel.risk);
    });

    test('uses the most serious measurement as the overall level', () {
      final record = HealthRecord(
        id: 'record',
        userId: 'me',
        recordedAt: DateTime(2026),
        systolic: 118,
        diastolic: 76,
        bloodSugarFasting: 7.2,
      );

      expect(record.overallLevel, HealthLevel.risk);
    });
  });

  group('DemoHealthRepository', () {
    test('seeds a readable trend for the demo mother', () async {
      final repository = DemoHealthRepository();

      final records =
          await repository
              .watchRecords(
                familyId: 'demo-family',
                userId: 'demo-mom',
                days: 30,
              )
              .first;

      expect(records, hasLength(14));
      expect(records.first.recordedAt.isAfter(records.last.recordedAt), isTrue);
    });

    test('adds a record and emits it as the latest value', () async {
      final repository = DemoHealthRepository();
      final emissions =
          repository
              .watchRecords(familyId: 'family', userId: 'me', days: 30)
              .take(2)
              .toList();

      await repository.addRecord(
        familyId: 'family',
        draft: HealthRecordDraft(
          userId: 'me',
          recordedAt: DateTime.now(),
          systolic: 122,
          diastolic: 81,
          note: '睡得不错',
        ),
      );

      final values = await emissions;
      expect(values.first, isEmpty);
      expect(values.last.single.systolic, 122);
      expect(values.last.single.note, '睡得不错');
    });

    test('rejects an empty health record', () async {
      final repository = DemoHealthRepository();

      expect(
        () => repository.addRecord(
          familyId: 'family',
          draft: HealthRecordDraft(userId: 'me', recordedAt: DateTime.now()),
        ),
        throwsA(isA<HealthFailure>()),
      );
    });

    test('restores recorded data after an app restart', () async {
      final repository = DemoHealthRepository();
      await repository.addRecord(
        familyId: 'family',
        draft: HealthRecordDraft(
          userId: 'account-a',
          recordedAt: DateTime.now(),
          systolic: 135,
          diastolic: 86,
          bloodSugarFasting: 6.4,
        ),
      );

      final restored = DemoHealthRepository(
        initialState: repository.exportState(),
      );
      final records =
          await restored
              .watchRecords(familyId: 'family', userId: 'account-a', days: 30)
              .first;

      expect(records.single.systolic, 135);
      expect(records.single.bloodSugarFasting, 6.4);
    });
  });
}
