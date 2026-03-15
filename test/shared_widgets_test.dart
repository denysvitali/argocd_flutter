import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapInApp(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
    return MaterialApp(
      themeMode: themeMode,
      theme: ThemeData(
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
          error: Colors.red,
        ),
      ),
      darkTheme: ThemeData(
        splashFactory: InkRipple.splashFactory,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          error: Colors.redAccent,
        ),
      ),
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

    testWidgets('semantic label includes Status prefix', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(const StatusChip(label: 'Missing', color: Colors.grey)),
      );

      // The Semantics wrapper sets label 'Status: Missing'
      expect(
        find.bySemanticsLabel(RegExp(r'Status: Missing')),
        findsOneWidget,
      );
    });

    testWidgets('renders long label text without overflow error', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          const SizedBox(
            width: 300,
            child: StatusChip(
              label: 'A very long status label',
              color: Colors.purple,
            ),
          ),
        ),
      );

      expect(find.text('A very long status label'), findsOneWidget);
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const StatusChip(label: 'Healthy', color: Colors.teal),
          themeMode: ThemeMode.dark,
        ),
      );

      expect(find.text('Healthy'), findsOneWidget);
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
      expect(text.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('renders without title when title is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          const SectionCard(child: Text('Only child')),
        ),
      );

      expect(find.text('Only child'), findsOneWidget);
      // No title rendered, so only one Text widget
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders complex child widgets', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const SectionCard(
            title: 'Resources',
            child: Column(
              children: <Widget>[
                Text('resource-1'),
                Text('resource-2'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Resources'), findsOneWidget);
      expect(find.text('resource-1'), findsOneWidget);
      expect(find.text('resource-2'), findsOneWidget);
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

    testWidgets('has combined semantic label for accessibility', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          const EmptyStateCard(
            title: 'No applications',
            subtitle: 'Deploy your first app.',
          ),
        ),
      );

      // Semantics node combines title and subtitle for screen readers
      expect(
        find.bySemanticsLabel(
          RegExp(r'No applications\. Deploy your first app\.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const EmptyStateCard(
            title: 'Empty',
            subtitle: 'No data.',
          ),
          themeMode: ThemeMode.dark,
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
      expect(find.text('No data.'), findsOneWidget);
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

    testWidgets('renders large value correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(const SummaryTile(label: 'Total', value: 9999)),
      );

      expect(find.text('9999'), findsOneWidget);
    });

    testWidgets('has semantic label combining value and label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(const SummaryTile(label: 'Healthy Apps', value: 7)),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'7 Healthy Apps')),
        findsOneWidget,
      );
    });

    testWidgets('renders without valueColor when not provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(const SummaryTile(label: 'Apps', value: 3)),
      );

      final text = tester.widget<Text>(find.text('3'));
      // No explicit valueColor override — color should not be green (custom)
      expect(text.style?.color, isNot(Colors.green));
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

    testWidgets('icon is excluded from semantics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapInApp(
          const FactBadge(icon: Icons.folder, label: 'apps/payments'),
        ),
      );

      // ExcludeSemantics wraps the icon
      expect(find.byType(ExcludeSemantics), findsWidgets);
    });

    testWidgets('renders long label text', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const SizedBox(
            width: 300,
            child: FactBadge(
              icon: Icons.link,
              label: 'https://github.com/example/very-long-repo-name',
            ),
          ),
        ),
      );

      expect(
        find.text('https://github.com/example/very-long-repo-name'),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapInApp(
          const FactBadge(icon: Icons.cloud, label: 'production'),
          themeMode: ThemeMode.dark,
        ),
      );

      expect(find.text('production'), findsOneWidget);
      expect(find.byIcon(Icons.cloud), findsOneWidget);
    });
  });
}
