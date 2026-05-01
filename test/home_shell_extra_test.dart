import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('HomeShell — bottom navigation', () {
    testWidgets(
      'renders four destinations on narrow screens (width < 900)',
      (WidgetTester tester) async {
        final controller = await createAuthenticatedController();

        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightAppTheme(),
            home: HomeShell(
              controller: controller,
              themeController: ThemeController(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(navBar.destinations.length, 4);
      },
    );

    testWidgets(
      'uses theme alwaysShow label behaviour for M3 navigation',
      (WidgetTester tester) async {
        final controller = await createAuthenticatedController();

        tester.view.physicalSize = const Size(800, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightAppTheme(),
            home: HomeShell(
              controller: controller,
              themeController: ThemeController(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final BuildContext context = tester.element(find.byType(NavigationBar));
        expect(
          Theme.of(context).navigationBarTheme.labelBehavior,
          NavigationDestinationLabelBehavior.alwaysShow,
        );
      },
    );
  });

  group('HomeShell — page preservation', () {
    testWidgets(
      'switching tabs and back preserves content without rebuilding',
      (WidgetTester tester) async {
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

        // Verify we start on Dashboard.
        expect(find.text('admin @ https://argocd.example.com'), findsOneWidget);

        // Switch to Applications tab.
        await tester.tap(find.byIcon(Icons.dashboard_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Applications'), findsWidgets);

        // Switch to Settings tab.
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.settings), findsOneWidget);

        // Switch back to Dashboard — content must still be present because
        // IndexedStack keeps all pages alive.
        await tester.tap(find.byIcon(Icons.analytics_outlined));
        await tester.pumpAndSettle();
        expect(find.text('admin @ https://argocd.example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'switching from Applications back to Dashboard preserves both pages',
      (WidgetTester tester) async {
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

        // Go to Applications.
        await tester.tap(find.byIcon(Icons.dashboard_outlined));
        await tester.pumpAndSettle();

        // Return to Dashboard — use the outlined (unselected) Dashboard icon.
        await tester.tap(find.byIcon(Icons.analytics_outlined));
        await tester.pumpAndSettle();

        // Both pages exist in the tree because IndexedStack keeps them alive.
        expect(find.text('admin @ https://argocd.example.com'), findsOneWidget);
        // Applications page is offstage but still in the widget tree.
        expect(
          find.text('Applications', skipOffstage: false),
          findsWidgets,
        );
      },
    );
  });
}
