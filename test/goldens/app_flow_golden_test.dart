@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Unauthenticated state — sign-in screen
  // ---------------------------------------------------------------------------

  testGoldens('unauthenticated sign-in screen matches light theme', (
    WidgetTester tester,
  ) async {
    await pumpGoldenApp(
      tester,
      storage: MemorySessionStorage(),
      themeMode: ThemeMode.light,
    );

    await screenMatchesGolden(tester, 'app_flow_sign_in_light');
  });

  testGoldens('unauthenticated sign-in screen matches dark theme', (
    WidgetTester tester,
  ) async {
    await pumpGoldenApp(
      tester,
      storage: MemorySessionStorage(),
      themeMode: ThemeMode.dark,
    );

    await screenMatchesGolden(tester, 'app_flow_sign_in_dark');
  });

  // ---------------------------------------------------------------------------
  // Authenticated state — home shell with dashboard tab
  // ---------------------------------------------------------------------------

  testGoldens('authenticated home shell dashboard matches light theme', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'argocd.theme_mode': 'light',
    });

    final storage = MemorySessionStorage()..seedSession(testSession);
    final controller = createTestController(
      storage: storage,
      api: FakeArgoCdApi.withSeedData(),
    );
    final themeController = ThemeController();

    await tester.pumpWidgetBuilder(
      SizedBox(
        width: goldenPhoneSize.width,
        height: goldenPhoneSize.height,
        child: ArgoCdApp(
          controller: controller,
          themeController: themeController,
        ),
      ),
      surfaceSize: goldenPhoneSize,
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'app_flow_dashboard_light');
  });

  testGoldens('authenticated home shell dashboard matches dark theme', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'argocd.theme_mode': 'dark',
    });

    final storage = MemorySessionStorage()..seedSession(testSession);
    final controller = createTestController(
      storage: storage,
      api: FakeArgoCdApi.withSeedData(),
    );
    final themeController = ThemeController();

    await tester.pumpWidgetBuilder(
      SizedBox(
        width: goldenPhoneSize.width,
        height: goldenPhoneSize.height,
        child: ArgoCdApp(
          controller: controller,
          themeController: themeController,
        ),
      ),
      surfaceSize: goldenPhoneSize,
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'app_flow_dashboard_dark');
  });
}
