# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter mobile/web client for ArgoCD. Connects to ArgoCD server APIs to manage Kubernetes applications, projects, and resources.

## Setup

Uses [devenv](https://devenv.sh) for reproducible dev environment. After installing devenv:
```bash
devenv shell                  # Enter the dev shell
flutter pub get               # Install dependencies
```

## Common Commands

All flutter commands must be run through devenv to ensure the correct SDK versions:
```bash
devenv shell flutter pub get          # Install dependencies
devenv shell flutter analyze          # Lint (strict-casts, strict-inference, strict-raw-types enabled)
devenv shell flutter test             # Run all tests
devenv shell flutter test test/widget_test.dart  # Run single test file
devenv shell flutter run              # Run on connected device/emulator
devenv shell flutter build apk --debug   # Debug Android APK
devenv shell flutter build web --release  # Release web bundle
```

CI runs `flutter analyze --no-fatal-infos --no-fatal-warnings` then `flutter test`.

## Architecture

**State management**: Single `AppController` (ChangeNotifier) holds all app state — auth stage, application list, projects, loading/error states. No BLoC or Riverpod.

**Key layers** (all under `lib/`):
- `core/api/` — Dio-based HTTP client with platform-conditional adapters (native_dio_adapter on mobile, BrowserHttpClientAdapter on web). Per-request Dio instance with 20s/30s/20s connect/receive/send timeouts.
- `core/models/` — Data classes with `fromJson()` factories and defensive parsing (fallback values). Key models: AppSession, ArgoApplication, ArgoProject, ArgoResourceNode (tree-structured with parent/child relationships via `parentUids`).
- `core/services/` — AppController, ArgoCdApi (abstract + NetworkArgoCdApi), SessionStorage (abstract + SecureSessionStorage), ThemeController
- `features/` — Screen widgets organized by domain. Applications feature has sub-screens: list, detail, resource tree, logs, manifest viewer. Screens directly use `AppController` for data/actions.
- `ui/` — MaterialApp setup, `HomeShell` with `IndexedStack` for 4 bottom tabs (Dashboard, Applications, Projects, Settings), reusable widgets (StatusChip, SectionCard, ErrorRetryWidget), and `resource_icons.dart` mapping 30+ K8s resource kinds to icons/colors.

**Navigation**: Imperative Material Navigator with callback-based navigation (no named routes). Detail screens pushed as modal `MaterialPageRoute`. Tab pages preserved in memory via `IndexedStack`.

**Dependency injection**: Services are constructor-injected, not singletons. Tests use hand-written fakes (`_FakeArgoCdApi`, `_MemorySessionStorage`) — no mocking framework. Fakes accept seed data in constructors.

**Platform abstraction**: Conditional imports via `platform_io.dart` / `platform_stub.dart` for HTTP adapters and certificate handling. Android supports user-installed CA certificates.

**Auth & storage**: Token-based (Bearer header). Hybrid storage: token + username in flutter_secure_storage (encrypted), server URL in shared_preferences (unencrypted, persists across sign-outs for UX). AppController manages boot → unauthenticated → authenticated transitions. No token refresh — expired tokens trigger re-authentication.

## Code Style

- `analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` with all strict modes enabled
- Single quotes required (`prefer_single_quotes`)
- Dart SDK >=3.10.0, Flutter >=3.38.0
- Material 3 design with custom theme: Space Grotesk headings, DM Sans body (Google Fonts)

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`): analyze → test → build APK (debug on branches, release on main) → build web → deploy to GitHub Pages. Flutter 3.38.7, Java 17.
