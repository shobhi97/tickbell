/// Central runtime configuration.
///
/// Mirrors the React app's `VITE_SUPABASE_URL` / `VITE_SUPABASE_PUBLISHABLE_KEY`
/// env vars. Pass these at build/run time so no secrets are hard-coded:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=your-anon-or-publishable-key
///
/// The anon/publishable key is safe to embed in a shipped app — RLS enforces
/// access on the database side, exactly as documented in the web app's
/// `.env.example`. Never put the service_role key in the Flutter app.
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Name of the Supabase Edge Function that dispatches FCM pushes.
  /// See supabase/functions/send-fcm-push in this repo.
  static const fcmDispatchFunction = 'send-fcm-push';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
