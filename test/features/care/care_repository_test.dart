import 'package:family_health_monitor/features/care/data/demo_care_repository.dart';
import 'package:family_health_monitor/features/care/domain/care_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoCareRepository', () {
    test('ordinary viewing does not create a care event', () async {
      final repository = DemoCareRepository();

      expect(
        await repository
            .watchGroupEvents(groupId: 'group-a', viewerId: 'user-a')
            .first,
        isEmpty,
      );
    });

    test('care can be sent without a health record', () async {
      final repository = DemoCareRepository();
      final event = await repository.sendCare(
        groupId: 'group-a',
        fromUserId: 'user-a',
        toUserId: 'user-b',
        message: '最近辛苦了，记得休息',
        type: CareType.preset,
      );

      expect(event.recordId, isNull);
      expect(
        await repository
            .watchGroupEvents(groupId: 'group-a', viewerId: 'user-b')
            .first,
        hasLength(1),
      );
    });

    test('a response links to the original event', () async {
      final repository = DemoCareRepository();
      final parent = await repository.sendCare(
        groupId: 'group-a',
        fromUserId: 'user-a',
        toUserId: 'user-b',
        message: '给你一个拥抱',
        type: CareType.preset,
      );
      final response = await repository.sendCare(
        groupId: 'group-a',
        fromUserId: 'user-b',
        toUserId: 'user-a',
        message: '收到啦',
        type: CareType.response,
        parentCareId: parent.id,
      );

      expect(response.parentCareId, parent.id);
      expect(response.type, CareType.response);
    });

    test('care events stay isolated by group', () async {
      final repository = DemoCareRepository();
      await repository.sendCare(
        groupId: 'group-a',
        fromUserId: 'user-a',
        toUserId: 'user-b',
        message: '有需要随时找我',
        type: CareType.preset,
      );

      expect(
        await repository
            .watchGroupEvents(groupId: 'group-b', viewerId: 'user-b')
            .first,
        isEmpty,
      );
    });
  });
}
