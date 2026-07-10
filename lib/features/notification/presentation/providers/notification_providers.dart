import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/notification_models.dart';
import '../../domain/notification_repository.dart';

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
      throw UnimplementedError(
        'NotificationPreferencesRepository must be overridden at startup.',
      );
    });

final pushNotificationRegistrationServiceProvider =
    Provider<PushNotificationRegistrationService>(
      (ref) => const NoopPushNotificationRegistrationService(),
    );

final notificationPreferencesProvider =
    StreamProvider.family<NotificationPreferences, String>((ref, userId) {
      return ref
          .watch(notificationPreferencesRepositoryProvider)
          .watchPreferences(userId);
    });
