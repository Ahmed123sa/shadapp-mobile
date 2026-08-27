# ShadApp — Mobile (Flutter)

Flutter app for ShadApp, used by clients, sub-users and account managers.
Talks to the Laravel backend in `shadapp-backend`.

---

## Requirements

- Flutter SDK with Dart 3.5+
- Android Studio / Xcode for device builds
- A running backend (see `shadapp-backend/README.md`)

---

## Setup

```bash
flutter pub get
cp assets/env.txt.example assets/env.txt
```

Edit `assets/env.txt` for local development:

```env
API_BASE_URL=http://localhost:8000/api
REVERB_HOST=localhost
REVERB_PORT=8080
REVERB_KEY=shadapp-key
REVERB_SCHEME=ws
```

`assets/env.txt` is gitignored — never commit it.

### Talking to a backend on your own machine

`localhost` means the device, not your computer. From an emulator or a physical
phone you need the host machine's address instead:

| Target             | `API_BASE_URL` host          |
| ------------------ | ---------------------------- |
| Android emulator   | `10.0.2.2`                   |
| iOS simulator      | `localhost` works            |
| Physical device    | your machine's LAN IP        |
| Flutter web        | `localhost` works            |

`REVERB_HOST` needs the same treatment.

Also note `REVERB_SCHEME` is `ws`/`wss` here, while the dashboard's
`NEXT_PUBLIC_REVERB_SCHEME` is `http`/`https`. Both are correct — Laravel Echo
derives the WebSocket scheme itself, this app does not.

---

## Running

```bash
flutter run                  # attached device or emulator
flutter run -d chrome        # web
flutter analyze              # static analysis
flutter test                 # tests
```

---

## Tests

```bash
flutter test
```

`test/unit/` covers pure logic and the providers/`ApiClient` with `mocktail`
(no real network, no real secure storage/SharedPreferences). `test/widget/`
covers individual widgets and a few full screens (login, forgot password,
create client) with `flutter_test`.

Two things every widget test needs, both under `test/helpers/`:

- `pumpWithLocalizations()` (`pump_app.dart`) — every widget reads strings via
  `AppLocalizations.of(context)!`, which throws without the same
  `localizationsDelegates`/`supportedLocales` `main.dart` wires up.
- `buildTestApiClient()` (`mock_http_client.dart`) — `ApiClient` is normally a
  singleton (`ApiClient()`) that touches real secure storage and the network.
  `ApiClient.forTesting(client:, secureStorage:, token:)` and this helper
  exist specifically to make it injectable; `LoginPage`, `ForgotPasswordPage`
  and `CreateClientPage` each take an optional `api:` constructor param for
  the same reason. New screens that call the API should follow this pattern
  rather than reaching for the `ApiClient()` singleton directly, or they
  can't be widget-tested without hitting the network.

Two Flutter/package gotchas that cost real debugging time here, worth
knowing before adding more tests:

- **Never `pumpAndSettle()` a screen with a repeating animation or an open
  dialog awaiting dismissal** (a spinner, a `..repeat()` `AnimationController`,
  a success dialog nobody taps "OK" on) — it never "settles" and the test
  hangs until timeout. Use bounded `pump()`/`pump(duration)` calls instead.
- **A plain (non-`.builder`) `ListView` still only builds children near the
  viewport.** At the default test surface size (800×600), fields and buttons
  below the fold in a long form genuinely aren't in the widget tree yet.
  Either scroll to them or grow the test viewport
  (`tester.view.physicalSize = ...`, reset via `addTearDown`).

Not yet covered: most of the remaining screens/tabs beyond what's listed
above. Same patterns apply — add as they change or as time allows.

---

## Release builds

`main.dart` refuses to start a **release** build when `API_BASE_URL` still
points at `localhost`/`127.0.0.1` or uses plain `http://`. This is a guard
against shipping a build wired to a developer machine. For release:

```env
API_BASE_URL=https://api.your-production-domain.com/api
REVERB_HOST=your-production-domain.com
REVERB_PORT=443
REVERB_SCHEME=wss
REVERB_KEY=<matches the backend's REVERB_APP_KEY>
```

`REVERB_SCHEME` defaults to `ws` when omitted, which any production host will
reject — set it explicitly.

```bash
flutter build apk --release
flutter build ipa --release
```

---

## Architecture notes

### API client

`lib/core/api_client.dart` is a singleton wrapping all HTTP calls. It maps
failures onto typed exceptions — `AuthException`, `ValidationException`,
`RateLimitException`, `ConnectionException`, `ServerException` — so callers can
distinguish "wrong password" from "no internet" and show the right message.
Catch the specific type; a bare `catch` will mislabel network failures as bad
credentials.

### Realtime

`lib/core/reverb_service.dart` maintains the WebSocket connection.

All channels are **private** and authorised against the backend. There is
deliberately **no fallback** to a public channel on auth failure: subscribing
to the public channel name would bypass the server-side access check entirely,
so failing closed is the point. If realtime stops working, the cause is
configuration or authorisation — do not "fix" it by reintroducing a fallback.

The socket id is sent as an `X-Socket-Id` header on outgoing requests so the
backend can exclude the sender from its own broadcasts.

### Maps

Client location uses `flutter_map` with OpenStreetMap tiles and Nominatim for
search and reverse geocoding. No API key, no billing.

Two separate flows exist and both are intentional:

- **Check-in** — captures the manager's *current* GPS position. For real site
  visits.
- **Pick on map** — choose any point manually, with address search. For setting
  a client's address from the office.

### Localisation

ARB files in `lib/l10n/` (`app_en.arb`, `app_ar.arb`); Arabic is RTL. Add every
new string to **both** files — the generated `AppLocalizations` will not
compile otherwise. Generated output lives in `lib/generated/` and is rebuilt by
`flutter pub get` / `flutter run`.

---

## Layout

```
lib/
  core/           api_client, reverb_service, theme, shared widgets
  features/
    auth/         login
    am/           account-manager screens (clients, workspace, managers)
    chat/         client chat
    contracts/    contract list and detail
    payments/     payments
    signature/    signature capture
  l10n/           ARB translation sources
  generated/      generated localisations (do not edit)
assets/
  env.txt         local config (gitignored)
  env.txt.example template
```
