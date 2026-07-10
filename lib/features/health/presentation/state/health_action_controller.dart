import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/health_failure.dart';
import '../../domain/health_models.dart';
import '../providers/health_providers.dart';
import 'health_action_state.dart';

class HealthActionController extends Notifier<HealthActionState> {
  @override
  HealthActionState build() => const HealthActionState();

  Future<bool> addRecord({
    required String familyId,
    required HealthRecordDraft draft,
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await ref
          .read(healthRepositoryProvider)
          .addRecord(familyId: familyId, draft: draft);
      state = state.copyWith(isLoading: false, successMessage: '健康记录已经保存');
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error is HealthFailure ? error.message : '暂时没有保存成功，请稍后再试',
      );
      return false;
    }
  }

  Future<bool> saveRecord(HealthRecordDraft draft) async {
    return _run(() => ref.read(healthRepositoryProvider).saveRecord(draft));
  }

  Future<bool> updateRecord(HealthRecordDraft draft) async {
    return _run(() => ref.read(healthRepositoryProvider).updateRecord(draft));
  }

  Future<bool> deleteRecord({
    required String recordId,
    required String ownerUserId,
  }) async {
    return _run(
      () => ref
          .read(healthRepositoryProvider)
          .deleteRecord(recordId: recordId, ownerUserId: ownerUserId),
      successMessage: '这条记录已经删除',
    );
  }

  Future<bool> _run(
    Future<Object?> Function() action, {
    String successMessage = '已经帮你记下来了',
  }) async {
    if (state.isLoading) return false;
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );
    try {
      await action();
      state = state.copyWith(isLoading: false, successMessage: successMessage);
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error is HealthFailure ? error.message : '暂时没有保存成功，请稍后再试',
      );
      return false;
    }
  }
}
