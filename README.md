# Creative Moments

> Create something. Capture what inspired you. Keep the moment.

Creative Moments is a personal creative space for iOS and Android. You write, draw, sketch or photograph something; the app keeps **what you made**, **what inspired you** and **the atmosphere of that moment** together, as a private, editorial memory.

It is deliberately not a dashboard, a habit tracker or a social app: no feeds, no streaks, no levels, no AI.

## Contents

- [What is in V1](#what-is-in-v1)
- [Architecture](#architecture)
- [Stack](#stack)
- [Prerequisites](#prerequisites)
- [Backend setup](#backend-setup)
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
| Auth | Register, login, logout, session persistence, password reset by email (opens a web page, not the app), friendly errors, account deletion |
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
Flutter app ──HTTP (bearer token)──► Creative Moments API (backend/, Next.js)
                                          ├─► Postgres (Prisma), via Supabase's hosted database
                                          └─► Supabase Storage (private buckets, service_role key, server-side only)
```

There is **no local database and no AI**. The custom backend under `backend/` is the source of truth and the *only* thing that talks to Postgres or Storage — Supabase is used purely as a hosted Postgres instance and a private object store, never through its own Auth/RLS/PostgREST layer. The Flutter app only keeps temporary in-memory state (the draft being written, image caches); nothing is persisted on the device except the auth token.

- **State**: Riverpod (`Notifier` / `AsyncNotifier`). Widgets never talk to the backend directly.
- **Data access**: `lib/data/repositories` (auth, moments, preferences, profile). Repositories are the only code that calls the backend, through `lib/core/services/api_client.dart` (a thin `http` wrapper: base URL, bearer token, `ApiException` on non-2xx).
- **Navigation**: GoRouter with redirect rules (`redirectFor`, unit-tested) covering signed-out, loading, onboarding.
- **Security is in the backend**: every API route re-derives the caller from their bearer token and checks resource ownership itself before reading or writing anything (see `backend/src/app/api/**/route.ts`). The app never relies on client-side checks, and Storage is only ever touched server-side with the `service_role` key.
- **Saving**: ids are generated on the client and writes are upserts, so a retry after a dropped response cannot create duplicates. Details (inspirations, prompts, answers) are replaced atomically by the backend's `PUT /api/moments/:id/details`.
- **Media**: photos, drawing PNGs and avatars are uploaded as multipart requests to the backend, which stores them in Supabase Storage and returns a ready-to-use signed URL directly in the response — the app never resolves storage paths itself.
- **Questions**: a predefined library of 70+ prompts scored against creation type, inspirations, mood, time of day and environment, with randomised selection and no repeats (`lib/core/utils/question_selector.dart`).
- **Design system**: `lib/core/theme` (tokens, palette as a `ThemeExtension`, typography: Cormorant Garamond for writing and display, Manrope for UI) and `lib/shared/widgets` (glass surfaces, buttons, option tiles, skeletons, empty / error states). The environment engine lives in `lib/features/home/environment`.

## Stack

Flutter 3.47.2 / Dart 3.13 · flutter_riverpod 3 · go_router · google_fonts · geolocator + geocoding · image_picker · http + shared_preferences (talking to the custom backend) · Open-Meteo weather, no key needed.

Backend (`backend/`): Next.js (App Router) + TypeScript + Prisma + scrypt password hashing + Nodemailer + `@supabase/supabase-js` (server-side only, `service_role` key). See `backend/README.md`.

## Prerequisites

- Flutter **3.47.2** (stable), Xcode (iOS builds), Android SDK + JDK 17 (Android builds)
- The Creative Moments API deployed somewhere reachable (see `backend/README.md`) — a Supabase project is only needed as that backend's Postgres + Storage, never linked to directly from the app

## Backend setup

The backend lives in `backend/` and is a separate deployable app (Next.js on e.g. Railway). Follow `backend/README.md` for: creating/resetting the Supabase project it uses as raw Postgres + Storage, environment variables, running migrations, and deploying.

Once it is deployed, the only thing the Flutter app needs is its public URL.

## Running locally

```bash
cp .env.example .env          # then fill in API_BASE_URL with the backend's URL
flutter pub get
flutter run --dart-define-from-file=.env
```

Environment variables (`.env.example`; `.env` is git-ignored, credentials are never committed):

| Variable | Meaning |
| --- | --- |
| `API_BASE_URL` | Base URL of the deployed Creative Moments API, e.g. `https://creative-moments-api.up.railway.app` |

If the app is built without it, it shows a short "Almost there" screen instead of crashing.

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
flutter test                                   # unit + widget tests
flutter test integration_test -d <device-id>   # core journey on a simulator/device, in-memory backend
```

- **Unit**: models (nested JSON, drawing data, preferences), repositories (real classes against a fake HTTP transport, so the exact requests are asserted), preference logic, question selection, Home evolution, constellation layout, routing rules, error mapping, autosave / offline / finish / discard behaviour of the draft.
- **Widget**: Home, Create Moment, Writing, Inspiration (and mood / question steps), Moment Detail, plus accessibility checks (largest text size, semantic labels and selected state, 48 px targets).
- **Integration / journey**: Register → Onboarding → Home → Create → Write → Add inspiration → Save → Open Moment. The same journey runs headless in `flutter test` and on a device via `integration_test`.
- **Against a real deployed backend**:

  ```bash
  flutter test integration_test -d <device-id> \
    --dart-define-from-file=.env --dart-define=REAL_BACKEND=true
  ```

  This creates a new account per run. Use a test deployment, not production.

The backend (`backend/`) has its own test story — see `backend/README.md` (typecheck, build, unit tests, and a manual end-to-end smoke test against a throwaway Postgres).

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

Permission strings (location, photos, camera) are already in `Info.plist`; Android permissions are in `AndroidManifest.xml`. Neither app declares a custom URL scheme — password reset happens on the web, not via a deep link.

`flutter build apk --release` and `flutter build ios --release --no-codesign` were verified on this codebase.

## Deployment

Two independent pieces:

- **Backend** (`backend/`): deploy to Railway (or any Node host), run `prisma migrate deploy` against its Postgres. See `backend/README.md`.
- **Client**: ship the store builds above. `API_BASE_URL` is compiled in through `--dart-define`; it is not secret (it is just the backend's public URL).
- **CI**:
  - `.github/workflows/ci.yml`: Flutter analyze + tests, Android release build, iOS no-codesign build. Uses a placeholder `API_BASE_URL` and needs no secrets.
  - `.github/workflows/backend-ci.yml`: backend typecheck, `prisma validate`, Next.js build, unit tests. Triggered only on changes under `backend/`.

## Project layout

```
lib/
  core/       theme, routing, constants (catalog, question library), errors, services (api_client, config), utils, animations (sky)
  data/       models, repositories, providers (Riverpod), insights
  features/   auth, onboarding, home (+ environment engine), creation, writing, drawing,
              moments, calendar, world, profile, settings
  shared/     widgets (glass, buttons, cards, drawing view, images), components (shell, splash)
  dev/        in-memory fake backend (development and tests only)
backend/      Next.js + Prisma API: auth, moments, media, preferences, profile, account (own README)
test/         unit, widget, support (fakes, journey)
integration_test/
```

## Known limitations

Being explicit about what V1 does **not** do:

- **Not exercised against the real deployed backend in this repository's development environment.** The backend was built and manually smoke-tested end-to-end (signup, login, preferences, moments, save-details, forgot/reset-password) against a throwaway local Postgres, and typecheck/build/unit tests pass. It was never deployed to Railway, never connected to the real Supabase project over the network, and the Flutter side of the rewrite could not be run at all in this environment (no Flutter/Xcode/simulator here) — only reviewed file by file. Deploy the backend, wire up `API_BASE_URL`, and run the real-backend integration test above before inviting testers.
- **Voice / audio** is not implemented (the schema and `media.type` support it; the Voice option is intentionally not offered yet). Photos are supported.
- **Drawing layers** are not implemented; the canvas is a single vector layer.
- **Notifications** are not implemented, so the Settings screen has no notification toggle.
- **Music** is manual entry only; the data model (title, artist, album, artwork URL) is ready for Spotify / Apple Music, but no integration is faked.
- **Fonts** (Cormorant Garamond, Manrope) are fetched by `google_fonts` on first launch and cached; the very first launch offline uses system fonts. Bundle the font files under `assets/` if you need them guaranteed offline.
- **Weather** uses Open-Meteo (no key) with approximate coordinates and only when you enable it; when unavailable the environment simply follows your chosen atmosphere.
- **Autosave persists in-progress moments.** A new moment you started but did not "Save" still appears in Moments (it was saved, and the UI says so). Deleting it is one tap.
- **Tags** are not implemented (no schema, no UI). The old Supabase-era schema had unused `tags`/`moment_tags` tables; they were dropped in the rewrite since nothing referenced them.
- Large histories: the moments list loads up to 500 moments with their nested data in one request; add pagination before that becomes a limit for real users.
- Account deletion removes storage files and every database row atomically, server-side, in a single API call (`DELETE /api/account`).
