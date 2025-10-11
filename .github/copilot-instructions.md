# Copilot Instructions for CarePanion (Flutter)

This repository is a Flutter app using Supabase for auth/profile data, Google Fonts for theming, and a multi-screen navigation structure. Use these conventions to be productive quickly:

## Architecture & Key Files
- Entrypoint: `lib/main.dart`
  - Initializes Supabase with project URL/anon key.
  - Sets up `MaterialApp` routes. Initial route is `/` → `WelcomeScreen`.
- Screens are grouped by role:
  - Assisted: `lib/Assisted Screen/**` (e.g., `tasks_screen.dart`, `profile_screen.dart`).
  - Regular: `lib/Regular Screen/**` (e.g., `tasks_screen_regular.dart`, `profile_screen_regular.dart`).
  - Shared auth/flow: `lib/screen/**` (e.g., `signin_screen.dart`, `registration_*`, `role_selection_screen.dart`).
- Assets live in `assets/` and are declared in `pubspec.yaml` under `flutter/assets`.

## State, Navigation, and Patterns
- Navigation uses named routes from `MaterialApp.routes` defined in `main.dart`. Prefer `Navigator.pushReplacementNamed(context, "/route")` over hard-coded `MaterialPageRoute` when the route exists.
- UI style: Google Fonts (`GoogleFonts.nunito`) with a warm color palette (e.g., `Color(0xFFCA5000)`). Match existing spacing and rounded input borders.
- Forms use `GlobalKey<FormState>` and validators. Keep validators fast and synchronous.
- Async UI safety: After awaits, guard UI changes with `if (!mounted) return;` and wrap state updates with `if (mounted) setState(...)`.

## Supabase Integration
- Access client via `Supabase.instance.client`.
- Auth:
  - Email/pass: `supabase.auth.signInWithPassword(email, password)`.
  - Google OAuth: `supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: <callback>)`.
- Profiles table pattern: On sign-in, ensure a row exists for the user ID.
  - Use `ProfileService` (`lib/data/profile_service.dart`) to auto-detect the correct table name (handles `profiles`, `profile`, even `profile table`).
  - Reads use `.maybeSingle()`; creates via `upsert` for idempotency.
- Prefer non-throwing reads (e.g., `.maybeSingle()`) and handle nulls explicitly. Avoid using `.onError` on Futures returned by Supabase queries.

## Project Conventions
- File organization favors separate screens per role; when adding features, place Assisted/Regular implementations in their respective folders and keep names parallel (e.g., `feature.dart` and `feature_regular.dart`).
- Use named routes defined in `main.dart`; update both the route map and the correct role-specific screen when adding a new page.
- Keep colors and typography consistent with existing screens; reuse Nunito and `Color(0xFFCA5000)` accents.
- Avoid prints in production; prefer `ScaffoldMessenger.of(context).showSnackBar(...)` for user-facing errors and consider adding a logger for dev output.

## Build/Run/Debug
- Flutter version: Dart SDK constraint `^3.9.0` in `pubspec.yaml`. Use a current Flutter SDK compatible with Dart 3.9.
- Dependencies: see `pubspec.yaml` (notably `supabase_flutter`, `google_fonts`, `image_picker`, `intl`).
- Typical workflows:
  - Run: `flutter run` (choose target device/emulator).
  - Analyze/fix: `dart analyze`; format with `dart format .`.
  - Test scaffold exists but app has no custom tests; add `flutter_test` tests beside widgets when needed.

## Examples in Repo
- Sign-in flow: `lib/screen/signin_screen.dart`
  - Validators, loading state, OAuth, and post-auth profile ensure using `ProfileService.ensureProfileExists(...)`.
- Route setup: `lib/main.dart` shows canonical route map and Supabase startup.
- Role-based screens: `lib/Assisted Screen/tasks_screen.dart` vs `lib/Regular Screen/tasks_screen_regular.dart` for pattern parity.

## Notes for AI Changes
- If you modify navigation after async auth operations, always check `mounted` before using `context` to avoid analyzer warnings.
- When introducing new assets, add them under `assets/` and register in `pubspec.yaml`.
- Keep code null-safe and prefer returning early on invalid form states.
- Be cautious editing Supabase keys/URLs; they are initialized in `main.dart`.

If anything above is unclear or you see patterns that diverge in other files, call them out so we can refine these instructions.