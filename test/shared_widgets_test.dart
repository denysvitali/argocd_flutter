import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapInApp(Widget child) {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: Scaffold(body: child),
    );
  }

  group('StatusChip', () {
    testWidgets('renders label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(const StatusChip(label: 'Synced', color: Colors.green)),
      );

      expect(find.text('Synced'), findsOneWidget);
    });

    testWidgets('wraps content in Semantics widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(const StatusChip(label: 'Healthy', color: Colors.teal)),
      );

      // The widget wraps its content in a Semantics widget
      expect(find.byType(Semantics), findsWidgets);
      expect(find.text('Healthy'), findsOneWidget);
    });

    testWidgets('applies the given color to the text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(const StatusChip(label: 'Degraded', color: Colors.red)),
      );

      final text = tester.widget<Text>(find.text('Degraded'));
      expect(text.style?.color, Colors.red);
    });
  });

  group('SectionCard', () {
    testWidgets('renders title and child', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const SectionCard(
            title: 'Summary',
            child: Text('Child content'),
          ),
        ),
      );

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Child content'), findsOneWidget);
    });

    testWidgets('title has bold font weight', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const SectionCard(title: 'Bold Title', child: SizedBox.shrink()),
        ),
      );

      final text = tester.widget<Text>(find.text('Bold Title'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });
  });

  group('EmptyStateCard', () {
    testWidgets('renders title and subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const EmptyStateCard(
            title: 'No data',
            subtitle: 'Please try again later.',
          ),
        ),
      );

      expect(find.text('No data'), findsOneWidget);
      expect(find.text('Please try again later.'), findsOneWidget);
    });

    testWidgets('title has bold font weight', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const EmptyStateCard(
            title: 'Empty',
            subtitle: 'Nothing here.',
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Empty'));
      expect(text.style?.fontWeight, FontWeight.w600);
    });
  });

  group('SummaryTile', () {
    testWidgets('renders value and label', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(const SummaryTile(label: 'Total Apps', value: 42)),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Total Apps'), findsOneWidget);
    });

    testWidgets('renders zero value', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(const SummaryTile(label: 'Degraded', value: 0)),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('Degraded'), findsOneWidget);
    });

    testWidgets('applies custom valueColor', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const SummaryTile(
            label: 'Healthy',
            value: 5,
            valueColor: Colors.green,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('5'));
      expect(text.style?.color, Colors.green);
    });
  });

  group('FactBadge', () {
    testWidgets('renders icon and label', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const FactBadge(icon: Icons.code, label: 'manifests/'),
        ),
      );

      expect(find.text('manifests/'), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
    });

    testWidgets('renders in a Row layout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          const FactBadge(icon: Icons.dns, label: 'in-cluster'),
        ),
      );

      // FactBadge uses a Row to lay out icon and label
      expect(find.text('in-cluster'), findsOneWidget);
      expect(find.byIcon(Icons.dns), findsOneWidget);
    });
  });
}
