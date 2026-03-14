@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'golden_test_helpers.dart';

// All Kubernetes resource kinds supported by the mapping, in display order.
const List<String> _allKinds = <String>[
  'Application',
  'Deployment',
  'ReplicaSet',
  'StatefulSet',
  'DaemonSet',
  'Job',
  'CronJob',
  'Pod',
  'Service',
  'Ingress',
  'NetworkPolicy',
  'Endpoints',
  'EndpointSlice',
  'ConfigMap',
  'Secret',
  'PersistentVolumeClaim',
  'PersistentVolume',
  'StorageClass',
  'ServiceAccount',
  'Role',
  'ClusterRole',
  'RoleBinding',
  'ClusterRoleBinding',
  'Namespace',
  'Node',
  'HorizontalPodAutoscaler',
  'VerticalPodAutoscaler',
  'PodDisruptionBudget',
  'LimitRange',
  'ResourceQuota',
  'Certificate',
  'Issuer',
  'ClusterIssuer',
  'CustomResourceDefinition',
  'MutatingWebhookConfiguration',
  'ValidatingWebhookConfiguration',
  'Event',
  'UnknownResource',
];

class _ResourceIconsGrid extends StatelessWidget {
  const _ResourceIconsGrid();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Resource Icons'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _allKinds.length,
        itemBuilder: (BuildContext context, int index) {
          final kind = _allKinds[index];
          final icon = iconForResourceKind(kind);
          final color = colorForResourceKind(kind);
          return _ResourceKindRow(kind: kind, icon: icon, color: color);
        },
      ),
    );
  }
}

class _ResourceKindRow extends StatelessWidget {
  const _ResourceKindRow({
    required this.kind,
    required this.icon,
    required this.color,
  });

  final String kind;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: <Widget>[
          // Color dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Icon in a rounded container
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          // Kind name
          Expanded(
            child: Text(
              kind,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  testGoldens('resource icons grid matches light theme', (
    WidgetTester tester,
  ) async {
    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.light,
      size: const Size(390, 844),
      child: const _ResourceIconsGrid(),
    );

    await screenMatchesGolden(tester, 'resource_icons_light');
  });

  testGoldens('resource icons grid matches dark theme', (
    WidgetTester tester,
  ) async {
    await pumpGoldenScreen(
      tester,
      themeMode: ThemeMode.dark,
      size: const Size(390, 844),
      child: const _ResourceIconsGrid(),
    );

    await screenMatchesGolden(tester, 'resource_icons_dark');
  });
}
