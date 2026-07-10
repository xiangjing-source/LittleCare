import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/notification_repository.dart';

const littleCareNotificationChannelId = 'littlecare_updates';
const littleCareNotificationChannelName = 'LittleCare 提醒';
const littleCareNotificationChannelDescription = '关心、回复和群组健康记录更新';

class FirebasePushNotificationRegistrationService
    implements PushNotificationRegistrationService {
  FirebasePushNotificationRegistrationService({
    required FirebaseFirestore firestore,
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
  }) : _firestore = firestore,
       _messaging = messaging,
       _localNotifications = localNotifications;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  String? _activeUserId;
  String? _activeToken;
  bool _initialized = false;
  bool _messageListenersRegistered = false;

  @override
  Future<void> activateForUser(String userId) async {
    if (kIsWeb) return;
    if (_activeUserId == userId && _activeToken != null) return;
    await _initializeLocalNotifications();
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    _activeUserId = userId;
    _activeToken = token;
    await _saveToken(userId: userId, token: token);
    if (!_messageListenersRegistered) {
      _messaging.onTokenRefresh.listen((newToken) async {
        final currentUserId = _activeUserId;
        if (currentUserId == null || newToken.isEmpty) return;
        _activeToken = newToken;
        await _saveToken(userId: currentUserId, token: newToken);
      });
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      _messageListenersRegistered = true;
    }
  }

  @override
  Future<void> deactivate() async {
    final token = _activeToken;
    if (token != null) {
      await _firestore
          .collection('device_tokens')
          .doc(_tokenDocumentId(token))
          .set({
            'enabled': false,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    }
    _activeUserId = null;
    _activeToken = null;
  }

  Future<void> _initializeLocalNotifications() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings: settings);
    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        littleCareNotificationChannelId,
        littleCareNotificationChannelName,
        description: littleCareNotificationChannelDescription,
        importance: Importance.defaultImportance,
      ),
    );
    _initialized = true;
  }

  Future<void> _saveToken({
    required String userId,
    required String token,
  }) async {
    await _firestore
        .collection('device_tokens')
        .doc(_tokenDocumentId(token))
        .set({
          'token': token,
          'user_id': userId,
          'platform': defaultTargetPlatform.name,
          'enabled': true,
          'updated_at': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if (title == null && body == null) return;
    await _localNotifications.show(
      id: message.hashCode,
      title: title ?? 'LittleCare',
      body: body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          littleCareNotificationChannelId,
          littleCareNotificationChannelName,
          channelDescription: littleCareNotificationChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  String _tokenDocumentId(String token) => base64Url.encode(utf8.encode(token));
}
