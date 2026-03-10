import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
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
    notifyListeners();

    try {
      await refreshApplications(showSpinner: false);
    } catch (_) {
      _stage = AppStage.unauthenticated;
      _session = null;
      _applications = const <ArgoApplication>[];
      await _storage.clearSession();
      _errorMessage = 'Saved session expired. Sign in again.';
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
      await refreshApplications(showSpinner: false);
    });
  }

  Future<void> refreshApplications({bool showSpinner = true}) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    if (showSpinner) {
      await _runBusyAction(() async {
        _applications = await _api.fetchApplications(session);
      });
      return;
    }

    _applications = await _api.fetchApplications(session);
    notifyListeners();
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

  Future<void> syncApplication(String applicationName) async {
    final session = _session;
    if (session == null) {
      throw const ArgoCdException('Not signed in.');
    }

    await _runBusyAction(() async {
      await _api.syncApplication(session, applicationName);
      _applications = await _api.fetchApplications(session);
    });
  }

  Future<void> signOut() async {
    _session = null;
    _applications = const <ArgoApplication>[];
    _errorMessage = null;
    _stage = AppStage.unauthenticated;
    await _storage.clearSession();
    notifyListeners();
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
    notifyListeners();
    try {
      await action();
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
}
