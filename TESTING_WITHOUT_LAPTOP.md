# Testing this on your phone — no laptop required

You can get a working APK without installing anything, by letting GitHub's
servers do the actual `flutter build` for you. Everything below is doable
from the GitHub mobile app or your phone's browser.

## What you'll be able to test right away

Auth (sign up/sign in), Contacts, Groups (create/edit/members), Chat (DM +
group, realtime), and the Bell itself (ringing + the full-screen incoming
popup) — all of this runs over Supabase Realtime and works with **zero**
Firebase setup. The only thing that needs Firebase later is push
notifications while the app is backgrounded/killed — see "Add Firebase
later" at the bottom.

## Step 1 — Get this code into a GitHub repo

If you don't already have somewhere to put it:
- GitHub app or m.github.com → **+** → **New repository** → name it (e.g.
  `tickbell-flutter`) → Create.
- Then upload every file from the zip you were given. The GitHub mobile
  web UI supports "Add file → Upload files" and you can select multiple
  files/use a folder picker depending on your phone's file app — do this
  folder by folder if your browser only lets you pick files, not whole
  directories (`lib/`, `supabase/`, `.github/`, then the root files
  `pubspec.yaml`, `README.md`, etc.). If your phone can unzip and re-zip
  smaller pieces, that's the easiest path.
- Alternative if uploads from your phone are painful: install the
  **GitHub mobile app**, and use "Working Copy" (iOS) or **Termux** +
  `git` (Android) to clone-less create the repo by pushing a zip's
  contents — but honestly, the web upload flow is usually enough for ~45
  files.

## Step 2 — Add your Supabase credentials as repo secrets

In your new repo: **Settings → Secrets and variables → Actions → New
repository secret**. Add two:

- `SUPABASE_URL` → `https://<your-project-ref>.supabase.co`
- `SUPABASE_ANON_KEY` → your anon/publishable key (from Supabase dashboard
  → Project Settings → API — this is the same key already in your React
  app's `.env`, safe to reuse, it's public-safe by design since RLS
  enforces access)

## Step 3 — Run the build

The workflow file at `.github/workflows/build-apk.yml` is already in the
repo once you've uploaded it. Go to the **Actions** tab → **Build APK** (in
the left sidebar) → **Run workflow** button → **Run workflow** (confirm).

Wait 3-6 minutes. Refresh the run page — a green checkmark means it
succeeded.

## Step 4 — Download and install the APK

- Still on that workflow run's page, scroll to **Artifacts** → tap
  `tickbell-apk` → it downloads a zip containing `app-release.apk`.
- Unzip it on your phone (most Android file managers can do this; on
  iOS you can't install an APK at all — Android device required for this
  path, since this is a native Android build).
- Open the extracted `.apk` file → Android will prompt to allow install
  from this source the first time (Settings → apps → allow) → **Install**.
- Open **TickBell**, sign in (or create an account), and test away.

Every teammate testing this needs the same APK sent to them (or grab it
from the same Artifacts page) since it isn't published to the Play Store.

## If the build fails

Open the failed step in the Actions log (tappable on the run page) and
read the error — since I wrote this without a real Flutter toolchain to
verify against, the most likely first-run issues are small API drift
between the package versions pinned in `pubspec.yaml` and whatever
`flutter pub get` resolves today. Common fixes:
- A package version constraint too tight/loose → loosen the version in
  `pubspec.yaml` (e.g. `^2.5.11` → `^2.5.0`) and re-run.
- A Gradle/AGP/Kotlin version mismatch from the auto-scaffolded
  `android/` folder → these usually self-resolve on `flutter create .`
  since it always scaffolds versions compatible with the Flutter version
  it ships with.

If you get stuck, paste the failing step's log back to me and I'll patch
the code — I can't re-run the Action myself, but I can read logs you paste
in and fix the Dart/config that caused it.

## Add Firebase later (for real push notifications)

1. Follow SETUP.md's Firebase section to create the project and download
   `google-services.json`.
2. Base64-encode it isn't necessary — just add its **raw JSON contents**
   as a repo secret named `GOOGLE_SERVICES_JSON` (paste the whole file
   content as the secret value).
3. Deploy the backend pieces from SETUP.md section 4 (`supabase db push`,
   `supabase functions deploy send-fcm-push`) from any phone browser via
   Supabase's dashboard SQL editor for the migration, or from a
   cloud shell (e.g. GitHub Codespaces, also phone-accessible) for the CLI
   commands.
4. Re-run the **Build APK** workflow — it now detects the secret and wires
   up the Gradle plugin automatically.
