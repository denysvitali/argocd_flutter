@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/features/applications/app_diff_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import '../test_helpers.dart';
import 'golden_test_helpers.dart';

String _deployment({required int replicas, required String image}) {
  return '''
{
  "apiVersion": "apps/v1",
  "kind": "Deployment",
  "metadata": {
    "name": "checkout-web",
    "namespace": "checkout",
    "labels": {"app": "checkout-web", "tier": "frontend"}
  },
  "spec": {
    "replicas": $replicas,
    "selector": {"matchLabels": {"app": "checkout-web"}},
    "template": {
      "metadata": {"labels": {"app": "checkout-web"}},
      "spec": {
        "containers": [
          {
            "name": "web",
            "image": "$image",
            "ports": [{"containerPort": 8080}],
            "resources": {"limits": {"cpu": "500m", "memory": "512Mi"}}
          }
        ]
      }
    }
  },
  "status": {"observedGeneration": 7}
}
''';
}

const String _configTarget = '''
{"apiVersion": "v1", "kind": "ConfigMap",
 "metadata": {"name": "checkout-web-config", "namespace": "checkout"},
 "data": {"LOG_LEVEL": "info", "FEATURE_FLAGS": "new-cart"}}
''';

const String _configLive = '''
{"apiVersion": "v1", "kind": "ConfigMap",
 "metadata": {"name": "checkout-web-config", "namespace": "checkout"},
 "data": {"LOG_LEVEL": "debug", "FEATURE_FLAGS": "new-cart", "TRACE": "true"}}
''';

final List<ManagedResource> _driftedResources = <ManagedResource>[
  ManagedResource(
    kind: 'Deployment',
    name: 'checkout-web',
    namespace: 'checkout',
    group: 'apps',
    targetState: _deployment(
      replicas: 3,
      image: 'ghcr.io/example/checkout-web:1.8.2',
    ),
    liveState: _deployment(
      replicas: 2,
      image: 'ghcr.io/example/checkout-web:1.8.1',
    ),
  ),
  const ManagedResource(
    kind: 'ConfigMap',
    name: 'checkout-web-config',
    namespace: 'checkout',
    group: '',
    targetState: _configTarget,
    liveState: _configLive,
  ),
];

Future<void> _pumpDiff(WidgetTester tester, ThemeMode mode) async {
  final controller = await createAuthenticatedController(
    api: FakeArgoCdApi(managedResources: _driftedResources),
  );
  await pumpGoldenScreen(
    tester,
    themeMode: mode,
    child: AppDiffScreen(
      controller: controller,
      applicationName: 'checkout-web',
    ),
  );
}

void main() {
  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode == ThemeMode.light ? 'light' : 'dark';

    testGoldens('app diff screen matches $suffix theme', (
      WidgetTester tester,
    ) async {
      await _pumpDiff(tester, mode);
      await screenMatchesGolden(tester, 'app_diff_$suffix');
    });
  }

  testGoldens('app diff split view matches light theme', (
    WidgetTester tester,
  ) async {
    await _pumpDiff(tester, ThemeMode.light);
    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'app_diff_split_light');
  });
}
