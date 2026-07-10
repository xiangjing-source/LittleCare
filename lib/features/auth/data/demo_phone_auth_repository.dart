import 'dart:async';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/phone_auth_repository.dart';

class DemoPhoneAuthRepository implements PhoneAuthRepository {
  DemoPhoneAuthRepository();

  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  String? _pendingPhoneNumber;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _authStateController.stream;
  }

  @override
  Future<AppUser> startSession({
    required String displayName,
    String? phoneNumber,
    String? existingUserId,
    String? recoveryCode,
    bool recoverExisting = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final recoveredByPhone =
        recoverExisting && phoneNumber != null && phoneNumber.isNotEmpty;
    _currentUser = AppUser(
      id:
          existingUserId?.trim().isNotEmpty == true
              ? existingUserId!.trim()
              : recoveredByPhone
              ? _stableUserIdFor(phoneNumber)
              : 'FH-DEMO01',
      displayName: displayName.trim(),
      recoveryCode:
          recoveryCode?.trim().isNotEmpty == true
              ? recoveryCode!.trim()
              : 'DEMO2026',
      phoneNumber: phoneNumber,
    );
    _authStateController.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> requestVerificationCode({
    required String phoneNumber,
    required CodeSentCallback onCodeSent,
    required void Function() onAutoVerified,
    required AuthErrorCallback onError,
    int? forceResendingToken,
  }) async {
    _pendingPhoneNumber = phoneNumber;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    onCodeSent('demo-verification-id', 1);
  }

  @override
  Future<void> confirmVerificationCode({
    required String verificationId,
    required String smsCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (verificationId != 'demo-verification-id' || smsCode != '123456') {
      throw const AuthFailure('验证码不正确，请输入 123456', code: 'invalid-code');
    }

    final phoneNumber = _pendingPhoneNumber;
    if (phoneNumber == null) {
      throw const AuthFailure('验证已失效，请重新获取验证码', code: 'expired');
    }

    _currentUser = AppUser(
      id: _stableUserIdFor(phoneNumber),
      displayName: '我',
      phoneNumber: phoneNumber,
    );
    _authStateController.add(_currentUser);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _pendingPhoneNumber = null;
    _authStateController.add(null);
  }

  Future<void> dispose() => _authStateController.close();

  String _stableUserIdFor(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.endsWith('13900000001')) return 'demo-user';
    if (digits.endsWith('13900000002')) return 'demo-user-2';
    if (digits.endsWith('13900000003')) return 'demo-user-3';
    return digits.isEmpty ? 'demo-user' : 'demo-user-$digits';
  }
}
