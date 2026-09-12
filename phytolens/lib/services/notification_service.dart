// lib/services/notification_service.dart

import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log('FCM Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseService _supabase = SupabaseService();
  bool _initialized = false;

  /// Initialize FCM listeners and permissions
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Request notification permissions
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      log('FCM Permission status: ${settings.authorizationStatus}');

      // 2. Set background messaging handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 3. Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('FCM Foreground message: ${message.notification?.title} - ${message.notification?.body}');
      });

      // 4. Notification tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log('FCM Notification opened app: ${message.data}');
      });

      // 5. Get and register FCM token
      await syncDeviceToken();

      // 6. Token refresh listener
      _fcm.onTokenRefresh.listen((newToken) async {
        log('FCM Token refreshed: $newToken');
        await _saveTokenToSupabase(newToken);
      });

      // 7. Subscribe to global topic
      await _fcm.subscribeToTopic('all');
    } catch (e) {
      log('Error initializing FCM: $e');
    }
  }

  /// Sync FCM token for currently logged in user
  Future<void> syncDeviceToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        log('FCM Device Token: $token');
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      log('Error fetching FCM token: $e');
    }
  }

  /// Update user's FCM token in Supabase
  Future<void> _saveTokenToSupabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await _supabase.updateUser(user.uid, {
          'fcm_token': token,
        });
        log('FCM token saved to Supabase for user: ${user.uid}');
      } catch (e) {
        log('Failed to save FCM token to Supabase: $e');
      }
    }
  }

  /// Update user's subscribed topic based on plan tier
  Future<void> updateTopicForTier(String tier) async {
    try {
      await _fcm.unsubscribeFromTopic('tier_free');
      await _fcm.unsubscribeFromTopic('tier_pro');
      await _fcm.unsubscribeFromTopic('tier_farm');

      await _fcm.subscribeToTopic('tier_$tier');
      log('Subscribed device to FCM topic: tier_$tier');
    } catch (e) {
      log('Error updating FCM tier topic: $e');
    }
  }

  /// Send broadcast push notification via Supabase Edge Function
  Future<Map<String, dynamic>> sendAdminNotification({
    required String title,
    required String body,
    required String targetTier, // 'all', 'free', 'pro', 'farm'
    String? userId,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'send-notification',
        body: {
          'title': title,
          'body': body,
          'targetTier': targetTier,
          'userId': userId,
        },
      );

      log('Edge Function send-notification response: ${res.data}');

      if (res.status != 200 && res.status != 201) {
        throw Exception('Edge function returned status ${res.status}: ${res.data}');
      }

      return res.data is Map<String, dynamic> ? res.data : {'success': true};
    } catch (e) {
      log('Error triggering Edge Function send-notification: $e');
      rethrow;
    }
  }
}
