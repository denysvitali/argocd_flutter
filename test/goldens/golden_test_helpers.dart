import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

const Size goldenPhoneSize = Size(390, 844);

Future<void> pumpGoldenApp(
  WidgetTester tester, {
  FakeArgoCdApi? api,
  MemorySessionStorage? storage,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'argocd.theme_mode': switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    },
  });

  final effectiveStorage =
      storage ?? (MemorySessionStorage()..seedSession(testSession));
  final controller = createTestController(
    storage: effectiveStorage,
    api: api ?? FakeArgoCdApi.withSeedData(),
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
}

Future<void> pumpGoldenScreen(
  WidgetTester tester, {
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  Size size = goldenPhoneSize,
}) async {
  await tester.pumpWidgetBuilder(
    SizedBox(
      width: size.width,
      height: size.height,
      child: MaterialApp(
        themeMode: themeMode,
        theme: buildLightAppTheme(),
        darkTheme: buildDarkAppTheme(),
        home: child,
      ),
    ),
    surfaceSize: size,
  );
  await tester.pumpAndSettle();
}
