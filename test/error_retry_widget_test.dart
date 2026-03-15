import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapInApp(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData(
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
        colorScheme: const ColorScheme.light(error: Colors.red),
      ),
      darkTheme: ThemeData(
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(error: Colors.redAccent),
      ),
      home: Scaffold(body: child),
    );
  }

  group('ErrorRetryWidget', () {
    testWidgets('renders error message', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Something went wrong',
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('renders error icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Network error',
            onRetry: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error icon is excluded from semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Connection failed',
            onRetry: () {},
          ),
        ),
      );

      expect(find.byType(ExcludeSemantics), findsWidgets);
    });

    testWidgets('renders Retry button', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Failed to load',
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('tapping Retry triggers onRetry callback', (
      WidgetTester tester,
    ) async {
      var retryCount = 0;

      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Try again',
            onRetry: () {
              retryCount++;
            },
          ),
        ),
      );

      expect(retryCount, 0);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryCount, 1);
    });

    testWidgets('tapping Retry multiple times fires callback each time', (
      WidgetTester tester,
    ) async {
      var retryCount = 0;

      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Connection lost',
            onRetry: () {
              retryCount++;
            },
          ),
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retryCount, 3);
    });

    testWidgets('displays long error messages', (WidgetTester tester) async {
      const longMessage =
          'A very long error message that describes in detail what went '
          'wrong with the network request to the ArgoCD server API endpoint.';

      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: longMessage,
            onRetry: () {},
          ),
        ),
      );

      expect(find.text(longMessage), findsOneWidget);
    });

    testWidgets('error message has semantic label with Error prefix', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Unauthorized',
            onRetry: () {},
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'Error: Unauthorized')),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Dark theme error',
            onRetry: () {},
          ),
          themeMode: ThemeMode.dark,
        ),
      );

      expect(find.text('Dark theme error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('Retry button is an OutlinedButton', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          ErrorRetryWidget(
            message: 'Error',
            onRetry: () {},
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });
}
