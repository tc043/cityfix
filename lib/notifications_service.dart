import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsService {
  static final NotificationsService _instance = NotificationsService._internal();
  factory NotificationsService() => _instance;
  NotificationsService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Channel IDs
  final String _mainChannelId = 'main_channel';
  final String _reportChannelId = 'report_updates';

  bool _initialized = false;

  // Initialize notifications
  Future<void> init() async {
    if (_initialized) return;


    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onSelectNotification,
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }

    // Handle incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app was terminated
    FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageOpened);

    // Get and store FCM token
    await _getFcmToken();

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
      }
    });

    _initialized = true;
  }

  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    // Main channel
    const AndroidNotificationChannel mainChannel = AndroidNotificationChannel(
      'main_channel',
      'Main Channel',
      description: 'Main notifications channel',
      importance: Importance.high,
    );

    // Report updates channel
    const AndroidNotificationChannel reportChannel = AndroidNotificationChannel(
      'report_updates',
      'Report Updates',
      description: 'Notifications about report status updates',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(mainChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reportChannel);
  }

  // Get FCM token for this device
  Future<String?> _getFcmToken() async {
    final token = await _fcm.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    }
    return token;
  }


  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) async {
    // Check if notifications are enabled
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;

    if (!notificationsEnabled) return;

    // Extract notification data
    final notification = message.notification;
    final android = message.notification?.android;
    final data = message.data;

    if (notification != null) {
      final channelId = data['channel_id'] ?? _mainChannelId;

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId == _reportChannelId ? 'Report Updates' : 'Main Channel',
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            priority: Priority.high,
            importance: Importance.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: json.encode(data),
      );
    }
  }

  // Handle notification tap when app was terminated
  void _handleInitialMessage(RemoteMessage? message) {
    if (message != null) {
      _handleNotificationTapped(message.data);
    }
  }

  // Handle notification tap when app was in background
  void _handleBackgroundMessageOpened(RemoteMessage message) {
    _handleNotificationTapped(message.data);
  }

  // Handle notification selection/tap
  void _onSelectNotification(NotificationResponse details) {
    try {
      final payload = details.payload;
      if (payload != null) {
        final data = json.decode(payload) as Map<String, dynamic>;
        _handleNotificationTapped(data);
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  // Process notification tap based on type
  void _handleNotificationTapped(Map<String, dynamic> data) {
    final notificationType = data['type'];
    final id = data['id'];

    // Here you'll handle navigation based on notification type
    switch (notificationType) {
      case 'report_update':
        if (id != null) {
          // Navigate to specific report details
          // You'll need to implement this navigation
          debugPrint('Navigate to report: $id');
        }
        break;
      case 'announcement':
      // Navigate to announcements screen
        debugPrint('Navigate to announcements');
        break;
      default:
      // Handle other types or just open the app
        break;
    }
  }

  // Toggle notifications enabled/disabled
  Future<void> toggleNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', enabled);

    if (enabled) {
      // Re-subscribe to topics
      await subscribeToTopic('all_users');
      await subscribeToTopic('reports');
    } else {
      // Unsubscribe from topics
      await unsubscribeFromTopic('all_users');
      await unsubscribeFromTopic('reports');
    }
  }

  // Send a test local notification (useful for debugging)
  Future<void> sendTestNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;

    if (!notificationsEnabled) {
      debugPrint('Notifications are disabled');
      return;
    }

    await _localNotifications.show(
      0,
      'Test Notification',
      'This is a test notification from CityFix',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _mainChannelId,
          'Main Channel',
          priority: Priority.high,
          importance: Importance.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}