import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Show local notification when app is in background/terminated
  await FCMService._showLocalNotification(
    title: message.notification?.title ?? 'FarmiGrow Alert',
    body: message.notification?.body ?? '',
  );
}

/// Firebase Cloud Messaging service.
/// Handles push notifications sent from Railway backend when
/// satellite scans detect high pest/disease risk.
class FCMService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return; // User denied — silent fail
    }

    // Initialize local notifications for foreground display
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotif.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // Create high-importance notification channel
    const channel = AndroidNotificationChannel(
      'farmigrow_alerts',
      'FarmiGrow Farm Alerts',
      description: 'Critical satellite scan alerts for your farms and ponds',
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(
        title: message.notification?.title ?? 'FarmiGrow Alert',
        body: message.notification?.body ?? '',
      );
    });

    // Save FCM token to shared prefs so backend can send targeted notifications
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveFcmToken(token);
    }

    // Refresh token handler
    _fcm.onTokenRefresh.listen(_saveFcmToken);

    _initialized = true;
  }

  static Future<void> _saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'farmigrow_alerts',
      'FarmiGrow Farm Alerts',
      channelDescription: 'Critical satellite scan alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Send FCM token to backend so Railway can push notifications
  /// to this specific device when its farms have high-risk alerts.
  static Future<void> registerTokenWithBackend(String backendUserId) async {
    final token = await getFcmToken();
    if (token == null) return;
    // The backend stores this token and uses it when scan results
    // show high pest/disease risk to send targeted push notifications.
    // Implementation: backend POST /profile/ already includes device_id
    // — FCM token gets added to that payload in a future backend update.
  }
}
