@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

void main() {
  testGoldens('sign-in screen matches light theme', (
    WidgetTester tester,
  ) async {
    await pumpGoldenApp(
      tester,
      storage: MemorySessionStorage(),
      themeMode: ThemeMode.light,
    );

    await screenMatchesGolden(tester, 'sign_in_light');
  });

  testGoldens('sign-in screen matches dark theme', (WidgetTester tester) async {
    await pumpGoldenApp(
      tester,
      storage: MemorySessionStorage(),
      themeMode: ThemeMode.dark,
    );

    await screenMatchesGolden(tester, 'sign_in_dark');
  });

  testGoldens('authenticated shell pages match light theme', (
    WidgetTester tester,
  ) async {
    await pumpGoldenApp(tester, themeMode: ThemeMode.light);
    await screenMatchesGolden(tester, 'dashboard_light');

    await _tapShellTab(tester, Icons.dashboard_outlined);
    await screenMatchesGolden(tester, 'applications_light');

    await _tapShellTab(tester, Icons.folder_outlined);
    await screenMatchesGolden(tester, 'projects_light');

    await _tapShellTab(tester, Icons.settings_outlined);
    await screenMatchesGolden(tester, 'settings_light');
  });

  testGoldens('authenticated shell pages match dark theme', (
    WidgetTester tester,
  ) async {
    await pumpGoldenApp(tester, themeMode: ThemeMode.dark);
    await screenMatchesGolden(tester, 'dashboard_dark');

    await _tapShellTab(tester, Icons.dashboard_outlined);
    await screenMatchesGolden(tester, 'applications_dark');

    await _tapShellTab(tester, Icons.folder_outlined);
    await screenMatchesGolden(tester, 'projects_dark');

    await _tapShellTab(tester, Icons.settings_outlined);
    await screenMatchesGolden(tester, 'settings_dark');
  });
}

/// Taps a destination icon inside the bottom [NavigationBar], scoping the
/// match so it doesn't collide with icons that screens use for content
/// (e.g. the "Projects" filter dropdown also uses [Icons.folder_outlined]).
Future<void> _tapShellTab(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}
