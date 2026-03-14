import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/features/applications/resource_tree_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppController controller;
  late _FakeArgoCdApi api;

  final sampleNodes = <ArgoResourceNode>[
    const ArgoResourceNode(
      group: 'apps',
      version: 'v1',
      kind: 'Deployment',
      namespace: 'default',
      name: 'my-app',
      uid: 'uid-1',
      parentUids: <String>[],
      healthStatus: 'Healthy',
      healthMessage: 'All replicas ready',
      createdAt: '2026-03-01T10:00:00Z',
    ),
    const ArgoResourceNode(
      group: 'apps',
      version: 'v1',
      kind: 'ReplicaSet',
      namespace: 'default',
      name: 'my-app-abc123',
      uid: 'uid-2',
      parentUids: <String>['uid-1'],
      healthStatus: 'Healthy',
      healthMessage: '',
      createdAt: '2026-03-01T10:00:00Z',
    ),
    const ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'Pod',
      namespace: 'default',
      name: 'my-app-abc123-xyz',
      uid: 'uid-3',
      parentUids: <String>['uid-2'],
      healthStatus: 'Healthy',
      healthMessage: 'Running',
      createdAt: '2026-03-01T10:01:00Z',
    ),
    const ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'Service',
      namespace: 'default',
      name: 'my-app-svc',
      uid: 'uid-4',
      parentUids: <String>[],
      healthStatus: 'Healthy',
      healthMessage: '',
      createdAt: '2026-03-01T10:00:00Z',
    ),
    const ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'ConfigMap',
      namespace: 'default',
      name: 'my-app-config',
      uid: 'uid-5',
      parentUids: <String>[],
      healthStatus: 'Degraded',
      healthMessage: 'Missing key',
      createdAt: '2026-03-01T09:00:00Z',
    ),
  ];

  setUp(() {
    final storage = _MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'admin',
          token: 'test-token',
        ),
      );
    api = _FakeArgoCdApi(resourceNodes: sampleNodes);
    controller = AppController(
      storage: storage,
      api: api,
      certificateProvider: const CertificateProvider(),
    );
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: ResourceTreeScreen(
        controller: controller,
        applicationName: 'test-app',
      ),
    );
  }

  testWidgets('renders resource tree with sample nodes', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Should show the screen title
    expect(find.text('Resource Tree'), findsOneWidget);
    expect(find.text('test-app'), findsOneWidget);

    // Should show the summary header
    expect(find.text('Resource Summary'), findsOneWidget);

    // Should show root-level resource names
    expect(find.text('my-app'), findsOneWidget);
    expect(find.text('my-app-svc'), findsOneWidget);
    expect(find.text('my-app-config'), findsOneWidget);

    // Should show resource kinds
    expect(find.text('Deployment'), findsWidgets);
    expect(find.text('Service'), findsWidgets);
    expect(find.text('ConfigMap'), findsWidgets);
  });

  testWidgets('summary header shows correct counts', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Total resources count in the donut
    expect(find.text('5'), findsOneWidget);
    expect(find.text('resources'), findsOneWidget);

    // Health legend items
    expect(find.text('4 Healthy'), findsOneWidget);
    expect(find.text('1 Degraded'), findsOneWidget);
  });

  testWidgets('expand and collapse works via expand all button', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Children should be visible when initially expanded
    expect(find.text('my-app-abc123'), findsOneWidget);
    expect(find.text('my-app-abc123-xyz'), findsOneWidget);

    // Find and tap the collapse all button
    final collapseButton = find.byTooltip('Collapse All');
    expect(collapseButton, findsOneWidget);
    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    // After collapsing, children should not be visible
    expect(find.text('my-app-abc123'), findsNothing);
    expect(find.text('my-app-abc123-xyz'), findsNothing);

    // Root nodes should still be visible
    expect(find.text('my-app'), findsOneWidget);

    // Expand all button should now appear
    final expandButton = find.byTooltip('Expand All');
    expect(expandButton, findsOneWidget);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    // Children should be visible again
    expect(find.text('my-app-abc123'), findsOneWidget);
  });

  testWidgets('search filters resources by name', (WidgetTester tester) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // All resources visible initially
    expect(find.text('my-app-svc'), findsOneWidget);
    expect(find.text('my-app-config'), findsOneWidget);

    // Type in the search bar
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'config');
    await tester.pumpAndSettle();

    // Only config-related resources should be visible
    expect(find.text('my-app-config'), findsOneWidget);

    // Service should be filtered out (it does not match 'config')
    expect(find.text('my-app-svc'), findsNothing);
  });

  testWidgets('search filters resources by kind', (WidgetTester tester) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'service');
    await tester.pumpAndSettle();

    // Service should be visible
    expect(find.text('my-app-svc'), findsOneWidget);

    // Deployment root should not be visible since neither it nor
    // its descendants match 'service'
    expect(find.text('my-app-config'), findsNothing);
  });

  testWidgets('shows empty state when no resources', (
    WidgetTester tester,
  ) async {
    final storage = _MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'admin',
          token: 'test-token',
        ),
      );
    final emptyController = AppController(
      storage: storage,
      api: _FakeArgoCdApi(),
      certificateProvider: const CertificateProvider(),
    );
    await emptyController.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: ResourceTreeScreen(
          controller: emptyController,
          applicationName: 'empty-app',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No resources found'), findsOneWidget);
    expect(
      find.text('No resource tree data returned by the ArgoCD API.'),
      findsOneWidget,
    );
  });

  testWidgets('search with no matches shows no-results message', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'nonexistent-resource-xyz');
    await tester.pumpAndSettle();

    expect(find.textContaining('No resources match'), findsOneWidget);
  });

  testWidgets('resource detail bottom sheet opens on long press', (
    WidgetTester tester,
  ) async {
    // Use a small set of nodes so everything fits on screen.
    final storage = _MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'admin',
          token: 'test-token',
        ),
      );
    final singleNodeController = AppController(
      storage: storage,
      api: _FakeArgoCdApi(
        resourceNodes: const <ArgoResourceNode>[
          ArgoResourceNode(
            group: '',
            version: 'v1',
            kind: 'Service',
            namespace: 'default',
            name: 'test-svc',
            uid: 'uid-single',
            parentUids: <String>[],
            healthStatus: 'Healthy',
            healthMessage: 'Active',
            createdAt: '2026-01-01T00:00:00Z',
          ),
        ],
      ),
      certificateProvider: const CertificateProvider(),
    );
    await singleNodeController.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: ResourceTreeScreen(
          controller: singleNodeController,
          applicationName: 'detail-test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ensure the node is visible by dragging the list up.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Long-press the node to open the detail sheet.
    expect(find.text('test-svc'), findsOneWidget);
    await tester.longPress(find.text('test-svc'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Bottom sheet should show detail fields.
    // The sheet shows resource details - verify the key visible fields.
    expect(find.text('Kind'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('test-svc'), findsWidgets);
  });

  testWidgets('kind count badges show in summary header', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    // Should show kind counts in the summary
    expect(find.text('1 Deployment'), findsOneWidget);
    expect(find.text('1 ReplicaSet'), findsOneWidget);
    expect(find.text('1 Pod'), findsOneWidget);
    expect(find.text('1 Service'), findsOneWidget);
    expect(find.text('1 ConfigMap'), findsOneWidget);
  });

  testWidgets('pod logs open without forcing a container name', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.article_outlined).first);
    await tester.tap(find.byIcon(Icons.article_outlined).first);
    await tester.pumpAndSettle();

    expect(api.lastLogRequest, isNotNull);
    expect(api.lastLogRequest!.podName, 'my-app-abc123-xyz');
    expect(api.lastLogRequest!.containerName, isNull);
    expect(find.text('my-app-abc123-xyz'), findsWidgets);
    expect(find.textContaining('INFO resource tree log line'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// Test fakes
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
    List<ArgoResourceNode> resourceNodes = const <ArgoResourceNode>[],
  }) : _resourceNodes = resourceNodes;

  final List<ArgoResourceNode> _resourceNodes;
  _LogRequest? lastLogRequest;

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async {
    return _resourceNodes;
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    return const <ArgoApplication>[];
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async {
    return const <ArgoProject>[];
  }

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    throw const ArgoCdException('Not found');
  }

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    throw const ArgoCdException('Not found');
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
    return '2026-03-10T10:00:00Z INFO resource tree log line';
  }

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
