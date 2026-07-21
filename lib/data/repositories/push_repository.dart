import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_config.dart';

/// Native push, ported from `src/lib/push.ts` + `push.functions.ts` +
/// `push-dispatch.server.ts`.
///
/// IMPORTANT ARCHITECTURE NOTE: the existing web app registers *Web Push*
/// subscriptions (endpoint/p256dh/auth) into `push_subscriptions` and sends
/// via the VAPID protocol from a TanStack server function. Native apps use
/// FCM device tokens instead, which are a completely different delivery
/// mechanism — a browser Web Push endpoint cannot receive a message sent to
/// an FCM token or vice versa. So this app:
///   1. Stores its FCM token in a NEW `fcm_tokens` table (see
///      supabase/migrations/…_fcm_tokens.sql) — the original
///      `push_subscriptions` table is untouched and keeps serving the PWA.
///   2. Dispatches sends through a NEW Supabase Edge Function
///      (`send-fcm-push`) that calls the FCM HTTP v1 API — the original
///      `push-dispatch.server.ts` keeps serving the PWA's Web Push sends.
/// Both dispatch paths are triggered from the same app events (send_bell,
/// message insert) — the Flutter app just also calls the Edge Function in
/// addition to (or instead of, if the PWA isn't in scope) whatever the web
/// client already does.
class PushRepository {
  PushRepository(this._client);
  final SupabaseClient _client;

  Future<void> saveFcmToken({
    required String userId,
    required String token,
    String? platform,
  }) async {
    await _client.from('fcm_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': platform,
        'last_seen_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  Future<void> deleteFcmToken(String token) async {
    await _client.from('fcm_tokens').delete().eq('token', token);
  }

  /// Calls the `send-fcm-push` Edge Function. Fire-and-forget from the
  /// caller's perspective, same as `dispatchPush(...).catch(console.error)`
  /// in the React app — failures here should never block the UI action
  /// that triggered them (ringing a bell, sending a message).
  Future<void> dispatch({required String kind, required String id}) async {
    await _client.functions.invoke(
      AppConfig.fcmDispatchFunction,
      body: {'kind': kind, 'id': id},
    );
  }
}

/// Decodes the `data` payload of an FCM message the same way the web app's
/// service worker decodes its Web Push payload JSON (`{ title, body, url,
/// kind, tag }`), so both platforms can share one notification-routing
/// convention.
class PushPayload {
  final String? title;
  final String? body;
  final String? url;
  final String? kind;
  final String? tag;

  const PushPayload({this.title, this.body, this.url, this.kind, this.tag});

  factory PushPayload.fromData(Map<String, dynamic> data) {
    // The FCM `data` map only supports string values; if the whole payload
    // was sent as a single JSON string under a `payload` key, decode that.
    if (data['payload'] is String) {
      final decoded = jsonDecode(data['payload'] as String) as Map<String, dynamic>;
      return PushPayload(
        title: decoded['title'] as String?,
        body: decoded['body'] as String?,
        url: decoded['url'] as String?,
        kind: decoded['kind'] as String?,
        tag: decoded['tag'] as String?,
      );
    }
    return PushPayload(
      title: data['title'] as String?,
      body: data['body'] as String?,
      url: data['url'] as String?,
      kind: data['kind'] as String?,
      tag: data['tag'] as String?,
    );
  }
}
