// supabase/functions/send-fcm-push/index.ts
//
// Deploy with:  supabase functions deploy send-fcm-push
// Secrets needed (supabase secrets set ...):
//   SUPABASE_URL                    (auto-provided in the function runtime)
//   SUPABASE_SERVICE_ROLE_KEY       (same one push-dispatch.server.ts uses)
//   FCM_SERVICE_ACCOUNT_JSON        the full Firebase service account JSON,
//                                   as a single-line string (Project settings
//                                   → Service accounts → Generate new private key)
//
// This is a NEW function alongside the existing Web Push dispatch code in
// `src/lib/push-dispatch.server.ts` — that file and `push_subscriptions`
// keep serving the PWA untouched. This function reads the SAME `bells` /
// `messages` rows the web app already writes, and sends to the NEW
// `fcm_tokens` table's native device tokens instead of Web Push endpoints.
//
// Request body: { "kind": "bell" | "message", "id": "<row uuid>" }
// Called via `supabase.functions.invoke('send-fcm-push', { body })` from the
// Flutter app right after a successful `send_bell` RPC or message insert —
// see lib/data/repositories/push_repository.dart.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SERVICE_ACCOUNT_JSON = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON')!;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
const serviceAccount = JSON.parse(SERVICE_ACCOUNT_JSON) as {
  project_id: string;
  client_email: string;
  private_key: string;
};

// --- Google OAuth2 access token (cached in-memory for the isolate's lifetime) ---
let cachedToken: { token: string; expiresAt: number } | null = null;

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : new Uint8Array(input);
  let str = '';
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.token;

  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;
  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(signature)}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error(`OAuth token exchange failed: ${res.status} ${await res.text()}`);
  const data = await res.json();
  cachedToken = { token: data.access_token, expiresAt: now + data.expires_in };
  return cachedToken.token;
}

// --- Payload building --------------------------------------------------------

type Recipients = { userIds: string[] };

async function recipientsForBell(bellId: string): Promise<{ senderId: string; payload: Record<string, string> } & Recipients> {
  const { data: bell, error } = await admin
    .from('bells')
    .select('id, sender_id, recipient_id, group_id, sender:profiles!bells_sender_id_profile_fkey(display_name), groups(name)')
    .eq('id', bellId)
    .single();
  if (error || !bell) throw new Error(`Bell ${bellId} not found: ${error?.message}`);

  let userIds: string[] = [];
  if (bell.recipient_id) {
    userIds = [bell.recipient_id];
  } else if (bell.group_id) {
    const { data: members } = await admin
      .from('group_members')
      .select('user_id')
      .eq('group_id', bell.group_id);
    userIds = (members ?? []).map((m) => m.user_id).filter((id) => id !== bell.sender_id);
  }

  const senderName = (bell as any).sender?.display_name ?? 'Someone';
  const groupName = (bell as any).groups?.name as string | undefined;
  return {
    senderId: bell.sender_id,
    userIds,
    payload: {
      kind: 'bell',
      title: '🔔 Incoming bell',
      body: groupName ? `${senderName} rang ${groupName}` : `${senderName} is ringing you`,
      url: bell.group_id ? `/chat/group:${bell.group_id}` : `/chat/dm:${bell.sender_id}`,
      tag: `bell-${bell.id}`,
    },
  };
}

async function recipientsForMessage(messageId: string): Promise<{ senderId: string; payload: Record<string, string> } & Recipients> {
  const { data: message, error } = await admin
    .from('messages')
    .select('id, sender_id, recipient_id, group_id, content, sender:profiles!messages_sender_id_profile_fkey(display_name)')
    .eq('id', messageId)
    .single();
  if (error || !message) throw new Error(`Message ${messageId} not found: ${error?.message}`);

  let userIds: string[] = [];
  if (message.recipient_id) {
    userIds = [message.recipient_id];
  } else if (message.group_id) {
    const { data: members } = await admin
      .from('group_members')
      .select('user_id')
      .eq('group_id', message.group_id);
    userIds = (members ?? []).map((m) => m.user_id).filter((id) => id !== message.sender_id);
  }

  const senderName = (message as any).sender?.display_name ?? 'Someone';
  return {
    senderId: message.sender_id,
    userIds,
    payload: {
      kind: 'message',
      title: senderName,
      body: String(message.content ?? '').slice(0, 120),
      url: message.group_id ? `/chat/group:${message.group_id}` : `/chat/dm:${message.sender_id}`,
      tag: message.group_id ? `group-${message.group_id}` : `dm-${message.sender_id}`,
    },
  };
}

async function sendToToken(projectId: string, accessToken: string, token: string, payload: Record<string, string>) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        data: payload,
        notification: { title: payload.title, body: payload.body },
        android: { priority: 'high' },
        apns: {
          headers: { 'apns-priority': '10' },
          payload: { aps: { sound: 'default', 'content-available': 1 } },
        },
      },
    }),
  });
  return res;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  try {
    const { kind, id } = (await req.json()) as { kind: 'bell' | 'message'; id: string };
    if (!id || (kind !== 'bell' && kind !== 'message')) {
      return new Response(JSON.stringify({ error: 'invalid body' }), { status: 400 });
    }

    const { userIds, payload } = kind === 'bell'
      ? await recipientsForBell(id)
      : await recipientsForMessage(id);

    if (userIds.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), { status: 200 });
    }

    const { data: tokenRows } = await admin
      .from('fcm_tokens')
      .select('id, token')
      .in('user_id', userIds);

    if (!tokenRows || tokenRows.length === 0) {
      return new Response(JSON.stringify({ ok: true, sent: 0 }), { status: 200 });
    }

    const accessToken = await getAccessToken();
    const staleTokenIds: string[] = [];
    let sent = 0;

    await Promise.all(
      tokenRows.map(async (row) => {
        const res = await sendToToken(serviceAccount.project_id, accessToken, row.token, payload);
        if (res.ok) {
          sent += 1;
        } else if (res.status === 404 || res.status === 400) {
          const body = await res.text();
          if (body.includes('UNREGISTERED') || body.includes('NOT_FOUND') || body.includes('INVALID_ARGUMENT')) {
            staleTokenIds.push(row.id);
          }
        }
      }),
    );

    if (staleTokenIds.length > 0) {
      await admin.from('fcm_tokens').delete().in('id', staleTokenIds);
    }

    return new Response(JSON.stringify({ ok: true, sent, pruned: staleTokenIds.length }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('send-fcm-push error', err);
    return new Response(JSON.stringify({ ok: false, error: String(err) }), { status: 500 });
  }
});
