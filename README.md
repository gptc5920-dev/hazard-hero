# Hazard Hero

Hazard Hero is a Flutter disaster-preparedness application for Android, iOS,
web, and Windows. It includes disaster alerts, evacuation centers, emergency
hotlines, preparedness guides, a persistent Go Bag checklist, responder tools,
language selection, offline mode, and dark mode.

## Separate Flutter applications

The project contains three Android applications sharing the Django API:

- **Resident (Citizen)**: public information, Go Bag checklist, languages, and downloads; no login.
- **Responder**: the same resident features plus a private equipment inventory, login, sign-up, and account settings. New sign-ups await administrator verification before login.
- **Admin**: the existing content management, responder accounts, translation, and audit console.

The Responder inventory supports adding, editing, deleting, searching, and filtering equipment, with total quantity, quantity in use, unit, condition, location, and notes. Equipment is saved **on the device, separately for each account**. It is not synchronized to the server or other responders. Inventory remains usable without a connection during a signed-in session. Signing in or restoring a session after reopening the app requires the API. Clearing app data or uninstalling removes the inventory.

Contacts use text-only cards and detail pages. The Contacts and Responders account forms do not offer image uploads, and My Account does not display or upload profile photos.

- `lib/citizen/` — anonymous, public, read-only Citizen application
- `lib/responder/` — JWT-protected Administrator/Responder application
- `lib/shared/` — API, secure storage, themes, network errors, and offline files

Run the Citizen application on Windows:

```powershell
flutter run -d windows -t lib/main_citizen.dart --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

Run the Responder application:

```powershell
flutter run -d windows -t lib/main_responder.dart --dart-define=API_BASE_URL=http://127.0.0.1:8001
```

For an Android emulator, replace the API URL with `http://10.0.2.2:8001`.
Physical devices must use the backend computer's LAN address. Production URLs
are supplied with the same `API_BASE_URL` compile-time variable.

Build separate Android release APKs (each has its own application ID and can be installed together):

```powershell
flutter build apk --release --flavor citizen -t lib/main_citizen.dart
flutter build apk --release --flavor responder -t lib/main_responder.dart
flutter build apk --release --flavor admin -t lib/main_admin.dart
```

APKs are written to `build/app/outputs/flutter-apk/`:

- `app-citizen-release.apk`
- `app-responder-release.apk`
- `app-admin-release.apk`

The API defaults to `https://hazardheroapi.site`; override with `--dart-define=API_BASE_URL=...` as needed. Release builds currently use the project's configured debug signing key.

The previous `main_responder.dart` opened the admin console. That console now uses `main_admin.dart` and the `admin` flavor. The default `main.dart` still opens the admin console. The backend currently uses the same `administrator_responder` account role for both authenticated clients; this split adds a field-focused UI, not new server-side role permissions.

Responder sign-up requires the backend's `POST /api/responder/auth/signup/` endpoint. Deploy the updated `backend/accounts/` and `backend/config/` code with the app update. No database migration is needed. New accounts are active but unverified, receive no tokens during sign-up, and cannot log in until an existing administrator verifies them in **Responders**. Public registration cannot set verification, staff, superuser, or role fields and is limited to five requests per hour per IP.

Existing Windows distributions are available under:

- `build/distributions/hazard_hero_citizen/`
- `build/distributions/hazard_hero_responder/`

The Citizen app stores its selected language and public API cache locally. A
downloaded guideline uses the backend offline manifest, verifies SHA-256 file
checksums, and saves media into application document storage. The Responder app
stores JWT access and refresh tokens only through platform secure storage and
automatically refreshes access tokens.

## Run locally

```sh
flutter pub get
flutter run -d windows
```

The Windows target writes to the inspectable native SQLite file at
`%USERPROFILE%\Documents\hazard_hero.sqlite`. Chrome and Edge use a separate
browser-isolated SQLite database and do not update that Windows file.

Select another platform with `flutter run -d <device>` when needed.

## Administrator account

A fresh database automatically contains this administrator account:

- Email: `admin@hazardhero.local`
- Password: `HazardHero123!`

Override the built-in account for a deployment with compile-time values:

```sh
flutter run --dart-define=DEFAULT_ADMIN_NAME="Operations Admin" \
  --dart-define=DEFAULT_ADMIN_EMAIL="admin@example.com" \
  --dart-define=DEFAULT_ADMIN_PASSWORD="replace-with-a-secure-password"
```

Automatic provisioning only runs when the user table is empty and never
overwrites existing accounts.

## SQLite database

Drift creates and verifies the SQLite database before authentication starts.
The portable SQL definition is available at `database/schema.sql`. Native
builds store the live `hazard_hero.sqlite` file in the platform application
documents directory; web builds store it in the browser's database storage.

## Validate

```sh
flutter analyze
flutter test
```

## Django + MySQL API

The backend is in [`backend/`](backend/README.md). The fastest local setup is:

```sh
docker compose up --build
```

It provides authenticated resource/user CRUD plus the `/api/health`,
`/api/sync/push`, and `/api/sync/pull` endpoints expected by the Flutter app.

The application entry point is `lib/main.dart`. Shared app state and themes are
in `lib/src/app.dart`; screens, models, and seed data are under `lib/src/`.
