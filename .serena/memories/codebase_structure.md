# Codebase structure

Important root files:
- README.md: setup and quality commands.
- CLAUDE.md: detailed project guidance and architecture notes.
- pubspec.yaml / pubspec.lock: Flutter dependencies and SDK constraints.
- analysis_options.yaml: flutter_lints plus strict analyzer settings.
- devenv.nix / devenv.lock: reproducible development shell.
- flutter_test_config.dart: global golden_toolkit font loading for tests.

Source layout:
- lib/main.dart: bootstrap and service wiring.
- lib/platform_io.dart and lib/platform_stub.dart: platform helpers via conditional imports.
- lib/core/api: HTTP adapter helpers for native vs web.
- lib/core/models: ArgoCD data models with fromJson parsing.
- lib/core/services: AppController, NetworkArgoCdApi, session storage, health monitor, theme controller, certificate provider.
- lib/core/utils: JSON parsing, diff, time formatting.
- lib/features/auth: sign-in screen.
- lib/features/dashboard: dashboard metrics and incident feed.
- lib/features/applications: app list, detail, diff, logs, manifests, resource tree.
- lib/features/projects: project list/detail.
- lib/features/settings: theme, connection, health monitor settings.
- lib/ui: app root/theme, design tokens, shared widgets, colors, resource icons, error and last-updated widgets.

Tests:
- test/test_helpers.dart contains shared fakes, seed data, and controller factories.
- test/goldens contains golden tests and reference images in test/goldens/goldens.
- integration_test/app_test.dart contains integration coverage.
