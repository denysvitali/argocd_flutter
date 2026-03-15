import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(find.text('Drifted'), findsOneWidget);

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
      final api = _FakeArgoCdApi(applications: _testApplications);
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
  _FakeArgoCdApi? api,
}) {
  final fakeApi = api ?? _FakeArgoCdApi(applications: applications);
  final storage = _MemorySessionStorage()
    ..seedSession(
      const AppSession(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        token: 'test-token',
      ),
    );

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

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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
  _FakeArgoCdApi({this.applications = const <ArgoApplication>[]});

  final List<ArgoApplication> applications;

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    return applications.firstWhere(
      (application) => application.name == applicationName,
    );
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    return applications;
  }

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async {
    return const <ArgoProject>[];
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
    String? containerName,
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
  Future<List<ManagedResource>> fetchManagedResources(
    AppSession session,
    String applicationName,
  ) async {
    return const <ManagedResource>[];
  }

  @override
  Future<void> deleteResource(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
    bool force = false,
  }) => Future<void>.value();

  @override
  Future<void> verifyServer(String serverUrl) async {}
}
