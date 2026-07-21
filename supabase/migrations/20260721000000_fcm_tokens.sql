-- Native push (FCM) device tokens for the Flutter app.
--
-- This is intentionally a SEPARATE table from `public.push_subscriptions`,
-- which stores Web Push subscriptions (endpoint/p256dh/auth) for the PWA.
-- The two delivery mechanisms are not interchangeable — an FCM device token
-- cannot receive a Web Push send and vice versa — so both tables and both
-- dispatch paths (the existing `push-dispatch.server.ts` for Web Push, and
-- the new `send-fcm-push` Edge Function for this table) run side by side.
-- Nothing about `push_subscriptions` or the existing dispatch code changes.

CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL UNIQUE,
  platform text CHECK (platform IN ('ios', 'android')),
  created_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.fcm_tokens TO authenticated;
GRANT ALL ON public.fcm_tokens TO service_role;

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own fcm tokens" ON public.fcm_tokens;
CREATE POLICY "Users manage own fcm tokens"
  ON public.fcm_tokens FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON public.fcm_tokens(user_id);
