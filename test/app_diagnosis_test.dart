import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/utils/app_diagnosis.dart';
import 'package:argocd_flutter/features/applications/application_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

ArgoApplication _app({
  required String name,
  String health = 'Healthy',
  String sync = 'Synced',
  String phase = 'Succeeded',
  String? message,
  String? healthMessage,
  List<ArgoResource> resources = const <ArgoResource>[],
  List<ArgoCondition> conditions = const <ArgoCondition>[],
}) {
  return ArgoApplication(
    name: name,
    project: 'bootstrap',
    namespace: 'argocd',
    cluster: 'https://kubernetes.default.svc',
    repoUrl: 'https://github.com/example/gitops',
    path: 'apps/$name',
    targetRevision: 'main',
    syncStatus: sync,
    healthStatus: health,
    operationPhase: phase,
    operationMessage: message,
    lastSyncedAt: '2026-03-10T10:00:00Z',
    resources: resources,
    history: const <ArgoHistoryEntry>[],
    healthMessage: healthMessage,
    conditions: conditions,
  );
}

ArgoResource _res(
  String kind,
  String name, {
  String health = 'Healthy',
  String healthMessage = '',
  String status = 'Synced',
  bool hasHealth = true,
  String group = '',
}) {
  return ArgoResource(
    kind: kind,
    name: name,
    namespace: 'argocd',
    group: group,
    version: 'v1',
    status: status,
    health: health,
    healthMessage: healthMessage,
    hasHealth: hasHealth,
  );
}

ArgoResource _childApp(String name, {String health = 'Healthy'}) =>
    _res('Application', name, health: health, group: 'argoproj.io');

void main() {
  group('diagnoseApplication', () {
    test('healthy synced app has no issues', () {
      final app = _app(
        name: 'ok',
        resources: <ArgoResource>[
          _res('Deployment', 'web'),
          _res('Namespace', 'ok', hasHealth: false, health: 'Unknown'),
        ],
      );
      expect(diagnoseApplication(app), isEmpty);
      expect(summarizeApplicationProblem(app), isNull);
    });

    test('orders sync failure, conditions, then resources by severity', () {
      final app = _app(
        name: 'orders',
        health: 'Degraded',
        sync: 'OutOfSync',
        phase: 'Failed',
        message: 'one or more objects failed to apply',
        conditions: const <ArgoCondition>[
          ArgoCondition(
            type: 'OrphanedResourceWarning',
            message: '2 orphaned resources',
          ),
          ArgoCondition(type: 'SyncError', message: 'quota exceeded'),
          ArgoCondition(type: 'SharedResourceInfo', message: 'ignored'),
        ],
        resources: <ArgoResource>[
          _res('Deployment', 'worker', health: 'Progressing'),
          _res('ConfigMap', 'cfg', hasHealth: false, status: 'OutOfSync'),
          _res(
            'Deployment',
            'api',
            health: 'Degraded',
            healthMessage: 'Deployment exceeded its progress deadline',
          ),
          _res('Service', 'api'),
        ],
      );

      final issues = diagnoseApplication(app);

      expect(issues.map((i) => i.title).toList(), <String>[
        'Last sync failed',
        'Orphaned resource warning',
        'Sync error',
        'api',
        'cfg',
        'worker',
      ]);
      expect(issues[3].detail, 'Deployment exceeded its progress deadline');
      expect(issues[3].status, 'Degraded');
      expect(issues[4].status, 'OutOfSync');
      expect(issues[4].detail, 'Live state differs from Git');
      expect(issues[5].severity, IssueSeverity.progressing);
    });

    test('out-of-sync resources are ignored while the app is synced', () {
      final app = _app(
        name: 'synced',
        resources: <ArgoResource>[
          _res('ConfigMap', 'cfg', hasHealth: false, status: 'OutOfSync'),
        ],
      );
      expect(diagnoseApplication(app), isEmpty);
    });

    test('explains child applications using their own top issue', () {
      final child = _app(
        name: 'payments',
        health: 'Degraded',
        resources: <ArgoResource>[
          _res(
            'Deployment',
            'payments-api',
            health: 'Degraded',
            healthMessage: 'Deployment exceeded its progress deadline',
          ),
          _res('StatefulSet', 'payments-db', health: 'Degraded'),
        ],
      );
      final parent = _app(
        name: 'app-of-apps',
        health: 'Degraded',
        resources: <ArgoResource>[
          _childApp('payments', health: 'Degraded'),
          _childApp('unknown-child', health: 'Degraded'),
          _childApp('ingress'),
        ],
      );

      final issues = diagnoseApplication(
        parent,
        knownApplications: <ArgoApplication>[parent, child],
      );

      expect(issues, hasLength(2));
      expect(issues[0].title, 'payments');
      expect(
        issues[0].detail,
        'Deployment payments-api: Deployment exceeded its progress deadline '
        '(+1 more degraded)',
      );
      // Child not in the fleet list: nothing to say, but still listed.
      expect(issues[1].title, 'unknown-child');
      expect(issues[1].detail, isNull);
    });

    test('falls back to the app-level health message', () {
      final app = _app(
        name: 'x',
        health: 'Degraded',
        healthMessage: 'custom health check failed',
      );
      expect(
        summarizeApplicationProblem(app),
        'Application health: custom health check failed',
      );
    });
  });

  test('humanizeConditionType', () {
    expect(humanizeConditionType('ComparisonError'), 'Comparison error');
    expect(
      humanizeConditionType('OrphanedResourceWarning'),
      'Orphaned resource warning',
    );
    expect(humanizeConditionType('InvalidSpecError'), 'Invalid spec error');
  });

  group('detail screen issues list', () {
    testWidgets('explains a degraded app-of-apps and opens the child', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final child = _app(
        name: 'payments',
        health: 'Degraded',
        resources: <ArgoResource>[
          _res(
            'Deployment',
            'payments-api',
            health: 'Degraded',
            healthMessage: 'Deployment exceeded its progress deadline',
          ),
        ],
      );
      final parent = _app(
        name: 'app-of-apps',
        health: 'Degraded',
        resources: <ArgoResource>[
          _childApp('payments', health: 'Degraded'),
          _childApp('ingress'),
          for (var i = 0; i < 3; i++)
            _res('Namespace', 'ns-$i', hasHealth: false, health: 'Unknown'),
        ],
      );
      final controller = await createAuthenticatedController(
        api: FakeArgoCdApi(applications: <ArgoApplication>[parent, child]),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ApplicationDetailScreen(
            controller: controller,
            applicationName: 'app-of-apps',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WHY IT’S DEGRADED'), findsOneWidget);
      expect(find.text('Degraded · Application'), findsOneWidget);
      expect(
        find.text(
          'Deployment payments-api: Deployment exceeded its progress deadline',
        ),
        findsOneWidget,
      );
      // Namespaces have no health check: not lumped in as "Unknown".
      expect(find.text('3 without a health check'), findsOneWidget);
      expect(find.text('3 Unknown'), findsNothing);

      await tester.tap(find.text('payments').first);
      await tester.pumpAndSettle();

      // The child's own detail screen explains its degraded Deployment.
      expect(find.text('payments-api'), findsOneWidget);
      expect(
        find.text('Deployment exceeded its progress deadline'),
        findsOneWidget,
      );
    });

    testWidgets('collapses long issue lists', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final app = _app(
        name: 'big',
        health: 'Degraded',
        resources: <ArgoResource>[
          for (var i = 0; i < 9; i++)
            _res('Deployment', 'svc-$i', health: 'Degraded'),
        ],
      );
      final controller = await createAuthenticatedController(
        api: FakeArgoCdApi(applications: <ArgoApplication>[app]),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ApplicationDetailScreen(
            controller: controller,
            applicationName: 'big',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('svc-4'), findsOneWidget);
      expect(find.text('svc-5'), findsNothing);

      await tester.tap(find.text('Show all 9 issues'));
      await tester.pumpAndSettle();

      expect(find.text('svc-8'), findsOneWidget);
      expect(find.text('Show fewer'), findsOneWidget);
    });
  });
}
