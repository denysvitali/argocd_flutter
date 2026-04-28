# Project overview

ArgoCD Flutter is a Flutter mobile/web client for ArgoCD operators. It connects to ArgoCD server REST APIs to manage Kubernetes applications, projects, resources, logs, manifests, sync/rollback/delete operations, and health monitoring.

Primary targets are Android and web. The repo includes platform folders for iOS, macOS, Linux, and Windows, but project notes say CI focuses on Android APK and web.

Tech stack:
- Dart SDK >=3.10.0 <4.0.0 and Flutter >=3.38.0.
- Flutter Material 3 UI.
- Dio for HTTP, native_dio_adapter for native HTTP, BrowserHttpClientAdapter on web through conditional imports.
- flutter_secure_storage for token/username, shared_preferences for server URL/theme/health monitor settings.
- sentry_flutter and sentry_dio for Sentry integration.
- golden_toolkit for golden tests.
- devenv/Nix for reproducible local tooling.

High-level architecture:
- A single AppController ChangeNotifier owns app auth state, lists, loading flags, errors, session, and refresh flow.
- Widgets observe state through AnimatedBuilder/ListenableBuilder; there is no Provider, Riverpod, BLoC, service locator, router package, code generation, or mocking framework.
- Navigation is imperative Navigator.push with MaterialPageRoute.
- Services are constructor-injected from main.dart and tests use handwritten fakes.
- Models use defensive fromJson parsing helpers and mostly keep raw string timestamps.
