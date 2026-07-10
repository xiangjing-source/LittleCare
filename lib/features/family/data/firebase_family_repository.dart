import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/family_failure.dart';
import '../domain/family_models.dart';
import '../domain/family_repository.dart';

class FirebaseFamilyRepository implements FamilyRepository {
  FirebaseFamilyRepository(this._firestore);

  static const _inviteCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _firestore;
  final Random _random = Random.secure();

  @override
  Stream<String?> watchCurrentFamilyId(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['current_family_id'] as String?);
  }

  @override
  Stream<FamilySnapshot> watchFamily({
    required String familyId,
    required String viewerId,
  }) {
    final familyReference = _firestore.collection('families').doc(familyId);
    return familyReference.snapshots().asyncMap((familyDocument) async {
      final data = familyDocument.data();
      if (data == null) {
        throw const FamilyFailure('这个群组已经不存在了', code: 'not-found');
      }

      final results = await Future.wait([
        familyReference.collection('members').get(),
        familyReference
            .collection('relations')
            .where('from_user_id', isEqualTo: viewerId)
            .get(),
      ]);
      final memberDocuments = results[0];
      final relationDocuments = results[1];
      final members =
          memberDocuments.docs.map((document) {
              final member = document.data();
              return FamilyMember(
                userId: document.id,
                role:
                    member['role'] == 'owner'
                        ? FamilyRole.owner
                        : FamilyRole.member,
                defaultName: member['default_name'] as String? ?? '群组成员',
                joinedAt: _dateFrom(member['joined_at']),
              );
            }).toList()
            ..sort((left, right) {
              if (left.role != right.role) {
                return left.role == FamilyRole.owner ? -1 : 1;
              }
              return left.joinedAt.compareTo(right.joinedAt);
            });
      final nicknames = <String, String>{
        for (final document in relationDocuments.docs)
          if (document.data()['nickname'] case final String nickname)
            document.data()['to_user_id'] as String: nickname,
      };

      return FamilySnapshot(
        family: Family(
          id: familyDocument.id,
          inviteCode: data['invite_code'] as String,
          ownerId: data['owner_id'] as String,
          createdAt: _dateFrom(data['created_at']),
        ),
        members: members,
        nicknames: nicknames,
      );
    });
  }

  @override
  Future<void> createFamily({required String userId}) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final familyReference = _firestore.collection('families').doc();
      final inviteCode = _newInviteCode();
      final inviteReference = _firestore
          .collection('inviteCodes')
          .doc(inviteCode);
      final userReference = _firestore.collection('users').doc(userId);
      try {
        await _firestore.runTransaction((transaction) async {
          final inviteDocument = await transaction.get(inviteReference);
          final userDocument = await transaction.get(userReference);
          if (inviteDocument.exists) {
            throw const FamilyFailure('邀请码冲突', code: 'code-collision');
          }
          if (userDocument.data()?['current_family_id'] != null) {
            throw const FamilyFailure('你已经加入了一个群组', code: 'already-joined');
          }

          final now = FieldValue.serverTimestamp();
          transaction.set(familyReference, {
            'invite_code': inviteCode,
            'owner_id': userId,
            'created_at': now,
            'updated_at': now,
          });
          transaction.set(familyReference.collection('members').doc(userId), {
            'role': 'owner',
            'default_name': '群组创建者',
            'joined_at': now,
            'created_by_owner': true,
          });
          transaction.set(inviteReference, {
            'family_id': familyReference.id,
            'created_at': now,
          });
          transaction.set(userReference, {
            'current_family_id': familyReference.id,
          }, SetOptions(merge: true));
        });
        return;
      } on FamilyFailure catch (error) {
        if (error.code != 'code-collision') rethrow;
      } on FirebaseException catch (error) {
        throw FamilyFailure('创建群组失败，请稍后重试', code: error.code);
      }
    }
    throw const FamilyFailure('暂时无法生成邀请码，请重试', code: 'code-collision');
  }

  @override
  Future<void> joinFamily({
    required String userId,
    required String inviteCode,
  }) async {
    final normalized = inviteCode.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw const FamilyFailure('请输入邀请码', code: 'bad-code');
    }
    final inviteReference = _firestore
        .collection('inviteCodes')
        .doc(normalized);
    final userReference = _firestore.collection('users').doc(userId);
    try {
      await _firestore.runTransaction((transaction) async {
        final inviteDocument = await transaction.get(inviteReference);
        final userDocument = await transaction.get(userReference);
        final familyId = inviteDocument.data()?['family_id'] as String?;
        if (familyId == null) {
          throw const FamilyFailure('没有找到这个邀请码，请检查后重试', code: 'bad-code');
        }
        if (userDocument.data()?['current_family_id'] != null) {
          throw const FamilyFailure('你已经加入了一个群组', code: 'already-joined');
        }

        final familyReference = _firestore.collection('families').doc(familyId);
        final familyDocument = await transaction.get(familyReference);
        if (!familyDocument.exists) {
          throw const FamilyFailure('这个群组已经不存在了', code: 'not-found');
        }
        final now = FieldValue.serverTimestamp();
        transaction.set(familyReference.collection('members').doc(userId), {
          'role': 'member',
          'default_name': '新成员',
          'joined_at': now,
          'joined_via_code': normalized,
        });
        transaction.update(familyReference, {'updated_at': now});
        transaction.set(userReference, {
          'current_family_id': familyId,
        }, SetOptions(merge: true));
      });
    } on FamilyFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw FamilyFailure('加入群组失败，请稍后重试', code: error.code);
    }
  }

  @override
  Future<void> setNickname({
    required String familyId,
    required String fromUserId,
    required String toUserId,
    required String nickname,
  }) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty || normalized.length > 12) {
      throw const FamilyFailure('称呼请输入 1–12 个字符', code: 'bad-nickname');
    }
    final familyReference = _firestore.collection('families').doc(familyId);
    final relationId = '${fromUserId}_$toUserId';
    final batch = _firestore.batch();
    batch.set(familyReference.collection('relations').doc(relationId), {
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'nickname': normalized,
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(familyReference, {'updated_at': FieldValue.serverTimestamp()});
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      throw FamilyFailure('修改称呼失败，请稍后重试', code: error.code);
    }
  }

  String _newInviteCode() =>
      List.generate(
        6,
        (_) => _inviteCharacters[_random.nextInt(_inviteCharacters.length)],
      ).join();

  DateTime _dateFrom(Object? value) {
    return value is Timestamp ? value.toDate() : DateTime.now();
  }
}
