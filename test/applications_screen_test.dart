import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/features/applications/applications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  late AppController controller;
  late MemorySessionStorage storage;
  late List<String> openedApplications;

  setUp(() {
    openedApplications = <String>[];
  });

  Future<void> pumpApplicationsScreen(
    WidgetTester tester, {
    List<ArgoApplication> applications = const <ArgoApplication>[],
  }) async {
    storage = MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'ops',
          token: 'token',
        ),
      );
    controller = AppController(
      storage: storage,
      api: FakeArgoCdApi(applications: applications),
      certificateProvider: const CertificateProvider(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 1200)),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return ApplicationsScreen(
                controller: controller,
                onOpenApplication: (name) => openedApplications.add(name),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ApplicationsScreen', () {
    testWidgets('renders applications in list view', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      // Scroll to ensure cards are visible
      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('payments-api'), findsOneWidget);
      expect(find.text('Application control plane'), findsOneWidget);
    });

    testWidgets('search filters applications by name', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      await tester.enterText(find.byType(TextField), 'payments');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('payments-api'), findsOneWidget);
      expect(find.text('frontend-app'), findsNothing);
    });

    testWidgets('search filters applications by project', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      await tester.enterText(find.byType(TextField), 'web-team');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('frontend-app'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('frontend-app'), findsOneWidget);
      expect(find.text('payments-api'), findsNothing);
    });

    testWidgets('filter chips filter by health status', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      // Tap the Degraded filter chip (use the FilterChip specifically)
      final degradedChip = _filterChipFinder('Degraded');
      await tester.tap(degradedChip);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('frontend-app'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('frontend-app'), findsOneWidget);
      expect(find.text('payments-api'), findsNothing);
    });

    testWidgets('filter chips show healthy only', (WidgetTester tester) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      final healthyChip = _filterChipFinder('Healthy');
      await tester.tap(healthyChip);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('payments-api'), findsOneWidget);
      expect(find.text('frontend-app'), findsNothing);
    });

    testWidgets('filter All shows all applications', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      // Switch to Healthy first
      final healthyChip = _filterChipFinder('Healthy');
      await tester.tap(healthyChip);
      await tester.pumpAndSettle();
      expect(find.text('frontend-app'), findsNothing);

      // Switch back to All
      final allChip = _filterChipFinder('All');
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('payments-api'), findsOneWidget);
    });

    testWidgets('grid/list toggle switches view mode', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      // Default is list view, grid icon should be shown
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);

      // Tap grid toggle
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      // Now the list icon should be shown
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);

      // Apps should still be visible (scroll to find them)
      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('payments-api'), findsOneWidget);
    });

    testWidgets('empty state shows when no applications exist', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester);

      await tester.scrollUntilVisible(
        find.text('No applications loaded'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No applications loaded'), findsOneWidget);
    });

    testWidgets('empty state shows when filter matches nothing', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      await tester.enterText(find.byType(TextField), 'nonexistent-app-xyz');
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('No applications match this filter'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No applications match this filter'), findsOneWidget);
    });

    testWidgets('tapping a card calls onOpenApplication', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final nameFinder = find.text('payments-api').last;
      await tester.ensureVisible(nameFinder);
      final tapHandler = tester
          .widgetList<InkWell>(
            find.ancestor(of: nameFinder, matching: find.byType(InkWell)),
          )
          .map((widget) => widget.onTap)
          .whereType<VoidCallback>()
          .first;
      tapHandler();
      await tester.pumpAndSettle();

      expect(openedApplications, <String>['payments-api']);
    });

    testWidgets('sort dropdown is visible', (WidgetTester tester) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      expect(find.byIcon(Icons.sort_rounded), findsOneWidget);
    });

    testWidgets('refresh button is visible', (WidgetTester tester) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows relative sync time', (WidgetTester tester) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      // Scroll to ensure cards are visible
      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // The relative time text will show as some amount of time ago
      expect(find.textContaining('ago'), findsWidgets);
    });

    testWidgets('clear search restores all applications', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(tester, applications: _sampleApplications);

      // Enter search
      await tester.enterText(find.byType(TextField), 'payments');
      await tester.pumpAndSettle();
      expect(find.text('frontend-app'), findsNothing);

      // Clear using the clear button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('payments-api'), findsOneWidget);
    });
  });
}

Finder _filterChipFinder(String labelPrefix) {
  return find.byWidgetPredicate((widget) {
    if (widget is! FilterChip) {
      return false;
    }
    final label = widget.label;
    if (label is Text) {
      return label.data?.startsWith(labelPrefix) ?? false;
    }
    if (label is Row) {
      for (final child in label.children) {
        if (child is Text && (child.data?.startsWith(labelPrefix) ?? false)) {
          return true;
        }
      }
    }
    return false;
  });
}

const _sampleApplications = <ArgoApplication>[
  ArgoApplication(
    name: 'payments-api',
    project: 'platform',
    namespace: 'payments',
    cluster: 'https://kubernetes.default.svc',
    repoUrl: 'https://github.com/example/platform',
    path: 'apps/payments-api',
    targetRevision: 'main',
    syncStatus: 'Synced',
    healthStatus: 'Healthy',
    operationPhase: 'Succeeded',
    lastSyncedAt: '2025-03-10T10:00:00Z',
    resources: <ArgoResource>[],
    history: <ArgoHistoryEntry>[],
  ),
  ArgoApplication(
    name: 'frontend-app',
    project: 'web-team',
    namespace: 'frontend',
    cluster: 'https://kubernetes.default.svc',
    repoUrl: 'https://github.com/example/frontend',
    path: 'apps/frontend',
    targetRevision: 'main',
    syncStatus: 'OutOfSync',
    healthStatus: 'Degraded',
    operationPhase: 'Failed',
    lastSyncedAt: '2025-03-09T08:00:00Z',
    resources: <ArgoResource>[],
    history: <ArgoHistoryEntry>[],
  ),
];

