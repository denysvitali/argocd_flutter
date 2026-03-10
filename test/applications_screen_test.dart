import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/features/applications/applications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppController controller;
  late _MemorySessionStorage storage;
  late List<String> openedApplications;

  setUp(() {
    openedApplications = <String>[];
  });

  Future<void> pumpApplicationsScreen(
    WidgetTester tester, {
    List<ArgoApplication> applications = const <ArgoApplication>[],
  }) async {
    storage = _MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'ops',
          token: 'token',
        ),
      );
    controller = AppController(
      storage: storage,
      api: _FakeArgoCdApi(applications: applications),
      certificateProvider: const CertificateProvider(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
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
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      // Scroll to ensure cards are visible
      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('payments-api'), findsOneWidget);
      expect(find.text('Applications'), findsOneWidget);
    });

    testWidgets('search filters applications by name', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      await tester.enterText(
        find.byType(TextField),
        'payments',
      );
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
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      await tester.enterText(
        find.byType(TextField),
        'web-team',
      );
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
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      // Tap the Degraded filter chip (use the FilterChip specifically)
      final degradedChip = find.descendant(
        of: find.byType(FilterChip),
        matching: find.text('Degraded'),
      );
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

    testWidgets('filter chips show healthy only', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      final healthyChip = find.descendant(
        of: find.byType(FilterChip),
        matching: find.text('Healthy'),
      );
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
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      // Switch to Healthy first
      final healthyChip = find.descendant(
        of: find.byType(FilterChip),
        matching: find.text('Healthy'),
      );
      await tester.tap(healthyChip);
      await tester.pumpAndSettle();
      expect(find.text('frontend-app'), findsNothing);

      // Switch back to All
      final allChip = find.descendant(
        of: find.byType(FilterChip),
        matching: find.text('All'),
      );
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
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

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
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      await tester.enterText(
        find.byType(TextField),
        'nonexistent-app-xyz',
      );
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
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      await tester.scrollUntilVisible(
        find.text('payments-api'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('payments-api'));
      await tester.pumpAndSettle();

      expect(openedApplications, <String>['payments-api']);
    });

    testWidgets('sort dropdown is visible', (WidgetTester tester) async {
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      expect(find.byIcon(Icons.sort_rounded), findsOneWidget);
    });

    testWidgets('FAB refresh button is visible', (
      WidgetTester tester,
    ) async {
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('shows relative sync time', (WidgetTester tester) async {
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

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
      await pumpApplicationsScreen(
        tester,
        applications: _sampleApplications,
      );

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

class _MemorySessionStorage implements SessionStorage {
  AppSession? _session;
  String? _serverUrl;

  @override
  Future<void> clearSession() async {
    _session = null;
  }

  @override
  Future<String?> loadLastServerUrl() async => _serverUrl;

  @override
  Future<AppSession?> loadSession() async => _session;

  @override
  Future<void> saveLastServerUrl(String serverUrl) async {
    _serverUrl = serverUrl;
  }

  @override
  Future<void> saveSession(AppSession session) async {
    _session = session;
    _serverUrl = session.serverUrl;
  }

  void seedSession(AppSession session) {
    _session = session;
    _serverUrl = session.serverUrl;
  }
}

class _FakeArgoCdApi implements ArgoCdApi {
  _FakeArgoCdApi({
    List<ArgoApplication> applications = const <ArgoApplication>[],
    List<ArgoProject> projects = const <ArgoProject>[],
  }) : _applications = applications,
       _projects = projects;

  final List<ArgoApplication> _applications;
  final List<ArgoProject> _projects;

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    return _applications.firstWhere(
      (application) => application.name == applicationName,
    );
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    return _applications;
  }

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    return _projects.firstWhere((project) => project.name == projectName);
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async {
    return _projects;
  }

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async {
    return const <ArgoResourceNode>[];
  }

  @override
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    required String containerName,
    int tailLines = 500,
  }) async {
    return '';
  }

  @override
  Future<void> deleteApplication(
    AppSession session,
    String applicationName, {
    bool cascade = true,
  }) async {}

  @override
  Future<void> rollbackApplication(
    AppSession session,
    String applicationName,
    int historyId,
  ) async {}

  @override
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    return AppSession(serverUrl: serverUrl, username: username, token: 'token');
  }

  @override
  Future<void> syncApplication(
    AppSession session,
    String applicationName,
  ) async {}

  @override
  Future<String> fetchResourceManifest(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
  }) async {
    return '';
  }

  @override
  Future<void> verifyServer(String serverUrl) async {}
}
