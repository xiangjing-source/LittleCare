import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/notification_models.dart';
import '../domain/notification_repository.dart';

class FirebaseNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  FirebaseNotificationPreferencesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<NotificationPreferences> watchPreferences(String userId) {
    return _firestore
        .collection('notification_preferences')
        .doc(userId)
        .snapshots()
        .map((document) {
          final data = document.data() ?? const <String, dynamic>{};
          return NotificationPreferences(
            userId: userId,
            careNotificationsEnabled:
                data['care_notifications_enabled'] as bool? ?? true,
            healthNotificationsEnabled:
                data['health_notifications_enabled'] as bool? ?? true,
            measurementRemindersEnabled:
                data['measurement_reminders_enabled'] as bool? ?? false,
            quietHoursEnabled: data['quiet_hours_enabled'] as bool? ?? true,
            quietHoursStart: data['quiet_hours_start'] as String? ?? '22:00',
            quietHoursEnd: data['quiet_hours_end'] as String? ?? '08:00',
            showReadStatus: data['show_read_status'] as bool? ?? true,
            mutedGroupIds: Set<String>.from(
              data['muted_group_ids'] as List? ?? const [],
            ),
          );
        });
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    await _firestore
        .collection('notification_preferences')
        .doc(preferences.userId)
        .set({
          'user_id': preferences.userId,
          'care_notifications_enabled': preferences.careNotificationsEnabled,
          'health_notifications_enabled':
              preferences.healthNotificationsEnabled,
          'measurement_reminders_enabled':
              preferences.measurementRemindersEnabled,
          'quiet_hours_enabled': preferences.quietHoursEnabled,
          'quiet_hours_start': preferences.quietHoursStart,
          'quiet_hours_end': preferences.quietHoursEnd,
          'show_read_status': preferences.showReadStatus,
          'muted_group_ids': preferences.mutedGroupIds.toList(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
