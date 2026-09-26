# Creative Moments

> Create something. Capture what inspired you. Keep the moment.

Creative Moments is a personal creative space for iOS and Android. You write, draw, sketch or photograph something; the app keeps **what you made**, **what inspired you** and **the atmosphere of that moment** together, as a private, editorial memory.

It is deliberately not a dashboard, a habit tracker or a social app: no feeds, no streaks, no levels, no AI.

## Contents

- [What is in V1](#what-is-in-v1)
- [Architecture](#architecture)
- [Stack](#stack)
- [Prerequisites](#prerequisites)
- [Supabase setup](#supabase-setup)
- [Running locally](#running-locally)
- [Running without a backend (development harness)](#running-without-a-backend-development-harness)
- [Testing](#testing)
- [Production builds](#production-builds)
- [Deployment](#deployment)
- [Project layout](#project-layout)
- [Known limitations](#known-limitations)

## What is in V1

| Area | What works |
| --- | --- |
| Auth | Register, login, logout, session persistence, password reset by email (deep link), friendly errors, account deletion |
| Onboarding | 3 story screens, then "What inspires you?" (15 environments, multi-select) and atmosphere / time / density. The personalised Home exists immediately |
| Home | A living environment (moon, stars, flowers, nature, ocean, mountains, desert, city, rain, clouds, sunset, fire, autumn, winter, abstract) that reacts to time of day (gradual dawn → day → sunset → night), atmosphere, density, optional weather, and slowly to your history. Every recent moment is a star you can open |
| Customize | Environment, time, atmosphere, visual density, applied live |
| Create | 7 creation types + "I don't know yet". Real writing editor (title, serif body, focus mode, undo/redo, word count, photos) and a real drawing canvas (pencil, brush, eraser, 12 colours, size, undo/redo, clear, paper colours, full screen). Freeform mixes text, drawing and photos |
| Details | Inspiration (15 options + custom), mood (12 + custom), music (manual entry, structured for future Spotify / Apple Music), location (device / manual / skip), contextual creative questions (answer, skip or ask for another) |
| Moments | Timeline grouped by month, calendar (mood-tinted days, tap to open), Moment detail as an editorial page, edit, delete |
| World | Creative Constellation (force-laid-out graph linked by inspiration, mood, type, time, place; pinch/zoom, filters, tap a star) and My World (orbs of inspirations, moods, places, music, types → tap for the moments) |
| Profile | Avatar, name, count, favourite types, recurring inspirations / moods / atmospheres / places |
| Settings | Account, dark / light, Reduce Motion, Home customization, location + weather, privacy, delete all moments, log out, delete account |
| Safety | Autosave with debounce; honest save state ("Not saved yet", never a fake "Saved"); unsaved work stays in memory when offline and is retried; leaving asks first |

## Architecture

```
Flutter app ──► Supabase Auth
            ├─► Supabase Postgres (PostgREST, Row Level Security)
            └─► Supabase Storage (private buckets, signed URLs)
```

There is **no custom server, no local database and no AI**. Postgres is the source of truth. The app only keeps temporary in-memory state (the draft being written, image caches); nothing is persisted on the device.

- **State**: Riverpod (`Notifier` / `AsyncNotifier`). Widgets never talk to Supabase.
- **Data access**: `lib/data/repositories` (auth, moments, preferences, profile, storage). Repositories are the only code that imports the Supabase client.
- **Navigation**: GoRouter with redirect rules (`redirectFor`, unit-tested) covering signed-out, loading, onboarding, password recovery.
- **Security is in the database**: RLS policies on every table, ownership helper `owns_moment()`, private storage buckets scoped to `<user_id>/…`. The app never relies on client-side checks.
- **Saving**: ids are generated on the client and writes are upserts, so a retry after a dropped response cannot create duplicates. Details (inspirations, prompts, answers) are replaced atomically by the `save_moment_details` RPC.
- **Questions**: a predefined library of 70+ prompts scored against creation type, inspirations, mood, time of day and environment, with randomised selection and no repeats (`lib/core/utils/question_selector.dart`).
- **Design system**: `lib/core/theme` (tokens, palette as a `ThemeExtension`, typography: Cormorant Garamond for writing and display, Manrope for UI) and `lib/shared/widgets` (glass surfaces, buttons, option tiles, skeletons, empty / error states). The environment engine lives in `lib/features/home/environment`.

## Stack

Flutter 3.47.2 / Dart 3.13 · flutter_riverpod 3 · go_router · supabase_flutter · google_fonts · geolocator + geocoding · image_picker · http (Open-Meteo weather, no key needed).

## Prerequisites

- Flutter **3.47.2** (stable), Xcode (iOS builds), Android SDK + JDK 17 (Android builds)
- A Supabase project (free tier is enough) and the [Supabase CLI](https://supabase.com/docs/guides/cli)

## Supabase setup

1. **Create a project** at <https://supabase.com/dashboard>.
2. **Apply the migrations** (they create tables, indexes, constraints, RLS, storage buckets and functions from scratch):

   ```bash
   supabase login
   supabase link --project-ref <your-project-ref>
   supabase db push
   ```

   Migrations live in `supabase/migrations`:

   | File | Contents |
   | --- | --- |
   | `…_schema.sql` | `profiles`, `user_preferences`, `moments`, `creations`, `inspirations`, `prompts`, `answers`, `media`, `tags`, `moment_tags`, triggers (`updated_at`, profile + preferences on signup) |
   | `…_rls.sql` | RLS on every table, `owns_moment()`, `delete_my_account()` |
   | `…_storage.sql` | Private buckets `moment-media` and `avatars`, per-user object policies |
   | `…_functions.sql` | `save_moment_details()` (atomic replace of inspirations / prompts / answers) |

   You can also paste them into the SQL editor in order.

3. **Auth settings** (Dashboard → Authentication):
   - *URL Configuration → Redirect URLs*: add `creativemoments://login-callback` and `creativemoments://reset-callback`.
   - *Providers → Email*: leave enabled. "Confirm email" may be on or off; with it on, new users are told to confirm before signing in.
4. **Keys**: Dashboard → Project Settings → API. You need the project URL and the **anon / publishable** key. Never use the `service_role` key in the app.

### Verifying the security model

`supabase/tests/rls.sql` is a regression test that proves one user cannot read, write, list or delete another's rows or files, that anonymous users get nothing, that deletes cascade, and that buckets are private. It rolls back everything it does.

```bash
# against your Supabase database (use a throwaway project or branch, not production)
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls.sql

# or against any empty local Postgres (applies the migrations with minimal auth/storage stand-ins)
DB_URL=postgres://postgres:postgres@localhost:5432/postgres ./supabase/tests/run_rls.sh
```

CI runs the second form on Postgres 17.

## Running locally

```bash
cp .env.example .env          # then fill in SUPABASE_URL and SUPABASE_ANON_KEY
flutter pub get
flutter run --dart-define-from-file=.env
```

Environment variables (`.env.example`; `.env` is git-ignored, credentials are never committed):

| Variable | Meaning |
| --- | --- |
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | anon or publishable key |

If the app is built without them it shows a short "Almost there" screen instead of crashing.

## Running without a backend (development harness)

`lib/dev/fake_backend.dart` is an **in-memory** stand-in for the repositories. It exists only for UI development and tests; the production entrypoint (`lib/main.dart`) does not import it and it persists nothing.

```bash
flutter run -t lib/main_dev.dart                          # signed in as the demo account, with sample moments
flutter run -t lib/main_dev.dart --dart-define=ONBOARDED=false
flutter run -t lib/main_dev.dart --dart-define=SIGNED_IN=false   # demo@creative.moments / demo-password
```

## Testing

```bash
flutter analyze
flutter test                                   # unit + widget tests (90+)
flutter test integration_test -d <device-id>   # core journey on a simulator/device, in-memory backend
```

- **Unit**: models (nested JSON, drawing data, preferences), repositories (real classes against a fake HTTP transport, so the exact requests are asserted), preference logic, question selection, Home evolution, constellation layout, routing rules, error mapping, autosave / offline / finish / discard behaviour of the draft.
- **Widget**: Home, Create Moment, Writing, Inspiration (and mood / question steps), Moment Detail, plus accessibility checks (largest text size, semantic labels and selected state, 48 px targets).
- **Integration / journey**: Register → Onboarding → Home → Create → Write → Add inspiration → Save → Open Moment. The same journey runs headless in `flutter test` and on a device via `integration_test`.
- **Against a real Supabase project**: 

  ```bash
  flutter test integration_test -d <device-id> \
    --dart-define-from-file=.env --dart-define=REAL_BACKEND=true
  ```

  This creates a new account per run and needs email confirmation disabled on that project. Use a test project.

## Production builds

Set your own identifiers first: Android `applicationId` in `android/app/build.gradle.kts` and the iOS bundle identifier in Xcode (both currently `app.creativemoments.creative_moments`).

### Android

1. Create a keystore and `android/key.properties` (both git-ignored):

   ```properties
   storeFile=../upload-keystore.jks
   storePassword=…
   keyAlias=upload
   keyPassword=…
   ```

2. Build:

   ```bash
   flutter build appbundle --release --dart-define-from-file=.env      # Play Store
   flutter build apk --release --split-per-abi --dart-define-from-file=.env
   ```

   Without `key.properties` the release build is signed with the debug key so CI works; never upload such a build.

### iOS

1. Open `ios/Runner.xcworkspace`, set your Team and bundle id, enable automatic signing.
2. Build:

   ```bash
   flutter build ipa --release --dart-define-from-file=.env
   ```

   then upload with Transporter / `xcrun altool`, or archive from Xcode.

Permission strings (location, photos, camera) and the `creativemoments://` URL scheme are already in `Info.plist`; Android permissions and the deep-link intent filter are in `AndroidManifest.xml`.

`flutter build apk --release` and `flutter build ios --release --no-codesign` were verified on this codebase.

## Deployment

There is nothing to deploy besides Supabase:

- **Backend**: `supabase db push` for every migration; never edit tables by hand.
- **Client**: ship the store builds above. The Supabase URL and anon key are compiled in through `--dart-define`; they are safe to embed because RLS protects the data.
- **CI** (`.github/workflows/ci.yml`): analyze + tests, migrations + RLS test on Postgres 17, Android release build, iOS no-codesign build. It uses placeholder Supabase values and needs no secrets.

## Project layout

```
lib/
  core/       theme, routing, constants (catalog, question library), errors, services, utils, animations (sky)
  data/       models, repositories, providers (Riverpod), insights
  features/   auth, onboarding, home (+ environment engine), creation, writing, drawing,
              moments, calendar, world, profile, settings
  shared/     widgets (glass, buttons, cards, drawing view, images), components (shell, splash)
  dev/        in-memory fake backend (development and tests only)
supabase/     config.toml, migrations, tests (RLS)
test/         unit, widget, support (fakes, journey)
integration_test/
```

## Known limitations

Being explicit about what V1 does **not** do:

- **Not exercised against a live Supabase project in this repository's development environment.** The migrations and RLS policies were run on real PostgreSQL, the repositories were tested against a fake HTTP layer, and the whole UI journey against an in-memory backend. Supabase Auth (email delivery, deep-link password reset, PKCE) and Storage were not run end to end. Run the real-backend integration test above on your project before inviting testers.
- **Voice / audio** is not implemented (the schema and `media.type` support it; the Voice option is intentionally not offered yet). Photos are supported.
- **Drawing layers** are not implemented; the canvas is a single vector layer.
- **Notifications** are not implemented, so the Settings screen has no notification toggle.
- **Music** is manual entry only; the data model (title, artist, album, artwork URL) is ready for Spotify / Apple Music, but no integration is faked.
- **Fonts** (Cormorant Garamond, Manrope) are fetched by `google_fonts` on first launch and cached; the very first launch offline uses system fonts. Bundle the font files under `assets/` if you need them guaranteed offline.
- **Weather** uses Open-Meteo (no key) with approximate coordinates and only when you enable it; when unavailable the environment simply follows your chosen atmosphere.
- **Autosave persists in-progress moments.** A new moment you started but did not "Save" still appears in Moments (it was saved, and the UI says so). Deleting it is one tap.
- **Tags** exist in the schema (`tags`, `moment_tags`) with RLS but have no UI yet.
- Large histories: the moments list loads up to 500 moments with their nested data in one query; add pagination before that becomes a limit for real users.
- Account deletion removes storage files through the Storage API first, then the account (Postgres cascades everything else). If the app is killed mid-way you can run it again.
