# Style and conventions

Analyzer/lints:
- analysis_options.yaml extends package:flutter_lints/flutter.yaml.
- strict-casts, strict-inference, and strict-raw-types are enabled.
- prefer_single_quotes is enabled.

Dart style:
- Prefer direct imports; the repo does not use barrel/index files.
- Prefer top-level helper functions for focused utilities, as in resource_icons.dart and json_parsing.dart.
- Keep services constructor-injected for testability.
- When adding a service-like dependency, follow the existing pattern: abstract interface where useful, concrete production implementation, handwritten fake for tests.
- Models use defensive parsing via lib/core/utils/json_parsing.dart helpers. Existing models generally implement fromJson only; they do not define toJson, ==, or hashCode.

State/navigation patterns:
- AppController is the central ChangeNotifier state holder.
- UI listens with AnimatedBuilder or ListenableBuilder.
- Navigation is imperative Navigator.of(context).push(MaterialPageRoute(...)); no named routes or router package.

Testing patterns:
- No mocking framework; use handwritten fakes.
- Prefer shared helpers in test/test_helpers.dart when practical.
- Widget tests often wrap screens in MaterialApp with ThemeData(splashFactory: InkRipple.splashFactory).
- For reactive screens, wrap with ListenableBuilder(listenable: controller, ...).
- Use createAuthenticatedController() for tests that should skip auth setup.

UI style:
- Material 3, Space Grotesk for headings, DM Sans for body.
- Shared colors and tokens live in lib/ui/app_colors.dart and lib/ui/design_tokens.dart.
- Reuse shared widgets from lib/ui/shared_widgets.dart where they match the pattern.
