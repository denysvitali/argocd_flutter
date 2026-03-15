import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

// Pumps ArgoCdApp with an empty storage so the controller starts in booting
// state and stays there (no pumpAndSettle, just the initial frame).
Future<void> _pumpBootstrap(WidgetTester tester) async {
  final controller = createTestController(storage: MemorySessionStorage());
  await tester.pumpWidget(
    ArgoCdApp(
      controller: controller,
      themeController: ThemeController(),
    ),
  );
  // Do NOT call pump/pumpAndSettle here – the initial frame already shows
  // the _BootstrapScreen because initialize() is async and hasn't settled yet.
}

void main() {
  group('BootstrapScreen', () {
    testWidgets('shows cloud_queue_rounded icon', (WidgetTester tester) async {
      await _pumpBootstrap(tester);

      expect(find.byIcon(Icons.cloud_queue_rounded), findsOneWidget);
    });

    testWidgets('shows ArgoCD Flutter title', (WidgetTester tester) async {
      await _pumpBootstrap(tester);

      // The sign-in screen also contains this text but we are still in the
      // booting stage, so only the bootstrap label should be present.
      expect(find.text('ArgoCD Flutter'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator', (
      WidgetTester tester,
    ) async {
      await _pumpBootstrap(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('has FadeTransition for the fade-in animation', (
      WidgetTester tester,
    ) async {
      await _pumpBootstrap(tester);

      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('fade animation starts near zero opacity', (
      WidgetTester tester,
    ) async {
      await _pumpBootstrap(tester);

      // Find the FadeTransition that wraps the bootstrap content column.
      final fadeTransitions = tester.widgetList<FadeTransition>(
        find.byType(FadeTransition),
      );
      // At the very first frame the bootstrap animation has just begun —
      // at least one FadeTransition should have near-zero opacity.
      expect(
        fadeTransitions.any((ft) => ft.opacity.value < 0.1),
        isTrue,
      );
    });

    testWidgets('fade animation progresses to near full opacity after 800ms', (
      WidgetTester tester,
    ) async {
      await _pumpBootstrap(tester);

      // Advance the animation without resolving async futures.
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 800));

      final fadeTransition = tester.widget<FadeTransition>(
        find.byType(FadeTransition).first,
      );
      expect(fadeTransition.opacity.value, greaterThan(0.9));
    });

    testWidgets('does not show sign-in screen in booting state', (
      WidgetTester tester,
    ) async {
      await _pumpBootstrap(tester);

      expect(find.text('Server URL'), findsNothing);
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('content is laid out in a centered column', (
      WidgetTester tester,
    ) async {
      await _pumpBootstrap(tester);

      // Icon, title and progress indicator should all be present inside the
      // widget tree.
      expect(find.byIcon(Icons.cloud_queue_rounded), findsOneWidget);
      expect(find.text('ArgoCD Flutter'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
