@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

void main() {
  testGoldens('HomeShell Dashboard tab matches light theme', (
    WidgetTester tester,
  ) async {
    final controller = await createAuthenticatedController();

    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.light,
      child: HomeShell(
        controller: controller,
        themeController: ThemeController(),
      ),
    );

    await screenMatchesGolden(tester, 'home_shell_dashboard_light');
  });

  testGoldens('HomeShell Dashboard tab matches dark theme', (
    WidgetTester tester,
  ) async {
    final controller = await createAuthenticatedController();

    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.dark,
      child: HomeShell(
        controller: controller,
        themeController: ThemeController(),
      ),
    );

    await screenMatchesGolden(tester, 'home_shell_dashboard_dark');
  });

  testGoldens('HomeShell Applications tab matches light theme', (
    WidgetTester tester,
  ) async {
    final controller = await createAuthenticatedController();

    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.light,
      child: HomeShell(
        controller: controller,
        themeController: ThemeController(),
      ),
    );

    // Navigate to Applications tab
    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'home_shell_applications_light');
  });
}
