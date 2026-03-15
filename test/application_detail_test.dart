import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/features/applications/application_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppController controller;
  late _FakeArgoCdApi api;

  setUp(() async {
    final storage = _MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'ops',
          token: 'token',
        ),
      );
    api = _FakeArgoCdApi.withSeedData();
    controller = AppController(
      storage: storage,
      api: api,
      certificateProvider: const CertificateProvider(),
    );
    await controller.initialize();
  });

  Widget buildApp({String applicationName = 'payments-api'}) {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: ApplicationDetailScreen(
        controller: controller,
        applicationName: applicationName,
      ),
    );
  }

  testWidgets('renders detail screen with application data', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Hero header shows the app name
    expect(find.text('payments-api'), findsWidgets);
    // Health and sync chips are visible
    expect(find.text('Healthy'), findsWidgets);
    expect(find.text('Synced'), findsWidgets);
  });

  testWidgets('tabs are present and overview is default', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tab labels are visible
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Resources'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Overview tab content is visible by default
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
  });

  testWidgets('switches to resources tab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Switch to Resources tab
    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();

    // Resource cards should be visible
    expect(find.text('Deployment'), findsWidgets);
    expect(find.text('my-deploy'), findsOneWidget);
  });

  testWidgets('switches to history tab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Switch to History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // History timeline entries should be visible
    expect(find.text('Deploy #1'), findsOneWidget);
    expect(find.text('Deploy #2'), findsOneWidget);
    expect(find.textContaining('Current'), findsOneWidget);
    expect(find.text('Rollback'), findsOneWidget);
  });

  testWidgets('action buttons are present in header toolbar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Toolbar buttons in header
    expect(find.text('Sync'), findsWidgets);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Diff'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('confirmation dialog appears for delete', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tap the delete toolbar button by its icon
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Delete Application'), findsOneWidget);
    expect(
      find.textContaining('Are you sure you want to delete'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    // 'Delete' text appears in both toolbar button and dialog button
    expect(find.text('Delete'), findsWidgets);

    // Dismiss the dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Application'), findsNothing);
  });

  testWidgets('confirmation dialog appears for sync', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tap the Sync button in the bottom bar (by its icon)
    await tester.tap(find.byIcon(Icons.sync));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Sync Application'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('rollback confirmation dialog appears from history tab', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Switch to History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // Tap rollback button
    await tester.tap(find.text('Rollback'));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Rollback Application'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('resource cards show kind icons and health status', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Switch to Resources tab
    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();

    // Resource names visible
    expect(find.text('my-deploy'), findsOneWidget);
    expect(find.text('my-pod'), findsOneWidget);

    // Health statuses visible
    expect(find.text('Healthy'), findsWidgets);
    expect(find.text('Progressing'), findsOneWidget);
  });

  testWidgets('pod logs open without forcing container name to pod name', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logs'));
    await tester.pumpAndSettle();

    expect(api.lastLogRequest, isNotNull);
    expect(api.lastLogRequest!.podName, 'my-pod');
    expect(api.lastLogRequest!.containerName, isNull);
    expect(find.text('my-pod'), findsWidgets);
    expect(find.textContaining('2026-03-10T10:00:00Z INFO'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// Test fakes (following existing pattern from widget_test.dart)
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
  _FakeArgoCdApi({
    List<ArgoApplication> applications = const <ArgoApplication>[],
    List<ArgoProject> projects = const <ArgoProject>[],
  }) : _applications = applications,
       _projects = projects;

  _FakeArgoCdApi.withSeedData()
    : _applications = const <ArgoApplication>[
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
          lastSyncedAt: '2026-03-10T10:00:00Z',
          resources: <ArgoResource>[
            ArgoResource(
              kind: 'Deployment',
              name: 'my-deploy',
              namespace: 'payments',
              group: 'apps',
              version: 'v1',
              status: 'Synced',
              health: 'Healthy',
              healthMessage: '',
            ),
            ArgoResource(
              kind: 'Pod',
              name: 'my-pod',
              namespace: 'payments',
              group: '',
              version: 'v1',
              status: 'Synced',
              health: 'Progressing',
              healthMessage: '',
            ),
          ],
          history: <ArgoHistoryEntry>[
            ArgoHistoryEntry(
              id: 1,
              revision: 'abc123',
              deployedAt: '2026-03-09T10:00:00Z',
            ),
            ArgoHistoryEntry(
              id: 2,
              revision: 'def456',
              deployedAt: '2026-03-10T10:00:00Z',
            ),
          ],
        ),
      ],
      _projects = const <ArgoProject>[];

  final List<ArgoApplication> _applications;
  final List<ArgoProject> _projects;
  _LogRequest? lastLogRequest;

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
    String? containerName,
    int tailLines = 500,
  }) async {
    lastLogRequest = _LogRequest(
      applicationName: applicationName,
      namespace: namespace,
      podName: podName,
      containerName: containerName,
    );
    return '2026-03-10T10:00:00Z INFO payments-api booted';
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

class _LogRequest {
  const _LogRequest({
    required this.applicationName,
    required this.namespace,
    required this.podName,
    required this.containerName,
  });

  final String applicationName;
  final String namespace;
  final String podName;
  final String? containerName;
}
