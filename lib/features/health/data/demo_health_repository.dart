import 'dart:async';
import 'dart:convert';

import '../../../core/storage/demo_storage_contract.dart';
import '../domain/health_failure.dart';
import '../domain/health_models.dart';
import '../domain/health_repository.dart';

class DemoHealthRepository implements HealthRepository {
  DemoHealthRepository({
    DemoStorage? preferences,
    String? initialState,
    String? legacyState,
    String? legacyFamilyState,
  }) : _preferences = preferences {
    final legacyGroupsByUser = _legacyGroups(legacyFamilyState);
    final restored = initialState != null && _restoreV2(initialState);
    final migrated =
        !restored &&
        legacyState != null &&
        _restoreLegacy(legacyState, legacyGroupsByUser);
    if (!restored && !migrated) _seedDemoRecords();
  }

  static const storageKey = 'demo_health_state_v2';
  static const legacyStorageKey = 'demo_health_state_v1';

  final DemoStorage? _preferences;
  final Map<String, HealthRecord> _records = {};
  final StreamController<String> _updates = StreamController.broadcast();

  void _seedDemoRecords() {
    final now = DateTime.now();
    for (var index = 0; index < 14; index++) {
      final day = 13 - index;
      final record = HealthRecord(
        id: 'demo-mom-$index',
        ownerUserId: 'demo-mom',
        measuredAt: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: day, hours: -8)),
        systolic: 116 + (index % 5) * 3,
        diastolic: 74 + (index % 4) * 2,
        bloodSugarFasting: 5.2 + (index % 4) * 0.25,
        bloodSugarPostprandial: 6.8 + (index % 5) * 0.35,
        totalCholesterol: index.isEven ? 4.7 : null,
        triglycerides: index.isEven ? 1.2 : null,
        sharedGroupIds: const {'demo-group'},
        note: index == 13 ? '今天精神不错，饭后散步了半小时。' : '',
      );
      _records[record.id] = record;
    }
  }

  @override
  Stream<List<HealthRecord>> watchUserRecords({
    required String userId,
    required HealthRange range,
  }) async* {
    yield _recordsForUser(userId, range);
    yield* _updates.stream
        .where((key) => key == 'user:$userId')
        .map((_) => _recordsForUser(userId, range));
  }

  @override
  Stream<List<HealthRecord>> watchGroupSharedRecords({
    required String groupId,
    required HealthRange range,
  }) async* {
    yield _recordsForGroup(groupId, range);
    yield* _updates.stream
        .where((key) => key == 'group:$groupId')
        .map((_) => _recordsForGroup(groupId, range));
  }

  List<HealthRecord> _recordsForUser(String userId, HealthRange range) =>
      _filterAndSort(
        _records.values.where((record) => record.ownerUserId == userId),
        range,
      );

  List<HealthRecord> _recordsForGroup(String groupId, HealthRange range) =>
      _filterAndSort(
        _records.values.where(
          (record) => record.sharedGroupIds.contains(groupId),
        ),
        range,
      );

  List<HealthRecord> _filterAndSort(
    Iterable<HealthRecord> records,
    HealthRange range,
  ) {
    final threshold =
        range.days == null
            ? null
            : DateTime.now().subtract(Duration(days: range.days!));
    final result =
        records
            .where(
              (record) =>
                  threshold == null || record.measuredAt.isAfter(threshold),
            )
            .toList()
          ..sort((left, right) => right.measuredAt.compareTo(left.measuredAt));
    return List.unmodifiable(result);
  }

  List<HealthRecord> _recordsSince(
    List<HealthRecord> sorted,
    DateTime threshold,
  ) =>
      sorted.where((record) => !record.measuredAt.isBefore(threshold)).toList();

  List<HealthRecord> _recordsInRange(
    List<HealthRecord> sorted,
    DateTime? start,
    DateTime? end,
  ) {
    if (start == null || end == null) return const [];
    final startDay = DateTime(start.year, start.month, start.day);
    final endExclusive = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));
    return sorted
        .where(
          (record) =>
              !record.measuredAt.isBefore(startDay) &&
              record.measuredAt.isBefore(endExclusive),
        )
        .toList();
  }

  List<HealthRecord> _latestEffectiveDayRecords(
    List<HealthRecord> sorted,
    int days,
  ) {
    final seenKeys = <String>{};
    final selectedKeys = <String>{};
    for (final record in sorted) {
      final key = _dateKey(record.measuredAt);
      if (seenKeys.add(key)) selectedKeys.add(key);
      if (seenKeys.length >= days) break;
    }
    return sorted
        .where((record) => selectedKeys.contains(_dateKey(record.measuredAt)))
        .toList();
  }

  String _dateKey(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';

  @override
  Future<HealthRecord> saveRecord(HealthRecordDraft draft) async {
    _validate(draft);
    // Give newly-created stream subscriptions a chance to receive their
    // initial snapshot before the mutation event is broadcast.
    await Future<void>.delayed(Duration.zero);
    final now = DateTime.now();
    final record = _recordFromDraft(
      draft,
      id: 'record-${now.microsecondsSinceEpoch}',
      createdAt: now,
      updatedAt: now,
    );
    _records[record.id] = record;
    await _persist();
    _notify(record, const {});
    return record;
  }

  @override
  Future<HealthRecord> updateRecord(HealthRecordDraft draft) async {
    _validate(draft);
    final id = draft.recordId;
    final existing = id == null ? null : _records[id];
    if (existing == null) {
      throw const HealthFailure('没有找到这条记录', code: 'not-found');
    }
    if (existing.ownerUserId != draft.ownerUserId) {
      throw const HealthFailure('只能修改自己的记录', code: 'forbidden');
    }
    final updated = _recordFromDraft(
      draft,
      id: existing.id,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    _records[id!] = updated;
    await _persist();
    _notify(updated, existing.sharedGroupIds);
    return updated;
  }

  @override
  Future<void> deleteRecord({
    required String recordId,
    required String ownerUserId,
  }) async {
    final existing = _records[recordId];
    if (existing == null) return;
    if (existing.ownerUserId != ownerUserId) {
      throw const HealthFailure('只能删除自己的记录', code: 'forbidden');
    }
    _records.remove(recordId);
    await _persist();
    _updates.add('user:$ownerUserId');
    for (final groupId in existing.sharedGroupIds) {
      _updates.add('group:$groupId');
    }
  }

  @override
  Future<void> setRecordShares({
    required String recordId,
    required String ownerUserId,
    required Set<String> groupIds,
  }) async {
    final existing = _records[recordId];
    if (existing == null) {
      throw const HealthFailure('没有找到这条记录', code: 'not-found');
    }
    if (existing.ownerUserId != ownerUserId) {
      throw const HealthFailure('只能调整自己记录的分享范围', code: 'forbidden');
    }
    final updated = HealthRecord(
      id: existing.id,
      ownerUserId: existing.ownerUserId,
      measuredAt: existing.measuredAt,
      systolic: existing.systolic,
      diastolic: existing.diastolic,
      bloodSugarFasting: existing.bloodSugarFasting,
      bloodSugarPostprandial: existing.bloodSugarPostprandial,
      totalCholesterol: existing.totalCholesterol,
      triglycerides: existing.triglycerides,
      ldlC: existing.ldlC,
      hdlC: existing.hdlC,
      note: existing.note,
      sharedGroupIds: Set.unmodifiable(groupIds),
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    _records[recordId] = updated;
    await _persist();
    _notify(updated, existing.sharedGroupIds);
  }

  @override
  Future<HistoryShareResult> shareHistoryRecords({
    required String ownerUserId,
    required String groupId,
    required HistoryShareRange range,
    DateTime? start,
    DateTime? end,
  }) async {
    final sorted =
        _records.values
            .where((record) => record.ownerUserId == ownerUserId)
            .toList()
          ..sort((left, right) => right.measuredAt.compareTo(left.measuredAt));
    final selected = switch (range) {
      HistoryShareRange.sevenDays => _recordsSince(
        sorted,
        DateTime.now().subtract(const Duration(days: 7)),
      ),
      HistoryShareRange.thirtyDays => _recordsSince(
        sorted,
        DateTime.now().subtract(const Duration(days: 30)),
      ),
      HistoryShareRange.ninetyEffectiveDays => _latestEffectiveDayRecords(
        sorted,
        90,
      ),
      HistoryShareRange.custom => _recordsInRange(sorted, start, end),
    };
    final pending =
        selected
            .where((record) => !record.sharedGroupIds.contains(groupId))
            .toList();
    final now = DateTime.now();
    for (final existing in pending) {
      final updated = HealthRecord(
        id: existing.id,
        ownerUserId: existing.ownerUserId,
        measuredAt: existing.measuredAt,
        systolic: existing.systolic,
        diastolic: existing.diastolic,
        bloodSugarFasting: existing.bloodSugarFasting,
        bloodSugarPostprandial: existing.bloodSugarPostprandial,
        totalCholesterol: existing.totalCholesterol,
        triglycerides: existing.triglycerides,
        ldlC: existing.ldlC,
        hdlC: existing.hdlC,
        note: existing.note,
        sharedGroupIds: Set.unmodifiable({...existing.sharedGroupIds, groupId}),
        createdAt: existing.createdAt,
        updatedAt: now,
      );
      _records[existing.id] = updated;
      _notify(updated, existing.sharedGroupIds);
    }
    if (pending.isNotEmpty) await _persist();
    return HistoryShareResult(
      shared: pending.length,
      alreadyShared: selected.length - pending.length,
    );
  }

  void _validate(HealthRecordDraft draft) {
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      throw HealthFailure(errors.first, code: 'invalid-record');
    }
  }

  HealthRecord _recordFromDraft(
    HealthRecordDraft draft, {
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => HealthRecord(
    id: id,
    ownerUserId: draft.ownerUserId,
    measuredAt: draft.measuredAt,
    systolic: draft.systolic,
    diastolic: draft.diastolic,
    bloodSugarFasting: draft.bloodSugarFasting,
    bloodSugarPostprandial: draft.bloodSugarPostprandial,
    totalCholesterol: draft.totalCholesterol,
    triglycerides: draft.triglycerides,
    ldlC: draft.ldlC,
    hdlC: draft.hdlC,
    note: draft.note.trim(),
    sharedGroupIds: Set.unmodifiable(draft.sharedGroupIds),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  void _notify(HealthRecord current, Set<String> previousGroups) {
    _updates.add('user:${current.ownerUserId}');
    for (final groupId in {...previousGroups, ...current.sharedGroupIds}) {
      _updates.add('group:$groupId');
    }
  }

  @override
  Stream<List<HealthRecord>> watchRecords({
    required String familyId,
    required String userId,
    required int days,
  }) => watchUserRecords(userId: userId, range: _rangeForDays(days));

  @override
  Future<void> addRecord({
    required String familyId,
    required HealthRecordDraft draft,
  }) => saveRecord(
    HealthRecordDraft(
      ownerUserId: draft.ownerUserId,
      measuredAt: draft.measuredAt,
      systolic: draft.systolic,
      diastolic: draft.diastolic,
      bloodSugarFasting: draft.bloodSugarFasting,
      bloodSugarPostprandial: draft.bloodSugarPostprandial,
      totalCholesterol: draft.totalCholesterol,
      triglycerides: draft.triglycerides,
      ldlC: draft.ldlC,
      hdlC: draft.hdlC,
      note: draft.note,
      sharedGroupIds: {familyId},
    ),
  ).then((_) {});

  HealthRange _rangeForDays(int days) {
    if (days <= 7) return HealthRange.sevenDays;
    if (days <= 30) return HealthRange.thirtyDays;
    if (days <= 90) return HealthRange.ninetyDays;
    return HealthRange.all;
  }

  Future<void> _persist() async {
    await _preferences?.setString(storageKey, exportState());
  }

  String exportState() => jsonEncode({
    'schema_version': 2,
    'records': _records.values.map(_toJson).toList(),
  });

  bool _restoreV2(String encoded) {
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      for (final raw in (data['records'] as List<dynamic>? ?? const [])) {
        final record = _fromJson(Map<String, dynamic>.from(raw as Map));
        _records[record.id] = record;
      }
      return true;
    } catch (_) {
      _records.clear();
      return false;
    }
  }

  bool _restoreLegacy(String encoded, Map<String, String> legacyGroupsByUser) {
    try {
      final values = jsonDecode(encoded) as List<dynamic>;
      for (final raw in values) {
        final data = Map<String, dynamic>.from(raw as Map);
        final record = HealthRecord(
          id: data['id'] as String,
          ownerUserId: data['user_id'] as String,
          measuredAt: DateTime.parse(data['recorded_at'] as String),
          systolic: (data['systolic'] as num?)?.toInt(),
          diastolic: (data['diastolic'] as num?)?.toInt(),
          bloodSugarFasting: (data['blood_sugar_fasting'] as num?)?.toDouble(),
          bloodSugarPostprandial:
              (data['blood_sugar_postprandial'] as num?)?.toDouble(),
          totalCholesterol: (data['blood_lipid'] as num?)?.toDouble(),
          note: data['note'] as String? ?? '',
          // v1 records were visible to the current family. The group migration
          // preserves that behavior via the legacy group id when known by UI.
          sharedGroupIds: {
            if (legacyGroupsByUser[data['user_id'] as String]
                case final groupId?)
              groupId,
            if (data['user_id'] == 'demo-mom') 'demo-group',
          },
        );
        _records[record.id] = record;
      }
      return true;
    } catch (_) {
      _records.clear();
      return false;
    }
  }

  static Map<String, String> _legacyGroups(String? encoded) {
    if (encoded == null) return const {};
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      return Map<String, dynamic>.from(
        data['family_ids'] as Map? ?? const {},
      ).map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return const {};
    }
  }

  static Map<String, dynamic> _toJson(HealthRecord record) => {
    'id': record.id,
    'owner_user_id': record.ownerUserId,
    'measured_at': record.measuredAt.toIso8601String(),
    'systolic': record.systolic,
    'diastolic': record.diastolic,
    'blood_sugar_fasting': record.bloodSugarFasting,
    'blood_sugar_postprandial': record.bloodSugarPostprandial,
    'total_cholesterol': record.totalCholesterol,
    'triglycerides': record.triglycerides,
    'ldl_c': record.ldlC,
    'hdl_c': record.hdlC,
    'note': record.note,
    'shared_group_ids': record.sharedGroupIds.toList(),
    'created_at': record.createdAt.toIso8601String(),
    'updated_at': record.updatedAt.toIso8601String(),
  };

  static HealthRecord _fromJson(Map<String, dynamic> data) => HealthRecord(
    id: data['id'] as String,
    ownerUserId: data['owner_user_id'] as String,
    measuredAt: DateTime.parse(data['measured_at'] as String),
    systolic: (data['systolic'] as num?)?.toInt(),
    diastolic: (data['diastolic'] as num?)?.toInt(),
    bloodSugarFasting: (data['blood_sugar_fasting'] as num?)?.toDouble(),
    bloodSugarPostprandial:
        (data['blood_sugar_postprandial'] as num?)?.toDouble(),
    totalCholesterol: (data['total_cholesterol'] as num?)?.toDouble(),
    triglycerides: (data['triglycerides'] as num?)?.toDouble(),
    ldlC: (data['ldl_c'] as num?)?.toDouble(),
    hdlC: (data['hdl_c'] as num?)?.toDouble(),
    note: data['note'] as String? ?? '',
    sharedGroupIds: Set<String>.from(
      data['shared_group_ids'] as List? ?? const [],
    ),
    createdAt: DateTime.parse(data['created_at'] as String),
    updatedAt: DateTime.parse(data['updated_at'] as String),
  );
}
