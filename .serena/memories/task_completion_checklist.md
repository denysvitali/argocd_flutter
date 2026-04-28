# Task completion checklist

Before finishing code, documentation, or configuration changes:

1. Check the working tree:
```bash
git status --short --branch
```

2. Run focused verification appropriate to the change. Prefer at least:
```bash
devenv shell -- flutter analyze --no-fatal-infos --no-fatal-warnings
devenv shell -- flutter test --exclude-tags=golden
```

3. For UI or visual changes, also run relevant widget/golden tests. Golden tests are tagged and can be run separately:
```bash
devenv shell -- flutter test --tags=golden
```

4. For changed formatting-sensitive Dart files, use Flutter/Dart formatting if needed:
```bash
devenv shell -- dart format <paths>
```

5. Check for whitespace/errors in diffs:
```bash
git diff --check
```

6. Stage only relevant changes, commit, and push the current branch unless the user explicitly asks not to or pushing is impossible:
```bash
git add <relevant paths>
git commit -m "<message>"
git push
```

Mention any verification that could not be run and why.
