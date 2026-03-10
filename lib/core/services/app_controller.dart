import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:flutter/foundation.dart';

import 'argocd_api.dart';
import 'certificate_provider.dart';
import 'session_storage.dart';

enum AppStage { booting, unauthenticated, authenticated }

class AppController extends ChangeNotifier {
  AppController({
    required SessionStorage storage,
    required ArgoCdApi api,
    required CertificateProvider certificateProvider,
  }) : _storage = storage,
       _api = api,
       _certificateProvider = certificateProvider;

  final SessionStorage _storage;
  final ArgoCdApi _api;
  final CertificateProvider _certificateProvider;

  AppStage _stage = AppStage.booting;
  AppStage get stage => _stage;

  bool _busy = false;
  bool get busy => _busy;

  bool _loadingApplications = false;
  bool get loadingApplications => _loadingApplications;

  bool _hasLoadedApplications = false;
  bool get hasLoadedApplications => _hasLoadedApplications;

  bool _loadingProjects = false;
  bool get loadingProjects => _loadingProjects;

  bool _hasLoadedProjects = false;
  bool get hasLoadedProjects => _hasLoadedProjects;

  DateTime? _lastRefreshedAt;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AppSession? _session;
  AppSession? get session => _session;

  String _lastServerUrl = '';
  String get lastServerUrl => _lastServerUrl;

  CertificateStatus? _certificateStatus;
  CertificateStatus? get certificateStatus => _certificateStatus;

  List<ArgoApplication> _applications = const <ArgoApplication>[];
  List<ArgoApplication> get applications => _applications;

  List<ArgoProject> _projects = const <ArgoProject>[];
  List<ArgoProject> get projects => _projects;

  Future<void>? _bootstrapFuture;
  Future<void> initialize() {
    return _bootstrapFuture ??= _initializeImpl();
  }

  Future<void> _initializeImpl() async {
    _certificateStatus = await _certificateProvider.getStatus();
    _lastServerUrl = await _storage.loadLastServerUrl() ?? '';

    final storedSession = await _storage.loadSession();
    if (storedSession == null) {
      _stage = AppStage.unauthenticated;
      notifyListeners();
      return;
    }

    _session = storedSession;
    _lastServerUrl = storedSession.serverUrl;
    _stage = AppStage.authenticated;
    _loadingApplications = true;
    notifyListeners();

    try {
      await Future.wait<void>(<Future<void>>[
        refreshApplications(showSpinner: false),
        refreshProjects(showSpinner: false),
      ]);
    } catch (_) {
      _stage = AppStage.unauthenticated;
      _session = null;
      _applications = const <ArgoApplication>[];
      _projects = const <ArgoProject>[];
      await _storage.clearSession();
      _errorMessage = 'Saved session expired. Sign in again.';
      _loadingApplications = false;
      _loadingProjects = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    await _runBusyAction(() async {
      final normalizedServerUrl = serverUrl.trim();
      _errorMessage = null;
      await _storage.saveLastServerUrl(normalizedServerUrl);
      _lastServerUrl = normalizedServerUrl;

      await _api.verifyServer(normalizedServerUrl);
      final nextSession = await _api.signIn(
        serverUrl: normalizedServerUrl,
        username: username.trim(),
        password: password,
      );

      _session = nextSession;
      _stage = AppStage.authenticated;
      await _storage.saveSession(nextSession);
      await Future.wait<void>(<Future<void>>[
        refreshApplications(showSpinner: false),
        refreshProjects(showSpinner: false),
      ]);
    });
  }

  Future<void> refreshApplications({bool showSpinner = true}) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    if (showSpinner) {
      await _runBusyAction(() async {
        await _fetchApplications(session);
      });
      return;
    }

    await _fetchApplications(session);
  }

  Future<void> refreshProjects({bool showSpinner = true}) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    if (showSpinner) {
      await _runBusyAction(() async {
        await _fetchProjects(session);
      });
      return;
    }

    await _fetchProjects(session);
  }

  Future<ArgoApplication> loadApplication(
    String applicationName, {
    bool refresh = false,
  }) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    return _api.fetchApplication(session, applicationName, refresh: refresh);
  }

  Future<ArgoProject> loadProject(String projectName) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    return _api.fetchProject(session, projectName);
  }

  Future<List<ArgoResourceNode>> loadResourceTree(
    String applicationName,
  ) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    return _api.fetchResourceTree(session, applicationName);
  }

  Future<void> syncApplication(String applicationName) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    await _runBusyAction(() async {
      await _api.syncApplication(session, applicationName);
      await _fetchApplications(session);
    });
  }

  Future<void> rollbackApplication(
    String applicationName,
    int historyId,
  ) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    await _runBusyAction(() async {
      await _api.rollbackApplication(session, applicationName, historyId);
      await _fetchApplications(session);
    });
  }

  Future<void> deleteApplication(
    String applicationName, {
    bool cascade = true,
  }) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    await _runBusyAction(() async {
      await _api.deleteApplication(session, applicationName, cascade: cascade);
      await _fetchApplications(session);
    });
  }

  Future<String> fetchResourceLogs({
    required String applicationName,
    required String namespace,
    required String podName,
    required String containerName,
    int tailLines = 500,
  }) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    return _api.fetchResourceLogs(
      session,
      applicationName: applicationName,
      namespace: namespace,
      podName: podName,
      containerName: containerName,
      tailLines: tailLines,
    );
  }

  Future<String> fetchResourceManifest({
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
  }) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    return _api.fetchResourceManifest(
      session,
      applicationName: applicationName,
      namespace: namespace,
      resourceName: resourceName,
      kind: kind,
      group: group,
      version: version,
    );
  }

  Future<void> signOut() async {
    _session = null;
    _applications = const <ArgoApplication>[];
    _projects = const <ArgoProject>[];
    _errorMessage = null;
    _hasLoadedApplications = false;
    _loadingApplications = false;
    _hasLoadedProjects = false;
    _loadingProjects = false;
    _lastRefreshedAt = null;
    _stage = AppStage.unauthenticated;
    await _storage.clearSession();
    notifyListeners();
  }

  Future<void> updateServerUrl(String serverUrl) async {
    final normalizedServerUrl = serverUrl.trim();
    await _storage.saveLastServerUrl(normalizedServerUrl);
    _lastServerUrl = normalizedServerUrl;
    if (_session != null) {
      await signOut();
      return;
    }
    notifyListeners();
  }

  Future<void> testConnection([String? serverUrl]) async {
    final targetUrl = serverUrl?.trim().isNotEmpty == true
        ? serverUrl!.trim()
        : (_session?.serverUrl ?? _lastServerUrl);

    if (targetUrl.isEmpty) {
      throw const ArgoCdException('Enter a server URL first.');
    }

    await _runBusyAction(() async {
      await _api.verifyServer(targetUrl);
    });
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _runBusyAction(Future<void> Function() action) async {
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      _errorMessage = null;
    } on ArgoCdException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } catch (_) {
      _errorMessage = 'Something went wrong while contacting ArgoCD.';
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _fetchApplications(AppSession session) async {
    _loadingApplications = true;
    notifyListeners();

    try {
      _applications = await _api.fetchApplications(session);
      _hasLoadedApplications = true;
      _lastRefreshedAt = DateTime.now();
      _errorMessage = null;
    } finally {
      _loadingApplications = false;
      notifyListeners();
    }
  }

  Future<void> _fetchProjects(AppSession session) async {
    _loadingProjects = true;
    notifyListeners();

    try {
      _projects = await _api.fetchProjects(session);
      _hasLoadedProjects = true;
      _lastRefreshedAt = DateTime.now();
      _errorMessage = null;
    } finally {
      _loadingProjects = false;
      notifyListeners();
    }
  }
}
