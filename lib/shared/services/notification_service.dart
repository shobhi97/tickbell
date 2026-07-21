import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/repositories/push_repository.dart';

/// Ports `src/lib/push.ts` (Web Push registration) and
/// `src/lib/tickbell.ts#showBrowserNotification` for native FCM delivery.
///
/// Must call [init] once after Firebase.initializeApp() and after the user
/// is signed in (so the token can be attached to their account), and call
/// [registerTokenForUser] again on every sign-in.
class NotificationService {
  NotificationService(this._pushRepository);
  final PushRepository _pushRepository;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'tickbell_alerts',
    'TickBell Alerts',
    description: 'Bell rings, chat messages, and bell responses',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  /// Navigation callback wired up by the app shell (routes to /chat/:id etc.)
  void Function(String url)? onNotificationTap;

  Future<void> init() async {
    await _initLocalNotifications();

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleOpenedMessage(initialMessage);
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final url = response.payload;
        if (url != null && onNotificationTap != null) onNotificationTap!(url);
      },
    );
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final payload = PushPayload.fromData(message.data);
    final title = payload.title ?? message.notification?.title ?? 'TickBell';
    final body = payload.body ?? message.notification?.body ?? '';
    final isBell = payload.kind == 'bell';
    final notificationId = (payload.tag ?? '${payload.kind ?? 'notif'}-${message.messageId ?? title}').hashCode;

    await _localNotifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: isBell ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
          fullScreenIntent: isBell,
          ticker: title,
          ongoing: false,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: payload.url ?? '/home',
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final payload = PushPayload.fromData(message.data);
    final url = payload.url ?? '/home';
    onNotificationTap?.call(url);
  }

  /// Call after sign-in. Attaches the current FCM token to the signed-in
  /// user and keeps it fresh on rotation.
  Future<void> registerTokenForUser(String userId) async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _pushRepository.saveFcmToken(
        userId: userId,
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _pushRepository.saveFcmToken(
        userId: userId,
        token: newToken,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
    });
  }

  Future<void> unregisterOnSignOut() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _pushRepository.deleteFcmToken(token);
    }
  }
}

/// Top-level background handler — must be a top-level or static function per
/// the firebase_messaging plugin's requirements. Register in `main()` via
/// `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM + APNs already display a system notification for background
  // messages when the payload includes a `notification` block (which the
  // send-fcm-push Edge Function always includes), so there's nothing to do
  // here beyond letting the OS handle it. This hook exists so the plugin is
  // wired correctly and so you have a place to add background data-sync
  // logic later if needed.
}
