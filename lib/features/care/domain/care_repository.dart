import 'care_models.dart';

abstract interface class CareRepository {
  Stream<List<CareEvent>> watchGroupEvents({
    required String groupId,
    required String viewerId,
  });

  Future<CareEvent> sendCare({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required String message,
    required CareType type,
    String? recordId,
    String? parentCareId,
  });

  Future<void> markRead({required String careId, required String viewerId});
}
