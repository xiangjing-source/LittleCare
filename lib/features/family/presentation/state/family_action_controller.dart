import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/family_failure.dart';
import '../providers/family_providers.dart';
import 'family_action_state.dart';

class FamilyActionController extends Notifier<FamilyActionState> {
  @override
  FamilyActionState build() => const FamilyActionState();

  Future<bool> createFamily(String userId) {
    return _run(
      () => ref.read(familyRepositoryProvider).createFamily(userId: userId),
      successMessage: '群组创建好了，可以邀请重要的人加入',
    );
  }

  Future<bool> joinFamily({
    required String userId,
    required String inviteCode,
  }) {
    return _run(
      () => ref
          .read(familyRepositoryProvider)
          .joinFamily(userId: userId, inviteCode: inviteCode),
      successMessage: '已经和群组成员连接上了',
    );
  }

  Future<bool> setNickname({
    required String familyId,
    required String fromUserId,
    required String toUserId,
    required String nickname,
  }) {
    return _run(
      () => ref
          .read(familyRepositoryProvider)
          .setNickname(
            familyId: familyId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            nickname: nickname,
          ),
      successMessage: '称呼已经保存',
    );
  }

  Future<bool> _run(
    Future<void> Function() action, {
    required String successMessage,
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
        errorMessage: error is FamilyFailure ? error.message : '暂时没有完成，请稍后再试',
      );
      return false;
    }
  }

  void clearMessage() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }
}
