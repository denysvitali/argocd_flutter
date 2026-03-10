import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows sign-in flow when there is no saved session', (
    WidgetTester tester,
  ) async {
    final controller = AppController(
      storage: _MemorySessionStorage(),
      api: _FakeArgoCdApi(),
      certificateProvider: const CertificateProvider(),
    );

    await tester.pumpWidget(
      ArgoCdApp(controller: controller, themeController: ThemeController()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect to ArgoCD'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Test server'), findsOneWidget);
  });

  testWidgets('restores a saved session into the authenticated shell', (
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
    final controller = AppController(
      storage: storage,
      api: _FakeArgoCdApi.withSeedData(),
      certificateProvider: const CertificateProvider(),
    );

    await tester.pumpWidget(
      ArgoCdApp(controller: controller, themeController: ThemeController()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('All applications are healthy and synced!'), findsOneWidget);
  });
}

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
          resources: <ArgoResource>[],
          history: <ArgoHistoryEntry>[],
        ),
      ],
      _projects = const <ArgoProject>[
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
      ];

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
