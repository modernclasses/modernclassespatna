import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint(
    "📩 Received background FCM message: ${message.messageId} - ${message.notification?.title}",
  );
}

/// Production service managing Push Notifications, FCM device tokens,
/// Android 13+ permissions, lockscreen banners, and Supabase synchronization.
class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static String? _currentFcmToken;

  static String? get currentFcmToken => _currentFcmToken;
  static bool get isInitialized => _isInitialized;

  /// High-importance notification channel for Android lockscreen heads-up banners
  static const AndroidNotificationChannel
  _highPriorityChannel = AndroidNotificationChannel(
    'modern_classes_alerts',
    'Modern Classes Patna Class Alerts',
    description:
        'Real-time live class alerts, schedule changes, and 15-minute advance reminders.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Initialize Firebase Messaging, Local Notifications, and Channels
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase Core
      await Firebase.initializeApp();

      // 2. Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Setup Android notification channel for lockscreen display
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(_highPriorityChannel);
          await androidPlugin.requestNotificationsPermission();
        }
      }

      // 4. Initialize Local Notifications Plugin
      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint(
            "🔔 Notification tapped with payload: ${response.payload}",
          );
        },
      );

      final messaging = FirebaseMessaging.instance;

      // 5. Request User Notification Permissions (Required on Android 13+ & iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint(
        "📱 Push notification permission status: ${settings.authorizationStatus}",
      );

      // 6. Set foreground notification presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 7. Retrieve FCM Token and sync with backend
      // ignore: deprecated_member_use
      _currentFcmToken = await messaging.getToken();
      if (_currentFcmToken != null) {
        debugPrint("🔑 FCM Device Token: $_currentFcmToken");
        await syncTokenWithBackend(_currentFcmToken!);
      }

      // 8. Listen for Token Refreshes
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((newToken) async {
        _currentFcmToken = newToken;
        await syncTokenWithBackend(newToken);
      });

      // 9. Foreground Notification Listener (Display heads-up banner when app is open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null && !kIsWeb) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _highPriorityChannel.id,
                _highPriorityChannel.name,
                channelDescription: _highPriorityChannel.description,
                icon: android?.smallIcon ?? '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true,
                visibility: NotificationVisibility.public,
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });

      _isInitialized = true;
      debugPrint("✅ PushNotificationService successfully initialized.");
    } catch (e) {
      debugPrint(
        "ℹ️ PushNotificationService notice (Firebase not configured yet or missing google-services.json): $e",
      );
    }
  }

  /// Show a heads-up local notification alert on device
  static Future<void> showLocalBanner({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (kIsWeb) return;
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'modern_classes_alerts',
            'Modern Classes Patna Class Alerts',
            channelDescription:
                'Real-time live class alerts, schedule changes, and 15-minute advance reminders.',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[PushNotificationService] showLocalBanner notice: $e');
    }
  }

  /// Synchronize the device FCM token to Supabase `user_device_tokens` table
  static Future<void> syncTokenWithBackend(String token) async {
    if (!AppConfig.isSupabaseConfigured) return;

    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;

      await client.rpc(
        'register_device_token',
        params: {
          'p_fcm_token': token,
          'p_device_type': Platform.isAndroid
              ? 'android'
              : (Platform.isIOS ? 'ios' : 'unknown'),
          'p_app_version': '1.0.0',
        },
      );

      debugPrint(
        "✅ FCM token registered with Supabase user: ${client.auth.currentUser!.id}",
      );
    } catch (e) {
      debugPrint("⚠️ Failed to sync FCM token to Supabase: $e");
    }
  }

  /// Subscribe to a specific batch topic for instant broadcast routing
  static Future<void> subscribeToBatch(String batchId) async {
    if (!_isInitialized) return;
    try {
      final cleanId = batchId.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.subscribeToTopic('batch_$cleanId');
      debugPrint("✅ Subscribed to batch topic: batch_$cleanId");
    } catch (e) {
      debugPrint("⚠️ Failed to subscribe to batch topic: $e");
    }
  }

  /// Unsubscribe from a batch topic
  static Future<void> unsubscribeFromBatch(String batchId) async {
    if (!_isInitialized) return;
    try {
      final cleanId = batchId.replaceAll(RegExp(r'[^a-zA-Z0-9-_.~%]'), '_');
      await FirebaseMessaging.instance.unsubscribeFromTopic('batch_$cleanId');
    } catch (_) {}
  }
}
