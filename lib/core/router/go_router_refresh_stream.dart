import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges any Stream to GoRouter's `refreshListenable`, so router redirects
/// re-evaluate whenever Supabase's auth state changes (sign in / sign out) —
/// equivalent to the web app's `router.invalidate()` call inside its
/// `onAuthStateChange` listener in `__root.tsx`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
