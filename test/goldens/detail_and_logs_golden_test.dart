@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/features/applications/application_detail_screen.dart';
import 'package:argocd_flutter/features/applications/log_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

void main() {
  testGoldens('application detail screen matches light theme', (
    WidgetTester tester,
  ) async {
    final controller = await createAuthenticatedController();

    await tester.pumpWidgetBuilder(
      SizedBox(
        width: goldenPhoneSize.width,
        height: goldenPhoneSize.height,
        child: MaterialApp(
          home: ApplicationDetailScreen(
            controller: controller,
            applicationName: 'payments-api',
          ),
        ),
      ),
      surfaceSize: goldenPhoneSize,
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'application_detail_light');
  });

  testGoldens('log viewer matches light and dark themes', (
    WidgetTester tester,
  ) async {
    final builder = GoldenBuilder.column()
      ..addScenario('light', const _LogViewerHost(themeMode: ThemeMode.light))
      ..addScenario('dark', const _LogViewerHost(themeMode: ThemeMode.dark));

    await tester.pumpWidgetBuilder(
      builder.build(),
      surfaceSize: const Size(430, 1400),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'log_viewer_themes');
  });
}

class _LogViewerHost extends StatelessWidget {
  const _LogViewerHost({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    final controller = AppController(
      storage: MemorySessionStorage()..seedSession(testSession),
      api: const _LogViewerApi(
        logs:
            '2026-03-10T10:00:00Z INFO started\n'
            '2026-03-10T10:00:02Z WARN cache miss\n'
            '2026-03-10T10:00:05Z INFO synced',
      ),
      certificateProvider: const CertificateProvider(),
    );

    return SizedBox(
      width: goldenPhoneSize.width,
      height: 620,
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        home: LogViewerScreen(
          controller: controller,
          applicationName: 'payments-api',
          namespace: 'payments',
          podName: 'payments-api-7f9d9c',
        ),
      ),
    );
  }
}

class _LogViewerApi implements ArgoCdApi {
  const _LogViewerApi({required this.logs});

  final String logs;

  @override
  Future<void> deleteApplication(
    AppSession session,
    String applicationName, {
    bool cascade = true,
  }) async {}

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    throw const ArgoCdException('Not implemented');
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    return const <ArgoApplication>[];
  }

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    throw const ArgoCdException('Not implemented');
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async {
    return const <ArgoProject>[];
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
    return logs;
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
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async {
    return const <ArgoResourceNode>[];
  }

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
    return testSession;
  }

  @override
  Future<void> syncApplication(
    AppSession session,
    String applicationName,
  ) async {}

  @override
  Future<void> verifyServer(String serverUrl) async {}
}
