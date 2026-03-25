import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';

// ---------------------------------------------------------------------------
// Shared test session
// ---------------------------------------------------------------------------

const testSession = AppSession(
  serverUrl: 'https://argocd.example.com',
  username: 'admin',
  token: 'test-token',
);

// ---------------------------------------------------------------------------
// Seed data builders
// ---------------------------------------------------------------------------

const seedApp = ArgoApplication(
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
  operationMessage: null,
  lastSyncedAt: '2026-03-10T10:00:00Z',
  resources: <ArgoResource>[],
  history: <ArgoHistoryEntry>[],
);

const seedProject = ArgoProject(
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
);

const degradedApp = ArgoApplication(
  name: 'orders-api',
  project: 'platform',
  namespace: 'orders',
  cluster: 'https://kubernetes.default.svc',
  repoUrl: 'https://github.com/example/platform',
  path: 'apps/orders-api',
  targetRevision: 'main',
  syncStatus: 'OutOfSync',
  healthStatus: 'Degraded',
  operationPhase: 'Failed',
  operationMessage: 'one or more objects failed to apply',
  lastSyncedAt: '2026-03-10T09:00:00Z',
  resources: <ArgoResource>[],
  history: <ArgoHistoryEntry>[],
);

// ---------------------------------------------------------------------------
// MemorySessionStorage
// ---------------------------------------------------------------------------

class MemorySessionStorage implements SessionStorage {
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

// ---------------------------------------------------------------------------
// FakeArgoCdApi
// ---------------------------------------------------------------------------

class FakeArgoCdApi implements ArgoCdApi {
  FakeArgoCdApi({
    List<ArgoApplication> applications = const <ArgoApplication>[],
    List<ArgoProject> projects = const <ArgoProject>[],
    this.signInError,
    this.fetchApplicationsError,
    this.fetchProjectsError,
  }) : applications = List<ArgoApplication>.of(applications),
       projects = List<ArgoProject>.of(projects);

  FakeArgoCdApi.withSeedData()
    : applications = <ArgoApplication>[seedApp],
      projects = <ArgoProject>[seedProject],
      signInError = null,
      fetchApplicationsError = null,
      fetchProjectsError = null;

  FakeArgoCdApi.empty()
    : applications = <ArgoApplication>[],
      projects = <ArgoProject>[],
      signInError = null,
      fetchApplicationsError = null,
      fetchProjectsError = null;

  List<ArgoApplication> applications;
  List<ArgoProject> projects;

  final ArgoCdException? signInError;
  final ArgoCdException? fetchApplicationsError;
  final ArgoCdException? fetchProjectsError;

  final List<String> syncedApplications = <String>[];
  final List<String> deletedApplications = <String>[];

  void Function(String name)? onDelete;

  @override
  Future<void> verifyServer(String serverUrl) async {}

  @override
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    if (signInError != null) {
      throw signInError!;
    }
    return AppSession(
      serverUrl: serverUrl,
      username: username,
      token: 'fake-token',
    );
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    if (fetchApplicationsError != null) {
      throw fetchApplicationsError!;
    }
    return applications;
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async {
    if (fetchProjectsError != null) {
      throw fetchProjectsError!;
    }
    return projects;
  }

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    return applications.firstWhere(
      (ArgoApplication app) => app.name == applicationName,
    );
  }

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    return projects.firstWhere(
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
    String? containerName,
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
  Future<List<ManagedResource>> fetchManagedResources(
    AppSession session,
    String applicationName,
  ) async {
    return const <ManagedResource>[];
  }

  @override
  Future<void> syncApplication(
    AppSession session,
    String applicationName,
  ) async {
    syncedApplications.add(applicationName);
  }

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
  }) async {
    deletedApplications.add(applicationName);
    onDelete?.call(applicationName);
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
}

// ---------------------------------------------------------------------------
// Helper to create an authenticated AppController
// ---------------------------------------------------------------------------

AppController createTestController({
  MemorySessionStorage? storage,
  FakeArgoCdApi? api,
}) {
  return AppController(
    storage: storage ?? MemorySessionStorage(),
    api: api ?? FakeArgoCdApi(),
    certificateProvider: const CertificateProvider(),
  );
}

Future<AppController> createAuthenticatedController({
  MemorySessionStorage? storage,
  FakeArgoCdApi? api,
}) async {
  final effectiveStorage =
      storage ?? (MemorySessionStorage()..seedSession(testSession));
  final effectiveApi = api ?? FakeArgoCdApi.withSeedData();
  final controller = AppController(
    storage: effectiveStorage,
    api: effectiveApi,
    certificateProvider: const CertificateProvider(),
  );
  await controller.initialize();
  return controller;
}

ThemeController createTestThemeController() => ThemeController();
