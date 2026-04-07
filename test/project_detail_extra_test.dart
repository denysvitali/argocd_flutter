import 'dart:async';

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/features/projects/project_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProjectDetailScreen extra', () {
    late _MemorySessionStorage storage;

    setUp(() {
      storage = _MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'ops',
            token: 'token',
          ),
        );
    });

    testWidgets('shows loading indicator while fetching project', (
      WidgetTester tester,
    ) async {
      final api = _SlowArgoCdApi();
      final controller = AppController(
        storage: storage,
        api: api,
        certificateProvider: const CertificateProvider(),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );

      // Do not call pumpAndSettle – fetch is still in progress.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading project details...'), findsOneWidget);

      // Complete the pending future so the test can cleanly dispose.
      api.completeAll();
      await tester.pumpAndSettle();
    });

    testWidgets('shows error state when project fetch fails', (
      WidgetTester tester,
    ) async {
      final controller = AppController(
        storage: storage,
        api: _ErrorArgoCdApi('Network error'),
        certificateProvider: const CertificateProvider(),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ErrorRetryWidget shows the error text and a Retry button.
      expect(find.textContaining('Network error'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('refresh button reloads project after error', (
      WidgetTester tester,
    ) async {
      var callCount = 0;
      final api = _CountingArgoCdApi(
        onFetch: () {
          callCount++;
          if (callCount == 1) {
            throw const ArgoCdException('Temporary failure');
          }
          return const ArgoProject(
            name: 'platform',
            description: 'Reloaded',
            sourceRepos: <String>[],
            destinations: <ArgoProjectDestination>[],
            clusterResourceWhitelist: <ArgoProjectClusterResource>[],
          );
        },
      );

      final controller = AppController(
        storage: storage,
        api: api,
        certificateProvider: const CertificateProvider(),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First load failed – error is shown.
      expect(find.text('Retry'), findsOneWidget);

      // Tap the Retry button; second fetch succeeds.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Successful data is now visible.
      expect(find.text('platform'), findsWidgets);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('refresh button in app bar reloads project', (
      WidgetTester tester,
    ) async {
      var callCount = 0;
      final api = _CountingArgoCdApi(
        onFetch: () {
          callCount++;
          return ArgoProject(
            name: 'platform',
            description: 'Version $callCount',
            sourceRepos: <String>[],
            destinations: <ArgoProjectDestination>[],
            clusterResourceWhitelist: <ArgoProjectClusterResource>[],
          );
        },
      );

      final controller = AppController(
        storage: storage,
        api: api,
        certificateProvider: const CertificateProvider(),
      );
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ProjectDetailScreen(
            controller: controller,
            projectName: 'platform',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(callCount, equals(1));

      // Tap the refresh icon in the AppBar.
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();

      expect(callCount, equals(2));
      // Still showing project content after refresh.
      expect(find.text('platform'), findsWidgets);
    });
  });
}

// ---------------------------------------------------------------------------
// Test fakes
// ---------------------------------------------------------------------------

class _MemorySessionStorage implements SessionStorage {
  AppSession? _session;
  String? _serverUrl;
  String? _lastUsername;

  @override
  Future<void> clearSession() async {
    _session = null;
  }

  @override
  Future<String?> loadLastServerUrl() async => _serverUrl;

  @override
  Future<String?> loadLastUsername() async => _lastUsername;

  @override
  Future<AppSession?> loadSession() async => _session;

  @override
  Future<void> saveLastServerUrl(String serverUrl) async {
    _serverUrl = serverUrl;
  }

  @override
  Future<void> saveLastUsername(String username) async {
    _lastUsername = username;
  }

  @override
  Future<void> saveSession(AppSession session) async {
    _session = session;
    _serverUrl = session.serverUrl;
    _lastUsername = session.username;
  }

  void seedSession(AppSession session) {
    _session = session;
    _serverUrl = session.serverUrl;
    _lastUsername = session.username;
  }
}

/// An API that never resolves fetchProject, simulating a slow network.
class _SlowArgoCdApi implements ArgoCdApi {
  final List<Completer<ArgoProject>> _completers = <Completer<ArgoProject>>[];

  void completeAll() {
    for (final c in _completers) {
      if (!c.isCompleted) {
        c.complete(
          const ArgoProject(
            name: 'platform',
            description: '',
            sourceRepos: <String>[],
            destinations: <ArgoProjectDestination>[],
            clusterResourceWhitelist: <ArgoProjectClusterResource>[],
          ),
        );
      }
    }
  }

  @override
  Future<ArgoProject> fetchProject(AppSession session, String projectName) {
    final c = Completer<ArgoProject>();
    _completers.add(c);
    return c.future;
  }

  @override
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async =>
      AppSession(serverUrl: serverUrl, username: username, token: 'token');

  @override
  Future<void> verifyServer(String serverUrl) async {}

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async =>
      const <ArgoProject>[];

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async =>
      const <ArgoApplication>[];

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async => throw UnimplementedError();

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async => const <ArgoResourceNode>[];

  @override
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 500,
  }) async => '';

  @override
  Future<String> fetchResourceManifest(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
  }) async => '';

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
}

/// An API that always throws on fetchProject.
class _ErrorArgoCdApi implements ArgoCdApi {
  const _ErrorArgoCdApi(this._message);

  final String _message;

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async => throw ArgoCdException(_message);

  @override
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async =>
      AppSession(serverUrl: serverUrl, username: username, token: 'token');

  @override
  Future<void> verifyServer(String serverUrl) async {}

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async =>
      const <ArgoProject>[];

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async =>
      const <ArgoApplication>[];

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async => throw UnimplementedError();

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async => const <ArgoResourceNode>[];

  @override
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 500,
  }) async => '';

  @override
  Future<String> fetchResourceManifest(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
  }) async => '';

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
}

/// An API whose fetchProject behaviour is controlled by a callback.
class _CountingArgoCdApi implements ArgoCdApi {
  _CountingArgoCdApi({required ArgoProject Function() onFetch})
    : _onFetch = onFetch;

  final ArgoProject Function() _onFetch;

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async => _onFetch();

  @override
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async =>
      AppSession(serverUrl: serverUrl, username: username, token: 'token');

  @override
  Future<void> verifyServer(String serverUrl) async {}

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async =>
      const <ArgoProject>[];

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async =>
      const <ArgoApplication>[];

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async => throw UnimplementedError();

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async => const <ArgoResourceNode>[];

  @override
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 500,
  }) async => '';

  @override
  Future<String> fetchResourceManifest(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
  }) async => '';

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
}
