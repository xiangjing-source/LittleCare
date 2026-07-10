import '../domain/health_models.dart';

abstract final class HealthTrendService {
  static List<HealthRecord> filter(
    Iterable<HealthRecord> records,
    HealthRange range, {
    DateTime? now,
  }) {
    final threshold =
        range.days == null
            ? null
            : (now ?? DateTime.now()).subtract(Duration(days: range.days!));
    final result =
        records
            .where(
              (record) =>
                  threshold == null || record.measuredAt.isAfter(threshold),
            )
            .toList()
          ..sort((left, right) => left.measuredAt.compareTo(right.measuredAt));
    return result;
  }

  static List<({DateTime measuredAt, double value, String note})> points(
    Iterable<HealthRecord> records,
    double? Function(HealthRecord record) valueOf,
  ) =>
      records
          .map(
            (record) => (
              measuredAt: record.measuredAt,
              value: valueOf(record),
              note: record.note,
            ),
          )
          .where((point) => point.value != null)
          .map(
            (point) => (
              measuredAt: point.measuredAt,
              value: point.value!,
              note: point.note,
            ),
          )
          .toList();
}
