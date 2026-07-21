# Setup guide

## 0. Prerequisites

- Flutter (stable channel) installed and on PATH — `flutter doctor` should
  be clean for the platforms you're targeting.
- A Firebase project linked to your app (create one if you don't have one;
  it's independent of Supabase).
- The Supabase CLI, if you'll deploy the migration/Edge Function from here
  rather than through your existing pipeline.

## 1. Scaffold the native projects

This code was written without access to the Flutter SDK, so `android/` and
`ios/` are **not** pre-generated native projects — running `flutter create`
in-place is what normally produces them, and it needs the real toolchain.
From the project root:

```bash
flutter create . --platforms=android,ios --org io.tickbell
flutter pub get
```

This won't touch `lib/`, `pubspec.yaml`, or the `supabase/` folder — it only
fills in `android/`, `ios/`, and a couple of top-level Flutter housekeeping
files.

## 2. Firebase (push notifications)

1. In the [Firebase console](https://console.firebase.google.com), create/open
   a project, then add an Android app (package name must match
   `android/app/build.gradle`'s `applicationId`, e.g. `io.tickbell.app`) and
   an iOS app (bundle id must match `ios/Runner.xcodeproj`, same value).
2. Download `google-services.json` → place it at `android/app/google-services.json`.
3. Download `GoogleService-Info.plist` → add it to `ios/Runner/` via Xcode
   (drag into the Runner target so it's actually bundled).
4. Android: in `android/build.gradle` add the Google services classpath, and
   in `android/app/build.gradle` apply the `com.google.gms.google-services`
   plugin — `flutterfire configure` (from the `flutterfire_cli` package) can
   do steps 2–4 for you if you'd rather not hand-edit Gradle files.
5. iOS: enable **Push Notifications** and **Background Modes → Remote
   notifications** capabilities in Xcode's Signing & Capabilities tab, and
   upload an APNs auth key (Apple Developer portal) to Firebase → Project
   Settings → Cloud Messaging.
6. Generate a **service account** key for the FCM HTTP v1 API (Project
   Settings → Service Accounts → Generate new private key) — you'll use the
   downloaded JSON in step 4 below, not in the app itself.

## 3. Google OAuth deep link (native sign-in)

The app calls `signInWithOAuth` with redirect
`io.tickbell.app://login-callback/`. Wire this up in three places:

- **Supabase dashboard** → Authentication → URL Configuration → Redirect
  URLs → add `io.tickbell.app://login-callback/`.
- **Android** — in `android/app/src/main/AndroidManifest.xml`, inside the
  `<activity>` for `MainActivity`, add an intent filter:
  ```xml
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.tickbell.app" android:host="login-callback" />
  </intent-filter>
  ```
- **iOS** — in `ios/Runner/Info.plist`, add:
  ```xml
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLSchemes</key>
      <array><string>io.tickbell.app</string></array>
    </dict>
  </array>
  ```

If you'd rather not stand up a native deep link yet, comment out the
"Continue with Google" button in `lib/features/auth/auth_screen.dart` —
email/password auth works with zero extra native config.

## 4. Backend additions (FCM push dispatch)

```bash
supabase link --project-ref <your-project-ref>
supabase db push                                  # applies fcm_tokens migration
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json | tr -d '\n')"
supabase functions deploy send-fcm-push
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically to
Edge Functions at runtime — no need to set those secrets yourself.

## 5. Run it

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-or-publishable-key>
```

For a release build, pass the same `--dart-define`s to `flutter build apk`
/ `flutter build ipa`, or bake them into your CI via
`--dart-define-from-file`.

## 6. First build-and-fix pass

Since this was written without a Flutter/Dart toolchain, treat the first
`flutter pub get && flutter analyze` as a normal integration step, not a
sign that something went unusually wrong. The import graph, brace/paren
balance, and every Riverpod provider reference were checked by hand/script
already (see the project README), so expect mostly minor things: exact
`supabase_flutter`/`go_router` API surface drift between the pinned
versions in `pubspec.yaml` and whatever the resolver picks, and any
Android/iOS Gradle/Xcode config from step 1 that needs a version bump.
If you'd like, hand this off to Claude Code (which has a real Flutter
toolchain and pub.dev access) to run the build loop and fix anything that
comes up automatically.
