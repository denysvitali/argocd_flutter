import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/features/applications/app_diff_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  Future<void> pumpDiffScreen(
    WidgetTester tester, {
    required List<ManagedResource> managedResources,
  }) async {
    final controller = await createAuthenticatedController(
      api: FakeArgoCdApi(managedResources: managedResources),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: AppDiffScreen(
          controller: controller,
          applicationName: 'payments-api',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AppDiffScreen', () {
    testWidgets('shows empty state when managed resources match', (
      WidgetTester tester,
    ) async {
      await pumpDiffScreen(
        tester,
        managedResources: const <ManagedResource>[
          ManagedResource(
            kind: 'Service',
            name: 'web',
            namespace: 'payments',
            group: '',
            targetState: '{"kind":"Service","metadata":{"name":"web"}}',
            liveState: '{"kind":"Service","metadata":{"name":"web"}}',
          ),
        ],
      );

      expect(find.text('Diff: payments-api'), findsOneWidget);
      expect(find.text('In Sync'), findsOneWidget);
      expect(
        find.text('All resources match their desired state.'),
        findsOneWidget,
      );
    });

    testWidgets('renders changed resource diff and hides server fields', (
      WidgetTester tester,
    ) async {
      await pumpDiffScreen(
        tester,
        managedResources: <ManagedResource>[
          ManagedResource(
            kind: 'Deployment',
            name: 'web',
            namespace: 'payments',
            group: 'apps',
            targetState: _deploymentJson(
              replicas: 2,
              image: 'ghcr.io/example/web:v1',
              manager: 'argocd-controller',
              observedGeneration: 1,
            ),
            liveState: _deploymentJson(
              replicas: 3,
              image: 'ghcr.io/example/web:v2',
              manager: 'kubectl',
              observedGeneration: 2,
            ),
          ),
        ],
      );

      expect(find.text('Diff: payments-api'), findsOneWidget);
      expect(find.text('Deployment'), findsOneWidget);
      expect(find.text('payments/web'), findsOneWidget);
      expect(find.textContaining('replicas: 2'), findsOneWidget);
      expect(find.textContaining('replicas: 3'), findsOneWidget);
      expect(find.textContaining('managedFields'), findsNothing);
      expect(find.textContaining('observedGeneration'), findsNothing);
    });

    testWidgets('managed fields can be shown from the toolbar', (
      WidgetTester tester,
    ) async {
      await pumpDiffScreen(
        tester,
        managedResources: <ManagedResource>[
          ManagedResource(
            kind: 'Deployment',
            name: 'web',
            namespace: 'payments',
            group: 'apps',
            targetState: _deploymentJson(
              replicas: 2,
              image: 'ghcr.io/example/web:v1',
              manager: 'argocd-controller',
              observedGeneration: 1,
            ),
            liveState: _deploymentJson(
              replicas: 2,
              image: 'ghcr.io/example/web:v1',
              manager: 'kubectl',
              observedGeneration: 2,
            ),
          ),
        ],
      );

      expect(find.textContaining('managedFields'), findsNothing);
      expect(find.textContaining('observedGeneration'), findsNothing);

      await tester.tap(find.byTooltip('Show managed fields'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide managed fields'), findsOneWidget);
      expect(find.textContaining('managedFields'), findsWidgets);
      expect(find.textContaining('observedGeneration'), findsWidgets);
      expect(find.textContaining('argocd-controller'), findsOneWidget);
      expect(find.textContaining('kubectl'), findsOneWidget);
    });

    testWidgets('ignore whitespace hides whitespace-only changes', (
      WidgetTester tester,
    ) async {
      await pumpDiffScreen(
        tester,
        managedResources: const <ManagedResource>[
          ManagedResource(
            kind: 'ConfigMap',
            name: 'web-config',
            namespace: 'payments',
            group: '',
            targetState: 'kind: ConfigMap\nmetadata:\n  name: web-config',
            liveState: 'kind: ConfigMap\nmetadata:\nname:   web-config',
          ),
        ],
      );

      expect(find.text('ConfigMap'), findsOneWidget);
      expect(find.textContaining('name: web-config'), findsOneWidget);
      expect(find.textContaining('name:   web-config'), findsOneWidget);

      await tester.tap(find.byTooltip('Ignore whitespace'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Compare whitespace'), findsOneWidget);
      expect(
        find.text('No visible diff with the current filters.'),
        findsOneWidget,
      );
    });
  });
}

String _deploymentJson({
  required int replicas,
  required String image,
  required String manager,
  required int observedGeneration,
}) {
  return '''
{
  "apiVersion": "apps/v1",
  "kind": "Deployment",
  "metadata": {
    "name": "web",
    "namespace": "payments",
    "managedFields": [
      {
        "manager": "$manager"
      }
    ]
  },
  "spec": {
    "replicas": $replicas,
    "template": {
      "spec": {
        "containers": [
          {
            "name": "web",
            "image": "$image"
          }
        ]
      }
    }
  },
  "status": {
    "observedGeneration": $observedGeneration
  }
}
''';
}
