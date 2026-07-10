import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/care_models.dart';
import '../domain/care_repository.dart';

class FirebaseCareRepository implements CareRepository {
  FirebaseCareRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('care_events');

  @override
  Stream<List<CareEvent>> watchGroupEvents({
    required String groupId,
    required String viewerId,
  }) {
    return _events.where('group_id', isEqualTo: groupId).snapshots().map((
      snapshot,
    ) {
      final events =
          snapshot.docs
              .map(_fromDocument)
              .where(
                (event) =>
                    event.fromUserId == viewerId || event.toUserId == viewerId,
              )
              .toList()
            ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return events;
    });
  }

  @override
  Future<CareEvent> sendCare({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required String message,
    required CareType type,
    String? recordId,
    String? parentCareId,
  }) async {
    final normalized = message.trim();
    if (normalized.isEmpty || normalized.length > 80) {
      throw ArgumentError('关心的话请输入 1–80 个字符');
    }
    final reference = _events.doc();
    final now = DateTime.now();
    final write = reference.set({
      'group_id': groupId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'record_id': recordId,
      'parent_care_id': parentCareId,
      'care_type': type.name,
      'message': normalized,
      'created_at': FieldValue.serverTimestamp(),
      'read_at': null,
    });
    await write.timeout(const Duration(seconds: 2), onTimeout: () {});
    // Push delivery belongs in a trusted Cloud Function triggered by this write.
    return CareEvent(
      id: reference.id,
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      recordId: recordId,
      parentCareId: parentCareId,
      type: type,
      message: normalized,
      createdAt: now,
    );
  }

  @override
  Future<void> markRead({
    required String careId,
    required String viewerId,
  }) async {
    final reference = _events.doc(careId);
    await _firestore.runTransaction((transaction) async {
      final event = await transaction.get(reference);
      if (event.data()?['to_user_id'] != viewerId) return;
      transaction.update(reference, {'read_at': FieldValue.serverTimestamp()});
    });
  }

  CareEvent _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return CareEvent(
      id: document.id,
      groupId: data['group_id'] as String,
      fromUserId: data['from_user_id'] as String,
      toUserId: data['to_user_id'] as String,
      recordId: data['record_id'] as String?,
      parentCareId: data['parent_care_id'] as String?,
      type: CareType.values.byName(data['care_type'] as String),
      message: data['message'] as String,
      createdAt:
          data['created_at'] is Timestamp
              ? (data['created_at'] as Timestamp).toDate()
              : DateTime.now(),
      readAt:
          data['read_at'] is Timestamp
              ? (data['read_at'] as Timestamp).toDate()
              : null,
    );
  }
}
