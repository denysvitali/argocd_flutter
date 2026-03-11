import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('shows sign-in flow when there is no saved session', (
    WidgetTester tester,
  ) async {
    final controller = createTestController();

    await tester.pumpWidget(
      ArgoCdApp(controller: controller, themeController: ThemeController()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect to ArgoCD'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Test server'), findsOneWidget);
  });

  testWidgets('restores a saved session into the authenticated shell', (
    WidgetTester tester,
  ) async {
    final storage = MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'ops',
          token: 'token',
        ),
      );
    final controller = createTestController(
      storage: storage,
      api: FakeArgoCdApi.withSeedData(),
    );

    await tester.pumpWidget(
      ArgoCdApp(controller: controller, themeController: ThemeController()),
    );
    await controller.initialize();
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Cluster dashboard'), findsOneWidget);
    expect(controller.applications.length, equals(1));
    expect(controller.applications.first.name, equals('payments-api'));
  });
}
