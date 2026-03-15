@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/features/applications/log_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

const _sampleLogs =
    '2026-03-10T10:00:00Z INFO started\n'
    '2026-03-10T10:00:02Z WARN cache miss\n'
    '2026-03-10T10:00:05Z INFO synced';

AppController _buildLogController() {
  return AppController(
    storage: MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'admin',
          token: 'test-token',
        ),
      ),
    api: const _LogViewerApi(logs: _sampleLogs),
    certificateProvider: const CertificateProvider(),
  );
}

void main() {
  testGoldens('log viewer matches light theme', (WidgetTester tester) async {
    final controller = _buildLogController();
    await controller.initialize();

    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.light,
      child: LogViewerScreen(
        controller: controller,
        applicationName: 'payments-api',
        namespace: 'payments',
        podName: 'payments-api-7f9d9c',
      ),
    );

    await screenMatchesGolden(tester, 'log_viewer_light');
  });

  testGoldens('log viewer matches dark theme', (WidgetTester tester) async {
    final controller = _buildLogController();
    await controller.initialize();

    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.dark,
      child: LogViewerScreen(
        controller: controller,
        applicationName: 'payments-api',
        namespace: 'payments',
        podName: 'payments-api-7f9d9c',
      ),
    );

    await screenMatchesGolden(tester, 'log_viewer_dark');
  });

  testGoldens(
    'log viewer with container name shows podName/containerName title',
    (WidgetTester tester) async {
      final controller = _buildLogController();
      await controller.initialize();

      await pumpGoldenScreen(
        tester,
        themeMode: ThemeMode.light,
        child: LogViewerScreen(
          controller: controller,
          applicationName: 'payments-api',
          namespace: 'payments',
          podName: 'payments-api-7f9d9c',
          containerName: 'app',
        ),
      );

      await screenMatchesGolden(tester, 'log_viewer_with_container_light');
    },
  );

  testGoldens('log viewer empty state matches light theme', (
    WidgetTester tester,
  ) async {
    final controller = AppController(
      storage: MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'admin',
            token: 'test-token',
          ),
        ),
      api: const _LogViewerApi(logs: ''),
      certificateProvider: const CertificateProvider(),
    );
    await controller.initialize();

    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.light,
      child: LogViewerScreen(
        controller: controller,
        applicationName: 'payments-api',
        namespace: 'payments',
        podName: 'payments-api-7f9d9c',
      ),
    );

    await screenMatchesGolden(tester, 'log_viewer_empty_light');
  });
}

// ---------------------------------------------------------------------------
// Minimal API implementation returning fixed log content
// ---------------------------------------------------------------------------

class _LogViewerApi implements ArgoCdApi {
  const _LogViewerApi({required this.logs});

  final String logs;

  @override
  Future<String> fetchResourceLogs(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String podName,
    String? containerName,
    int tailLines = 500,
  }) async =>
      logs;

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
      const AppSession(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        token: 'test-token',
      );

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

  @override
  Future<void> verifyServer(String serverUrl) async {}
}
