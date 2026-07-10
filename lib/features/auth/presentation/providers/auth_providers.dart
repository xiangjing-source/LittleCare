import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/app_user.dart';
import '../../domain/phone_auth_repository.dart';
import '../state/phone_auth_controller.dart';
import '../state/phone_auth_state.dart';

final authRepositoryProvider = Provider<PhoneAuthRepository>((ref) {
  throw UnimplementedError(
    'PhoneAuthRepository must be overridden at startup.',
  );
});

final firebaseEnabledProvider = Provider<bool>((ref) => false);

final authUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final phoneAuthControllerProvider =
    NotifierProvider<PhoneAuthController, PhoneAuthState>(
      PhoneAuthController.new,
    );
