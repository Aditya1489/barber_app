import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/services/api_service.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

final refreshTriggerProvider = StateProvider((ref) => 0);
final unreadNotificationCountProvider = StateProvider((ref) => 0);

class NotificationService {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  Timer? _pollingTimer;
  final Set<String> _alertedIds = {};

  NotificationService(this._ref);

  Future<void> initialize() async {
    try {
      // Android settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS settings  
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // Combined settings
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // Use named parameters for v20.0.0+
      await _flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          print("Notification tapped: ${details.payload}");
        },
      );
      
      // Request permissions for Android
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
              
      await androidImplementation?.requestNotificationsPermission();
      
      print("✅ Notification service initialized successfully");
    } catch (e) {
      print("⚠️ Notification initialization error (non-fatal): $e");
    }
  }

  void startPolling(String userId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkNotifications(userId));
    _checkNotifications(userId);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> _checkNotifications(String userId) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      final notifications = await apiService.getNotifications(userId);
      
      bool foundNew = false;
      int unreadCount = 0;
      for (final notif in notifications) {
        if (!notif['isRead']) {
          unreadCount++;
        }
        
        if (!notif['isRead'] && !_alertedIds.contains(notif['id'])) {
          _showLocalNotification(notif);
          _alertedIds.add(notif['id']);
          foundNew = true;
        }
      }

      _ref.read(unreadNotificationCountProvider.notifier).state = unreadCount;

      if (foundNew) {
        _ref.read(refreshTriggerProvider.notifier).state++;
      }
    } catch (e) {
      print("❌ Error polling notifications: $e");
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notif) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'barber_sync_notifications',
        'BarberSync Notifications',
        channelDescription: 'Notifications for BarberSync appointments and updates',
        importance: Importance.max,
        priority: Priority.high,
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

      // Use ALL named parameters for v20.0.0+
      await _flutterLocalNotificationsPlugin.show(
        id: notif['id'].hashCode,
        title: notif['title'] ?? 'Notification',
        body: notif['body'] ?? '',
        notificationDetails: details,
        payload: notif['data']?.toString(),
      );
    } catch (e) {
      print("⚠️ Error showing notification: $e");
    }
  }
}
