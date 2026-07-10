import 'app_user.dart';

typedef CodeSentCallback =
    void Function(String verificationId, int? resendToken);
typedef AuthErrorCallback = void Function(Object error);

abstract interface class PhoneAuthRepository {
  Stream<AppUser?> authStateChanges();

  Future<AppUser> startSession({
    required String displayName,
    String? phoneNumber,
    String? existingUserId,
    String? recoveryCode,
    bool recoverExisting = false,
  });

  Future<void> requestVerificationCode({
    required String phoneNumber,
    required CodeSentCallback onCodeSent,
    required void Function() onAutoVerified,
    required AuthErrorCallback onError,
    int? forceResendingToken,
  });

  Future<void> confirmVerificationCode({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();
}
