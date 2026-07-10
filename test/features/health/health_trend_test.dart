import 'package:family_health_monitor/features/health/domain/health_models.dart';
import 'package:family_health_monitor/features/health/services/health_trend_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 2, 12);

  HealthRecord record(
    String id,
    int daysAgo, {
    double? fasting,
    int? systolic,
  }) {
    return HealthRecord(
      id: id,
      ownerUserId: 'me',
      measuredAt: now.subtract(Duration(days: daysAgo)),
      bloodSugarFasting: fasting,
      systolic: systolic,
      diastolic: systolic == null ? null : 80,
    );
  }

  test('time ranges filter records correctly', () {
    final records = [
      record('today', 0, fasting: 5.6),
      record('day-10', 10, fasting: 5.8),
      record('day-60', 60, fasting: 6.0),
      record('day-120', 120, fasting: 6.2),
    ];

    expect(
      HealthTrendService.filter(records, HealthRange.sevenDays, now: now),
      hasLength(1),
    );
    expect(
      HealthTrendService.filter(records, HealthRange.thirtyDays, now: now),
      hasLength(2),
    );
    expect(
      HealthTrendService.filter(records, HealthRange.ninetyDays, now: now),
      hasLength(3),
    );
    expect(
      HealthTrendService.filter(records, HealthRange.all, now: now),
      hasLength(4),
    );
  });

  test('missing metrics do not create zero-valued points', () {
    final records = [
      record('sugar', 0, fasting: 5.6),
      record('pressure', 1, systolic: 120),
    ];

    final fasting = HealthTrendService.points(
      records,
      (record) => record.bloodSugarFasting,
    );
    final pressure = HealthTrendService.points(
      records,
      (record) => record.systolic?.toDouble(),
    );

    expect(fasting.map((point) => point.value), [5.6]);
    expect(pressure.map((point) => point.value), [120.0]);
    expect(fasting.any((point) => point.value == 0), isFalse);
  });
}
