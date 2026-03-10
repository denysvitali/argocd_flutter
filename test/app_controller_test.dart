import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testSession = AppSession(
    serverUrl: 'https://argocd.example.com',
    username: 'admin',
    token: 'test-token',
  );

  const seedApp = ArgoApplication(
    name: 'my-app',
    project: 'default',
    namespace: 'default',
    cluster: 'https://kubernetes.default.svc',
    repoUrl: 'https://github.com/example/repo',
    path: 'apps/my-app',
    targetRevision: 'main',
    syncStatus: 'Synced',
    healthStatus: 'Healthy',
    operationPhase: 'Succeeded',
    lastSyncedAt: '2026-03-10T10:00:00Z',
    resources: <ArgoResource>[],
    history: <ArgoHistoryEntry>[],
  );

  const seedProject = ArgoProject(
    name: 'default',
    description: 'Default project',
    sourceRepos: <String>['*'],
    destinations: <ArgoProjectDestination>[
      ArgoProjectDestination(
        server: 'https://kubernetes.default.svc',
        namespace: 'default',
        name: 'in-cluster',
      ),
    ],
    clusterResourceWhitelist: <ArgoProjectClusterResource>[],
  );

  AppController createController({
    _MemorySessionStorage? storage,
    _ConfigurableFakeApi? api,
  }) {
    return AppController(
      storage: storage ?? _MemorySessionStorage(),
      api: api ?? _ConfigurableFakeApi(),
      certificateProvider: const CertificateProvider(),
    );
  }

  test('initial state is AppStage.booting', () {
    final controller = createController();
    expect(controller.stage, AppStage.booting);
    expect(controller.busy, isFalse);
    expect(controller.applications, isEmpty);
    expect(controller.projects, isEmpty);
    expect(controller.session, isNull);
    expect(controller.errorMessage, isNull);
  });

  test('initialize() with no saved session transitions to unauthenticated',
      () async {
    final controller = createController();

    await controller.initialize();

    expect(controller.stage, AppStage.unauthenticated);
    expect(controller.session, isNull);
    expect(controller.applications, isEmpty);
    expect(controller.projects, isEmpty);
  });

  test(
      'initialize() with saved session transitions to authenticated '
      'and loads data', () async {
    final storage = _MemorySessionStorage()..seedSession(testSession);
    final api = _ConfigurableFakeApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final controller = createController(storage: storage, api: api);

    await controller.initialize();

    expect(controller.stage, AppStage.authenticated);
    expect(controller.session, testSession);
    expect(controller.applications, hasLength(1));
    expect(controller.applications.first.name, 'my-app');
    expect(controller.projects, hasLength(1));
    expect(controller.projects.first.name, 'default');
    expect(controller.hasLoadedApplications, isTrue);
    expect(controller.hasLoadedProjects, isTrue);
  });

  test('signIn() with valid credentials transitions to authenticated',
      () async {
    final api = _ConfigurableFakeApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = _MemorySessionStorage();
    final controller = createController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.stage, AppStage.unauthenticated);

    // signIn internally calls _runBusyAction which rethrows; but on success
    // there is no exception.
    await controller.signIn(
      serverUrl: 'https://argocd.example.com',
      username: 'admin',
      password: 'password',
    );

    expect(controller.stage, AppStage.authenticated);
    expect(controller.session, isNotNull);
    expect(controller.session!.token, 'fake-token');
    expect(controller.applications, hasLength(1));
    expect(controller.projects, hasLength(1));
    expect(controller.errorMessage, isNull);
    expect(controller.busy, isFalse);

    // Verify session was persisted
    final savedSession = await storage.loadSession();
    expect(savedSession, isNotNull);
    expect(savedSession!.token, 'fake-token');
  });

  test('signIn() with invalid credentials sets error message', () async {
    final api = _ConfigurableFakeApi(
      signInError: const ArgoCdException('Invalid username or password'),
    );
    final controller = createController(api: api);
    await controller.initialize();

    expect(
      () => controller.signIn(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        password: 'wrong',
      ),
      throwsA(isA<ArgoCdException>()),
    );

    // Wait for microtasks to settle
    await Future<void>.delayed(Duration.zero);

    expect(controller.stage, AppStage.unauthenticated);
    expect(controller.errorMessage, 'Invalid username or password');
    expect(controller.busy, isFalse);
    expect(controller.session, isNull);
  });

  test('signOut() clears session and transitions to unauthenticated',
      () async {
    final storage = _MemorySessionStorage()..seedSession(testSession);
    final api = _ConfigurableFakeApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final controller = createController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.stage, AppStage.authenticated);

    await controller.signOut();

    expect(controller.stage, AppStage.unauthenticated);
    expect(controller.session, isNull);
    expect(controller.applications, isEmpty);
    expect(controller.projects, isEmpty);
    expect(controller.hasLoadedApplications, isFalse);
    expect(controller.hasLoadedProjects, isFalse);
    expect(controller.errorMessage, isNull);

    // Verify session was cleared from storage
    final savedSession = await storage.loadSession();
    expect(savedSession, isNull);
  });

  test('refreshApplications() updates the application list', () async {
    final api = _ConfigurableFakeApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = _MemorySessionStorage()..seedSession(testSession);
    final controller = createController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.applications, hasLength(1));

    // Update the API to return a second application
    const secondApp = ArgoApplication(
      name: 'other-app',
      project: 'default',
      namespace: 'other',
      cluster: 'https://kubernetes.default.svc',
      repoUrl: 'https://github.com/example/other',
      path: 'apps/other-app',
      targetRevision: 'main',
      syncStatus: 'OutOfSync',
      healthStatus: 'Degraded',
      operationPhase: 'Failed',
      lastSyncedAt: '2026-03-10T11:00:00Z',
      resources: <ArgoResource>[],
      history: <ArgoHistoryEntry>[],
    );
    api.applications = <ArgoApplication>[seedApp, secondApp];

    await controller.refreshApplications();

    expect(controller.applications, hasLength(2));
    expect(controller.applications[1].name, 'other-app');
    expect(controller.busy, isFalse);
    expect(controller.loadingApplications, isFalse);
    expect(controller.hasLoadedApplications, isTrue);
  });

  test('refreshProjects() updates the project list', () async {
    final api = _ConfigurableFakeApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = _MemorySessionStorage()..seedSession(testSession);
    final controller = createController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.projects, hasLength(1));

    const secondProject = ArgoProject(
      name: 'staging',
      description: 'Staging project',
      sourceRepos: <String>['*'],
      destinations: <ArgoProjectDestination>[],
      clusterResourceWhitelist: <ArgoProjectClusterResource>[],
    );
    api.projects = <ArgoProject>[seedProject, secondProject];

    await controller.refreshProjects();

    expect(controller.projects, hasLength(2));
    expect(controller.projects[1].name, 'staging');
    expect(controller.busy, isFalse);
    expect(controller.loadingProjects, isFalse);
    expect(controller.hasLoadedProjects, isTrue);
  });

  test('syncApplication() calls the API correctly', () async {
    final api = _ConfigurableFakeApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = _MemorySessionStorage()..seedSession(testSession);
    final controller = createController(storage: storage, api: api);
    await controller.initialize();

    await controller.syncApplication('my-app');

    expect(api.syncedApplications, contains('my-app'));
    expect(controller.busy, isFalse);
    // Applications should have been refreshed after sync
    expect(controller.hasLoadedApplications, isTrue);
  });

  test('deleteApplication() removes from list on success', () async {
    final api = _ConfigurableFakeApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = _MemorySessionStorage()..seedSession(testSession);
    final controller = createController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.applications, hasLength(1));

    // Configure the fake to remove the app on delete and return empty list
    api.onDelete = (String name) {
      api.applications = <ArgoApplication>[];
    };

    await controller.deleteApplication('my-app');

    expect(api.deletedApplications, contains('my-app'));
    expect(controller.applications, isEmpty);
    expect(controller.busy, isFalse);
  });

  test(
      'initialize() with expired saved session falls back to unauthenticated',
      () async {
    final storage = _MemorySessionStorage()..seedSession(testSession);
    final api = _ConfigurableFakeApi(
      fetchApplicationsError: const ArgoCdException('Unauthorized'),
    );
    final controller = createController(storage: storage, api: api);

    await controller.initialize();

    expect(controller.stage, AppStage.unauthenticated);
    expect(controller.session, isNull);
    expect(controller.errorMessage, 'Saved session expired. Sign in again.');
  });
}

// ---------------------------------------------------------------------------
// Test doubles
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

class _ConfigurableFakeApi implements ArgoCdApi {
  _ConfigurableFakeApi({
    List<ArgoApplication> applications = const <ArgoApplication>[],
    List<ArgoProject> projects = const <ArgoProject>[],
    this.signInError,
    this.fetchApplicationsError,
  }) : applications = List<ArgoApplication>.of(applications),
       projects = List<ArgoProject>.of(projects);

  List<ArgoApplication> applications;
  List<ArgoProject> projects;

  final ArgoCdException? signInError;
  final ArgoCdException? fetchApplicationsError;

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
}
