import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/health_models.dart';
import '../../domain/health_repository.dart';
import '../state/health_action_controller.dart';
import '../state/health_action_state.dart';

typedef HealthRecordsQuery = ({String familyId, String userId, int days});
typedef UserHealthRecordsQuery = ({String userId, HealthRange range});
typedef GroupHealthRecordsQuery = ({String groupId, HealthRange range});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  throw UnimplementedError('HealthRepository must be overridden at startup.');
});

final healthRecordsProvider =
    StreamProvider.family<List<HealthRecord>, HealthRecordsQuery>((ref, query) {
      return ref
          .watch(healthRepositoryProvider)
          .watchRecords(
            familyId: query.familyId,
            userId: query.userId,
            days: query.days,
          );
    });

final userHealthRecordsProvider =
    StreamProvider.family<List<HealthRecord>, UserHealthRecordsQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(healthRepositoryProvider)
          .watchUserRecords(userId: query.userId, range: query.range);
    });

final groupSharedRecordsProvider =
    StreamProvider.family<List<HealthRecord>, GroupHealthRecordsQuery>((
      ref,
      query,
    ) {
      return ref
          .watch(healthRepositoryProvider)
          .watchGroupSharedRecords(groupId: query.groupId, range: query.range);
    });

final healthTrendProvider = userHealthRecordsProvider;

final healthActionControllerProvider =
    NotifierProvider<HealthActionController, HealthActionState>(
      HealthActionController.new,
    );
