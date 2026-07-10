import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/care_models.dart';
import '../../domain/care_repository.dart';

final careRepositoryProvider = Provider<CareRepository>((ref) {
  throw UnimplementedError('CareRepository must be overridden at startup.');
});

final careEventsProvider =
    StreamProvider.family<List<CareEvent>, ({String groupId, String viewerId})>(
      (ref, query) {
        return ref
            .watch(careRepositoryProvider)
            .watchGroupEvents(groupId: query.groupId, viewerId: query.viewerId);
      },
    );
