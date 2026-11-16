import 'dart:convert';

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/models/pod_details.dart';
import 'package:argocd_flutter/features/applications/log_viewer_screen.dart';
import 'package:argocd_flutter/features/applications/pod_screen.dart';
import 'package:argocd_flutter/features/applications/pods_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

ArgoResourceNode _node(
  String kind,
  String name, {
  List<String> parents = const <String>[],
  Map<String, String> info = const <String, String>{},
}) => ArgoResourceNode(
  group: kind == 'Pod' ? '' : 'apps',
  version: 'v1',
  kind: kind,
  namespace: 'ns',
  name: name,
  uid: '$kind/$name',
  parentUids: parents,
  healthStatus: 'Healthy',
  healthMessage: '',
  createdAt: '2026-04-10T08:00:00Z',
  info: info,
);

final _tree = <ArgoResourceNode>[
  _node('Deployment', 'web'),
  _node('ReplicaSet', 'web-75966bdf89', parents: <String>['Deployment/web']),
  _node(
    'Pod',
    'web-75966bdf89-zgcnm',
    parents: <String>['ReplicaSet/web-75966bdf89'],
    info: <String, String>{
      'Status Reason': 'Running',
      'Containers': '2/3',
      'Restart Count': '4',
    },
  ),
];

final _podManifest = <String, dynamic>{
  'kind': 'Pod',
  'spec': <String, dynamic>{
    'nodeName': 'node-a',
    'initContainers': <dynamic>[
      <String, dynamic>{'name': 'provision', 'image': 'busybox'},
    ],
    'containers': <dynamic>[
      <String, dynamic>{'name': 'qemu', 'image': 'ghcr.io/x/qemu:1'},
      <String, dynamic>{'name': 'novnc', 'image': 'ghcr.io/x/novnc:1'},
    ],
  },
  'status': <String, dynamic>{
    'phase': 'Running',
    'podIP': '10.0.0.7',
    'initContainerStatuses': <dynamic>[
      <String, dynamic>{
        'name': 'provision',
        'ready': false,
        'restartCount': 0,
        'state': <String, dynamic>{
          'terminated': <String, dynamic>{'reason': 'Completed', 'exitCode': 0},
        },
      },
    ],
    'containerStatuses': <dynamic>[
      <String, dynamic>{
        'name': 'qemu',
        'ready': true,
        'restartCount': 0,
        'state': <String, dynamic>{'running': <String, dynamic>{}},
      },
      <String, dynamic>{
        'name': 'novnc',
        'ready': false,
        'restartCount': 4,
        'state': <String, dynamic>{
          'waiting': <String, dynamic>{'reason': 'CrashLoopBackOff'},
        },
      },
    ],
  },
};

class _PodApi extends FakeArgoCdApi {
  _PodApi() : super.withSeedData();

  final List<String?> logRequests = <String?>[];

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async => _tree;

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
    // Same shape as the managed-resources envelope: liveState is a string.
    return jsonEncode(<String, dynamic>{
      'manifest': jsonEncode(_podManifest),
      'liveState': jsonEncode(_podManifest),
    });
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
    logRequests.add(containerName);
    if (containerName == null) {
      return 'a container name must be specified for pod $podName, '
          'choose one of: [qemu novnc] or one of the init containers: '
          '[provision]';
    }
    return 'hello from $containerName';
  }
}

Widget _wrap(Widget child) => MaterialApp(
  theme: ThemeData(splashFactory: InkRipple.splashFactory),
  home: child,
);

void main() {
  test('PodDetails parses envelope with init and app containers', () {
    final details = PodDetails.fromManifestPayload(
      jsonEncode(<String, dynamic>{'liveState': jsonEncode(_podManifest)}),
    );
    expect(details.nodeName, 'node-a');
    expect(details.initContainers.single.completedOk, isTrue);
    expect(details.appContainers.map((c) => c.name), <String>['qemu', 'novnc']);
    expect(details.restartCount, 4);
    expect(
      containerStatusLabel(details.appContainers[1]),
      'CrashLoopBackOff · 4 restarts',
    );
  });

  test('containersFromLogError extracts app containers', () {
    expect(
      containersFromLogError(
        'a container name must be specified for pod p-1, choose one of: '
        '[provision qemu novnc]',
      ),
      <String>['provision', 'qemu', 'novnc'],
    );
    expect(containersFromLogError('regular log line'), isNull);
  });

  testWidgets('pods list shows workload, revision and pod status', (
    tester,
  ) async {
    final controller = await createAuthenticatedController(api: _PodApi());
    await tester.pumpWidget(
      _wrap(PodsScreen(controller: controller, applicationName: 'app')),
    );
    await tester.pumpAndSettle();

    expect(find.text('web'), findsOneWidget);
    expect(find.text('Deployment · ReplicaSet 75966bdf89'), findsOneWidget);
    expect(find.text('web-75966bdf89-zgcnm'), findsOneWidget);
    expect(find.text('Running · 2/3 ready · 4 restarts · 2h'), findsOneWidget);

    await tester.tap(find.text('web-75966bdf89-zgcnm'));
    await tester.pumpAndSettle();
    expect(find.byType(PodScreen), findsOneWidget);
    expect(find.text('qemu'), findsOneWidget);
    expect(find.text('novnc'), findsOneWidget);
    expect(find.text('provision'), findsOneWidget);
    expect(find.text('CrashLoopBackOff · 4 restarts'), findsOneWidget);
  });

  testWidgets('pod screen opens logs for the tapped container', (tester) async {
    final api = _PodApi();
    final controller = await createAuthenticatedController(api: api);
    await tester.pumpWidget(
      _wrap(
        PodScreen(
          controller: controller,
          applicationName: 'app',
          pod: _tree.last,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('novnc'));
    await tester.pumpAndSettle();
    expect(find.byType(LogViewerScreen), findsOneWidget);
    expect(api.logRequests, <String?>['novnc']);
    expect(find.textContaining('hello from novnc'), findsOneWidget);
  });

  testWidgets('log viewer recovers when ArgoCD asks for a container', (
    tester,
  ) async {
    final api = _PodApi();
    final controller = await createAuthenticatedController(api: api);
    await tester.pumpWidget(
      _wrap(
        LogViewerScreen(
          controller: controller,
          applicationName: 'app',
          namespace: 'ns',
          podName: 'web-75966bdf89-zgcnm',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.logRequests, <String?>[null, 'qemu']);
    expect(find.textContaining('hello from qemu'), findsOneWidget);

    await tester.tap(find.byTooltip('Switch container'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'novnc'),
    );
    await tester.pumpAndSettle();
    expect(api.logRequests.last, 'novnc');
    expect(find.textContaining('hello from novnc'), findsOneWidget);
  });
}
