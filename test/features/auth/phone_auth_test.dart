import 'package:family_health_monitor/features/auth/domain/app_user.dart';
import 'package:family_health_monitor/features/auth/domain/auth_failure.dart';
import 'package:family_health_monitor/features/auth/domain/phone_auth_repository.dart';
import 'package:family_health_monitor/features/auth/domain/phone_number_validator.dart';
import 'package:family_health_monitor/features/auth/presentation/providers/auth_providers.dart';
import 'package:family_health_monitor/features/auth/presentation/state/phone_auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumberValidator', () {
    test('normalizes a mainland China phone number to E.164', () {
      expect(PhoneNumberValidator.normalize('138 0013 8000'), '+8613800138000');
      expect(PhoneNumberValidator.validate('138 0013 8000'), isNull);
    });

    test('keeps a valid international E.164 phone number', () {
      expect(
        PhoneNumberValidator.normalize('+44 7700 900123'),
        '+447700900123',
      );
      expect(PhoneNumberValidator.validate('+44 7700 900123'), isNull);
    });

    test('rejects invalid phone numbers and SMS codes', () {
      expect(PhoneNumberValidator.validate('123'), isNotNull);
      expect(SmsCodeValidator.validate('12345'), isNotNull);
      expect(SmsCodeValidator.validate('123456'), isNull);
    });
  });

  group('PhoneAuthController', () {
    test('moves to code entry after a verification code is sent', () async {
      final repository = _FakePhoneAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(phoneAuthControllerProvider.notifier)
          .sendCode('13800138000');

      final state = container.read(phoneAuthControllerProvider);
      expect(repository.requestedPhone, '+8613800138000');
      expect(state.step, PhoneAuthStep.enterCode);
      expect(state.verificationId, 'verification-id');
      expect(state.isLoading, isFalse);
    });

    test('confirms a valid six digit code', () async {
      final repository = _FakePhoneAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(phoneAuthControllerProvider.notifier);

      await controller.sendCode('13800138000');
      await controller.confirmCode('123456');

      expect(repository.confirmedCode, '123456');
      expect(container.read(phoneAuthControllerProvider).errorMessage, isNull);
    });

    test('shows a friendly repository failure', () async {
      final repository = _FakePhoneAuthRepository(shouldFail: true);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(phoneAuthControllerProvider.notifier);

      await controller.sendCode('13800138000');
      await controller.confirmCode('123456');

      expect(
        container.read(phoneAuthControllerProvider).errorMessage,
        '验证码不正确',
      );
    });

    test(
      'recovers with phone and normalized recovery code without display name',
      () async {
        final repository = _FakePhoneAuthRepository();
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        await container
            .read(phoneAuthControllerProvider.notifier)
            .startSession(
              displayName: '',
              phoneNumber: '138 0013 8000',
              recoveryCode: ' test-2026 ',
              recoverExisting: true,
            );

        expect(repository.recoveredExisting, isTrue);
        expect(repository.startedDisplayName, '我');
        expect(repository.startedPhone, '+8613800138000');
        expect(repository.startedRecoveryCode, 'TEST2026');
        expect(
          container.read(phoneAuthControllerProvider).errorMessage,
          isNull,
        );
      },
    );
  });
}

class _FakePhoneAuthRepository implements PhoneAuthRepository {
  _FakePhoneAuthRepository({this.shouldFail = false});

  final bool shouldFail;
  String? requestedPhone;
  String? confirmedCode;
  String? startedDisplayName;
  String? startedPhone;
  String? startedRecoveryCode;
  bool recoveredExisting = false;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AppUser> startSession({
    required String displayName,
    String? phoneNumber,
    String? existingUserId,
    String? recoveryCode,
    bool recoverExisting = false,
  }) async {
    if (shouldFail) {
      throw const AuthFailure('无法进入', code: 'failed');
    }
    startedDisplayName = displayName;
    startedPhone = phoneNumber;
    startedRecoveryCode = recoveryCode;
    recoveredExisting = recoverExisting;
    return AppUser(
      id: existingUserId ?? 'FH-TEST01',
      displayName: displayName,
      recoveryCode: recoveryCode ?? 'TEST2026',
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<void> requestVerificationCode({
    required String phoneNumber,
    required CodeSentCallback onCodeSent,
    required void Function() onAutoVerified,
    required AuthErrorCallback onError,
    int? forceResendingToken,
  }) async {
    requestedPhone = phoneNumber;
    onCodeSent('verification-id', 7);
  }

  @override
  Future<void> confirmVerificationCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (shouldFail) {
      throw const AuthFailure('验证码不正确', code: 'invalid-code');
    }
    confirmedCode = smsCode;
  }

  @override
  Future<void> signOut() async {}
}
