class NotificationPreferences {
  const NotificationPreferences({
    required this.userId,
    this.careNotificationsEnabled = true,
    this.healthNotificationsEnabled = true,
    this.measurementRemindersEnabled = false,
    this.quietHoursEnabled = true,
    this.quietHoursStart = '22:00',
    this.quietHoursEnd = '08:00',
    this.showReadStatus = true,
    this.mutedGroupIds = const {},
  });

  final String userId;
  final bool careNotificationsEnabled;
  final bool healthNotificationsEnabled;
  final bool measurementRemindersEnabled;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool showReadStatus;
  final Set<String> mutedGroupIds;

  NotificationPreferences copyWith({
    bool? careNotificationsEnabled,
    bool? healthNotificationsEnabled,
    bool? measurementRemindersEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? showReadStatus,
    Set<String>? mutedGroupIds,
  }) => NotificationPreferences(
    userId: userId,
    careNotificationsEnabled:
        careNotificationsEnabled ?? this.careNotificationsEnabled,
    healthNotificationsEnabled:
        healthNotificationsEnabled ?? this.healthNotificationsEnabled,
    measurementRemindersEnabled:
        measurementRemindersEnabled ?? this.measurementRemindersEnabled,
    quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    quietHoursStart: quietHoursStart ?? this.quietHoursStart,
    quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    showReadStatus: showReadStatus ?? this.showReadStatus,
    mutedGroupIds: mutedGroupIds ?? this.mutedGroupIds,
  );
}
