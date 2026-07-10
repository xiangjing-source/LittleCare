import 'dart:async';
import 'dart:convert';

import '../../../core/storage/demo_storage_contract.dart';
import '../domain/care_models.dart';
import '../domain/care_repository.dart';

class DemoCareRepository implements CareRepository {
  DemoCareRepository({DemoStorage? storage, String? initialState})
    : _storage = storage {
    if (initialState != null) _restore(initialState);
  }

  static const storageKey = 'demo_care_state_v2';

  final DemoStorage? _storage;
  final Map<String, CareEvent> _events = {};
  final StreamController<String> _updates = StreamController.broadcast();

  @override
  Stream<List<CareEvent>> watchGroupEvents({
    required String groupId,
    required String viewerId,
  }) async* {
    yield _forGroup(groupId, viewerId);
    yield* _updates.stream
        .where((updatedGroupId) => updatedGroupId == groupId)
        .map((_) => _forGroup(groupId, viewerId));
  }

  List<CareEvent> _forGroup(String groupId, String viewerId) {
    final items =
        _events.values
            .where(
              (event) =>
                  event.groupId == groupId &&
                  (event.fromUserId == viewerId || event.toUserId == viewerId),
            )
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List.unmodifiable(items);
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
    final now = DateTime.now();
    final event = CareEvent(
      id: 'care-${now.microsecondsSinceEpoch}',
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      recordId: recordId,
      parentCareId: parentCareId,
      type: type,
      message: normalized,
      createdAt: now,
    );
    _events[event.id] = event;
    await _persist();
    _updates.add(groupId);
    return event;
  }

  @override
  Future<void> markRead({
    required String careId,
    required String viewerId,
  }) async {
    final event = _events[careId];
    if (event == null || event.toUserId != viewerId || event.isRead) return;
    _events[careId] = CareEvent(
      id: event.id,
      groupId: event.groupId,
      fromUserId: event.fromUserId,
      toUserId: event.toUserId,
      recordId: event.recordId,
      parentCareId: event.parentCareId,
      type: event.type,
      message: event.message,
      createdAt: event.createdAt,
      readAt: DateTime.now(),
    );
    await _persist();
    _updates.add(event.groupId);
  }

  Future<void> _persist() async {
    await _storage?.setString(storageKey, exportState());
  }

  String exportState() => jsonEncode({
    'events':
        _events.values
            .map(
              (event) => {
                'id': event.id,
                'group_id': event.groupId,
                'from_user_id': event.fromUserId,
                'to_user_id': event.toUserId,
                'record_id': event.recordId,
                'parent_care_id': event.parentCareId,
                'care_type': event.type.name,
                'message': event.message,
                'created_at': event.createdAt.toIso8601String(),
                'read_at': event.readAt?.toIso8601String(),
              },
            )
            .toList(),
  });

  void _restore(String encoded) {
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      for (final raw in (data['events'] as List<dynamic>? ?? const [])) {
        final item = Map<String, dynamic>.from(raw as Map);
        final event = CareEvent(
          id: item['id'] as String,
          groupId: item['group_id'] as String,
          fromUserId: item['from_user_id'] as String,
          toUserId: item['to_user_id'] as String,
          recordId: item['record_id'] as String?,
          parentCareId: item['parent_care_id'] as String?,
          type: CareType.values.byName(item['care_type'] as String),
          message: item['message'] as String,
          createdAt: DateTime.parse(item['created_at'] as String),
          readAt:
              item['read_at'] == null
                  ? null
                  : DateTime.parse(item['read_at'] as String),
        );
        _events[event.id] = event;
      }
    } catch (_) {
      _events.clear();
    }
  }
}
