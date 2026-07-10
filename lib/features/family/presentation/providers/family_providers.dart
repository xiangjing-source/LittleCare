import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/family_models.dart';
import '../../domain/family_repository.dart';
import '../state/family_action_controller.dart';
import '../state/family_action_state.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  throw UnimplementedError('FamilyRepository must be overridden at startup.');
});

final currentFamilyIdProvider = StreamProvider.family<String?, String>(
  (ref, userId) =>
      ref.watch(familyRepositoryProvider).watchCurrentFamilyId(userId),
);

final familySnapshotProvider =
    StreamProvider.family<FamilySnapshot, ({String familyId, String viewerId})>(
      (ref, query) => ref
          .watch(familyRepositoryProvider)
          .watchFamily(familyId: query.familyId, viewerId: query.viewerId),
    );

final familyActionControllerProvider =
    NotifierProvider<FamilyActionController, FamilyActionState>(
      FamilyActionController.new,
    );
