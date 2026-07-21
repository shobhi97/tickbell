import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'data/supabase/supabase_client_provider.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/notification_service_provider.dart';
import 'shared/services/push_availability.dart' as push_availability;

/// Global navigator/router container so the background message handler
/// (which runs before any widget tree exists) and the notification-tap
/// callback can both reach GoRouter. Populated once ProviderScope + the
/// router are created in `main()`.
late ProviderContainer _container;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    push_availability.firebasePushAvailable = true;
  } catch (e) {
    // No google-services.json/GoogleService-Info.plist yet, or Firebase
    // project not linked — that's fine for now, just skip push.
    debugPrint('Firebase not configured — push notifications disabled ($e)');
  }

  await initSupabase();

  _container = ProviderContainer();

  if (push_availability.firebasePushAvailable) {
    final notificationService = _container.read(notificationServiceProvider);
    try {
      await notificationService.init();
      notificationService.onNotificationTap = (url) {
        final router = _container.read(routerProvider);
        router.go(url);
      };

      final userId = _container.read(currentUserIdProvider);
      if (userId != null) {
        await notificationService.registerTokenForUser(userId);
      }
    } catch (e) {
      debugPrint('Push notification setup failed, continuing without it: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: _container,
      child: const TickBellApp(),
    ),
  );
}
