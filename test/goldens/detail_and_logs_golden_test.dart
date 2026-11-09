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

    await pumpGoldenScreen(
      tester,
      child: ApplicationDetailScreen(
        controller: controller,
        applicationName: 'payments-api',
      ),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'application_detail_light');
  });

  for (final themeMode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    final suffix = themeMode == ThemeMode.light ? 'light' : 'dark';
    testGoldens('app-of-apps detail explains why it is degraded ($suffix)', (
      WidgetTester tester,
    ) async {
      final controller = await createAuthenticatedController(
        api: FakeArgoCdApi(applications: _appOfAppsFleet()),
      );

      await pumpGoldenScreen(
        tester,
        themeMode: themeMode,
        child: ApplicationDetailScreen(
          controller: controller,
          applicationName: 'app-of-apps',
        ),
      );
      await tester.pumpAndSettle();

      await screenMatchesGolden(tester, 'app_of_apps_detail_$suffix');
    });
  }

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
        debugShowCheckedModeBanner: false,
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

ArgoApplication _fleetApp(
  String name, {
  String health = 'Healthy',
  List<ArgoResource> resources = const <ArgoResource>[],
}) {
  return ArgoApplication(
    name: name,
    project: 'bootstrap',
    namespace: name == 'app-of-apps' ? 'argocd' : name,
    cluster: 'https://kubernetes.default.svc',
    repoUrl: 'https://github.com/example/gitops',
    path: 'apps/$name',
    targetRevision: 'main',
    syncStatus: 'Synced',
    healthStatus: health,
    operationPhase: 'Succeeded',
    operationMessage: null,
    lastSyncedAt: '2026-04-10T08:00:00Z',
    resources: resources,
    history: const <ArgoHistoryEntry>[],
  );
}

ArgoResource _fleetRes(
  String kind,
  String name, {
  String health = 'Healthy',
  String message = '',
  String group = '',
  bool hasHealth = true,
}) {
  return ArgoResource(
    kind: kind,
    name: name,
    namespace: kind == 'Namespace' ? '' : 'argocd',
    group: group,
    version: 'v1',
    status: 'Synced',
    health: hasHealth ? health : 'Unknown',
    healthMessage: message,
    hasHealth: hasHealth,
  );
}

/// The app-of-apps from a real bug report: Degraded + Synced, where the
/// reason lives in the degraded child Applications.
List<ArgoApplication> _appOfAppsFleet() {
  ArgoResource child(String name, [String health = 'Healthy']) =>
      _fleetRes('Application', name, health: health, group: 'argoproj.io');

  return <ArgoApplication>[
    _fleetApp(
      'app-of-apps',
      health: 'Degraded',
      resources: <ArgoResource>[
        child('cert-manager'),
        child('external-secrets', 'Degraded'),
        child('grafana', 'Progressing'),
        child('ingress-nginx'),
        child('loki', 'Degraded'),
        child('postgres', 'Degraded'),
        for (final ns in <String>['grafana', 'loki', 'postgres', 'monitoring'])
          _fleetRes('Namespace', ns, hasHealth: false),
        _fleetRes('AppProject', 'platform', hasHealth: false),
      ],
    ),
    _fleetApp(
      'external-secrets',
      health: 'Degraded',
      resources: <ArgoResource>[
        _fleetRes(
          'ClusterSecretStore',
          'vault',
          health: 'Degraded',
          message: 'unable to validate store: permission denied',
          group: 'external-secrets.io',
        ),
      ],
    ),
    _fleetApp(
      'loki',
      health: 'Degraded',
      resources: <ArgoResource>[
        _fleetRes(
          'StatefulSet',
          'loki',
          health: 'Degraded',
          message: 'Pod loki-0 is in CrashLoopBackOff',
          group: 'apps',
        ),
      ],
    ),
    _fleetApp(
      'postgres',
      health: 'Degraded',
      resources: <ArgoResource>[
        _fleetRes(
          'PersistentVolumeClaim',
          'data-postgres-0',
          health: 'Degraded',
          message: 'PVC is not bound',
        ),
        _fleetRes('Deployment', 'pgbouncer', health: 'Degraded', group: 'apps'),
      ],
    ),
  ];
}
