import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase Auth. Mirrors `src/routes/auth.tsx` and
/// `profile.tsx`'s logout handler in the React app 1:1.
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Returns true if a session was created immediately (email confirmation
  /// disabled), false if the user must confirm their email first — matching
  /// the web app's `if (!data.session)` branch.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim().isNotEmpty ? displayName.trim() : email.split('@').first},
    );
    return res.session != null;
  }

  /// Native/deep-link Google OAuth. Requires the redirect scheme configured
  /// in the Supabase dashboard (Authentication → URL Configuration) and in
  /// the native Android/iOS projects — see SETUP.md.
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.tickbell.app://login-callback/',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Human-friendly error text — ported from the `friendly` regex switch in
  /// the React app's `handleSubmit` catch block.
  static String friendlyMessage(Object err) {
    final raw = err is AuthException ? err.message : err.toString();
    if (RegExp('invalid login credentials', caseSensitive: false).hasMatch(raw)) {
      return "Wrong email or password. If you're new here, tap 'Create an account'.";
    }
    if (RegExp('user already registered|already been registered', caseSensitive: false).hasMatch(raw)) {
      return 'That email is already registered. Try signing in instead.';
    }
    if (RegExp('weak|pwned|leaked|compromised', caseSensitive: false).hasMatch(raw)) {
      return 'That password is too common. Please pick a stronger one (mix letters, numbers, symbols).';
    }
    return raw;
  }
}
