import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/features/applications/pod_screen.dart';
import 'package:argocd_flutter/features/applications/resource_graph.dart';
import 'package:argocd_flutter/features/applications/resource_map_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

ArgoResourceNode _node(
  String kind,
  String name, {
  List<String> parents = const <String>[],
  String health = 'Healthy',
  String message = '',
  Map<String, String> info = const <String, String>{},
}) => ArgoResourceNode(
  group: '',
  version: 'v1',
  kind: kind,
  namespace: 'agents',
  name: name,
  uid: '$kind/$name',
  parentUids: parents,
  healthStatus: health,
  healthMessage: message,
  createdAt: '2026-04-09T10:00:00Z',
  info: info,
);

List<ArgoResourceNode> _tree({String podHealth = 'Healthy'}) =>
    <ArgoResourceNode>[
      _node(
        'Deployment',
        'happy-daemon',
        health: 'Progressing',
        message: 'Waiting for rollout to finish',
      ),
      _node(
        'ReplicaSet',
        'happy-daemon-6974484d8d',
        parents: <String>['Deployment/happy-daemon'],
        info: <String, String>{'Revision': 'Rev:10'},
      ),
      for (var rev = 1; rev <= 8; rev++)
        _node(
          'ReplicaSet',
          'happy-daemon-old$rev',
          parents: <String>['Deployment/happy-daemon'],
          info: <String, String>{'Revision': 'Rev:$rev'},
        ),
      _node(
        'Pod',
        'happy-daemon-6974484d8d-abcde',
        parents: <String>['ReplicaSet/happy-daemon-6974484d8d'],
        health: podHealth,
        info: <String, String>{'Restart Count': '2'},
      ),
      _node(
        'Pod',
        'happy-daemon-6974484d8d-fghij',
        parents: <String>['ReplicaSet/happy-daemon-6974484d8d'],
        health: 'Progressing',
      ),
      _node('Service', 'happy-daemon'),
      _node(
        'EndpointSlice',
        'happy-daemon-htxf8',
        parents: <String>['Service/happy-daemon'],
        health: 'Unknown',
      ),
      _node('Secret', 'happy-github-token', health: 'Unknown'),
    ];

const _managed = <ArgoResource>[
  ArgoResource(
    kind: 'Secret',
    name: 'happy-github-token',
    namespace: 'agents',
    group: '',
    version: 'v1',
    status: 'OutOfSync',
    health: 'Unknown',
    healthMessage: '',
    hasHealth: false,
  ),
];

class _MapApi extends FakeArgoCdApi {
  _MapApi() : super.withSeedData();

  List<ArgoResourceNode> tree = _tree();
  int treeCalls = 0;

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async {
    treeCalls++;
    return tree;
  }
}

void main() {
  group('buildResourceMap', () {
    test('groups roots into sections and folds old ReplicaSets', () {
      final sections = buildResourceMap(_tree(), managed: _managed);
      expect(sections.map((s) => s.title), <String>[
        'Workloads',
        'Networking',
        'Configuration',
      ]);

      final deployment = sections.first.roots.single;
      expect(deployment.node.name, 'happy-daemon');
      expect(deployment.children.single.node.name, 'happy-daemon-6974484d8d');
      expect(deployment.children.single.pods.length, 2);
      expect(deployment.olderReplicaSets.length, 8);
      // Newest revision first.
      expect(deployment.olderReplicaSets.first.node.name, 'happy-daemon-old8');

      final service = sections[1].roots.single;
      expect(service.children.single.node.kind, 'EndpointSlice');

      final secret = sections[2].roots.single;
      expect(secret.isOutOfSync, isTrue);
    });

    test('keeps newest ReplicaSet visible when none have pods', () {
      final sections = buildResourceMap(<ArgoResourceNode>[
        _node('Deployment', 'web'),
        _node(
          'ReplicaSet',
          'web-a',
          parents: <String>['Deployment/web'],
          info: <String, String>{'Revision': '1'},
        ),
        _node(
          'ReplicaSet',
          'web-b',
          parents: <String>['Deployment/web'],
          info: <String, String>{'Revision': '2'},
        ),
      ]);
      final deployment = sections.single.roots.single;
      expect(deployment.children.single.node.name, 'web-b');
      expect(deployment.olderReplicaSets.single.node.name, 'web-a');
    });
  });

  Widget wrap(Widget child) => MaterialApp(
    theme: ThemeData(splashFactory: InkRipple.splashFactory),
    home: child,
  );

  testWidgets('renders the map with pods, folded ReplicaSets and sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final api = _MapApi();
    final controller = await createAuthenticatedController(api: api);
    await tester.pumpWidget(
      wrap(
        ResourceMapScreen(
          controller: controller,
          applicationName: 'payments-api',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show as list'));
    await tester.pumpAndSettle();

    expect(find.text('Workloads'), findsOneWidget);
    expect(find.text('Networking'), findsOneWidget);
    // ReplicaSet shows as its hash under the Deployment.
    expect(find.text('6974484d8d'), findsOneWidget);
    expect(find.text('ReplicaSet · rev 10 · 2 pods · 1d'), findsOneWidget);
    expect(find.text('Waiting for rollout to finish'), findsOneWidget);
    // Pods as chips with their unique suffix.
    expect(find.text('abcde'), findsOneWidget);
    expect(find.text('fghij'), findsOneWidget);

    expect(find.text('8 older ReplicaSets'), findsOneWidget);
    expect(find.text('happy-daemon-old8'), findsNothing);
    await tester.tap(find.text('8 older ReplicaSets'));
    await tester.pumpAndSettle();
    expect(find.text('old8'), findsOneWidget);
    expect(find.text('Hide older ReplicaSets'), findsOneWidget);

    // Collapse a section.
    await tester.tap(find.text('Networking'));
    await tester.pumpAndSettle();
    expect(find.text('happy-daemon-htxf8'), findsNothing);

    // Tap a pod chip to open the pod.
    await tester.tap(find.text('abcde'));
    await tester.pumpAndSettle();
    expect(find.byType(PodScreen), findsOneWidget);
  });

  testWidgets('issues filter keeps only unhealthy or drifted resources', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final api = _MapApi();
    final controller = await createAuthenticatedController(api: api);
    await tester.pumpWidget(
      wrap(
        ResourceMapScreen(
          controller: controller,
          applicationName: 'payments-api',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show as list'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Issues'));
    await tester.pumpAndSettle();
    expect(find.text('Workloads'), findsOneWidget);
    expect(find.text('Networking'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing-matches');
    await tester.pumpAndSettle();
    expect(find.text('No Matches'), findsOneWidget);
  });

  testWidgets('refreshes itself while on screen', (tester) async {
    final api = _MapApi();
    final controller = await createAuthenticatedController(api: api);
    await tester.pumpWidget(
      wrap(
        ResourceMapScreen(
          controller: controller,
          applicationName: 'payments-api',
          refreshInterval: const Duration(seconds: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.treeCalls, 1);

    api.tree = _tree(podHealth: 'Degraded');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(api.treeCalls, 2);
  });

  group('layoutResourceGraph', () {
    test('places columns by depth and centres parents on children', () {
      final layout = layoutResourceGraph(
        applicationName: 'happy-daemon',
        sections: buildResourceMap(_tree()),
      );
      final byName = <String, GraphNode>{
        for (final n in layout.nodes)
          if (n.resource != null) '${n.resource!.kind}/${n.resource!.name}': n,
      };
      final deploy = byName['Deployment/happy-daemon']!;
      final rs = byName['ReplicaSet/happy-daemon-6974484d8d']!;
      expect(layout.root.position.dx, kGraphPadding);
      expect(
        deploy.position.dx,
        kGraphPadding + kGraphNodeWidth + kGraphColumnGap,
      );
      expect(rs.position.dx, greaterThan(deploy.position.dx));
      // RS card grows to hold its two pods.
      expect(rs.height, kGraphHeaderHeight + 2 * kGraphPodRowHeight + 8);
      // Older ReplicaSets are a single stack node.
      final stacks = layout.nodes.where((n) => n.type == GraphNodeType.stack);
      expect(stacks.single.stackCount, 8);
      // No two cards overlap.
      for (final a in layout.nodes) {
        for (final b in layout.nodes) {
          if (!identical(a, b)) {
            expect(a.rect.overlaps(b.rect), isFalse);
          }
        }
      }
    });

    test('collapsed nodes hide children, expanded stacks show them', () {
      final sections = buildResourceMap(_tree());
      final collapsed = layoutResourceGraph(
        applicationName: 'a',
        sections: sections,
        collapsed: <String>{'Deployment/happy-daemon'},
      );
      expect(
        collapsed.nodes.where((n) => n.resource?.kind == 'ReplicaSet'),
        isEmpty,
      );
      final expanded = layoutResourceGraph(
        applicationName: 'a',
        sections: sections,
        expandedStacks: <String>{'Deployment/happy-daemon'},
      );
      expect(
        expanded.nodes.where((n) => n.resource?.kind == 'ReplicaSet').length,
        9,
      );
    });
  });

  testWidgets('graph is the default view; pods and stacks are tappable', (
    tester,
  ) async {
    final api = _MapApi();
    final controller = await createAuthenticatedController(api: api);
    await tester.pumpWidget(
      wrap(
        ResourceMapScreen(
          controller: controller,
          applicationName: 'payments-api',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ResourceGraphView), findsOneWidget);
    expect(find.text('8 ReplicaSets'), findsOneWidget);
    expect(find.text('rev:10'), findsOneWidget);

    await tester.tap(find.text('8 ReplicaSets'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Hide older ReplicaSets'), findsOneWidget);

    await tester.tap(find.byTooltip('Fit to screen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Collapse children').first);
    await tester.pumpAndSettle();
    expect(find.text('happy-daemon-6974484d8d'), findsNothing);
  });
}
