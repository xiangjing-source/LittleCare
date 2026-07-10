import 'package:family_health_monitor/features/family/data/demo_family_repository.dart';
import 'package:family_health_monitor/features/family/domain/family_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoFamilyRepository', () {
    test('creates a family and emits the new family id', () async {
      final repository = DemoFamilyRepository();
      final familyIds = repository.watchCurrentFamilyId('me').take(2).toList();

      await repository.createFamily(userId: 'me');

      final values = await familyIds;
      expect(values.first, isNull);
      expect(values.last, isNotEmpty);
      final snapshot =
          await repository
              .watchFamily(familyId: values.last!, viewerId: 'me')
              .first;
      expect(snapshot.members.single.userId, 'me');
      expect(snapshot.family.inviteCode, hasLength(6));
    });

    test('joins the seeded demo family with FAMILY1', () async {
      final repository = DemoFamilyRepository();

      await repository.joinFamily(userId: 'me', inviteCode: 'family1');

      final familyId = await repository.watchCurrentFamilyId('me').first;
      final snapshot =
          await repository
              .watchFamily(familyId: familyId!, viewerId: 'me')
              .first;
      expect(snapshot.members, hasLength(2));
      final partner = snapshot.members.singleWhere(
        (member) => member.userId == 'demo-mom',
      );
      expect(snapshot.displayNameFor(partner, 'me'), '伙伴');
    });

    test('stores nicknames as viewer-specific relations', () async {
      final repository = DemoFamilyRepository();
      await repository.joinFamily(userId: 'me', inviteCode: 'FAMILY1');
      final familyId = await repository.watchCurrentFamilyId('me').first;

      await repository.setNickname(
        familyId: familyId!,
        fromUserId: 'me',
        toUserId: 'demo-mom',
        nickname: '母亲大人',
      );

      final snapshot =
          await repository
              .watchFamily(familyId: familyId, viewerId: 'me')
              .first;
      expect(snapshot.nicknames['demo-mom'], '母亲大人');
    });

    test('rejects an unknown invite code', () async {
      final repository = DemoFamilyRepository();

      expect(
        () => repository.joinFamily(userId: 'me', inviteCode: 'WRONG'),
        throwsA(isA<FamilyFailure>()),
      );
    });

    test('keeps a created family invite code after restoration', () async {
      final repository = DemoFamilyRepository();
      await repository.createFamily(userId: 'account-a');
      final familyId = await repository.watchCurrentFamilyId('account-a').first;
      final firstSnapshot =
          await repository
              .watchFamily(familyId: familyId!, viewerId: 'account-a')
              .first;

      final restored = DemoFamilyRepository(
        initialState: repository.exportState(),
      );
      final restoredFamilyId =
          await restored.watchCurrentFamilyId('account-a').first;
      final restoredSnapshot =
          await restored
              .watchFamily(familyId: restoredFamilyId!, viewerId: 'account-a')
              .first;

      expect(restoredFamilyId, familyId);
      expect(
        restoredSnapshot.family.inviteCode,
        firstSnapshot.family.inviteCode,
      );
    });

    test('lets a different account join the restored family', () async {
      final ownerRepository = DemoFamilyRepository();
      await ownerRepository.createFamily(userId: 'account-a');
      final familyId =
          await ownerRepository.watchCurrentFamilyId('account-a').first;
      final ownerSnapshot =
          await ownerRepository
              .watchFamily(familyId: familyId!, viewerId: 'account-a')
              .first;
      final restored = DemoFamilyRepository(
        initialState: ownerRepository.exportState(),
      );

      await restored.joinFamily(
        userId: 'account-b',
        inviteCode: ownerSnapshot.family.inviteCode,
      );

      final joinedFamilyId =
          await restored.watchCurrentFamilyId('account-b').first;
      final joinedSnapshot =
          await restored
              .watchFamily(familyId: joinedFamilyId!, viewerId: 'account-b')
              .first;
      expect(joinedFamilyId, familyId);
      expect(joinedSnapshot.members, hasLength(2));
    });
  });
}
