import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../../../core/storage/demo_storage_contract.dart';
import '../domain/family_failure.dart';
import '../domain/family_models.dart';
import '../domain/family_repository.dart';

class DemoFamilyRepository implements FamilyRepository {
  DemoFamilyRepository({DemoStorage? preferences, String? initialState})
    : _preferences = preferences {
    _seedDemoFamily();
    if (initialState != null) _restore(initialState);
  }

  static const storageKey = 'demo_family_state_v1';

  final DemoStorage? _preferences;

  void _seedDemoFamily() {
    _families[_demoFamilyId] = _DemoFamilyData(
      family: Family(
        id: _demoFamilyId,
        inviteCode: _demoInviteCode,
        ownerId: 'demo-mom',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      members: [
        FamilyMember(
          userId: 'demo-mom',
          role: FamilyRole.owner,
          defaultName: '群组成员',
          joinedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ],
    );
  }

  static const _demoFamilyId = 'demo-family';
  static const _demoInviteCode = 'FAMILY1';
  static const _inviteCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final _random = Random();
  final Map<String, String?> _familyIdByUser = {};
  final Map<String, _DemoFamilyData> _families = {};
  final Map<String, Map<String, String>> _nicknamesByViewer = {};
  final StreamController<({String userId, String? familyId})> _familyIdUpdates =
      StreamController.broadcast();
  final StreamController<String> _familyUpdates = StreamController.broadcast();

  @override
  Stream<String?> watchCurrentFamilyId(String userId) async* {
    yield _familyIdByUser[userId];
    yield* _familyIdUpdates.stream
        .where((update) => update.userId == userId)
        .map((update) => update.familyId);
  }

  @override
  Stream<FamilySnapshot> watchFamily({
    required String familyId,
    required String viewerId,
  }) async* {
    yield _snapshot(familyId, viewerId);
    yield* _familyUpdates.stream
        .where((updatedId) => updatedId == familyId)
        .map((_) => _snapshot(familyId, viewerId));
  }

  FamilySnapshot _snapshot(String familyId, String viewerId) {
    final data = _families[familyId];
    if (data == null) {
      throw const FamilyFailure('这个群组已经不存在了', code: 'not-found');
    }
    return FamilySnapshot(
      family: data.family,
      members: List.unmodifiable(data.members),
      nicknames: Map.unmodifiable(_nicknamesByViewer[viewerId] ?? const {}),
    );
  }

  @override
  Future<void> createFamily({required String userId}) async {
    _ensureNotInFamily(userId);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final familyId = 'family-${DateTime.now().millisecondsSinceEpoch}';
    final inviteCode =
        List.generate(
          6,
          (_) => _inviteCharacters[_random.nextInt(_inviteCharacters.length)],
        ).join();
    final now = DateTime.now();
    _families[familyId] = _DemoFamilyData(
      family: Family(
        id: familyId,
        inviteCode: inviteCode,
        ownerId: userId,
        createdAt: now,
      ),
      members: [
        FamilyMember(
          userId: userId,
          role: FamilyRole.owner,
          defaultName: '群组创建者',
          joinedAt: now,
        ),
      ],
    );
    _setCurrentFamily(userId, familyId);
    await _persist();
  }

  @override
  Future<void> joinFamily({
    required String userId,
    required String inviteCode,
  }) async {
    _ensureNotInFamily(userId);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final normalized = inviteCode.trim().toUpperCase();
    final entry =
        _families.entries
            .where((item) => item.value.family.inviteCode == normalized)
            .firstOrNull;
    if (entry == null) {
      throw const FamilyFailure('没有找到这个邀请码，请检查后重试', code: 'bad-code');
    }

    if (!entry.value.members.any((member) => member.userId == userId)) {
      entry.value.members.add(
        FamilyMember(
          userId: userId,
          role: FamilyRole.member,
          defaultName: '新成员',
          joinedAt: DateTime.now(),
        ),
      );
    }
    if (entry.key == _demoFamilyId) {
      _nicknamesByViewer.putIfAbsent(userId, () => {})['demo-mom'] = '伙伴';
    }
    _setCurrentFamily(userId, entry.key);
    await _persist();
    _familyUpdates.add(entry.key);
  }

  void _ensureNotInFamily(String userId) {
    if (_familyIdByUser[userId] != null) {
      throw const FamilyFailure('你已经加入了一个群组', code: 'already-joined');
    }
  }

  void _setCurrentFamily(String userId, String familyId) {
    _familyIdByUser[userId] = familyId;
    _familyIdUpdates.add((userId: userId, familyId: familyId));
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
    final family = _families[familyId];
    if (family == null ||
        !family.members.any((member) => member.userId == toUserId)) {
      throw const FamilyFailure('没有找到这位群组成员', code: 'member-not-found');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _nicknamesByViewer.putIfAbsent(fromUserId, () => {})[toUserId] = normalized;
    await _persist();
    _familyUpdates.add(familyId);
  }

  void _restore(String encoded) {
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      final familyIds = data['family_ids'] as Map<String, dynamic>? ?? const {};
      _familyIdByUser.addAll(
        familyIds.map((key, value) => MapEntry(key, value as String?)),
      );

      final families = data['families'] as List<dynamic>? ?? const [];
      for (final item in families.cast<Map<String, dynamic>>()) {
        final familyData = item['family'] as Map<String, dynamic>;
        final family = Family(
          id: familyData['id'] as String,
          inviteCode: familyData['invite_code'] as String,
          ownerId: familyData['owner_id'] as String,
          createdAt: DateTime.parse(familyData['created_at'] as String),
        );
        final members =
            (item['members'] as List<dynamic>)
                .cast<Map<String, dynamic>>()
                .map(
                  (member) => FamilyMember(
                    userId: member['user_id'] as String,
                    role:
                        member['role'] == 'owner'
                            ? FamilyRole.owner
                            : FamilyRole.member,
                    defaultName: member['default_name'] as String,
                    joinedAt: DateTime.parse(member['joined_at'] as String),
                  ),
                )
                .toList();
        _families[family.id] = _DemoFamilyData(
          family: family,
          members: members,
        );
      }

      final nicknames = data['nicknames'] as Map<String, dynamic>? ?? const {};
      for (final entry in nicknames.entries) {
        _nicknamesByViewer[entry.key] = Map<String, String>.from(
          entry.value as Map,
        );
      }
      _seedDemoFamilyIfMissing();
    } catch (_) {
      _familyIdByUser.clear();
      _nicknamesByViewer.clear();
      _families.clear();
      _seedDemoFamily();
    }
  }

  void _seedDemoFamilyIfMissing() {
    if (!_families.containsKey(_demoFamilyId)) _seedDemoFamily();
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setString(storageKey, exportState());
  }

  String exportState() {
    return jsonEncode({
      'family_ids': _familyIdByUser,
      'families': [
        for (final data in _families.values)
          {
            'family': {
              'id': data.family.id,
              'invite_code': data.family.inviteCode,
              'owner_id': data.family.ownerId,
              'created_at': data.family.createdAt.toIso8601String(),
            },
            'members': [
              for (final member in data.members)
                {
                  'user_id': member.userId,
                  'role': member.role == FamilyRole.owner ? 'owner' : 'member',
                  'default_name': member.defaultName,
                  'joined_at': member.joinedAt.toIso8601String(),
                },
            ],
          },
      ],
      'nicknames': _nicknamesByViewer,
    });
  }
}

class _DemoFamilyData {
  _DemoFamilyData({required this.family, required this.members});

  final Family family;
  final List<FamilyMember> members;
}
