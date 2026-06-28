import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

export 'package:firebase_messaging/firebase_messaging.dart'
    show FirebaseMessaging;

/// Top-level handler required by FCM for background/terminated messages.
/// Must be a top-level function (not a closure or instance method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised by the time this runs (FlutterFire
  // guarantees it for background isolates). Nothing else to do here —
  // the notification is shown automatically by FCM when the app is in
  // the background or terminated; we just need the handler registered
  // so the data payload is available if we want to process it.
  debugPrint('FCM background message: ${message.messageId}');
}

/// Thin wrapper around [FirebaseMessaging] that:
///  1. Requests notification permission on first launch.
///  2. Creates the Android notification channel (required on API 26+).
///  3. Exposes [getToken] so the auth layer can register it with the backend.
///  4. Wires foreground message display via flutter_local_notifications.
///  5. Exposes a tap-stream ([onNotificationTap]) that go_router can listen to
///     and navigate to the [deep_link] from the notification data payload.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channelId = 'gympass_default';
  static const _channelName = 'GymPass Notifications';

  /// Emits the deep-link string from a tapped notification. The router
  /// subscribes to this stream to navigate without a BuildContext.
  // ignore: close_sinks — singleton lives for the app lifetime
  final _tapController = StreamController<String>.broadcast();
  Stream<String> get onNotificationTap => _tapController.stream;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS prompt + Android 13+ prompt).
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _createAndroidChannel();
    await _initLocalNotifications();

    // Show heads-up notification when the app is in the foreground —
    // FCM suppresses the system notification tray entry in foreground
    // by default, so we re-display via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Handle tap on a notification when the app was in the background
    // (not terminated — terminated start uses getInitialMessage).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Handle tap on the notification that launched the app from terminated.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  Future<String?> getToken() => _messaging.getToken();

  Future<void> deleteToken() => _messaging.deleteToken();

  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initLocalNotifications() async {
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initDarwin = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
    );
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _tapController.add(payload);
        }
      },
    );
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final deepLink = message.data['deep_link'] as String? ?? '/notifications';
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: deepLink,
    );
  }

  void _handleTap(RemoteMessage message) {
    final deepLink = message.data['deep_link'] as String? ?? '/notifications';
    _tapController.add(deepLink);
  }
}
