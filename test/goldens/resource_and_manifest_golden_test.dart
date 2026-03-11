@Tags(<String>['golden'])
import 'dart:convert';

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/features/applications/manifest_viewer_screen.dart';
import 'package:argocd_flutter/features/applications/resource_tree_screen.dart';
import 'package:argocd_flutter/features/projects/project_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

void main() {
  testGoldens('resource tree matches light theme', (WidgetTester tester) async {
    final controller = await _createGoldenController();
    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.light,
      child: ResourceTreeScreen(
        controller: controller,
        applicationName: 'payments-api',
      ),
    );

    await screenMatchesGolden(tester, 'resource_tree_light');
  });

  testGoldens('resource tree matches dark theme', (WidgetTester tester) async {
    final controller = await _createGoldenController();
    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.dark,
      child: ResourceTreeScreen(
        controller: controller,
        applicationName: 'payments-api',
      ),
    );

    await screenMatchesGolden(tester, 'resource_tree_dark');
  });

  testGoldens('project detail matches light theme', (
    WidgetTester tester,
  ) async {
    final controller = await _createGoldenController();
    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.light,
      child: ProjectDetailScreen(
        controller: controller,
        projectName: 'platform',
      ),
    );

    await screenMatchesGolden(tester, 'project_detail_light');
  });

  testGoldens('project detail matches dark theme', (WidgetTester tester) async {
    final controller = await _createGoldenController();
    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.dark,
      child: ProjectDetailScreen(
        controller: controller,
        projectName: 'platform',
      ),
    );

    await screenMatchesGolden(tester, 'project_detail_dark');
  });

  testGoldens('manifest viewer matches light theme', (
    WidgetTester tester,
  ) async {
    final controller = await _createGoldenController();

    await pumpGoldenScreen(
      tester,
      child: ManifestViewerScreen(
        controller: controller,
        applicationName: 'payments-api',
        namespace: 'payments',
        resourceName: 'payments-api',
        kind: 'Deployment',
        group: 'apps',
        version: 'v1',
      ),
    );

    await screenMatchesGolden(tester, 'manifest_viewer_light');
  });
}

Future<AppController> _createGoldenController() {
  return createAuthenticatedController(api: _GoldenDataApi());
}

class _GoldenDataApi extends FakeArgoCdApi {
  _GoldenDataApi()
    : super(
        applications: const <ArgoApplication>[seedApp, degradedApp],
        projects: const <ArgoProject>[_project],
      );

  static const ArgoProject _project = ArgoProject(
    name: 'platform',
    description: 'Platform services spanning payments, orders, and ingress.',
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
      ArgoProjectClusterResource(group: 'rbac.authorization.k8s.io', kind: '*'),
      ArgoProjectClusterResource(group: 'networking.k8s.io', kind: 'Ingress'),
    ],
  );

  static const List<ArgoResourceNode> _nodes = <ArgoResourceNode>[
    ArgoResourceNode(
      group: 'apps',
      version: 'v1',
      kind: 'Deployment',
      namespace: 'payments',
      name: 'payments-api',
      uid: 'deployment-payments-api',
      parentUids: <String>[],
      healthStatus: 'Healthy',
      healthMessage: 'Deployment is available.',
      createdAt: '2026-03-10T10:00:00Z',
    ),
    ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'ReplicaSet',
      namespace: 'payments',
      name: 'payments-api-7f9d9c',
      uid: 'rs-payments-api',
      parentUids: <String>['deployment-payments-api'],
      healthStatus: 'Healthy',
      healthMessage: 'ReplicaSet is current.',
      createdAt: '2026-03-10T10:01:00Z',
    ),
    ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'Pod',
      namespace: 'payments',
      name: 'payments-api-7f9d9c-abcde',
      uid: 'pod-payments-api',
      parentUids: <String>['rs-payments-api'],
      healthStatus: 'Healthy',
      healthMessage: 'Pod is ready.',
      createdAt: '2026-03-10T10:02:00Z',
    ),
    ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'Service',
      namespace: 'payments',
      name: 'payments-api',
      uid: 'svc-payments-api',
      parentUids: <String>['deployment-payments-api'],
      healthStatus: 'Healthy',
      healthMessage: 'Service endpoints are available.',
      createdAt: '2026-03-10T10:02:30Z',
    ),
  ];

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    return _project;
  }

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async {
    return _nodes;
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
    return jsonEncode(<String, dynamic>{
      'apiVersion': 'apps/v1',
      'kind': 'Deployment',
      'metadata': <String, dynamic>{
        'name': resourceName,
        'namespace': namespace,
        'labels': <String, dynamic>{
          'app.kubernetes.io/name': 'payments-api',
          'app.kubernetes.io/part-of': 'platform',
        },
      },
      'spec': <String, dynamic>{
        'replicas': 3,
        'selector': <String, dynamic>{
          'matchLabels': <String, dynamic>{'app': 'payments-api'},
        },
        'template': <String, dynamic>{
          'metadata': <String, dynamic>{
            'labels': <String, dynamic>{'app': 'payments-api'},
          },
          'spec': <String, dynamic>{
            'containers': <Map<String, dynamic>>[
              <String, dynamic>{
                'name': 'payments-api',
                'image': 'ghcr.io/example/payments-api:2026.03.10',
                'ports': <Map<String, dynamic>>[
                  <String, dynamic>{'containerPort': 8080},
                ],
                'env': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'name': 'ENVIRONMENT',
                    'value': 'production',
                  },
                ],
              },
            ],
          },
        },
      },
      'desiredManifest': <String, dynamic>{
        'spec': <String, dynamic>{'replicas': 3},
      },
      'liveManifest': <String, dynamic>{
        'spec': <String, dynamic>{'replicas': 2},
      },
    });
  }
}
