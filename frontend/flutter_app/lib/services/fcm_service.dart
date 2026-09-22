import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/chat_page.dart';
import '../screens/metro_ride_details_page.dart';
import 'api_service.dart';

// Top-level background message handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("⚡ FCM Background Push Received: ${message.notification?.title}");
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Track if user is currently looking at a specific chat screen (prevents duplicate heads-up alerts)
  static String? currentActiveChatRideId;

  static const AndroidNotificationChannel _rideChannel =
      AndroidNotificationChannel(
    'automate_rides_channel',
    'AutoMate Ride Alerts',
    description: 'Real-time alerts for ride bookings, cancellations, and messages.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Initialize Firebase, Permissions, Notification Channels, and Listeners
  static Future<void> initialize() async {
    try {
      // 1. Request Notification Permissions (Android 13+ & iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint("🔔 FCM Permission status: ${settings.authorizationStatus}");

      // 2. Setup Local Notification Channel for Android
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_rideChannel);

      // 3. Initialize Local Notifications Plugin
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!);
              _handleNotificationTap(data);
            } catch (e) {
              debugPrint("Error parsing notification payload: $e");
            }
          }
        },
      );

      // 4. Foreground Message Listener (When App is Open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("📩 FCM Foreground Message: ${message.notification?.title}");
        final data = message.data;
        final rideId = data['rideId']?.toString();
        final type = data['type']?.toString();

        // 🚫 Suppress notification if user is already looking at this exact chat screen
        if (type == 'CHAT_MESSAGE' &&
            currentActiveChatRideId != null &&
            currentActiveChatRideId == rideId) {
          return;
        }

        final notification = message.notification;
        if (notification != null) {
          _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _rideChannel.id,
                _rideChannel.name,
                channelDescription: _rideChannel.description,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
                playSound: true,
              ),
            ),
            payload: jsonEncode(data),
          );
        }
      });

      // 5. App Opened from Background via Notification Tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("🚀 FCM App Opened via Notification Tap: ${message.data}");
        _handleNotificationTap(message.data);
      });

      // 6. App Launched from Terminated/Killed State via Notification Tap
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint("🚀 FCM App Launched from Terminated: ${initialMessage.data}");
        Future.delayed(const Duration(milliseconds: 1000), () {
          _handleNotificationTap(initialMessage.data);
        });
      }

      // 7. Sync Device Token with Backend
      await syncDeviceToken();

      // 8. Refresh Token Listener
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint("🔄 FCM Token Refreshed");
        _sendTokenToBackend(newToken);
      });
    } catch (e) {
      debugPrint("❌ FCM Initialization error: $e");
    }
  }

  /// Fetches FCM token and uploads to backend
  static Future<void> syncDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint("🔑 FCM Device Token: $token");
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint("Error fetching FCM token: $e");
    }
  }

  /// Sends token to Node.js backend
  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final jwt = await ApiService.getToken();
      if (jwt == null || jwt.isEmpty) return; // User not logged in yet

      await ApiService.postRequest('/auth/fcm-token', {
        'fcmToken': token,
        'deviceType': 'android',
      });
      debugPrint("✅ FCM token successfully registered with backend");
    } catch (e) {
      debugPrint("Failed to register FCM token with backend: $e");
    }
  }

  /// Deep Links to the target ride or chat page on tap
  static void _handleNotificationTap(Map<String, dynamic> data) {
    final rideId = data['rideId']?.toString();
    final type = data['type']?.toString();

    if (rideId == null || rideId.isEmpty) return;

    final navContext = ApiService.navigatorKey.currentContext;
    if (navContext == null) return;

    if (type == 'CHAT_MESSAGE') {
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(rideId: rideId),
        ),
      );
    } else {
      Navigator.of(navContext).push(
        MaterialPageRoute(
          builder: (_) => MetroRideDetailsPage(rideId: rideId),
        ),
      );
    }
  }
}
