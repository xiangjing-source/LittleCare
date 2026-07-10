import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/storage/demo_storage.dart';
import 'features/auth/data/firebase_phone_auth_repository.dart';
import 'features/auth/domain/app_user.dart';
import 'features/auth/domain/auth_failure.dart';
import 'features/auth/domain/phone_auth_repository.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/care/data/demo_care_repository.dart';
import 'features/care/data/firebase_care_repository.dart';
import 'features/care/domain/care_repository.dart';
import 'features/care/presentation/providers/care_providers.dart';
import 'features/family/data/demo_family_repository.dart';
import 'features/family/data/firebase_family_repository.dart';
import 'features/family/domain/family_repository.dart';
import 'features/family/presentation/providers/family_providers.dart';
import 'features/group/data/demo_group_repository.dart';
import 'features/group/data/firebase_group_repository.dart';
import 'features/group/domain/group_repository.dart';
import 'features/group/presentation/providers/group_providers.dart';
import 'features/health/data/demo_health_repository.dart';
import 'features/health/data/firebase_health_repository.dart';
import 'features/health/domain/health_repository.dart';
import 'features/health/presentation/providers/health_providers.dart';
import 'features/notification/data/demo_notification_repository.dart';
import 'features/notification/data/firebase_notification_repository.dart';
import 'features/notification/domain/notification_repository.dart';
import 'features/notification/presentation/providers/notification_providers.dart';

const _useFirebase = bool.fromEnvironment('USE_FIREBASE');
const _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDswuHSGGkcAF-_eOPzqZmBS786hiIJ9CI',
  appId: '1:451084972347:android:7a9547871813f8f7b6c71e',
  messagingSenderId: '451084972347',
  projectId: 'littlecare-83003',
  storageBucket: 'littlecare-83003.firebasestorage.app',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final PhoneAuthRepository authRepository;
  final FamilyRepository familyRepository;
  final GroupRepository groupRepository;
  final HealthRepository healthRepository;
  final CareRepository careRepository;
  final NotificationPreferencesRepository notificationRepository;
  final PushNotificationRegistrationService pushNotificationService;
  if (_useFirebase) {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: kIsWeb ? _webFirebaseOptions : null,
      );
    }
    authRepository = FirebasePhoneAuthRepository(
      FirebaseAuth.instance,
      FirebaseFirestore.instance,
    );
    familyRepository = FirebaseFamilyRepository(FirebaseFirestore.instance);
    groupRepository = FirebaseGroupRepository(FirebaseFirestore.instance);
    healthRepository = FirebaseHealthRepository(FirebaseFirestore.instance);
    careRepository = FirebaseCareRepository(FirebaseFirestore.instance);
    notificationRepository = FirebaseNotificationPreferencesRepository(
      FirebaseFirestore.instance,
    );
    pushNotificationService = const NoopPushNotificationRegistrationService();
  } else {
    final preferences = createDemoStorage();
    final legacyFamilyState = await preferences.getString(
      DemoFamilyRepository.storageKey,
    );
    authRepository = _PersistentDemoPhoneAuthRepository(
      preferences: preferences,
      initialPhoneNumber: await preferences.getString(_demoAuthStorageKey),
    );
    familyRepository = DemoFamilyRepository(
      preferences: preferences,
      initialState: legacyFamilyState,
    );
    groupRepository = DemoGroupRepository(
      storage: preferences,
      initialState: await preferences.getString(DemoGroupRepository.storageKey),
      legacyFamilyState: legacyFamilyState,
    );
    healthRepository = DemoHealthRepository(
      preferences: preferences,
      initialState: await preferences.getString(
        DemoHealthRepository.storageKey,
      ),
      legacyState: await preferences.getString(
        DemoHealthRepository.legacyStorageKey,
      ),
      legacyFamilyState: legacyFamilyState,
    );
    careRepository = DemoCareRepository(
      storage: preferences,
      initialState: await preferences.getString(DemoCareRepository.storageKey),
    );
    notificationRepository = DemoNotificationPreferencesRepository(
      storage: preferences,
      initialState: await preferences.getString(
        DemoNotificationPreferencesRepository.storageKey,
      ),
    );
    pushNotificationService = const NoopPushNotificationRegistrationService();
  }

  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        familyRepositoryProvider.overrideWithValue(familyRepository),
        groupRepositoryProvider.overrideWithValue(groupRepository),
        healthRepositoryProvider.overrideWithValue(healthRepository),
        careRepositoryProvider.overrideWithValue(careRepository),
        notificationPreferencesRepositoryProvider.overrideWithValue(
          notificationRepository,
        ),
        pushNotificationRegistrationServiceProvider.overrideWithValue(
          pushNotificationService,
        ),
        firebaseEnabledProvider.overrideWithValue(_useFirebase),
      ],
      child: const FamilyHealthApp(),
    ),
  );
}

const _demoAuthStorageKey = 'demo_auth_phone_v1';
const _demoIdentityStorageKey = 'demo_auth_identity_v1';

class _PersistentDemoPhoneAuthRepository implements PhoneAuthRepository {
  _PersistentDemoPhoneAuthRepository({
    required DemoStorage preferences,
    String? initialPhoneNumber,
  }) : _preferences = preferences,
       _currentUser =
           initialPhoneNumber == null
               ? null
               : _userForPhone(initialPhoneNumber);

  final DemoStorage _preferences;
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  AppUser? _currentUser;
  String? _pendingPhoneNumber;

  @override
  Stream<AppUser?> authStateChanges() async* {
    if (_currentUser != null && _currentUser!.recoveryCode == null) {
      final profile = await _preferences.getString(_demoIdentityStorageKey);
      if (profile != null) _currentUser = _decodeProfile(profile);
    }
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
    final savedProfile = await _preferences.getString(_demoIdentityStorageKey);
    final savedUser =
        savedProfile == null ? null : _decodeProfile(savedProfile);
    if (recoverExisting) {
      final normalizedCode = _normalizeRecoveryCode(recoveryCode ?? '');
      if (phoneNumber == null ||
          phoneNumber.isEmpty ||
          normalizedCode.isEmpty ||
          savedUser == null ||
          savedUser.phoneNumber != phoneNumber ||
          _normalizeRecoveryCode(savedUser.recoveryCode ?? '') !=
              normalizedCode) {
        throw const AuthFailure('手机号或恢复码不正确', code: 'bad-recovery');
      }
      _currentUser = savedUser;
      await _preferences.setString(_demoAuthStorageKey, phoneNumber);
      _authStateController.add(_currentUser);
      return _currentUser!;
    }

    final userId =
        existingUserId?.trim().isNotEmpty == true
            ? existingUserId!.trim()
            : _newPublicUserId();
    final code = _newRecoveryCode();
    _currentUser = AppUser(
      id: userId,
      displayName: displayName.trim(),
      recoveryCode: code,
      phoneNumber: phoneNumber,
    );
    await _preferences.setString(
      _demoIdentityStorageKey,
      jsonEncode({
        'id': _currentUser!.id,
        'display_name': _currentUser!.displayName,
        'recovery_code': _currentUser!.recoveryCode,
        'phone_number': _currentUser!.phoneNumber,
      }),
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
    await Future<void>.delayed(const Duration(milliseconds: 350));
    onCodeSent('demo-verification-id', 1);
  }

  @override
  Future<void> confirmVerificationCode({
    required String verificationId,
    required String smsCode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (verificationId != 'demo-verification-id' || smsCode != '123456') {
      throw const AuthFailure('验证码不正确，请输入 123456', code: 'invalid-code');
    }
    final phoneNumber = _pendingPhoneNumber;
    if (phoneNumber == null) {
      throw const AuthFailure('验证已失效，请重新获取验证码', code: 'expired');
    }
    _currentUser = _userForPhone(phoneNumber);
    await _preferences.setString(_demoAuthStorageKey, phoneNumber);
    _authStateController.add(_currentUser);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _pendingPhoneNumber = null;
    await _preferences.remove(_demoAuthStorageKey);
    _authStateController.add(null);
  }

  static AppUser _userForPhone(String phoneNumber) {
    final encoded = base64Url
        .encode(utf8.encode(phoneNumber))
        .replaceAll('=', '');
    return AppUser(
      id: 'demo-$encoded',
      displayName: '我',
      phoneNumber: phoneNumber,
    );
  }

  static AppUser? _decodeProfile(String profile) {
    try {
      final data = jsonDecode(profile) as Map<String, dynamic>;
      return AppUser(
        id: data['id'] as String,
        displayName: data['display_name'] as String? ?? '我',
        recoveryCode: data['recovery_code'] as String?,
        phoneNumber: data['phone_number'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static String _newPublicUserId() => 'FH-${_randomToken(6)}';

  static String _newRecoveryCode() {
    final raw = _randomToken(10);
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8)}';
  }

  static String _randomToken(int length) {
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = math.Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  static String _normalizeRecoveryCode(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
}
