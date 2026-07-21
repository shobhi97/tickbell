# TickBell — Flutter (native)

A native Flutter client for the existing TickBell Supabase backend
(`sathchinn/urgent-connect`). No WebView — this talks to Supabase directly
via `supabase_flutter`, reusing your existing schema, RLS policies, and RPCs
(`send_bell`, `has_role`, `find_user_by_phone`, `get_group_members`) as-is.

## What was reused vs. added

**Reused, unchanged:** `profiles`, `groups`, `group_members`, `messages`,
`bells`, `bell_responses`, `bell_blocks`, `push_subscriptions`, every RLS
policy, every RPC/trigger, and Supabase Auth (email/password + Google OAuth).

**Added (additive only — nothing existing was modified):**
- `supabase/migrations/20260721000000_fcm_tokens.sql` — a new table for
  native FCM device tokens, parallel to `push_subscriptions` (Web Push).
  Native apps can't receive Web Push sends, so this couldn't be avoided —
  see the note in `lib/data/repositories/push_repository.dart`.
- `supabase/functions/send-fcm-push/index.ts` — a new Edge Function that
  sends to those tokens via FCM's HTTP v1 API, reading the same `bells`
  and `messages` rows the web app already writes. Your existing
  `push-dispatch.server.ts` keeps serving the PWA untouched.

Run `supabase db push` (or apply the migration through your normal pipeline)
and `supabase functions deploy send-fcm-push` before testing native push.

## Feature parity map

| React route / component | Flutter equivalent |
|---|---|
| `routes/auth.tsx` | `lib/features/auth/auth_screen.dart` |
| `routes/_authenticated/route.tsx` (guard + listeners) | `lib/core/router/app_router.dart` (redirect) + `lib/shared/widgets/authenticated_shell.dart` |
| `routes/_authenticated/home.tsx` → `BellTab` | `lib/features/home/bell_tab.dart` |
| `routes/_authenticated/home.tsx` → `ChatsTab` | `lib/features/home/chats_tab.dart` |
| `routes/_authenticated/home.tsx` → `ContactsTab` | `lib/features/home/contacts_tab.dart` |
| `routes/_authenticated/home.tsx` → `CreateGroupButton` | `lib/features/home/create_group_dialog.dart` |
| `routes/_authenticated/chat.$id.tsx` | `lib/features/chat/chat_screen.dart` |
| `routes/_authenticated/group.$id.tsx` | `lib/features/group/group_screen.dart` |
| `routes/_authenticated/profile.tsx` | `lib/features/profile/profile_screen.dart` |
| `routes/_authenticated/admin.blocks.tsx` | `lib/features/admin/blocks_screen.dart` |
| `components/incoming-bell.tsx` | `lib/shared/widgets/incoming_bell_overlay.dart` + `lib/shared/services/incoming_bell_controller.dart` |
| `components/message-notifier.tsx` | message-insert listener inside `authenticated_shell.dart` |
| `components/bell-response-listener.tsx` | bell-response listener inside `authenticated_shell.dart` |
| `src/lib/tickbell.ts` (send_bell wrapper, sounds, formatting) | `lib/shared/services/ring_action.dart`, `lib/shared/services/sound_service.dart`, `lib/core/utils/formatters.dart` |
| `src/lib/push.ts` / `push-dispatch.server.ts` | `lib/shared/services/notification_service.dart` + `lib/data/repositories/push_repository.dart` + `supabase/functions/send-fcm-push` |

## Folder structure

```
lib/
  core/            theme, router, constants, formatting/validation utils
  data/
    models/        Profile, Group, GroupMember, ChatMessage, Bell, BellBlock
    repositories/   one per domain area, thin wrappers over supabase_flutter
    supabase/       client bootstrap + auth-state providers
  features/
    auth/ home/ chat/ group/ profile/ admin/     one folder per screen
  shared/
    widgets/        AvatarWidget, GroupAvatar, IncomingBellOverlay, AuthenticatedShell
    services/       NotificationService, SoundService, ring_action, IncomingBellController
  providers/        cross-feature Riverpod providers (repositories, myProfile, myGroups, isAdmin)
```

State management is hand-written Riverpod (`Provider`/`FutureProvider`/
`StateNotifierProvider`), not `riverpod_generator` — deliberately, since
code generation requires running `build_runner`, and this project was built
in a sandbox with no Flutter/Dart toolchain or pub.dev access to verify that
step. Everything here is plain, generator-free Dart.

## Getting it running

```bash
flutter create . --platforms=android,ios --org io.tickbell   # scaffolds android/ ios/ properly
flutter pub get
```

Then follow `SETUP.md` for Firebase, Google OAuth deep links, and secrets,
and see "Known simplifications" below.

## Known simplifications (please read)

1. **Bell/chime sound fidelity.** The web app synthesizes its tones live
   with WebAudio oscillators — there's no audio file to port. This build
   uses matching vibration patterns + a system UI sound in the foreground
   (see `sound_service.dart`); backgrounded pushes get the OS's default
   notification sound. Drop `bell.mp3`/`chime.mp3` into
   `android/app/src/main/res/raw/` (and reference them from the Android
   notification channel + APNs payload) for an exact match — the code has
   comments marking exactly where.
2. **This code was written and structurally verified (import graph, brace
   balance, provider wiring) without a Flutter/Dart toolchain** — pub.dev
   isn't reachable from the sandbox this was built in, so `flutter pub get`
   / `flutter analyze` / `flutter build` were never run here. Expect a
   normal build-and-fix pass locally or in Claude Code; see SETUP.md.
3. **Google OAuth** uses `signInWithOAuth` with a native redirect
   (`io.tickbell.app://login-callback/`) — you'll need to register that
   scheme in the Supabase dashboard and in the native Android/iOS projects
   (SETUP.md has the exact steps).
