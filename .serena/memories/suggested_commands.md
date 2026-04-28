# Suggested commands

Run commands from the repository root. The project expects devenv/Nix for reproducible tooling.

Setup:
```bash
devenv shell
flutter pub get
```

One-shot commands without entering the shell:
```bash
devenv shell -- flutter pub get
devenv shell -- flutter analyze --no-fatal-infos --no-fatal-warnings
devenv shell -- flutter test
devenv shell -- flutter test test/some_test.dart
devenv shell -- flutter test --exclude-tags=golden
devenv shell -- flutter test --tags=golden
devenv shell -- flutter test --update-goldens test/goldens/
devenv shell -- flutter run
devenv shell -- flutter build web --release
devenv shell -- flutter build apk --debug
```

CI-like quality checks:
```bash
devenv shell -- flutter analyze --no-fatal-infos --no-fatal-warnings
devenv shell -- flutter test --exclude-tags=golden
devenv shell -- flutter test --tags=golden
```

Useful local utilities on this Linux workspace:
```bash
git status --short --branch
git diff --check
git diff -- <path>
rg "pattern" lib test
rg --files
find lib -maxdepth 3 -type d | sort
```

Notes:
- README lists `devenv shell -- flutter analyze`; CLAUDE.md notes CI uses `flutter analyze --no-fatal-infos --no-fatal-warnings`.
- Android SDK is not provided by devenv according to CLAUDE.md, so Android builds may be CI-only unless the local machine has Android tooling configured separately.
