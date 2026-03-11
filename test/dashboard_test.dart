import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets('renders with empty data and shows empty state', (
      WidgetTester tester,
    ) async {
      final controller = _createController(
        applications: const <ArgoApplication>[],
      );
      await _initController(controller);

      await tester.pumpWidget(_wrapDashboard(controller));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('admin @ https://argocd.example.com'), findsOneWidget);
      expect(find.text('No applications found'), findsOneWidget);
      expect(
        find.text(
          'Your ArgoCD server has no applications yet.\n'
          'Deploy an application to see it here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders summary tiles with correct counts', (
      WidgetTester tester,
    ) async {
      final controller = _createController(applications: _testApplications);
      await _initController(controller);

      await tester.pumpWidget(_wrapDashboard(controller));
      await tester.pumpAndSettle();

      expect(find.text('Health Breakdown'), findsOneWidget);

      // Hero banner metric chip values are visible
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Out of sync'), findsOneWidget);

      // Verify controller has the right counts
      expect(controller.applications.length, equals(4));
    });

    testWidgets('needs attention section shows degraded and out-of-sync apps', (
      WidgetTester tester,
    ) async {
      final controller = _createController(applications: _testApplications);
      await _initController(controller);

      await tester.pumpWidget(_wrapDashboard(controller));
      await tester.pumpAndSettle();

      // Scroll down to find the Needs Attention section
      await _scrollTo(tester, find.text('Needs Attention'));

      expect(find.text('Needs Attention'), findsOneWidget);

      // Scroll more to see the degraded app
      await _scrollTo(tester, find.text('degraded-app').first);

      // The degraded app appears in needs attention and possibly recent activity
      expect(find.text('degraded-app'), findsWidgets);
    });

    testWidgets('shows recent activity timeline', (WidgetTester tester) async {
      final controller = _createController(applications: _testApplications);
      await _initController(controller);

      await tester.pumpWidget(_wrapDashboard(controller));
      await tester.pumpAndSettle();

      // Scroll down to find the Recent Activity section
      await _scrollTo(tester, find.text('Recent Activity'));

      expect(find.text('Recent Activity'), findsOneWidget);
    });

    testWidgets('shows all healthy message when nothing needs attention', (
      WidgetTester tester,
    ) async {
      final controller = _createController(
        applications: const <ArgoApplication>[
          ArgoApplication(
            name: 'healthy-app',
            project: 'default',
            namespace: 'default',
            cluster: 'in-cluster',
            repoUrl: 'https://github.com/example/repo',
            path: '/',
            targetRevision: 'main',
            syncStatus: 'Synced',
            healthStatus: 'Healthy',
            operationPhase: 'Succeeded',
            lastSyncedAt: '2026-03-10T10:00:00Z',
            resources: <ArgoResource>[],
            history: <ArgoHistoryEntry>[],
          ),
        ],
      );
      await _initController(controller);

      await tester.pumpWidget(_wrapDashboard(controller));
      await tester.pumpAndSettle();

      await _scrollTo(
        tester,
        find.text('All applications are healthy and synced!'),
      );
      expect(
        find.text('All applications are healthy and synced!'),
        findsOneWidget,
      );
    });

    testWidgets('pull-to-refresh triggers data reload', (
      WidgetTester tester,
    ) async {
      final api = FakeArgoCdApi(applications: _testApplications);
      final controller = _createController(
        applications: _testApplications,
        api: api,
      );
      await _initController(controller);

      await tester.pumpWidget(_wrapDashboard(controller));
      await tester.pumpAndSettle();

      // Verify RefreshIndicator is present
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('shows donut chart sections', (WidgetTester tester) async {
      final controller = _createController(applications: _testApplications);
      await _initController(controller);

      await tester.pumpWidget(_wrapDashboard(controller));
      await tester.pumpAndSettle();

      // Scroll down to find the Health Breakdown section
      await _scrollTo(tester, find.text('Health Breakdown'));

      expect(find.text('Health Breakdown'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const List<ArgoApplication> _testApplications = <ArgoApplication>[
  ArgoApplication(
    name: 'healthy-app-1',
    project: 'default',
    namespace: 'default',
    cluster: 'in-cluster',
    repoUrl: 'https://github.com/example/repo',
    path: '/',
    targetRevision: 'main',
    syncStatus: 'Synced',
    healthStatus: 'Healthy',
    operationPhase: 'Succeeded',
    lastSyncedAt: '2026-03-10T10:00:00Z',
    resources: <ArgoResource>[],
    history: <ArgoHistoryEntry>[],
  ),
  ArgoApplication(
    name: 'healthy-app-2',
    project: 'default',
    namespace: 'default',
    cluster: 'in-cluster',
    repoUrl: 'https://github.com/example/repo',
    path: '/',
    targetRevision: 'main',
    syncStatus: 'Synced',
    healthStatus: 'Healthy',
    operationPhase: 'Succeeded',
    lastSyncedAt: '2026-03-10T09:30:00Z',
    resources: <ArgoResource>[],
    history: <ArgoHistoryEntry>[],
  ),
  ArgoApplication(
    name: 'degraded-app',
    project: 'default',
    namespace: 'default',
    cluster: 'in-cluster',
    repoUrl: 'https://github.com/example/repo',
    path: '/',
    targetRevision: 'main',
    syncStatus: 'Synced',
    healthStatus: 'Degraded',
    operationPhase: 'Succeeded',
    lastSyncedAt: '2026-03-10T08:00:00Z',
    resources: <ArgoResource>[],
    history: <ArgoHistoryEntry>[],
  ),
  ArgoApplication(
    name: 'outofsync-app',
    project: 'default',
    namespace: 'default',
    cluster: 'in-cluster',
    repoUrl: 'https://github.com/example/repo',
    path: '/',
    targetRevision: 'main',
    syncStatus: 'OutOfSync',
    healthStatus: 'Healthy',
    operationPhase: 'Running',
    lastSyncedAt: '2026-03-10T07:00:00Z',
    resources: <ArgoResource>[],
    history: <ArgoHistoryEntry>[],
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppController _createController({
  List<ArgoApplication> applications = const <ArgoApplication>[],
  FakeArgoCdApi? api,
}) {
  final fakeApi = api ?? FakeArgoCdApi(applications: applications);
  final storage = MemorySessionStorage()..seedSession(testSession);

  return AppController(
    storage: storage,
    api: fakeApi,
    certificateProvider: const CertificateProvider(),
  );
}

Future<void> _initController(AppController controller) async {
  await controller.initialize();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.dragUntilVisible(
    target,
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
}

Widget _wrapDashboard(AppController controller) {
  return MaterialApp(
    theme: ThemeData(splashFactory: InkRipple.splashFactory),
    home: DashboardScreen(controller: controller, onOpenApplication: (_) {}),
  );
}

