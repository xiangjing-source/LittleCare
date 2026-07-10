import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/health_failure.dart';
import '../domain/health_models.dart';
import '../domain/health_repository.dart';

class FirebaseHealthRepository implements HealthRepository {
  FirebaseHealthRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _records =>
      _firestore.collection('health_records');
  CollectionReference<Map<String, dynamic>> get _shares =>
      _firestore.collection('record_shares');

  @override
  Stream<List<HealthRecord>> watchUserRecords({
    required String userId,
    required HealthRange range,
  }) {
    return _records
        .where('owner_user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => _filter(snapshot.docs.map(_fromDocument), range));
  }

  @override
  Stream<List<HealthRecord>> watchGroupSharedRecords({
    required String groupId,
    required HealthRange range,
  }) {
    return _records
        .where('shared_group_ids', arrayContains: groupId)
        .snapshots()
        .map((snapshot) => _filter(snapshot.docs.map(_fromDocument), range));
  }

  List<HealthRecord> _filter(Iterable<HealthRecord> source, HealthRange range) {
    final threshold =
        range.days == null
            ? null
            : DateTime.now().subtract(Duration(days: range.days!));
    final records =
        source
            .where(
              (record) =>
                  threshold == null || record.measuredAt.isAfter(threshold),
            )
            .toList()
          ..sort((left, right) => right.measuredAt.compareTo(left.measuredAt));
    return records;
  }

  @override
  Future<HealthRecord> saveRecord(HealthRecordDraft draft) async {
    _validate(draft);
    final reference = _records.doc();
    final now = DateTime.now();
    final batch = _firestore.batch();
    batch.set(reference, _payload(draft, isCreate: true));
    _writeShares(
      batch,
      recordId: reference.id,
      ownerUserId: draft.ownerUserId,
      groupIds: draft.sharedGroupIds,
    );
    try {
      await batch.commit();
      return _recordFromDraft(draft, id: reference.id, createdAt: now);
    } on FirebaseException catch (error) {
      throw HealthFailure('这条记录暂时没有保存成功，请稍后再试', code: error.code);
    }
  }

  @override
  Future<HealthRecord> updateRecord(HealthRecordDraft draft) async {
    _validate(draft);
    final recordId = draft.recordId;
    if (recordId == null) {
      throw const HealthFailure('没有找到这条记录', code: 'not-found');
    }
    final reference = _records.doc(recordId);
    final existing = await reference.get();
    final data = existing.data();
    if (data == null) {
      throw const HealthFailure('没有找到这条记录', code: 'not-found');
    }
    if (data['owner_user_id'] != draft.ownerUserId) {
      throw const HealthFailure('只能修改自己的记录', code: 'forbidden');
    }
    final previousGroups = Set<String>.from(
      data['shared_group_ids'] as List? ?? const [],
    );
    final batch = _firestore.batch();
    batch.update(reference, _payload(draft, isCreate: false));
    for (final removed in previousGroups.difference(draft.sharedGroupIds)) {
      batch.delete(_shares.doc('${recordId}_$removed'));
    }
    _writeShares(
      batch,
      recordId: recordId,
      ownerUserId: draft.ownerUserId,
      groupIds: draft.sharedGroupIds,
    );
    await batch.commit();
    return _recordFromDraft(
      draft,
      id: recordId,
      createdAt: _date(data['created_at']),
    );
  }

  @override
  Future<void> deleteRecord({
    required String recordId,
    required String ownerUserId,
  }) async {
    final reference = _records.doc(recordId);
    final existing = await reference.get();
    final data = existing.data();
    if (data == null) return;
    if (data['owner_user_id'] != ownerUserId) {
      throw const HealthFailure('只能删除自己的记录', code: 'forbidden');
    }
    final groups = Set<String>.from(
      data['shared_group_ids'] as List? ?? const [],
    );
    final batch = _firestore.batch()..delete(reference);
    for (final groupId in groups) {
      batch.delete(_shares.doc('${recordId}_$groupId'));
    }
    await batch.commit();
  }

  @override
  Future<void> setRecordShares({
    required String recordId,
    required String ownerUserId,
    required Set<String> groupIds,
  }) async {
    final reference = _records.doc(recordId);
    final existing = await reference.get();
    final data = existing.data();
    if (data == null) {
      throw const HealthFailure('没有找到这条记录', code: 'not-found');
    }
    if (data['owner_user_id'] != ownerUserId) {
      throw const HealthFailure('只能调整自己记录的分享范围', code: 'forbidden');
    }
    final previous = Set<String>.from(
      data['shared_group_ids'] as List? ?? const [],
    );
    final batch =
        _firestore.batch()..update(reference, {
          'shared_group_ids': groupIds.toList(),
          'updated_at': FieldValue.serverTimestamp(),
        });
    for (final removed in previous.difference(groupIds)) {
      batch.delete(_shares.doc('${recordId}_$removed'));
    }
    _writeShares(
      batch,
      recordId: recordId,
      ownerUserId: ownerUserId,
      groupIds: groupIds,
    );
    await batch.commit();
  }

  @override
  Future<HistoryShareResult> shareHistoryRecords({
    required String ownerUserId,
    required String groupId,
    required HistoryShareRange range,
    DateTime? start,
    DateTime? end,
  }) async {
    final snapshot =
        await _records.where('owner_user_id', isEqualTo: ownerUserId).get();
    final documents = [...snapshot.docs]..sort(
      (left, right) => _date(
        right.data()['measured_at'],
      ).compareTo(_date(left.data()['measured_at'])),
    );
    DateTime? threshold;
    if (range == HistoryShareRange.sevenDays) {
      threshold = DateTime.now().subtract(const Duration(days: 7));
    } else if (range == HistoryShareRange.thirtyDays) {
      threshold = DateTime.now().subtract(const Duration(days: 30));
    } else if (range == HistoryShareRange.ninetyEffectiveDays) {
      final dates = <DateTime>[];
      for (final document in documents) {
        final value = _date(document.data()['measured_at']);
        final day = DateTime(value.year, value.month, value.day);
        if (!dates.contains(day)) dates.add(day);
        if (dates.length == 90) break;
      }
      threshold = dates.length < 90 ? null : dates.last;
    }
    final normalizedStart =
        start == null ? null : DateTime(start.year, start.month, start.day);
    final normalizedEnd =
        end == null
            ? null
            : DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    final selected =
        documents.where((document) {
          final measuredAt = _date(document.data()['measured_at']);
          if (range == HistoryShareRange.custom) {
            return normalizedStart != null &&
                normalizedEnd != null &&
                !measuredAt.isBefore(normalizedStart) &&
                !measuredAt.isAfter(normalizedEnd);
          }
          return threshold == null || !measuredAt.isBefore(threshold);
        }).toList();
    final pending =
        selected.where((document) {
          final groups = Set<String>.from(
            document.data()['shared_group_ids'] as List? ?? const [],
          );
          return !groups.contains(groupId);
        }).toList();
    for (var offset = 0; offset < pending.length; offset += 225) {
      final batch = _firestore.batch();
      for (final document in pending.skip(offset).take(225)) {
        batch.update(document.reference, {
          'shared_group_ids': FieldValue.arrayUnion([groupId]),
          'updated_at': FieldValue.serverTimestamp(),
        });
        batch.set(_shares.doc('${document.id}_$groupId'), {
          'record_id': document.id,
          'owner_user_id': ownerUserId,
          'owner_account_id': ownerUserId,
          'group_id': groupId,
          'shared_at': FieldValue.serverTimestamp(),
          'shared_by': ownerUserId,
          'share_source': 'history_share',
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
    return HistoryShareResult(
      shared: pending.length,
      alreadyShared: selected.length - pending.length,
    );
  }

  Map<String, dynamic> _payload(
    HealthRecordDraft draft, {
    required bool isCreate,
  }) {
    final payload = <String, dynamic>{
      'owner_user_id': draft.ownerUserId,
      'measured_at': Timestamp.fromDate(draft.measuredAt),
      'metrics': {
        'blood_pressure':
            draft.hasBloodPressure
                ? {'systolic': draft.systolic, 'diastolic': draft.diastolic}
                : null,
        'blood_sugar': {
          'fasting': draft.bloodSugarFasting,
          'postprandial_2h': draft.bloodSugarPostprandial,
        },
        'blood_lipid': {
          'total_cholesterol': draft.totalCholesterol,
          'triglycerides': draft.triglycerides,
          'ldl_c': draft.ldlC,
          'hdl_c': draft.hdlC,
        },
      },
      'note': draft.note.trim(),
      'shared_group_ids': draft.sharedGroupIds.toList(),
      'updated_at': FieldValue.serverTimestamp(),
      'schema_version': 2,
    };
    if (isCreate) payload['created_at'] = FieldValue.serverTimestamp();
    return payload;
  }

  void _writeShares(
    WriteBatch batch, {
    required String recordId,
    required String ownerUserId,
    required Set<String> groupIds,
  }) {
    for (final groupId in groupIds) {
      batch.set(_shares.doc('${recordId}_$groupId'), {
        'record_id': recordId,
        'owner_user_id': ownerUserId,
        'owner_account_id': ownerUserId,
        'group_id': groupId,
        'shared_at': FieldValue.serverTimestamp(),
        'shared_by': ownerUserId,
        'share_source': 'record_share',
      });
    }
  }

  void _validate(HealthRecordDraft draft) {
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      throw HealthFailure(errors.first, code: 'invalid-record');
    }
  }

  HealthRecord _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final metrics = Map<String, dynamic>.from(
      data['metrics'] as Map? ?? const {},
    );
    final pressure = Map<String, dynamic>.from(
      metrics['blood_pressure'] as Map? ?? const {},
    );
    final sugar = Map<String, dynamic>.from(
      metrics['blood_sugar'] as Map? ?? const {},
    );
    final lipid = Map<String, dynamic>.from(
      metrics['blood_lipid'] as Map? ?? const {},
    );
    return HealthRecord(
      id: document.id,
      ownerUserId: data['owner_user_id'] as String,
      measuredAt: _date(data['measured_at']),
      systolic: (pressure['systolic'] as num?)?.toInt(),
      diastolic: (pressure['diastolic'] as num?)?.toInt(),
      bloodSugarFasting: (sugar['fasting'] as num?)?.toDouble(),
      bloodSugarPostprandial: (sugar['postprandial_2h'] as num?)?.toDouble(),
      totalCholesterol: (lipid['total_cholesterol'] as num?)?.toDouble(),
      triglycerides: (lipid['triglycerides'] as num?)?.toDouble(),
      ldlC: (lipid['ldl_c'] as num?)?.toDouble(),
      hdlC: (lipid['hdl_c'] as num?)?.toDouble(),
      note: data['note'] as String? ?? '',
      sharedGroupIds: Set<String>.from(
        data['shared_group_ids'] as List? ?? const [],
      ),
      createdAt: _date(data['created_at']),
      updatedAt: _date(data['updated_at']),
    );
  }

  HealthRecord _recordFromDraft(
    HealthRecordDraft draft, {
    required String id,
    required DateTime createdAt,
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
    sharedGroupIds: draft.sharedGroupIds,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  DateTime _date(Object? value) =>
      value is Timestamp ? value.toDate() : DateTime.now();

  @override
  Stream<List<HealthRecord>> watchRecords({
    required String familyId,
    required String userId,
    required int days,
  }) => watchUserRecords(
    userId: userId,
    range: days <= 7 ? HealthRange.sevenDays : HealthRange.thirtyDays,
  );

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
}
