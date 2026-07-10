import 'package:family_health_monitor/features/notification/data/demo_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification preferences keep quiet hours and muted groups', () async {
    final repository = DemoNotificationPreferencesRepository();
    final initial = await repository.watchPreferences('me').first;

    await repository.savePreferences(
      initial.copyWith(
        careNotificationsEnabled: false,
        quietHoursStart: '21:30',
        quietHoursEnd: '07:30',
        mutedGroupIds: {'group-a'},
      ),
    );

    final restored = DemoNotificationPreferencesRepository(
      initialState: repository.exportState(),
    );
    final preferences = await restored.watchPreferences('me').first;
    expect(preferences.careNotificationsEnabled, isFalse);
    expect(preferences.quietHoursStart, '21:30');
    expect(preferences.mutedGroupIds, {'group-a'});
  });
}
