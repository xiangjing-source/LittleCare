import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/group_failure.dart';
import '../domain/group_models.dart';
import '../domain/group_repository.dart';

class FirebaseGroupRepository implements GroupRepository {
  FirebaseGroupRepository(this._firestore);

  static const _inviteCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _firestore;
  final Random _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');
  CollectionReference<Map<String, dynamic>> get _memberships =>
      _firestore.collection('group_memberships');
  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('invite_codes');
  CollectionReference<Map<String, dynamic>> get _aliases =>
      _firestore.collection('relation_aliases');

  @override
  Stream<List<UserGroup>> watchUserGroups(String userId) {
    return _memberships
        .where('user_id', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .asyncMap((snapshot) async {
          final result = <UserGroup>[];
          for (final membershipDocument in snapshot.docs) {
            final membership = _membershipFromDocument(membershipDocument);
            final groupDocument = await _groups.doc(membership.groupId).get();
            if (groupDocument.data() case final data?) {
              if (data['status'] == 'dissolved') continue;
              result.add(
                UserGroup(
                  group: _groupFromData(
                    groupDocument.id,
                    data,
                    displayNameOverride: membership.displayNameOverride,
                  ),
                  membership: membership,
                ),
              );
            }
          }
          result.sort(
            (left, right) =>
                right.group.updatedAt.compareTo(left.group.updatedAt),
          );
          return result;
        });
  }

  @override
  Stream<String?> watchSelectedGroupId(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['selected_group_id'] as String?);
  }

  @override
  Stream<GroupSnapshot> watchGroup({
    required String groupId,
    required String viewerId,
  }) {
    late final StreamController<GroupSnapshot> controller;
    DocumentSnapshot<Map<String, dynamic>>? groupDocument;
    QuerySnapshot<Map<String, dynamic>>? memberSnapshot;
    QuerySnapshot<Map<String, dynamic>>? aliasSnapshot;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? groupSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? memberSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? aliasSub;

    Future<void> emit() async {
      final document = groupDocument;
      final memberDocuments = memberSnapshot;
      final aliasDocuments = aliasSnapshot;
      if (document == null ||
          memberDocuments == null ||
          aliasDocuments == null) {
        return;
      }
      final data = document.data();
      if (data == null) {
        controller.addError(
          const GroupFailure('这个群组已经不存在了', code: 'not-found'),
        );
        return;
      }
      final members =
          memberDocuments.docs.map(_membershipFromDocument).toList()
            ..sort((left, right) => left.joinedAt.compareTo(right.joinedAt));
      final viewer =
          members.where((member) => member.userId == viewerId).firstOrNull;
      if (viewer == null) {
        controller.addError(
          const GroupFailure('你已不在这个群组中', code: 'not-member'),
        );
        return;
      }
      final profiles = await Future.wait(
        members.map(
          (member) => _firestore.collection('users').doc(member.userId).get(),
        ),
      );
      controller.add(
        GroupSnapshot(
          group: _groupFromData(
            document.id,
            data,
            displayNameOverride: viewer.displayNameOverride,
          ),
          members: members,
          aliases: {
            for (final alias in aliasDocuments.docs)
              alias.data()['to_user_id'] as String:
                  alias.data()['nickname'] as String,
          },
          profileNames: {
            for (final profile in profiles)
              if ((profile.data()?['display_name'] as String?) case final name?)
                profile.id: name,
          },
        ),
      );
    }

    controller = StreamController<GroupSnapshot>(
      onListen: () {
        groupSub = _groups.doc(groupId).snapshots().listen((snapshot) {
          groupDocument = snapshot;
          emit();
        }, onError: controller.addError);
        memberSub = _memberships
            .where('group_id', isEqualTo: groupId)
            .where('status', isEqualTo: 'active')
            .snapshots()
            .listen((snapshot) {
              memberSnapshot = snapshot;
              emit();
            }, onError: controller.addError);
        aliasSub = _aliases
            .where('group_id', isEqualTo: groupId)
            .where('from_user_id', isEqualTo: viewerId)
            .snapshots()
            .listen((snapshot) {
              aliasSnapshot = snapshot;
              emit();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await groupSub?.cancel();
        await memberSub?.cancel();
        await aliasSub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<Group> createGroup({
    required String userId,
    required String name,
    String description = '',
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 24) {
      throw const GroupFailure('群组名称请输入 1–24 个字符', code: 'bad-name');
    }
    for (var attempt = 0; attempt < 5; attempt++) {
      final groupReference = _groups.doc();
      final inviteCode = _newInviteCode();
      final inviteReference = _invites.doc(inviteCode);
      try {
        await _firestore.runTransaction((transaction) async {
          if ((await transaction.get(inviteReference)).exists) {
            throw const GroupFailure('邀请码冲突', code: 'code-collision');
          }
          final now = FieldValue.serverTimestamp();
          transaction.set(groupReference, {
            'name': normalizedName,
            'description': description.trim(),
            'avatar_url': null,
            'created_by': userId,
            'invite_code': inviteCode,
            'invite_code_expires_at': null,
            'created_at': now,
            'updated_at': now,
            'schema_version': 2,
          });
          transaction
              .set(_memberships.doc(_membershipId(groupReference.id, userId)), {
                'group_id': groupReference.id,
                'user_id': userId,
                'role': 'owner',
                'status': 'active',
                'display_name_in_group': '群组创建者',
                'created_by_owner': true,
                'joined_at': now,
                'updated_at': now,
              });
          transaction.set(inviteReference, {
            'group_id': groupReference.id,
            'active': true,
            'expires_at': null,
            'created_at': now,
          });
          transaction.set(_firestore.collection('users').doc(userId), {
            'selected_group_id': groupReference.id,
          }, SetOptions(merge: true));
        });
        final now = DateTime.now();
        return Group(
          id: groupReference.id,
          name: normalizedName,
          description: description.trim(),
          createdBy: userId,
          inviteCode: inviteCode,
          createdAt: now,
          updatedAt: now,
        );
      } on GroupFailure catch (error) {
        if (error.code != 'code-collision') rethrow;
      } on FirebaseException catch (error) {
        throw GroupFailure('创建群组失败，请稍后再试', code: error.code);
      }
    }
    throw const GroupFailure('暂时无法生成邀请码，请重试', code: 'code-collision');
  }

  @override
  Future<GroupInvitePreview> previewInvite(String inviteCode) async {
    final normalized = inviteCode.trim().toUpperCase();
    final invite = await _invites.doc(normalized).get();
    final data = invite.data();
    if (!_inviteIsValid(data)) {
      throw const GroupFailure('没有找到有效的邀请码，请检查后再试', code: 'bad-code');
    }
    final group = await _groups.doc(data!['group_id'] as String).get();
    final groupData = group.data();
    if (groupData == null) {
      throw const GroupFailure('这个群组已经不存在了', code: 'not-found');
    }
    return GroupInvitePreview(
      groupId: group.id,
      name: groupData['name'] as String,
      description: groupData['description'] as String? ?? '',
    );
  }

  @override
  Future<void> joinGroup({
    required String userId,
    required String inviteCode,
  }) async {
    final normalized = inviteCode.trim().toUpperCase();
    try {
      await _firestore.runTransaction((transaction) async {
        final invite = await transaction.get(_invites.doc(normalized));
        final inviteData = invite.data();
        if (!_inviteIsValid(inviteData)) {
          throw const GroupFailure('没有找到有效的邀请码，请检查后再试', code: 'bad-code');
        }
        final groupId = inviteData!['group_id'] as String;
        final group = await transaction.get(_groups.doc(groupId));
        if (!group.exists) {
          throw const GroupFailure('这个群组已经不存在了', code: 'not-found');
        }
        final now = FieldValue.serverTimestamp();
        transaction.set(_memberships.doc(_membershipId(groupId, userId)), {
          'group_id': groupId,
          'user_id': userId,
          'role': 'member',
          'status': 'active',
          'display_name_in_group':
              (await transaction.get(
                    _firestore.collection('users').doc(userId),
                  )).data()?['display_name']
                  as String? ??
              '群组成员',
          'joined_via_code': normalized,
          'joined_at': now,
          'updated_at': now,
        }, SetOptions(merge: true));
        transaction.set(_firestore.collection('users').doc(userId), {
          'selected_group_id': groupId,
        }, SetOptions(merge: true));
        transaction.update(_groups.doc(groupId), {'updated_at': now});
      });
    } on GroupFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw GroupFailure('加入群组失败，请稍后再试', code: error.code);
    }
  }

  @override
  Future<void> leaveGroup({
    required String userId,
    required String groupId,
  }) async {
    final reference = _memberships.doc(_membershipId(groupId, userId));
    final snapshot = await reference.get();
    if (snapshot.data()?['role'] == 'owner') {
      throw const GroupFailure('群主需要先转让群组，才能退出', code: 'owner-cannot-leave');
    }
    await reference.update({
      'status': 'left',
      'updated_at': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('users').doc(userId).set({
      'selected_group_id': null,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String requesterId,
    required String memberUserId,
  }) async {
    if (requesterId == memberUserId) {
      throw const GroupFailure('不能移除自己', code: 'cannot-remove-self');
    }
    final requester =
        await _memberships.doc(_membershipId(groupId, requesterId)).get();
    if (requester.data()?['role'] != 'owner' ||
        requester.data()?['status'] != 'active') {
      throw const GroupFailure('只有创建者可以移除成员', code: 'forbidden');
    }
    final memberReference = _memberships.doc(
      _membershipId(groupId, memberUserId),
    );
    final member = await memberReference.get();
    if (member.data()?['role'] == 'owner') {
      throw const GroupFailure('不能移除群组创建者', code: 'cannot-remove-owner');
    }
    if (member.data()?['status'] != 'active') return;
    final batch = _firestore.batch();
    batch.update(memberReference, {
      'status': 'removed',
      'removed_at': FieldValue.serverTimestamp(),
      'removed_by': requesterId,
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('users').doc(memberUserId), {
      'selected_group_id': null,
    }, SetOptions(merge: true));
    batch.update(_groups.doc(groupId), {
      'updated_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Future<void> renameGroup({
    required String groupId,
    required String requesterId,
    required String name,
  }) async {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 24) {
      throw const GroupFailure('群组名称请输入 1–24 个字符', code: 'bad-name');
    }
    final membership =
        await _memberships.doc(_membershipId(groupId, requesterId)).get();
    if (membership.data()?['role'] != 'owner' ||
        membership.data()?['status'] != 'active') {
      throw const GroupFailure('只有创建者可以重命名群组', code: 'forbidden');
    }
    await _groups.doc(groupId).update({
      'name': normalized,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setGroupDisplayName({
    required String groupId,
    required String userId,
    String? displayName,
  }) async {
    final normalized = displayName?.trim();
    await _memberships.doc(_membershipId(groupId, userId)).update({
      'display_name_override':
          normalized == null || normalized.isEmpty ? null : normalized,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> dissolveGroup({
    required String groupId,
    required String requesterId,
  }) async {
    final membership =
        await _memberships.doc(_membershipId(groupId, requesterId)).get();
    if (membership.data()?['role'] != 'owner' ||
        membership.data()?['status'] != 'active') {
      throw const GroupFailure('只有创建者可以解散群组', code: 'forbidden');
    }
    final group = await _groups.doc(groupId).get();
    final inviteCode = group.data()?['invite_code'] as String?;
    final batch =
        _firestore.batch()..update(_groups.doc(groupId), {
          'status': 'dissolved',
          'dissolved_at': FieldValue.serverTimestamp(),
          'dissolved_by': requesterId,
          'invite_code': null,
          'updated_at': FieldValue.serverTimestamp(),
        });
    if (inviteCode != null) {
      batch.set(_invites.doc(inviteCode), {
        'active': false,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> selectGroup({
    required String userId,
    required String groupId,
  }) async {
    final membership =
        await _memberships.doc(_membershipId(groupId, userId)).get();
    if (membership.data()?['status'] != 'active') {
      throw const GroupFailure('你已不在这个群组中', code: 'not-member');
    }
    await _firestore.collection('users').doc(userId).set({
      'selected_group_id': groupId,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setAlias({
    required String groupId,
    required String fromUserId,
    required String toUserId,
    required String nickname,
  }) async {
    final normalized = nickname.trim();
    if (normalized.isEmpty || normalized.length > 12) {
      throw const GroupFailure('称呼请输入 1–12 个字符', code: 'bad-alias');
    }
    await _aliases.doc('${groupId}_${fromUserId}_$toUserId').set({
      'group_id': groupId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'nickname': normalized,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _groups.doc(groupId).update({
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> regenerateInvite({
    required String groupId,
    required String requesterId,
    DateTime? expiresAt,
  }) async {
    final membership =
        await _memberships.doc(_membershipId(groupId, requesterId)).get();
    final role = membership.data()?['role'];
    if (membership.data()?['status'] != 'active' ||
        (role != 'owner' && role != 'admin')) {
      throw const GroupFailure('只有群主或管理员可以更新邀请码', code: 'forbidden');
    }
    final groupReference = _groups.doc(groupId);
    final current = await groupReference.get();
    final oldCode = current.data()?['invite_code'] as String?;
    final newCode = _newInviteCode();
    final batch = _firestore.batch();
    if (oldCode != null) {
      batch.set(_invites.doc(oldCode), {
        'active': false,
      }, SetOptions(merge: true));
    }
    batch.set(_invites.doc(newCode), {
      'group_id': groupId,
      'active': true,
      'expires_at': expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'created_at': FieldValue.serverTimestamp(),
    });
    batch.update(groupReference, {
      'invite_code': newCode,
      'invite_code_expires_at':
          expiresAt == null ? null : Timestamp.fromDate(expiresAt),
      'updated_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return newCode;
  }

  bool _inviteIsValid(Map<String, dynamic>? data) {
    if (data == null || data['active'] != true) return false;
    final expiresAt = data['expires_at'];
    return expiresAt is! Timestamp ||
        expiresAt.toDate().isAfter(DateTime.now());
  }

  Group _groupFromData(
    String id,
    Map<String, dynamic> data, {
    String? displayNameOverride,
  }) => Group(
    id: id,
    name: displayNameOverride ?? (data['name'] as String? ?? '我的群组'),
    description: data['description'] as String? ?? '',
    avatarUrl: data['avatar_url'] as String?,
    createdBy: data['created_by'] as String,
    inviteCode: data['invite_code'] as String? ?? '',
    inviteCodeExpiresAt: _dateOrNull(data['invite_code_expires_at']),
    createdAt: _date(data['created_at']),
    updatedAt: _date(data['updated_at']),
    schemaVersion: data['schema_version'] as int? ?? 2,
  );

  GroupMembership _membershipFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return GroupMembership(
      id: document.id,
      groupId: data['group_id'] as String,
      userId: data['user_id'] as String,
      role: GroupRole.values.byName(data['role'] as String),
      status: MembershipStatus.values.byName(data['status'] as String),
      displayNameInGroup: data['display_name_in_group'] as String?,
      displayNameOverride: data['display_name_override'] as String?,
      joinedAt: _date(data['joined_at']),
      updatedAt: _date(data['updated_at']),
    );
  }

  DateTime _date(Object? value) =>
      value is Timestamp ? value.toDate() : DateTime.now();
  DateTime? _dateOrNull(Object? value) =>
      value is Timestamp ? value.toDate() : null;
  String _newInviteCode() =>
      List.generate(
        6,
        (_) => _inviteCharacters[_random.nextInt(_inviteCharacters.length)],
      ).join();
  static String _membershipId(String groupId, String userId) =>
      '${groupId}_$userId';
}
