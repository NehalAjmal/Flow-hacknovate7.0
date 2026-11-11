# Flow frontend (v2)

Flutter desktop client for Windows and macOS. Uses Riverpod 3 and go_router 18, and is built against the `/api/v1` contract in the team's *Product Readiness* doc (§5).

> **Status:** architecture, API layer, mocks, state, routing and tests are done. **Every screen is a functional placeholder.** Behaviour and API wiring are final; layout and visuals are waiting for the design. Theme tokens live in `lib/theme/tokens.dart`.

## Run

```bash
flutter pub get
flutter run -d windows --dart-define=FLOW_DEV=true     # or -d macos
```

- `FLOW_DEV=true` turns on mocks and the dev panel. **Never pass it for a release build.**
- `--dart-define=FLOW_API_URL=http://host:port` sets the backend. The default is `http://127.0.0.1:8002`.
- Mock logins (password `password`):
  - `solo@flow.dev`
  - `employee@flow.dev`
  - `admin@flow.dev` (MFA code `123456`)
  - `new@flow.dev` (no consent yet)

## Mock ↔ real switch

**One file:** `lib/api/api_connector.dart`. To make an area hit the real backend, flip its entry in `defaultApiModes` from `ApiMode.mock` to `ApiMode.real`.

In dev builds, **Ctrl+Shift+D** (Cmd+Shift+D on macOS), or clicking the yellow `DEV` badge, opens the dev panel. From there you can:
- switch any area between mock and real at runtime
- change the backend URL
- pick a mock scenario: normal, quiet, new user, stream drops, token expires, backend down, small team
- watch every request (mock or real) with status and timing

The panel warns about mixed modes that can't work, such as mock auth combined with real session (the real backend rejects mock tokens).

### Shipping

1. Build without `FLOW_DEV`. `kDevBuild` is then a compile-time `false`, every area is forced to real, and the compiler drops mocks and the dev panel. Verified on a release web build: no mock accounts, scenarios or panel strings remain in the output.
2. Before the final release, delete `lib/api/mock/` and `lib/dev/`, then fix the references the analyzer flags (the `kDevBuild &&` branches in `api_connector.dart`, `app.dart` and `main.dart`).

## Layout

```
lib/
  api/
    api_connector.dart   ← mock/real switch + one provider per API
    contracts/           ← one interface per area (doc §5)
    models/              ← typed payloads; tolerant parsing
    real/                ← HTTP (refresh, SSE, error format) + local-agent WebSocket
    mock/                ← DEV ONLY: in-memory backend + scenarios
  state/                 ← auth, consent/settings/pause, live session, breaks, data
  router/                ← routes + pure redirect logic (auth, MFA, consent, roles)
  screens/               ← PLACEHOLDER UI
  widgets/common.dart    ← shared placeholder widgets (state chip, sensing chips…)
  theme/tokens.dart      ← PLACEHOLDER tokens (replace with the real theme)
  dev/                   ← DEV ONLY: dev panel
test/                    ← models, HTTP transport, redirects, full flows on mocks, widget smoke
```

## Behaviour already in place

- **Tokens:** stored in the OS keychain (`flutter_secure_storage`), not SharedPreferences. On a 401 the client refreshes once (concurrent calls share that one refresh) and retries. If the refresh fails, the user is signed out with a reason. A network failure during refresh does **not** sign the user out.
- **Live session:** updates arrive over SSE. If the stream drops, the client polls every 8 s and retries the stream periodically. A connection chip shows "updating every few seconds" or "offline".
- **Session timer:** derived from the server's `started_at` minus paused time, so it survives restarts.
- **Logout** ends the running session first, so tracking actually stops.
- **Consent:**
  - The router sends the user to `/consent` until the required `behavior` scope is granted.
  - Enabling camera, calendar or the AI assistant without the matching consent is blocked.
  - Withdrawing a consent switches the matching feature off.
- **Interventions:** shown as a bottom-right toast that never steals focus, with Take a break, Snooze, Dismiss, Why? and Report.
  - The Why? dialog starts with a short view; "More detail" shows the full table.
  - In lock mode the break screen always shows an emergency override with a reason picker.
- **After a break:** two optional taps (focus and fatigue). The local agent's time-to-first-edit is forwarded to the backend.
- **Team and admin views:** show a "not enough people" notice when suppressed, never zeros. The client discards `metrics` whenever `suppressed` is true.
- **Copy rules:** no accuracy or health claims, and never red for a person's state.

## Test

```bash
flutter analyze
flutter test
flutter test --dart-define=FLOW_DEV=true   # same suite with dev code compiled in
```

## Not done yet (needs design or platform work)

- Final visuals for every screen; theme tokens.
- System tray, always-on-top session widget and single-instance lock (`window_manager` / `tray_manager`). These have to be verified on real Windows and macOS machines.
- Calendar OAuth browser hand-off and redirect (`url_launcher`); Focus DNA save-to-file (`file_selector`).
- macOS: network client access is enabled. `flutter_secure_storage` may also need a Keychain access-group entitlement, depending on signing setup; verify on a signed build.
- Agent packaging and pairing UX (team B owns the agent; the proposed protocol is in `CONTRACT_NOTES.md`).

See `CONTRACT_NOTES.md` for every place the frontend had to choose an API shape the doc didn't specify.

## Desktop window modes (Windows / macOS)

`lib/desktop/` holds everything the app asks of the OS: window_manager 0.5, tray_manager 0.5, local_notifier, windows_single_instance and shared_preferences. Both window packages are pinned to the mature 0.5 line; 0.6/0.8 are rewrites on a new native layer.

- `desktop_host.dart`: the `DesktopHost` interface. Native on desktop (`desktop_host_io.dart`), no-op on web and in tests (`desktop_host_stub.dart`), chosen by a conditional import so the web build never touches `dart:ffi`.
- `window_controller.dart`: the window rules (spec §3).
  - The widget exists only during a session.
  - A nudge grows the card, which folds back after 60 s.
  - A lock break goes full screen.
  - Ending the session returns to the full app.
  - Closing hides to the tray.
  - A hidden window, or an unfocused full one, gets an OS notification.
  - Tray icon state and taskbar progress (Windows) follow the session.
- `compact_views.dart`: the 320×88 widget and the 380×320 card. The router stays mounted offstage, so nothing is lost when switching.
- Tray icons: `assets/tray/{idle,steady,approaching,breakDue,paused}.{png,ico}`.

**Verify on real machines (cannot be run in CI here):**
- frameless widget + always-on-top
- the snap-to-corner after a native drag
- tray menu: Show / Pause 1 h / Resume / Quit
- the second-launch focus on Windows
- notifications

**The pop-out (how the widget opens).** The window is hidden, made frameless, sized and placed while invisible, then shown; the content springs in once it is there (`popped`). Each native step is logged in dev builds as `[flow/window] <step> failed: …` if it fails. If the window does not take the shape, Flow returns to the full window and stops offering the widget for that run (`widgetUnavailable`), so it can never be stuck. Ways back to the full app: the widget's open button, **Esc**, or the tray's "Show Flow".

**Nudge styles.** `NudgeStyle` (full screen / windowed / notification) lives in `DesktopPrefs` (per computer). Full screen and windowed are window modes `nudgeFull` / `nudge`, drawn by `nudge_takeover.dart`; the controller returns to the previous mode when the nudge is answered, after 60 s, or on "Not now".

Do not reintroduce "hidden title bar + `setResizable(false)`" for the widget: on Windows window_manager insets the client area by 8 px on three sides in that mode while removing the resize border, which leaves dead black strips.

- **Linux tray** needs `libayatana-appindicator3-dev`.
- **Invite links:** `/invite?token=…` is routed. Registering a `flow://` URL scheme for links clicked outside the app is a separate native step (not done).

In a dev build, the dev panel's "Window" row previews full/mini/card/lock in a browser.

## Flutter version (team pin)

Everyone builds with **Flutter 3.47.9** (Dart 3.13.7). It's pinned in `.fvmrc`, and `pubspec.yaml` refuses older SDKs.

```bash
dart pub global activate fvm
```

```bash
fvm install
```

Then prefix commands with `fvm`:

```bash
fvm flutter pub get
```

```bash
fvm flutter run -d windows --dart-define=FLOW_DEV=true
```

VS Code: set `"dart.flutterSdkPath": ".fvm/flutter_sdk"` in workspace settings. FVM creates that link, and `.fvm/` is git-ignored.

## Security notes (frontend)

**Enforced in code** (`lib/core/endpoint_policy.dart`, tested in `test/security_test.dart`):
- **Transport.** Release builds send requests only over `https://`. Plain `http://` is allowed only to this machine (`127.0.0.1` / `localhost`) for local testing. Anything else is refused before a byte leaves the device (`insecure_transport`).
- **Local agent.** Activity data only travels over a loopback WebSocket (`ws://127.0.0.1…`). A `FLOW_AGENT_URL` pointing elsewhere is ignored.
- **OAuth hand-off.** The calendar consent URL comes from the server, so the app opens it only if it's `https://accounts.google.com/…`. `file:`, `javascript:`, look-alike hosts and plain http are refused.

**Data handling**
- **Tokens** live in the OS keychain/credential store (`flutter_secure_storage`). They're sent only in `Authorization` headers (never in URLs, including the session stream) and are cleared on sign-out even if server revocation fails.
- **Nothing is printed to the console.** The request log exists only in dev builds and records method, path and status only.
- **Feedback diagnostics** are opt-in and limited to app version, platform and agent status. Never tokens, task text or window titles.
- **Local preferences** (`shared_preferences`) hold only window settings (widget corner, auto-widget, close-to-tray). No personal data.

**Dev builds**
- `FLOW_DEV` is compile-time. Release builds contain no mocks, mock accounts, dev panel or `/dev/login` (verified by searching the compiled output).
- Never pass `--dart-define=FLOW_DEV=true` to a build you hand to real users: dev builds can point anywhere and include sign-in shortcuts.

**macOS sandbox entitlements:** network client, user-selected read/write (Save PNG only touches the file the person picks), and Keychain access for tokens.

**Backend assumptions to confirm** (see also `../BACKEND_REVIEW.md`):
- invite and reset tokens are single-use and expire
- delete-account requires a fresh credential
- the calendar OAuth redirect lands on the backend, never on the app
