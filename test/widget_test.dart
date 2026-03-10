import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
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

    await tester.pumpWidget(ArgoCdApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Connect to ArgoCD'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
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
}

class _FakeArgoCdApi implements ArgoCdApi {
  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    return const <ArgoApplication>[];
  }

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
