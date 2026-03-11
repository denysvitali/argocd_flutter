import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/features/projects/project_detail_screen.dart';
import 'package:argocd_flutter/features/projects/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectsScreen', () {
    late AppController controller;

    setUp(() async {
      final storage = _MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'ops',
            token: 'token',
          ),
        );
      controller = AppController(
        storage: storage,
        api: _FakeArgoCdApi(projects: _sampleProjects),
        certificateProvider: const CertificateProvider(),
      );
      await controller.initialize();
    });

    testWidgets('renders project list with data', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(controller: controller, onOpenProject: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text('Projects'), findsWidgets);
      // Project names appear in cards
      expect(find.text('platform'), findsWidgets);
      expect(find.text('data-team'), findsWidgets);
      // Descriptions
      expect(find.text('Platform services'), findsOneWidget);
      expect(find.text('Data engineering pipelines'), findsOneWidget);
    });

    testWidgets('shows overview strip with metrics', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(controller: controller, onOpenProject: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Overview strip is present
      expect(find.text('Project boundaries'), findsOneWidget);
      // Metric labels
      expect(find.text('Source repos'), findsOneWidget);
    });

    testWidgets('search filters projects by name', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(controller: controller, onOpenProject: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Both projects visible initially
      expect(find.text('platform'), findsWidgets);
      expect(find.text('data-team'), findsWidgets);

      // Type in search
      await tester.enterText(find.byType(TextField), 'plat');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      // Only platform visible (rendered as RichText with highlight)
      expect(_findRichTextContaining('platform'), findsWidgets);
      expect(_findRichTextContaining('data-team'), findsNothing);

      // Shows filter count
      expect(find.text('1 of 2 projects'), findsOneWidget);
    });

    testWidgets('search filters projects by description', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(controller: controller, onOpenProject: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'pipelines');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(_findRichTextContaining('data-team'), findsWidgets);
      expect(_findRichTextContaining('Platform services'), findsNothing);
    });

    testWidgets('empty state shown when no projects match filter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(controller: controller, onOpenProject: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      expect(find.text('No projects match this filter'), findsOneWidget);
    });

    testWidgets('empty state shown when no projects loaded', (
      WidgetTester tester,
    ) async {
      final emptyStorage = _MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'ops',
            token: 'token',
          ),
        );
      final emptyController = AppController(
        storage: emptyStorage,
        api: _FakeArgoCdApi(),
        certificateProvider: const CertificateProvider(),
      );
      await emptyController.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(
            controller: emptyController,
            onOpenProject: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No projects loaded'), findsOneWidget);
    });

    testWidgets('sort popup menu is available', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(controller: controller, onOpenProject: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Find sort button
      expect(find.byIcon(Icons.sort_rounded), findsOneWidget);

      // Tap sort button to open menu
      await tester.tap(find.byIcon(Icons.sort_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsWidgets);
      expect(find.text('Destinations'), findsWidgets);
      expect(find.text('Repos'), findsWidgets);
    });

    testWidgets('project card shows count badges', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(controller: controller, onOpenProject: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Check for count badge labels
      expect(find.text('repos'), findsWidgets);
      expect(find.text('destinations'), findsWidgets);
    });

    testWidgets('tapping project card invokes callback', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? openedProject;

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectsScreen(
            controller: controller,
            onOpenProject: (name) {
              openedProject = name;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('platform').first);
      await tester.pumpAndSettle();

      expect(openedProject, equals('platform'));
    });
  });

  group('ProjectDetailScreen', () {
    late AppController controller;

    setUp(() async {
      final storage = _MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'ops',
            token: 'token',
          ),
        );
      controller = AppController(
        storage: storage,
        api: _FakeArgoCdApi(projects: _sampleProjects),
        certificateProvider: const CertificateProvider(),
      );
      await controller.initialize();
    });

    testWidgets('renders project detail with header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('platform'), findsWidgets);
      expect(find.text('Platform services'), findsWidgets);
    });

    testWidgets('shows tab bar with all tabs', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Sources (1)'), findsOneWidget);
      expect(find.text('Destinations (1)'), findsOneWidget);
      expect(find.text('Permissions (0)'), findsOneWidget);
    });

    testWidgets('overview tab shows project details section', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overview tab is selected by default
      expect(find.text('Project Details'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('sources tab shows repositories', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sources tab
      await tester.tap(find.text('Sources (1)'));
      await tester.pumpAndSettle();

      expect(find.text('https://github.com/example/platform'), findsOneWidget);
    });

    testWidgets('destinations tab shows server and namespace', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Destinations tab
      await tester.tap(find.text('Destinations (1)'));
      await tester.pumpAndSettle();

      expect(find.text('https://kubernetes.default.svc'), findsOneWidget);
      expect(find.text('payments'), findsOneWidget);
      expect(find.text('in-cluster'), findsOneWidget);
    });

    testWidgets('permissions tab shows empty state when no resources', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Permissions tab
      await tester.tap(find.text('Permissions (0)'));
      await tester.pumpAndSettle();

      expect(find.text('No cluster resources'), findsOneWidget);
    });

    testWidgets('permissions tab shows resources when present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'data-team',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Permissions tab
      await tester.tap(find.text('Permissions (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Namespace'), findsOneWidget);
      expect(find.text('ClusterRole'), findsOneWidget);
    });

    testWidgets('sources tab shows empty state when no repos', (
      WidgetTester tester,
    ) async {
      final storage = _MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'ops',
            token: 'token',
          ),
        );
      final emptyController = AppController(
        storage: storage,
        api: _FakeArgoCdApi(
          projects: const <ArgoProject>[
            ArgoProject(
              name: 'empty-project',
              description: '',
              sourceRepos: <String>[],
              destinations: <ArgoProjectDestination>[],
              clusterResourceWhitelist: <ArgoProjectClusterResource>[],
            ),
          ],
        ),
        certificateProvider: const CertificateProvider(),
      );
      await emptyController.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: ProjectDetailScreen(
            controller: emptyController,
            projectName: 'empty-project',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sources tab
      await tester.tap(find.text('Sources (0)'));
      await tester.pumpAndSettle();

      expect(find.text('No source repositories'), findsOneWidget);
    });
  });
}

Finder _findRichTextContaining(String text) {
  return find.byWidgetPredicate((Widget widget) {
    if (widget is RichText) {
      return widget.text.toPlainText().contains(text);
    }
    return false;
  });
}

const List<ArgoProject> _sampleProjects = <ArgoProject>[
  ArgoProject(
    name: 'platform',
    description: 'Platform services',
    sourceRepos: <String>['https://github.com/example/platform'],
    destinations: <ArgoProjectDestination>[
      ArgoProjectDestination(
        server: 'https://kubernetes.default.svc',
        namespace: 'payments',
        name: 'in-cluster',
      ),
    ],
    clusterResourceWhitelist: <ArgoProjectClusterResource>[],
  ),
  ArgoProject(
    name: 'data-team',
    description: 'Data engineering pipelines',
    sourceRepos: <String>['https://github.com/example/data'],
    destinations: <ArgoProjectDestination>[
      ArgoProjectDestination(
        server: 'https://k8s.prod.example.com',
        namespace: 'data',
        name: 'prod',
      ),
      ArgoProjectDestination(
        server: 'https://k8s.staging.example.com',
        namespace: 'data-staging',
        name: 'staging',
      ),
    ],
    clusterResourceWhitelist: <ArgoProjectClusterResource>[
      ArgoProjectClusterResource(group: '', kind: 'Namespace'),
      ArgoProjectClusterResource(
        group: 'rbac.authorization.k8s.io',
        kind: 'ClusterRole',
      ),
    ],
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
  Future<void> verifyServer(String serverUrl) async {}
}
