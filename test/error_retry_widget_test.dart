import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
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
  });
}
