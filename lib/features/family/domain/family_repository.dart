import 'family_models.dart';

abstract interface class FamilyRepository {
  Stream<String?> watchCurrentFamilyId(String userId);

  Stream<FamilySnapshot> watchFamily({
    required String familyId,
    required String viewerId,
  });

  Future<void> createFamily({required String userId});

  Future<void> joinFamily({required String userId, required String inviteCode});

  Future<void> setNickname({
    required String familyId,
    required String fromUserId,
    required String toUserId,
    required String nickname,
  });
}
