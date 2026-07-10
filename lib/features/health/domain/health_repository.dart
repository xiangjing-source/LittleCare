import 'health_models.dart';

enum HistoryShareRange { sevenDays, thirtyDays, ninetyEffectiveDays, custom }

class HistoryShareResult {
  const HistoryShareResult({required this.shared, required this.alreadyShared});

  final int shared;
  final int alreadyShared;
}

abstract interface class HealthRepository {
  Stream<List<HealthRecord>> watchUserRecords({
    required String userId,
    required HealthRange range,
  });

  Stream<List<HealthRecord>> watchGroupSharedRecords({
    required String groupId,
    required HealthRange range,
  });

  Future<HealthRecord> saveRecord(HealthRecordDraft draft);

  Future<HealthRecord> updateRecord(HealthRecordDraft draft);

  Future<void> deleteRecord({
    required String recordId,
    required String ownerUserId,
  });

  Future<void> setRecordShares({
    required String recordId,
    required String ownerUserId,
    required Set<String> groupIds,
  });

  Future<HistoryShareResult> shareHistoryRecords({
    required String ownerUserId,
    required String groupId,
    required HistoryShareRange range,
    DateTime? start,
    DateTime? end,
  });

  // v1 compatibility used while old pages and data migrate.
  Stream<List<HealthRecord>> watchRecords({
    required String familyId,
    required String userId,
    required int days,
  });

  Future<void> addRecord({
    required String familyId,
    required HealthRecordDraft draft,
  });
}
