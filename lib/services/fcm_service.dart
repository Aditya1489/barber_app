import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/services/api_service.dart';

final fcmServiceProvider = Provider((ref) => FCMService(ref));

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔔 Background FCM message: ${message.notification?.title}");
}

class FCMService {
  final Ref _ref;
  
  FirebaseMessaging? get _fcm {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  FCMService(this._ref);

  Future<void> initialize(String userId) async {
    final fcm = _fcm;
    if (fcm == null) {
      print("⚠️ FCM: Firebase not initialized. Skipping FCM setup.");
      return;
    }

    try {
      // Request permission (iOS)
      NotificationSettings settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM: User granted permission');
      } else {
        print('⚠️ FCM: User declined or has not accepted permission');
        return;
      }

      // Get FCM token
      String? token = await fcm.getToken();
      if (token != null) {
        print("🔑 FCM Token: $token");
        // Send token to backend
        await _sendTokenToBackend(userId, token);
      }

      // Handle token refresh
      fcm.onTokenRefresh.listen((newToken) {
        print("🔄 FCM Token refreshed: $newToken");
        _sendTokenToBackend(userId, newToken);
      });

      // Configure local notifications
      await _configureLocalNotifications();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("📩 Foreground FCM message: ${message.notification?.title}");
        _showLocalNotification(message);
      });

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification tap (app opened from notification)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("👆 Notification tapped: ${message.data}");
        _handleNotificationTap(message);
      });

      // Check if app was opened from a terminated state via notification
      RemoteMessage? initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        print("🚀 App opened from notification: ${initialMessage.data}");
        _handleNotificationTap(initialMessage);
      }

      print("✅ FCM Service initialized successfully");
    } catch (e) {
      print("❌ FCM initialization error: $e");
    }
  }

  Future<void> _configureLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        print("Local notification tapped: ${details.payload}");
      },
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'barber_sync_fcm',
        'BarberSync Push Notifications',
        channelDescription: 'Real-time notifications for appointments and updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: message.hashCode,
        title: message.notification?.title ?? 'BarberSync',
        body: message.notification?.body ?? '',
        notificationDetails: details,
        payload: message.data.toString(),
      );
    } catch (e) {
      print("⚠️ Error showing local notification: $e");
    }
  }

  Future<void> _sendTokenToBackend(String userId, String token) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.updateFCMToken(userId, token);
      print("✅ FCM token sent to backend");
    } catch (e) {
      print("❌ Error sending FCM token to backend: $e");
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // TODO: Navigate to relevant screen based on message.data
    final data = message.data;
    if (data.containsKey('bookingId')) {
      print("Navigate to booking: ${data['bookingId']}");
      // context.go('/appointments'); // Implement navigation
    }
  }

  Future<void> deleteToken() async {
    final fcm = _fcm;
    if (fcm == null) return;
    
    try {
      await fcm.deleteToken();
      print("🗑️ FCM token deleted");
    } catch (e) {
      print("❌ Error deleting FCM token: $e");
    }
  }
}
