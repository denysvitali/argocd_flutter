# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter mobile/web client for ArgoCD. Connects to ArgoCD server REST APIs to manage Kubernetes applications, projects, and resources. Targets Android (arm64 APK) and web (GitHub Pages). No iOS build exists in CI despite platform stubs being present.

## Setup

Uses [devenv](https://devenv.sh) (Nix-based) for reproducible dev environment. No `.envrc` or Makefile — all commands go through `devenv shell`. The local Flutter version comes from the pinned nixpkgs snapshot and may differ from CI's pinned `3.38.7`.

```bash
devenv shell                  # Enter the dev shell (required for all commands below)
flutter pub get               # Install dependencies
```

Android SDK is **not** provided by devenv (`android.enable = false`). Android builds are CI-only.

## Common Commands

```bash
devenv shell flutter pub get                            # Install dependencies
devenv shell flutter analyze --no-fatal-infos --no-fatal-warnings  # Lint (matches CI — only errors are fatal)
devenv shell flutter test                               # Run all tests
devenv shell flutter test test/some_test.dart            # Run single test file
devenv shell flutter test --exclude-tags=golden          # Run non-golden tests only
devenv shell flutter test --tags=golden                  # Run golden tests only
devenv shell flutter test --update-goldens test/goldens/ # Regenerate golden images
devenv shell flutter run                                 # Run on connected device/emulator
devenv shell flutter build web --release                 # Release web bundle
```

CI runs analyze then tests (non-golden and golden separately). Golden failures upload diff PNGs as artifacts.

## Architecture

### State Management

Single `AppController` (ChangeNotifier) holds all app state — auth stage (`booting`/`unauthenticated`/`authenticated`), application list, project list, loading flags, a single shared error message, and last-refreshed timestamp. No BLoC, Riverpod, Provider, or any state management package. Widgets observe via `AnimatedBuilder` or `ListenableBuilder`.

Key behaviors:
- `_runBusyAction()` is a mutex — prevents concurrent mutations. A second action while busy throws immediately (not queued).
- Single `_errorMessage` field shared across all domains — whichever operation fails last overwrites it.
- `_lastRefreshedAt` is also shared — updated by either applications or projects fetch.
- After mutations (`syncApplication`, `rollbackApplication`, `deleteApplication`), applications are re-fetched immediately (optimistic-refresh, not optimistic-update).
- Detail/tree/logs/manifest data is fetched on-demand and returned to the caller — not stored in controller state.

### Source Layout

```
lib/
├── main.dart                          # Bootstrap, service wiring
├── platform_io.dart / platform_stub.dart  # Conditional imports for dart:io vs web
├── core/
│   ├── api/                           # HTTP adapters (native vs web, conditional import)
│   ├── models/                        # Data classes with fromJson() + defensive parsing
│   ├── services/                      # AppController, ArgoCdApi, SessionStorage, HealthMonitor, ThemeController
│   └── utils/                         # json_parsing.dart (parseMap/parseList/parseString), time_format.dart
├── features/
│   ├── auth/                          # SignInScreen
│   ├── dashboard/                     # DashboardScreen (metrics, incident feed, attention list)
│   ├── applications/                  # List, detail, resource tree, log viewer, manifest viewer
│   ├── projects/                      # List, detail
│   └── settings/                      # Theme, health monitor config, connection management
└── ui/
    ├── app_root.dart                  # MaterialApp, theme builders, HomeShell (4-tab IndexedStack)
    ├── app_colors.dart                # Color palette + theme-aware helpers + YAML syntax colors
    ├── design_tokens.dart             # AppSpacing, AppRadius, AppOpacity, AppIconSize, AppElevation, AppCardDecoration
    ├── resource_icons.dart            # iconForResourceKind() / colorForResourceKind() — 30+ K8s kinds
    ├── shared_widgets.dart            # StatusChip, SectionCard, SummaryTile, EmptyStateCard, FactBadge, YAML serializer + tokenizer
    ├── error_retry_widget.dart
    └── last_updated_text.dart
```

### API Layer (`core/api/` + `core/services/argocd_api.dart`)

- `ArgoCdApi` is an abstract interface; `NetworkArgoCdApi` is the concrete implementation.
- **Per-request Dio instances**: every API call creates a new `Dio`, uses it, then `dio.close(force: true)` in `finally`. No connection pooling or reuse.
- Timeouts: 20s connect / 30s receive / 20s send.
- `validateStatus: (_) => true` — Dio never throws on HTTP status. Status is checked manually by `_throwIfRequestFailed()` (>= 400). Forgetting to call this in a new endpoint means errors pass silently.
- All errors exit as `ArgoCdException` (typed, simple message wrapper).
- Platform HTTP adapter selected via conditional import: `NativeAdapter` (OS-native HTTP stack) on mobile/desktop, `BrowserHttpClientAdapter` on web.
- Log responses handle NDJSON (newline-delimited JSON), array, or single-object formats from ArgoCD's streaming API.
- No interceptors, no retry logic, no request tracing headers.

### Models (`core/models/`)

All models use defensive parsing via `json_parsing.dart` helpers (`parseMap`, `parseList`, `parseString`) with fallback values. No model has `toJson`, `==`, or `hashCode` — equality is reference-based.

Key distinctions:
- `ArgoResource` — flat summary from `application.status.resources[]`. Used in the detail screen's resource list tab.
- `ArgoResourceNode` — tree node from the resource-tree API with UID-based parent refs. Used in the resource tree screen. These two are **never merged or linked**.
- `ArgoApplication.fromJson` handles multi-source apps by picking only the first source from `spec.sources[]`.
- `HealthEvent` is the only model with a `DateTime` field (`detectedAt`) — all other timestamps are raw ISO strings.

### Navigation

Imperative `Navigator.of(context).push(MaterialPageRoute(...))`. No named routes, no router package. Detail screens pushed via callbacks (`onOpenApplication`, `onOpenProject`) threaded from `HomeShell`. Four bottom tabs in `IndexedStack` wrapped by `_IndexedStackWithTickerMode` which disables `TickerMode` for offscreen tabs (prevents `pumpAndSettle` hangs in tests).

### Dependency Injection

All services are constructor-injected in `main.dart`. No service locator, no `get_it`, no `Provider` package. Abstractions used for testability:

| Abstract / Service | Production | Test Fake |
|---|---|---|
| `ArgoCdApi` | `NetworkArgoCdApi` | `FakeArgoCdApi` (in test_helpers.dart) |
| `SessionStorage` | `SecureSessionStorage` | `MemorySessionStorage` (in test_helpers.dart) |
| `ThemeController` | (concrete, uses `shared_preferences`) | — |
| `CertificateProvider` | (concrete, reports Android cert trust status) | — |

The `HealthMonitor` ↔ `AppController` circular dependency is broken via `late final` in `main.dart`:
```dart
late final AppController controller;
final healthMonitor = HealthMonitor(
  onRefreshRequested: () => controller.refreshApplications(showSpinner: false),
);
controller = AppController(..., healthMonitor: healthMonitor);
```

### Auth & Storage

- Token-based auth (Bearer header). Password is never stored.
- **Hybrid storage**: token + username in `flutter_secure_storage` (encrypted), server URL in `shared_preferences` (unencrypted, persists across sign-outs for login pre-fill UX).
- `clearSession()` deletes only token/username — server URL is intentionally preserved.
- Boot: transitions to `authenticated` before validating the stored token (UI briefly shows authenticated state, then reverts on failure).
- No token refresh, no server-side logout call, no HTTPS enforcement at the app level.

### Health Monitoring

`HealthMonitor` (ChangeNotifier) diffs successive application lists via `_previousState` snapshots:
- First call always seeds baseline (no events).
- Transitions detected: health degraded/recovered, sync drifted/synced, operation failed.
- `HealthEventKind.failed` exists in the enum but is **never generated** — dead code.
- Recovery only fires for `Degraded → Healthy`, not intermediate states like `Degraded → Progressing`.
- Events stored in memory only — lost on app restart. Capped at 50 entries.
- Settings persisted in `shared_preferences` (enabled, interval, muted apps). Persistence is best-effort (exceptions silently caught).
- Dashboard shows swipeable incident cards: swipe-right-to-sync (drifted only), swipe-left-to-acknowledge.
- `onNewEvents` callback is a public mutable field set post-construction from `HomeShell`, not constructor-injected.

### Platform Handling

Conditional imports use `dart.library.js_interop` (Dart 3 idiom). `isIOS` is exported but never read — dead code. Android trusts user-installed CA certificates via `network_security_config.xml` (declarative, no programmatic cert pinning). Web requires CORS headers from the ArgoCD server (not documented in-app).

### Theme

Material 3 with two bundled font families (not Google Fonts CDN): Space Grotesk (headings), DM Sans (body). Color palette in `app_colors.dart` with theme-aware helper methods. YAML syntax highlighting colors are part of the global palette. Design tokens in `design_tokens.dart` (spacing, radius, opacity, icon sizes, elevation, card decoration).

## Testing

### Test Infrastructure

- **No mocking framework**. All fakes are hand-written.
- `test/test_helpers.dart` provides: seed data (`seedApp`, `degradedApp`, `seedProject`, `testSession`), `FakeArgoCdApi` (mutable data, side-effect tracking), `MemorySessionStorage`, `createTestController()` / `createAuthenticatedController()` factory helpers.
- `flutter_test_config.dart` loads bundled fonts globally via `golden_toolkit` before every test.
- Golden tests tagged `@Tags(['golden'])` in `test/goldens/`, reference PNGs in `test/goldens/goldens/`.

### Patterns to Follow

- Wrap test widgets in `MaterialApp(theme: ThemeData(splashFactory: InkRipple.splashFactory), home: ...)` — tests fail without the splash factory override.
- For reactive screens, wrap in `ListenableBuilder(listenable: controller, ...)`.
- Use `createAuthenticatedController()` to skip auth setup in widget tests.
- When adding new services: create an abstract interface, a concrete implementation, and a hand-written fake. Constructor-inject everywhere.

### Known Test Issues

- Several test files duplicate `FakeArgoCdApi` and `MemorySessionStorage` as private classes instead of reusing the shared versions from `test_helpers.dart`.
- `argocd_api_test.dart` re-implements private functions (`_normalizedServerUrl`, `_extractErrorMessage`, `_extractLogContent`) since they can't be accessed from tests — tests verify the re-implementation, not the production code.
- `FakeArgoCdApi.applications` is mutable — tests mutate it mid-test to simulate state changes.

## Code Style

- `analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` with `strict-casts`, `strict-inference`, `strict-raw-types` all enabled.
- Single quotes required (`prefer_single_quotes`).
- Dart SDK `>=3.10.0`, Flutter `>=3.38.0`.
- Top-level functions preferred over utility classes (see `resource_icons.dart`, `json_parsing.dart`).
- No barrel/index files — all imports use direct paths.

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`):

1. **analyze** — `flutter analyze --no-fatal-infos --no-fatal-warnings`
2. **test** — non-golden then golden tests separately; uploads failure PNGs as artifacts
3. **build-debug** — APK on non-main branches (`--target-platform android-arm64` only)
4. **build-release** — on main/tags; decodes keystore from `KEYSTORE_BASE64` secret, creates GitHub Release
5. **build-web** + **deploy-web** — on main; deploys to GitHub Pages

Flutter `3.41.2`, Java 21 (Temurin). `DART_VM_OPTIONS: --max-gen-heap-size=4096` (4 GB heap cap). Concurrency group cancels in-progress runs on the same ref. The `analyze` and `test` jobs run independently (no `needs:` dependency between them).

## Dependencies

Minimal footprint — no state management, routing, code generation, or mocking packages:

| Package | Purpose |
|---|---|
| `dio` | HTTP client |
| `native_dio_adapter` | OS-native HTTP adapter (Cronet on Android, NSURLSession on iOS) |
| `flutter_secure_storage` | Encrypted credential storage |
| `shared_preferences` | Unencrypted preferences (server URL, theme, health monitor settings) |
| `golden_toolkit` (dev) | Font loading + golden test utilities (unmaintained upstream — potential compatibility risk) |
| `flutter_lints` (dev) | Lint rule base |
