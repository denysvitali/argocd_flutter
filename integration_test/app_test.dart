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
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  testWidgets('full app flow: sign in, navigate tabs, sign out', (
    WidgetTester tester,
  ) async {
    final api = _IntegrationFakeApi();
    final storage = _IntegrationMemoryStorage();
    final controller = AppController(
      storage: storage,
      api: api,
      certificateProvider: const CertificateProvider(),
    );
    final themeController = ThemeController();

    // 1. App starts and shows sign-in screen
    await tester.pumpWidget(
      ArgoCdApp(controller: controller, themeController: themeController),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect to ArgoCD'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // 2. Fill in credentials and sign in
    final serverField = find.byType(TextFormField).first;
    await tester.enterText(serverField, 'https://argocd.example.com');

    // Find username and password fields
    final textFields = find.byType(TextFormField);
    await tester.enterText(textFields.at(1), 'admin');
    await tester.enterText(textFields.at(2), 'password');

    // Tap sign in
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    // 3. Dashboard loads with data
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Summary'), findsOneWidget);

    // 4. Navigate to Applications tab
    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Applications'), findsWidgets);
    expect(find.text('Control plane overview'), findsOneWidget);

    // 5. Navigate to Projects tab
    await tester.tap(find.byIcon(Icons.folder_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsWidgets);
    expect(find.text('Project boundaries'), findsOneWidget);

    // 6. Navigate to Settings tab
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);

    // 7. Sign out and return to sign-in
    // Scroll down to find Sign out button
    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // Should be back at sign-in screen
    expect(find.text('Connect to ArgoCD'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// Integration test fakes (self-contained, no imports from test/)
// ---------------------------------------------------------------------------

class _IntegrationMemoryStorage implements SessionStorage {
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
}

class _IntegrationFakeApi implements ArgoCdApi {
  static const _seedApplications = <ArgoApplication>[
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
  ];

  static const _seedProjects = <ArgoProject>[
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

  @override
  Future<void> verifyServer(String serverUrl) async {}

  @override
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    return AppSession(
      serverUrl: serverUrl,
      username: username,
      token: 'integration-test-token',
    );
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    return _seedApplications;
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async {
    return _seedProjects;
  }

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    return _seedApplications.firstWhere(
      (ArgoApplication app) => app.name == applicationName,
    );
  }

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    return _seedProjects.firstWhere(
      (ArgoProject project) => project.name == projectName,
    );
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
  Future<void> syncApplication(
    AppSession session,
    String applicationName,
  ) async {}

  @override
  Future<void> rollbackApplication(
    AppSession session,
    String applicationName,
    int historyId,
  ) async {}

  @override
  Future<void> deleteApplication(
    AppSession session,
    String applicationName, {
    bool cascade = true,
  }) async {}
}
