import 'notification_models.dart';

abstract interface class NotificationPreferencesRepository {
  Stream<NotificationPreferences> watchPreferences(String userId);

  Future<void> savePreferences(NotificationPreferences preferences);
}

abstract interface class PushNotificationRegistrationService {
  Future<void> activateForUser(String userId);

  Future<void> deactivate();
}

class NoopPushNotificationRegistrationService
    implements PushNotificationRegistrationService {
  const NoopPushNotificationRegistrationService();

  @override
  Future<void> activateForUser(String userId) async {}

  @override
  Future<void> deactivate() async {}
}

/// Actual FCM delivery must be implemented by trusted backend code.
abstract interface class NotificationDeliveryGateway {
  Future<void> requestCareDelivery(String careEventId);
}

class DeferredCloudFunctionNotificationGateway
    implements NotificationDeliveryGateway {
  const DeferredCloudFunctionNotificationGateway();

  @override
  Future<void> requestCareDelivery(String careEventId) async {
    // Firestore-triggered Cloud Functions should check recipient preferences,
    // quiet hours, and muted groups before sending FCM.
  }
}
