@Tags(<String>['golden'])
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

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'applications_light');

    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'projects_light');

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'settings_light');
  });

  testGoldens('authenticated shell pages match dark theme', (
    WidgetTester tester,
  ) async {
    await pumpGoldenApp(tester, themeMode: ThemeMode.dark);
    await screenMatchesGolden(tester, 'dashboard_dark');

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'applications_dark');

    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'projects_dark');

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'settings_dark');
  });
}
