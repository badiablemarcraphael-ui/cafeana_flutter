import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'web_notification_helper.dart';

/// Top-level background message handler for Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] Message received: ${message.messageId}');
}

/// Cross-platform notification service for Cafeana (Web & Mobile).
///
/// On Web:
/// - Displays native OS desktop / taskbar notifications (Windows Taskbar toast / Mac Notification Center)
/// - Utilizes Service Worker `firebase-messaging-sw.js` for background web push notifications
///
/// On Mobile:
/// - Displays system heads-up notifications in the Android notification drawer with sound and vibration
/// - Connects to Firebase Cloud Messaging (FCM) so push notifications arrive even when the app is terminated/removed
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Reactive notifier triggered whenever a user taps an order notification in the system tray or taskbar.
  /// Holds the orderId so the router can immediately navigate to [OrderTrackingPage].
  static final ValueNotifier<String?> onNotificationOrderTapped =
      ValueNotifier<String?>(null);

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Retrieves the current device FCM push token.
  Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[NotificationService] getFcmToken note: $e');
      return null;
    }
  }

  /// Initializes notification systems for the active platform.
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb) {
      // 1. Android / iOS local notifications initialization
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          debugPrint('[Notification] Local notification tapped with payload: $payload');
          if (payload != null && payload.isNotEmpty) {
            onNotificationOrderTapped.value = payload;
          }
        },
      );

      // Check if the app was launched by tapping a local notification (cold start)
      try {
        final launchDetails =
            await _localNotifications.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true &&
            launchDetails?.notificationResponse?.payload != null) {
          final payload = launchDetails!.notificationResponse!.payload;
          if (payload != null && payload.isNotEmpty) {
            onNotificationOrderTapped.value = payload;
          }
        }
      } catch (e) {
        debugPrint('[NotificationService] Launch details note: $e');
      }

      // Create Android Notification Channel with high priority & sound
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'cafeana_orders',
        'Caféana Order Updates',
        description:
            'Instant alerts for order status updates (queued, preparing, ready).',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidImpl = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl.createNotificationChannel(channel);
        await androidImpl.requestNotificationsPermission();
      }

      // 2. Firebase Cloud Messaging initialization for Mobile
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);

        // When a foreground FCM message arrives
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          final notification = message.notification;
          if (notification != null) {
            showNotification(
              title: notification.title ?? 'Caféana Order Update',
              body: notification.body ?? '',
              payload: (message.data['orderId'] as String?) ??
                  message.data['orderId']?.toString(),
            );
          }
        });

        // When user taps a background notification banner to open the app
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          final orderId = (message.data['orderId'] as String?) ??
              message.data['orderId']?.toString();
          debugPrint('[FCM] Message opened app with orderId: $orderId');
          if (orderId != null && orderId.isNotEmpty) {
            onNotificationOrderTapped.value = orderId;
          }
        });

        // When user taps a notification that launches the app from a closed/terminated state
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          final orderId = (initialMessage.data['orderId'] as String?) ??
              initialMessage.data['orderId']?.toString();
          debugPrint('[FCM] Cold-start message opened with orderId: $orderId');
          if (orderId != null && orderId.isNotEmpty) {
            onNotificationOrderTapped.value = orderId;
          }
        }
      } catch (e) {
        debugPrint('[NotificationService] FCM setup note: $e');
      }
    } else {
      // On Web: initialize FCM permissions & service worker connection
      try {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        await requestWebNotificationPermission();
      } catch (e) {
        debugPrint('[NotificationService] Web FCM setup note: $e');
      }
    }

    _isInitialized = true;
  }

  /// Requests explicit user notification permission (e.g., button click on Checkout or Profile).
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return await requestWebNotificationPermission();
    } else {
      try {
        final settings =
            await FirebaseMessaging.instance.requestPermission(alert: true, sound: true, badge: true);
        return settings.authorizationStatus == AuthorizationStatus.authorized;
      } catch (e) {
        return false;
      }
    }
  }

  /// Displays an instant push/system notification in the taskbar or notification tray.
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String? tag,
    int? id,
    bool ongoing = false,
  }) async {
    if (kIsWeb) {
      // Shows native OS taskbar toast / notification center popup
      await showWebNotification(
        title: title,
        body: body,
        tag: tag ?? payload,
      );
    } else {
      final notifId = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final androidDetails = AndroidNotificationDetails(
        'cafeana_orders',
        'Caféana Order Updates',
        channelDescription:
            'Instant alerts for order status updates (queued, preparing, ready).',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ongoing: ongoing,
        autoCancel: !ongoing,
        onlyAlertOnce: false,
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        ticker: 'Caféana Order Update',
        showWhen: true,
        icon: '@mipmap/launcher_icon',
      );
      final details = NotificationDetails(android: androidDetails);
      await _localNotifications.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    }
  }

  /// Formatted order status notification helper for the ordering lifecycle.
  /// Uses the orderNumber as notification ID so status transitions update the same
  /// notification banner in-place instead of spamming duplicates.
  Future<void> showOrderStatusNotification({
    required int orderNumber,
    required String status,
    String? orderId,
  }) async {
    String title;
    String body;
    final normStatus = status.toLowerCase();
    final bool isLiveOrder = normStatus == 'queued' ||
        normStatus == 'preparing' ||
        normStatus == 'ready';

    switch (normStatus) {
      case 'queued':
        title = 'Order #$orderNumber Received ⏳';
        body =
            'Your order has been queued in the kitchen. We will alert you when preparation starts!';
        break;
      case 'preparing':
        title = 'Preparing Order #$orderNumber ☕';
        body = 'The kitchen has started preparing your artisanal drink!';
        break;
      case 'ready':
        title = 'Order #$orderNumber Ready for Pickup! 🎉';
        body =
            'Order #$orderNumber is ready at the counter! Please come collect your order.';
        break;
      case 'completed':
      case 'received':
        title = 'Order #$orderNumber Completed ✨';
        body = 'Thank you for ordering at Caféana! Enjoy every sip.';
        break;
      case 'cancelled':
        title = 'Order #$orderNumber Cancelled';
        body = 'Your order #$orderNumber has been cancelled.';
        break;
      default:
        title = 'Order #$orderNumber Update';
        body = 'Your order status is now: $status';
    }

    await showNotification(
      title: title,
      body: body,
      tag: 'order-$orderNumber',
      payload: orderId,
      id: orderNumber > 0 ? orderNumber : null,
      ongoing: isLiveOrder,
    );
  }

  /// Saves the current device FCM token to Firestore so targeted background pushes
  /// can be delivered even when the app is removed from recent apps.
  Future<void> saveTokenToFirestore(String uid,
      [FirebaseFirestore? firestore]) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final db = firestore ?? FirebaseFirestore.instance;
        await db.collection('users').doc(uid).set({
          'fcmToken': token,
          'fcmPlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('[NotificationService] FCM token saved for user $uid');
      }
    } catch (e) {
      debugPrint('[NotificationService] Failed to save FCM token: $e');
    }
  }
}
