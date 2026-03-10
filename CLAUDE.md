# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter mobile/web client for ArgoCD. Connects to ArgoCD server APIs to manage Kubernetes applications, projects, and resources.

## Common Commands

```bash
flutter pub get          # Install dependencies
flutter analyze          # Lint (strict-casts, strict-inference, strict-raw-types enabled)
flutter test             # Run all tests
flutter test test/widget_test.dart  # Run single test file
flutter run              # Run on connected device/emulator
flutter build apk --debug   # Debug Android APK
flutter build web --release  # Release web bundle
```

CI runs `flutter analyze --no-fatal-infos --no-fatal-warnings` then `flutter test`.

## Architecture

**State management**: Single `AppController` (ChangeNotifier) holds all app state — auth stage, application list, projects, loading/error states. No BLoC or Riverpod.

**Key layers** (all under `lib/`):
- `core/api/` — Dio-based HTTP client with platform-conditional adapters (native_dio_adapter on mobile, BrowserHttpClientAdapter on web)
- `core/models/` — Data classes with `fromJson()` factories: AppSession, ArgoApplication, ArgoProject, ArgoResourceNode
- `core/services/` — AppController, ArgoCdApi (abstract + NetworkArgoCdApi), SessionStorage (abstract + SecureSessionStorage), ThemeController
- `features/` — Screen widgets organized by domain: auth, dashboard, applications, projects, settings
- `ui/app_root.dart` — MaterialApp setup and Navigator-based routing with bottom tab shell

**Dependency injection**: Services are constructor-injected, not singletons. Tests use `_FakeArgoCdApi` and `_MemorySessionStorage` in-memory implementations.

**Platform abstraction**: Conditional imports via `platform_io.dart` / `platform_stub.dart` for HTTP adapters and certificate handling.

**Auth**: Token-based (Bearer header). Token stored in flutter_secure_storage, server URL in shared_preferences. AppController manages boot → unauthenticated → authenticated transitions.

## Code Style

- `analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` with all strict modes enabled
- Single quotes required (`prefer_single_quotes`)
- Dart SDK >=3.10.0, Flutter >=3.38.0

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`): analyze → test → build APK (debug on branches, release on main) → build web → deploy to GitHub Pages. Flutter 3.38.7, Java 17.
