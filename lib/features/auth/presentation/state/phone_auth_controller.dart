import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/auth_failure.dart';
import '../../domain/phone_number_validator.dart';
import '../providers/auth_providers.dart';
import 'phone_auth_state.dart';

class PhoneAuthController extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  Future<void> startSession({
    required String displayName,
    String? phoneNumber,
    String? existingUserId,
    String? recoveryCode,
    bool recoverExisting = false,
  }) async {
    final normalizedName = displayName.trim();
    final normalizedPhone =
        phoneNumber?.trim().isEmpty ?? true
            ? ''
            : PhoneNumberValidator.normalize(phoneNumber!);
    final normalizedUserId = existingUserId?.trim();
    final normalizedRecoveryCode = _normalizeRecoveryCode(recoveryCode ?? '');

    if (!recoverExisting &&
        (normalizedName.isEmpty || normalizedName.length > 12)) {
      state = state.copyWith(errorMessage: '称呼请输入 1-12 个字符');
      return;
    }
    if (phoneNumber?.trim().isNotEmpty ?? false) {
      final phoneError = PhoneNumberValidator.validate(phoneNumber!);
      if (phoneError != null) {
        state = state.copyWith(errorMessage: phoneError);
        return;
      }
    }
    if (recoverExisting) {
      if (normalizedPhone.isEmpty || normalizedRecoveryCode.isEmpty) {
        state = state.copyWith(errorMessage: '请同时输入手机号和恢复码');
        return;
      }
    }
    if ((normalizedUserId?.isNotEmpty ?? false) &&
        normalizedUserId!.length < 4) {
      state = state.copyWith(errorMessage: '用户ID看起来太短，请检查后再输入');
      return;
    }

    state = state.copyWith(
      displayName: normalizedName,
      phoneNumber: normalizedPhone,
      existingUserId: normalizedUserId ?? '',
      recoveryCode: normalizedRecoveryCode,
      isLoading: true,
      errorMessage: null,
    );
    try {
      await ref
          .read(authRepositoryProvider)
          .startSession(
            displayName: normalizedName.isEmpty ? '我' : normalizedName,
            phoneNumber: normalizedPhone.isEmpty ? null : normalizedPhone,
            existingUserId:
                normalizedUserId?.isEmpty ?? true ? null : normalizedUserId,
            recoveryCode:
                normalizedRecoveryCode.isEmpty ? null : normalizedRecoveryCode,
            recoverExisting: recoverExisting,
          );
      ref.invalidate(authUserProvider);
      state = state.copyWith(isLoading: false);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(error),
      );
    }
  }

  Future<void> sendCode(String rawPhoneNumber) async {
    final validationError = PhoneNumberValidator.validate(rawPhoneNumber);
    if (validationError != null) {
      state = state.copyWith(errorMessage: validationError);
      return;
    }

    final phoneNumber = PhoneNumberValidator.normalize(rawPhoneNumber);
    state = state.copyWith(
      phoneNumber: phoneNumber,
      isLoading: true,
      errorMessage: null,
    );

    await _requestCode(phoneNumber: phoneNumber);
  }

  Future<void> resendCode() async {
    if (state.phoneNumber.isEmpty || state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    await _requestCode(
      phoneNumber: state.phoneNumber,
      forceResendingToken: state.resendToken,
    );
  }

  Future<void> _requestCode({
    required String phoneNumber,
    int? forceResendingToken,
  }) async {
    try {
      await ref
          .read(authRepositoryProvider)
          .requestVerificationCode(
            phoneNumber: phoneNumber,
            forceResendingToken: forceResendingToken,
            onCodeSent: (verificationId, resendToken) {
              state = state.copyWith(
                step: PhoneAuthStep.enterCode,
                verificationId: verificationId,
                resendToken: resendToken,
                isLoading: false,
                errorMessage: null,
              );
            },
            onAutoVerified: () {
              state = state.copyWith(isLoading: false, errorMessage: null);
            },
            onError: (error) {
              state = state.copyWith(
                isLoading: false,
                errorMessage: _friendlyMessage(error),
              );
            },
          );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(error),
      );
    }
  }

  Future<void> confirmCode(String smsCode) async {
    final validationError = SmsCodeValidator.validate(smsCode);
    if (validationError != null) {
      state = state.copyWith(errorMessage: validationError);
      return;
    }

    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(errorMessage: '验证已失效，请重新获取验证码');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await ref
          .read(authRepositoryProvider)
          .confirmVerificationCode(
            verificationId: verificationId,
            smsCode: smsCode,
          );
      ref.invalidate(authUserProvider);
      state = state.copyWith(isLoading: false);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyMessage(error),
      );
    }
  }

  void changePhoneNumber() {
    state = PhoneAuthState(displayName: state.displayName);
  }

  String _friendlyMessage(Object error) {
    if (error case AuthFailure(:final message)) return message;
    return '暂时无法登录，请稍后再试';
  }

  String _normalizeRecoveryCode(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
}
