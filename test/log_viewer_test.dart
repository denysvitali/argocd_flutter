import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/features/applications/log_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _testSession = AppSession(
  serverUrl: 'https://argocd.example.com',
  username: 'ops',
  token: 'token',
);

const _sampleLogs =
    '2026-03-10T10:00:00Z INFO started\n'
    '2026-03-10T10:00:02Z WARN cache miss\n'
    '2026-03-10T10:00:05Z INFO synced';

void main() {
  AppController _buildController({
    String logs = _sampleLogs,
    bool shouldFail = false,
  }) {
    final storage = _MemorySessionStorage()..seedSession(_testSession);
    return AppController(
      storage: storage,
      api: _FakeLogApi(logs: logs, shouldFail: shouldFail),
      certificateProvider: const CertificateProvider(),
    );
  }

  Widget _buildWidget({
    required AppController controller,
    String podName = 'payments-api-7f9d9c',
    String? containerName,
  }) {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: LogViewerScreen(
        controller: controller,
        applicationName: 'payments-api',
        namespace: 'payments',
        podName: podName,
        containerName: containerName,
      ),
    );
  }

  group('LogViewerScreen', () {
    testWidgets('shows loading indicator while fetching logs', (
      WidgetTester tester,
    ) async {
      final controller = _buildController();
      await controller.initialize();

      await tester.pumpWidget(_buildWidget(controller: controller));
      // Do not pumpAndSettle — check mid-flight loading state.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders log content after loading', (
      WidgetTester tester,
    ) async {
      final controller = _buildController();
      await controller.initialize();

      await tester.pumpWidget(_buildWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.textContaining('INFO started'), findsOneWidget);
      expect(find.textContaining('WARN cache miss'), findsOneWidget);
      expect(find.textContaining('INFO synced'), findsOneWidget);
    });

    testWidgets('shows error state with retry button on failure', (
      WidgetTester tester,
    ) async {
      final controller = _buildController(shouldFail: true);
      await controller.initialize();

      await tester.pumpWidget(_buildWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('Failed to load logs'), findsOneWidget);
    });

    testWidgets('shows "No logs returned." for empty log response', (
      WidgetTester tester,
    ) async {
      final controller = _buildController(logs: '');
      await controller.initialize();

      await tester.pumpWidget(_buildWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('No logs returned.'), findsOneWidget);
    });

    testWidgets('refresh button triggers reload', (WidgetTester tester) async {
      final controller = _buildController();
      await controller.initialize();

      await tester.pumpWidget(_buildWidget(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Should show loading indicator during refresh.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // Logs should be visible again after refresh.
      expect(find.textContaining('INFO started'), findsOneWidget);
    });

    testWidgets('retry button triggers reload after error', (
      WidgetTester tester,
    ) async {
      final api = _CountingLogApi(shouldFail: true);
      final storage = _MemorySessionStorage()..seedSession(_testSession);
      final controller = AppController(
        storage: storage,
        api: api,
        certificateProvider: const CertificateProvider(),
      );
      await controller.initialize();

      // Flutter test framework reports FutureBuilder errors as unhandled; allow
      // them so we can test the retry flow without the test itself failing.
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {};

      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: LogViewerScreen(
              controller: controller,
              applicationName: 'payments-api',
              namespace: 'payments',
              podName: 'payments-api-7f9d9c',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Retry'), findsOneWidget);
        final callsBefore = api.callCount;

        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(api.callCount, greaterThan(callsBefore));
        // Error message is shown again after the retry also fails.
        expect(find.text('Retry'), findsOneWidget);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('copy button is present in app bar', (
      WidgetTester tester,
    ) async {
      final controller = _buildController();
      await controller.initialize();

      await tester.pumpWidget(_buildWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy_all), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('title shows pod name when no container name', (
      WidgetTester tester,
    ) async {
      final controller = _buildController();
      await controller.initialize();

      await tester.pumpWidget(
        _buildWidget(controller: controller, podName: 'payments-api-7f9d9c'),
      );
      await tester.pumpAndSettle();

      expect(find.text('payments-api-7f9d9c'), findsWidgets);
    });

    testWidgets('title shows podName/containerName when container name given', (
      WidgetTester tester,
    ) async {
      final controller = _buildController();
      await controller.initialize();

      await tester.pumpWidget(
        _buildWidget(
          controller: controller,
          podName: 'payments-api-7f9d9c',
          containerName: 'app',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('payments-api-7f9d9c/app'), findsWidgets);
    });

    testWidgets('empty containerName falls back to pod name in title', (
      WidgetTester tester,
    ) async {
      final controller = _buildController();
      await controller.initialize();

      await tester.pumpWidget(
        _buildWidget(
          controller: controller,
          podName: 'payments-api-7f9d9c',
          containerName: '',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('payments-api-7f9d9c'), findsWidgets);
    });
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

class _FakeLogApi implements ArgoCdApi {
  _FakeLogApi({required this.logs, this.shouldFail = false});

  final String logs;
  final bool shouldFail;

  @override
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 500,
  }) async {
    if (shouldFail) {
      throw const ArgoCdException('Failed to load logs');
    }
    return logs;
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async =>
      const <ArgoApplication>[];

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    throw const ArgoCdException('Not implemented');
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async =>
      const <ArgoProject>[];

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    throw const ArgoCdException('Not implemented');
  }

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async =>
      const <ArgoResourceNode>[];

  @override
  Future<String> fetchResourceManifest(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
  }) async =>
      '';

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
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async =>
      AppSession(serverUrl: serverUrl, username: username, token: 'token');

  @override
  Future<void> verifyServer(String serverUrl) async {}
}

/// An API fake that counts how many times fetchResourceLogs has been called.
class _CountingLogApi extends _FakeLogApi {
  _CountingLogApi({super.logs = _sampleLogs, super.shouldFail});

  int callCount = 0;

  @override
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 500,
  }) async {
    callCount++;
    return super.fetchResourceLogs(
      session,
      applicationName: applicationName,
      namespace: namespace,
      podName: podName,
      containerName: containerName,
      tailLines: tailLines,
    );
  }
}
