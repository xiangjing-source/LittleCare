import 'dart:async';
import 'dart:convert';

import '../../../core/storage/demo_storage_contract.dart';
import '../domain/notification_models.dart';
import '../domain/notification_repository.dart';

class DemoNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  DemoNotificationPreferencesRepository({
    DemoStorage? storage,
    String? initialState,
  }) : _storage = storage {
    if (initialState != null) _restore(initialState);
  }

  static const storageKey = 'demo_notification_preferences_v2';

  final DemoStorage? _storage;
  final Map<String, NotificationPreferences> _preferences = {};
  final StreamController<String> _updates = StreamController.broadcast();

  @override
  Stream<NotificationPreferences> watchPreferences(String userId) async* {
    yield _preferences[userId] ?? NotificationPreferences(userId: userId);
    yield* _updates.stream
        .where((updatedUserId) => updatedUserId == userId)
        .map(
          (_) =>
              _preferences[userId] ?? NotificationPreferences(userId: userId),
        );
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    _preferences[preferences.userId] = preferences;
    await _storage?.setString(storageKey, exportState());
    _updates.add(preferences.userId);
  }

  String exportState() => jsonEncode({
    'users': _preferences.map(
      (key, value) => MapEntry(key, {
        'care_notifications_enabled': value.careNotificationsEnabled,
        'health_notifications_enabled': value.healthNotificationsEnabled,
        'measurement_reminders_enabled': value.measurementRemindersEnabled,
        'quiet_hours_enabled': value.quietHoursEnabled,
        'quiet_hours_start': value.quietHoursStart,
        'quiet_hours_end': value.quietHoursEnd,
        'show_read_status': value.showReadStatus,
        'muted_group_ids': value.mutedGroupIds.toList(),
      }),
    ),
  });

  void _restore(String encoded) {
    try {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      final users = Map<String, dynamic>.from(
        data['users'] as Map? ?? const {},
      );
      for (final entry in users.entries) {
        final value = Map<String, dynamic>.from(entry.value as Map);
        _preferences[entry.key] = NotificationPreferences(
          userId: entry.key,
          careNotificationsEnabled:
              value['care_notifications_enabled'] as bool? ?? true,
          healthNotificationsEnabled:
              value['health_notifications_enabled'] as bool? ?? true,
          measurementRemindersEnabled:
              value['measurement_reminders_enabled'] as bool? ?? false,
          quietHoursEnabled: value['quiet_hours_enabled'] as bool? ?? true,
          quietHoursStart: value['quiet_hours_start'] as String? ?? '22:00',
          quietHoursEnd: value['quiet_hours_end'] as String? ?? '08:00',
          showReadStatus: value['show_read_status'] as bool? ?? true,
          mutedGroupIds: Set<String>.from(
            value['muted_group_ids'] as List? ?? const [],
          ),
        );
      }
    } catch (_) {
      _preferences.clear();
    }
  }
}
