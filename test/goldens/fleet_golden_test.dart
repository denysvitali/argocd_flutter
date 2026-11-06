@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

/// Realistic multi-application fleet so goldens reflect the density users
/// actually see, rather than a single seeded app.
ArgoApplication _app(
  String name, {
  String project = 'platform',
  String namespace = 'default',
  String cluster = 'https://kubernetes.default.svc',
  String sync = 'Synced',
  String health = 'Healthy',
  String phase = 'Succeeded',
  String? message,
  String syncedAt = '2026-04-10T09:12:00Z',
  List<ArgoResource> resources = const <ArgoResource>[],
  List<ArgoHistoryEntry> history = const <ArgoHistoryEntry>[],
}) {
  return ArgoApplication(
    name: name,
    project: project,
    namespace: namespace,
    cluster: cluster,
    repoUrl: 'https://github.com/example/$project-deploy',
    path: 'apps/$name',
    targetRevision: 'main',
    syncStatus: sync,
    healthStatus: health,
    operationPhase: phase,
    operationMessage: message,
    lastSyncedAt: syncedAt,
    resources: resources,
    history: history,
  );
}

ArgoResource _res(
  String kind,
  String name, {
  String status = 'Synced',
  String health = 'Healthy',
  String message = '',
}) {
  return ArgoResource(
    kind: kind,
    name: name,
    namespace: 'payments',
    group: kind == 'Deployment' ? 'apps' : '',
    version: 'v1',
    status: status,
    health: health,
    healthMessage: message,
  );
}

final List<ArgoApplication> fleetApplications = <ArgoApplication>[
  _app(
    'checkout-web',
    project: 'storefront',
    namespace: 'checkout',
    sync: 'OutOfSync',
    health: 'Degraded',
    phase: 'Failed',
    message: 'Deployment "checkout-web" exceeded its progress deadline',
    syncedAt: '2026-04-10T08:40:00Z',
    resources: <ArgoResource>[
      _res(
        'Deployment',
        'checkout-web',
        status: 'OutOfSync',
        health: 'Degraded',
        message: 'exceeded its progress deadline',
      ),
      _res('Service', 'checkout-web'),
      _res('ConfigMap', 'checkout-web-config', status: 'OutOfSync'),
      _res('Ingress', 'checkout-web'),
    ],
    history: const <ArgoHistoryEntry>[
      ArgoHistoryEntry(
        id: 42,
        revision: '9f3c2a1b7e',
        deployedAt: '2026-04-10T08:40:00Z',
      ),
      ArgoHistoryEntry(
        id: 41,
        revision: '1a2b3c4d5e',
        deployedAt: '2026-04-09T16:02:00Z',
      ),
    ],
  ),
  _app(
    'payments-api',
    namespace: 'payments',
    resources: <ArgoResource>[
      _res('Deployment', 'payments-api'),
      _res('Service', 'payments-api'),
      _res('HorizontalPodAutoscaler', 'payments-api'),
    ],
  ),
  _app(
    'search-indexer',
    project: 'data',
    namespace: 'search',
    cluster: 'https://prod-eu-west-1.k8s.example.com',
    sync: 'OutOfSync',
    health: 'Healthy',
    syncedAt: '2026-04-09T22:15:00Z',
  ),
  _app(
    'ledger-worker',
    namespace: 'payments',
    health: 'Progressing',
    phase: 'Running',
    syncedAt: '2026-04-10T09:58:00Z',
  ),
  _app(
    'cart-service',
    project: 'storefront',
    namespace: 'checkout',
    cluster: 'https://prod-eu-west-1.k8s.example.com',
  ),
  _app(
    'kafka-connect',
    project: 'data',
    namespace: 'streaming',
    health: 'Missing',
    sync: 'OutOfSync',
    syncedAt: '2026-04-08T11:00:00Z',
  ),
  _app('ingress-nginx', project: 'infra', namespace: 'ingress'),
  _app('cert-manager', project: 'infra', namespace: 'cert-manager'),
];

const List<ArgoProject> fleetProjects = <ArgoProject>[
  ArgoProject(
    name: 'platform',
    description: 'Core platform services',
    sourceRepos: <String>['https://github.com/example/platform-deploy'],
    destinations: <ArgoProjectDestination>[
      ArgoProjectDestination(
        server: 'https://kubernetes.default.svc',
        namespace: 'payments',
        name: 'in-cluster',
      ),
    ],
    clusterResourceWhitelist: <ArgoProjectClusterResource>[],
  ),
  ArgoProject(
    name: 'storefront',
    description: 'Customer-facing web experience',
    sourceRepos: <String>['https://github.com/example/storefront-deploy'],
    destinations: <ArgoProjectDestination>[
      ArgoProjectDestination(
        server: 'https://kubernetes.default.svc',
        namespace: 'checkout',
        name: 'in-cluster',
      ),
      ArgoProjectDestination(
        server: 'https://prod-eu-west-1.k8s.example.com',
        namespace: 'checkout',
        name: 'prod-eu',
      ),
    ],
    clusterResourceWhitelist: <ArgoProjectClusterResource>[],
  ),
  ArgoProject(
    name: 'data',
    description: 'Streaming and search pipelines',
    sourceRepos: <String>['*'],
    destinations: <ArgoProjectDestination>[
      ArgoProjectDestination(server: '*', namespace: '*', name: 'any'),
    ],
    clusterResourceWhitelist: <ArgoProjectClusterResource>[],
  ),
];

FakeArgoCdApi _fleetApi() =>
    FakeArgoCdApi(applications: fleetApplications, projects: fleetProjects);

Future<void> _tapShellTab(WidgetTester tester, IconData icon) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(icon),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode == ThemeMode.light ? 'light' : 'dark';

    testGoldens('fleet shell pages match $suffix theme', (
      WidgetTester tester,
    ) async {
      await pumpGoldenApp(tester, api: _fleetApi(), themeMode: mode);
      await screenMatchesGolden(tester, 'fleet_dashboard_$suffix');

      await _tapShellTab(tester, Icons.dashboard_outlined);
      await screenMatchesGolden(tester, 'fleet_applications_$suffix');

      await tester.scrollUntilVisible(
        find.text('checkout-web'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('checkout-web').first);
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'fleet_application_detail_$suffix');
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tapShellTab(tester, Icons.folder_outlined);
      await screenMatchesGolden(tester, 'fleet_projects_$suffix');

      await _tapShellTab(tester, Icons.settings_outlined);
      await screenMatchesGolden(tester, 'fleet_settings_$suffix');
    });
  }
}
