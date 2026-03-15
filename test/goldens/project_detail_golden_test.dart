@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/features/projects/project_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

const ArgoProject _richProject = ArgoProject(
  name: 'platform',
  description:
      'Platform services spanning payments, orders, and ingress.',
  sourceRepos: <String>[
    'https://github.com/example/platform',
    'https://github.com/example/platform-infra',
  ],
  destinations: <ArgoProjectDestination>[
    ArgoProjectDestination(
      server: 'https://kubernetes.default.svc',
      namespace: 'payments',
      name: 'in-cluster',
    ),
    ArgoProjectDestination(
      server: 'https://prod-west.example.com',
      namespace: 'orders',
      name: 'prod-west',
    ),
  ],
  clusterResourceWhitelist: <ArgoProjectClusterResource>[
    ArgoProjectClusterResource(
      group: 'rbac.authorization.k8s.io',
      kind: '*',
    ),
    ArgoProjectClusterResource(
      group: 'networking.k8s.io',
      kind: 'Ingress',
    ),
  ],
);

Future<AppController> _buildController() =>
    createAuthenticatedController(
      api: FakeArgoCdApi(projects: <ArgoProject>[_richProject]),
    );

void main() {
  testGoldens('project detail overview tab matches light theme', (
    WidgetTester tester,
  ) async {
    final controller = await _buildController();

    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.light,
      child: ProjectDetailScreen(
        controller: controller,
        projectName: 'platform',
      ),
    );

    await screenMatchesGolden(tester, 'project_detail_overview_light');
  });

  testGoldens('project detail overview tab matches dark theme', (
    WidgetTester tester,
  ) async {
    final controller = await _buildController();

    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.dark,
      child: ProjectDetailScreen(
        controller: controller,
        projectName: 'platform',
      ),
    );

    await screenMatchesGolden(tester, 'project_detail_overview_dark');
  });
}
