import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/phone_auth_repository.dart';

class FirebasePhoneAuthRepository implements PhoneAuthRepository {
  FirebasePhoneAuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.authStateChanges().asyncMap(_profileForFirebaseUser);

  @override
  Future<AppUser> startSession({
    required String displayName,
    String? phoneNumber,
    String? existingUserId,
    String? recoveryCode,
    bool recoverExisting = false,
  }) async {
    try {
      final credential =
          _auth.currentUser == null ? await _auth.signInAnonymously() : null;
      final user = credential?.user ?? _auth.currentUser;
      if (user == null) {
        throw const AuthFailure('登录未完成，请重试', code: 'missing-user');
      }

      if (recoverExisting) {
        if (phoneNumber == null ||
            phoneNumber.isEmpty ||
            recoveryCode == null ||
            recoveryCode.trim().isEmpty) {
          throw const AuthFailure('请输入手机号和恢复码', code: 'missing-recovery-key');
        }
        return _recoverExistingProfileByPhone(
          user: user,
          phoneNumber: phoneNumber,
          recoveryCode: recoveryCode,
        );
      }

      final normalizedExistingId = existingUserId?.trim();
      if (normalizedExistingId != null && normalizedExistingId.isNotEmpty) {
        return _recoverExistingProfile(
          user: user,
          publicUserId: normalizedExistingId,
          phoneNumber: phoneNumber,
          recoveryCode: recoveryCode,
        );
      }

      return _createAccountForFirebaseUser(
        user: user,
        displayName: displayName,
        phoneNumber: phoneNumber,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthError(error);
    } on FirebaseException catch (error) {
      throw _mapFirestoreError(error);
    }
  }

  Future<AppUser?> _profileForFirebaseUser(User? user) async {
    if (user == null) return null;

    final binding =
        await _firestore.collection('auth_bindings').doc(user.uid).get();
    final accountId = binding.data()?['account_id'] as String?;
    if (accountId != null && accountId.isNotEmpty) {
      final profile = await _firestore.collection('users').doc(accountId).get();
      if (profile.exists) return _appUserFromProfile(profile);
    }

    final legacyQuery =
        await _firestore
            .collection('users')
            .where('auth_uid', isEqualTo: user.uid)
            .limit(1)
            .get();
    if (legacyQuery.docs.isEmpty) return null;

    final legacyProfile = legacyQuery.docs.first;
    await _bindFirebaseUid(user.uid, legacyProfile.id);
    return _appUserFromProfile(legacyProfile);
  }

  Future<AppUser> _createAccountForFirebaseUser({
    required User user,
    required String displayName,
    String? phoneNumber,
  }) async {
    final existing = await _profileForFirebaseUser(user);
    if (existing != null) return existing;

    final accountId = _newPublicUserId();
    final recoveryCode = _newRecoveryCode();
    final normalizedRecoveryCode = _normalizeRecoveryCode(recoveryCode);
    final reference = _firestore.collection('users').doc(accountId);

    await _firestore.runTransaction((transaction) async {
      transaction.set(reference, {
        'account_id': accountId,
        'public_user_id': accountId,
        'auth_uid': user.uid,
        'display_name': displayName,
        'recovery_phone_normalized': phoneNumber,
        if (phoneNumber != null)
          'recovery_phone_hash': _hashSecret(phoneNumber),
        'recovery_code': recoveryCode,
        'recovery_code_hash': _hashSecret(normalizedRecoveryCode),
        'schema_version': 2,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'last_signed_in_at': FieldValue.serverTimestamp(),
      });
      transaction.set(_firestore.collection('auth_bindings').doc(user.uid), {
        'firebase_uid': user.uid,
        'account_id': accountId,
        'bound_at': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    });

    return AppUser(
      id: accountId,
      displayName: displayName,
      recoveryCode: recoveryCode,
      phoneNumber: phoneNumber,
    );
  }

  Future<AppUser> _recoverExistingProfileByPhone({
    required User user,
    required String phoneNumber,
    required String recoveryCode,
  }) async {
    final normalizedCode = _normalizeRecoveryCode(recoveryCode);
    final phoneHash = _hashSecret(phoneNumber);
    final hashQuery =
        await _firestore
            .collection('users')
            .where('recovery_phone_hash', isEqualTo: phoneHash)
            .limit(10)
            .get();
    final candidates =
        hashQuery.docs.isNotEmpty
            ? hashQuery.docs
            : (await _firestore
                    .collection('users')
                    .where('recovery_phone', isEqualTo: phoneNumber)
                    .limit(10)
                    .get())
                .docs;

    for (final document in candidates) {
      if (_matchesRecoveryCode(document.data(), normalizedCode)) {
        return _recoverExistingProfile(
          user: user,
          publicUserId: document.id,
          phoneNumber: phoneNumber,
          recoveryCode: recoveryCode,
        );
      }
    }

    throw const AuthFailure('手机号或恢复码不正确', code: 'bad-recovery');
  }

  Future<AppUser> _recoverExistingProfile({
    required User user,
    required String publicUserId,
    String? phoneNumber,
    String? recoveryCode,
  }) async {
    final reference = _firestore.collection('users').doc(publicUserId);
    final snapshot = await reference.get();
    if (!snapshot.exists) {
      throw const AuthFailure('手机号或恢复码不正确', code: 'not-found');
    }

    final data = snapshot.data() ?? const <String, dynamic>{};
    final normalizedCode = _normalizeRecoveryCode(recoveryCode ?? '');
    if (!_matchesRecoveryCode(data, normalizedCode)) {
      throw const AuthFailure('手机号或恢复码不正确', code: 'bad-recovery-code');
    }

    await _firestore.runTransaction((transaction) async {
      transaction.set(_firestore.collection('auth_bindings').doc(user.uid), {
        'firebase_uid': user.uid,
        'account_id': publicUserId,
        'bound_at': FieldValue.serverTimestamp(),
        'status': 'active',
      });
      transaction.update(reference, {
        'auth_uid': user.uid,
        if (phoneNumber != null) ...{
          'recovery_phone_normalized': phoneNumber,
          'recovery_phone_hash': _hashSecret(phoneNumber),
        },
        if (recoveryCode != null && recoveryCode.trim().isNotEmpty)
          'recovery_code': recoveryCode.trim().toUpperCase(),
        'recovery_code_hash': _hashSecret(normalizedCode),
        'schema_version': 2,
        'updated_at': FieldValue.serverTimestamp(),
        'last_signed_in_at': FieldValue.serverTimestamp(),
      });
    });

    return AppUser(
      id:
          (data['account_id'] as String?) ??
          (data['public_user_id'] as String?) ??
          publicUserId,
      displayName: (data['display_name'] as String?) ?? '我',
      recoveryCode: data['recovery_code'] as String?,
      phoneNumber:
          phoneNumber ??
          data['recovery_phone_normalized'] as String? ??
          data['recovery_phone'] as String?,
    );
  }

  AppUser _appUserFromProfile(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return AppUser(id: snapshot.id, displayName: '我');
    return AppUser(
      id:
          (data['account_id'] as String?) ??
          (data['public_user_id'] as String?) ??
          snapshot.id,
      displayName: (data['display_name'] as String?) ?? '我',
      recoveryCode: data['recovery_code'] as String?,
      phoneNumber:
          data['recovery_phone_normalized'] as String? ??
          data['recovery_phone'] as String? ??
          data['phone'] as String?,
    );
  }

  Future<void> _bindFirebaseUid(String firebaseUid, String accountId) {
    return _firestore.collection('auth_bindings').doc(firebaseUid).set({
      'firebase_uid': firebaseUid,
      'account_id': accountId,
      'bound_at': FieldValue.serverTimestamp(),
      'status': 'active',
    }, SetOptions(merge: true));
  }

  bool _matchesRecoveryCode(Map<String, dynamic> data, String normalizedCode) {
    if (normalizedCode.isEmpty) return false;
    final codeHash = data['recovery_code_hash'] as String?;
    if (codeHash != null && codeHash == _hashSecret(normalizedCode)) {
      return true;
    }
    final legacyCode = data['recovery_code'] as String?;
    return legacyCode != null &&
        _normalizeRecoveryCode(legacyCode) == normalizedCode;
  }

  @override
  Future<void> requestVerificationCode({
    required String phoneNumber,
    required CodeSentCallback onCodeSent,
    required void Function() onAutoVerified,
    required AuthErrorCallback onError,
    int? forceResendingToken,
  }) => _auth.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    forceResendingToken: forceResendingToken,
    verificationCompleted: (credential) async {
      try {
        final result = await _auth.signInWithCredential(credential);
        await _ensurePhoneUserProfile(result.user);
        onAutoVerified();
      } on FirebaseAuthException catch (error) {
        onError(_mapFirebaseAuthError(error));
      } catch (error) {
        onError(error);
      }
    },
    verificationFailed: (error) => onError(_mapFirebaseAuthError(error)),
    codeSent: onCodeSent,
    codeAutoRetrievalTimeout: (_) {},
  );

  @override
  Future<void> confirmVerificationCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      await _ensurePhoneUserProfile(result.user);
    } on FirebaseAuthException catch (error) {
      throw _mapFirebaseAuthError(error);
    }
  }

  Future<void> _ensurePhoneUserProfile(User? user) async {
    if (user == null) {
      throw const AuthFailure('登录未完成，请重试', code: 'missing-user');
    }

    final reference = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final now = FieldValue.serverTimestamp();
      if (snapshot.exists) {
        transaction.update(reference, {
          'phone': user.phoneNumber,
          'last_signed_in_at': now,
        });
      } else {
        transaction.set(reference, {
          'phone': user.phoneNumber,
          'created_at': now,
          'last_signed_in_at': now,
        });
      }
    });
  }

  AuthFailure _mapFirebaseAuthError(FirebaseAuthException error) {
    final message = switch (error.code) {
      'operation-not-allowed' =>
        'Firebase 匿名登录还没开启，请在 Authentication 里启用 Anonymous',
      'invalid-phone-number' => '手机号格式不正确',
      'invalid-verification-code' => '验证码不正确，请重新输入',
      'session-expired' => '验证码已过期，请重新获取',
      'too-many-requests' => '尝试次数较多，请稍后再试',
      'quota-exceeded' => '今日短信额度已用完，请稍后再试',
      'network-request-failed' =>
        '连接 Firebase 失败，请确认手机网络/VPN 能让 App 访问 Google 服务',
      _ => 'Firebase 登录失败：${error.code}',
    };
    return AuthFailure(message, code: error.code);
  }

  AuthFailure _mapFirestoreError(FirebaseException error) {
    final message = switch (error.code) {
      'permission-denied' => 'Firestore 规则拒绝写入，请先发布测试规则或放开测试模式',
      'unavailable' => 'Firestore 暂时连接不上，请检查网络/VPN 后重试',
      'not-found' => 'Firestore 数据库未创建或项目配置不匹配',
      _ => 'Firestore 连接失败：${error.code}',
    };
    return AuthFailure(message, code: error.code);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _newPublicUserId() => 'FH-${_randomToken(6)}';

  String _newRecoveryCode() {
    final raw = _randomToken(10);
    return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-${raw.substring(8)}';
  }

  String _randomToken(int length) {
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final random = math.Random.secure();
    return List.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  String _normalizeRecoveryCode(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  String _hashSecret(String input) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode('family-health-monitor:$input')) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
