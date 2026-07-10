enum PhoneAuthStep { enterProfile, enterCode }

const _unset = Object();

class PhoneAuthState {
  const PhoneAuthState({
    this.step = PhoneAuthStep.enterProfile,
    this.phoneNumber = '',
    this.displayName = '',
    this.existingUserId = '',
    this.recoveryCode = '',
    this.verificationId,
    this.resendToken,
    this.isLoading = false,
    this.errorMessage,
  });

  final PhoneAuthStep step;
  final String phoneNumber;
  final String displayName;
  final String existingUserId;
  final String recoveryCode;
  final String? verificationId;
  final int? resendToken;
  final bool isLoading;
  final String? errorMessage;

  PhoneAuthState copyWith({
    PhoneAuthStep? step,
    String? phoneNumber,
    String? displayName,
    String? existingUserId,
    String? recoveryCode,
    Object? verificationId = _unset,
    Object? resendToken = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return PhoneAuthState(
      step: step ?? this.step,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      existingUserId: existingUserId ?? this.existingUserId,
      recoveryCode: recoveryCode ?? this.recoveryCode,
      verificationId:
          identical(verificationId, _unset)
              ? this.verificationId
              : verificationId as String?,
      resendToken:
          identical(resendToken, _unset)
              ? this.resendToken
              : resendToken as int?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          identical(errorMessage, _unset)
              ? this.errorMessage
              : errorMessage as String?,
    );
  }
}
