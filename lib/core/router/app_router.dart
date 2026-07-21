import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/supabase/supabase_client_provider.dart';
import '../../features/admin/blocks_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/group/group_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../shared/widgets/authenticated_shell.dart';
import 'go_router_refresh_stream.dart';

/// Ports the auth-gate redirect logic in `_authenticated/route.tsx` +
/// `router.tsx`. Public routes: `/auth`. Everything else requires a
/// session, mirroring `beforeLoad` throwing a redirect to `/auth`.
final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);

  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: GoRouterRefreshStream(client.auth.onAuthStateChange),
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final onAuthScreen = state.matchedLocation == '/auth';
      if (!loggedIn && !onAuthScreen) return '/auth';
      if (loggedIn && onAuthScreen) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      ShellRoute(
        builder: (context, state, child) => AuthenticatedShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) => ChatScreen(chatId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/group/:id',
            builder: (context, state) => GroupScreen(groupId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          GoRoute(path: '/admin/blocks', builder: (context, state) => const AdminBlocksScreen()),
        ],
      ),
    ],
  );
});
