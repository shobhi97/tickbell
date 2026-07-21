import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_config.dart';

/// Call once in `main()` before `runApp`.
Future<void> initSupabase() async {
  if (!AppConfig.isConfigured) {
    throw StateError(
      'Missing SUPABASE_URL / SUPABASE_ANON_KEY. Pass them with --dart-define '
      'when running/building (see lib/core/constants/app_config.dart).',
    );
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Stream of Supabase auth state changes — drives the router redirect logic
/// and lets any widget react to sign-in/sign-out, mirroring the web app's
/// `supabase.auth.onAuthStateChange` listener in `__root.tsx`.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Current user id, or null if signed out. Equivalent to `useCurrentUser()`.
final currentUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  // Re-evaluate whenever auth state changes.
  ref.watch(authStateChangesProvider);
  return client.auth.currentSession?.user.id;
});
