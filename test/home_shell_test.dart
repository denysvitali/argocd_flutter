import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('HomeShell', () {
    testWidgets('displays all four bottom navigation tabs', (
      WidgetTester tester,
    ) async {
      final controller = await createAuthenticatedController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: HomeShell(
            controller: controller,
            themeController: ThemeController(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Applications'), findsWidgets);
      expect(find.text('Projects'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('starts on Dashboard tab', (WidgetTester tester) async {
      final controller = await createAuthenticatedController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: HomeShell(
            controller: controller,
            themeController: ThemeController(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('admin @ https://argocd.example.com'), findsOneWidget);
    });

    testWidgets('switching to Applications tab shows applications content', (
      WidgetTester tester,
    ) async {
      final controller = await createAuthenticatedController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: HomeShell(
            controller: controller,
            themeController: ThemeController(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Applications tab in the NavigationBar
      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Applications'), findsWidgets);
    });

    testWidgets('switching to Projects tab shows projects content', (
      WidgetTester tester,
    ) async {
      final controller = await createAuthenticatedController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: HomeShell(
            controller: controller,
            themeController: ThemeController(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Projects tab
      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pumpAndSettle();

      // Projects screen overview strip heading (authenticated)
      expect(find.text('Projects \u00b7 admin'), findsOneWidget);
    });

    testWidgets('switching to Settings tab updates selected index', (
      WidgetTester tester,
    ) async {
      final controller = await createAuthenticatedController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: HomeShell(
            controller: controller,
            themeController: ThemeController(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Settings tab in the NavigationBar
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // After tapping, the selected icon should change to filled variant
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('navigation bar has correct icons', (
      WidgetTester tester,
    ) async {
      final controller = await createAuthenticatedController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: HomeShell(
            controller: controller,
            themeController: ThemeController(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all navigation icons are present
      // Dashboard tab: analytics icon (selected since it's the first tab)
      expect(find.byIcon(Icons.analytics), findsOneWidget);
      expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });
  });
}
