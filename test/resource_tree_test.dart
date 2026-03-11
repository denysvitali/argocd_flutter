import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/features/applications/resource_tree_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  late AppController controller;
  late FakeArgoCdApi api;

  final sampleNodes = <ArgoResourceNode>[
    const ArgoResourceNode(
      group: 'apps',
      version: 'v1',
      kind: 'Deployment',
      namespace: 'default',
      name: 'my-app',
      uid: 'uid-1',
      parentUids: <String>[],
      healthStatus: 'Healthy',
      healthMessage: 'All replicas ready',
      createdAt: '2026-03-01T10:00:00Z',
    ),
    const ArgoResourceNode(
      group: 'apps',
      version: 'v1',
      kind: 'ReplicaSet',
      namespace: 'default',
      name: 'my-app-abc123',
      uid: 'uid-2',
      parentUids: <String>['uid-1'],
      healthStatus: 'Healthy',
      healthMessage: '',
      createdAt: '2026-03-01T10:00:00Z',
    ),
    const ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'Pod',
      namespace: 'default',
      name: 'my-app-abc123-xyz',
      uid: 'uid-3',
      parentUids: <String>['uid-2'],
      healthStatus: 'Healthy',
      healthMessage: 'Running',
      createdAt: '2026-03-01T10:01:00Z',
    ),
    const ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'Service',
      namespace: 'default',
      name: 'my-app-svc',
      uid: 'uid-4',
      parentUids: <String>[],
      healthStatus: 'Healthy',
      healthMessage: '',
      createdAt: '2026-03-01T10:00:00Z',
    ),
    const ArgoResourceNode(
      group: '',
      version: 'v1',
      kind: 'ConfigMap',
      namespace: 'default',
      name: 'my-app-config',
      uid: 'uid-5',
      parentUids: <String>[],
      healthStatus: 'Degraded',
      healthMessage: 'Missing key',
      createdAt: '2026-03-01T09:00:00Z',
    ),
  ];

  setUp(() {
    final storage = MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'admin',
          token: 'test-token',
        ),
      );
    api = FakeArgoCdApi(
      resourceNodes: sampleNodes,
      logsToReturn: '2026-03-10T10:00:00Z INFO resource tree log line',
    );
    controller = AppController(
      storage: storage,
      api: api,
      certificateProvider: const CertificateProvider(),
    );
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: ResourceTreeScreen(
        controller: controller,
        applicationName: 'test-app',
      ),
    );
  }

  testWidgets('renders resource tree with sample nodes', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Resource Tree'), findsOneWidget);
    expect(find.text('test-app'), findsOneWidget);
    expect(find.text('Resource Summary'), findsOneWidget);
    expect(find.text('my-app'), findsOneWidget);
    expect(find.text('my-app-svc'), findsOneWidget);
    expect(find.text('my-app-config'), findsOneWidget);
    expect(find.text('Deployment'), findsWidgets);
    expect(find.text('Service'), findsWidgets);
    expect(find.text('ConfigMap'), findsWidgets);
  });

  testWidgets('summary header shows correct counts', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.text('resources'), findsOneWidget);
    expect(find.text('4 Healthy'), findsOneWidget);
    expect(find.text('1 Degraded'), findsOneWidget);
  });

  testWidgets('expand and collapse works via expand all button', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('my-app-abc123'), findsOneWidget);
    expect(find.text('my-app-abc123-xyz'), findsOneWidget);

    final collapseButton = find.byTooltip('Collapse All');
    expect(collapseButton, findsOneWidget);
    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    expect(find.text('my-app-abc123'), findsNothing);
    expect(find.text('my-app-abc123-xyz'), findsNothing);
    expect(find.text('my-app'), findsOneWidget);

    final expandButton = find.byTooltip('Expand All');
    expect(expandButton, findsOneWidget);
    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    expect(find.text('my-app-abc123'), findsOneWidget);
  });

  testWidgets('search filters resources by name', (WidgetTester tester) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('my-app-svc'), findsOneWidget);
    expect(find.text('my-app-config'), findsOneWidget);

    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'config');
    await tester.pumpAndSettle();

    expect(find.text('my-app-config'), findsOneWidget);
    expect(find.text('my-app-svc'), findsNothing);
  });

  testWidgets('search filters resources by kind', (WidgetTester tester) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'service');
    await tester.pumpAndSettle();

    expect(find.text('my-app-svc'), findsOneWidget);
    expect(find.text('my-app-config'), findsNothing);
  });

  testWidgets('shows empty state when no resources', (
    WidgetTester tester,
  ) async {
    final storage = MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'admin',
          token: 'test-token',
        ),
      );
    final emptyController = AppController(
      storage: storage,
      api: FakeArgoCdApi(),
      certificateProvider: const CertificateProvider(),
    );
    await emptyController.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: ResourceTreeScreen(
          controller: emptyController,
          applicationName: 'empty-app',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No resources found'), findsOneWidget);
    expect(
      find.text('No resource tree data returned by the ArgoCD API.'),
      findsOneWidget,
    );
  });

  testWidgets('search with no matches shows no-results message', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'nonexistent-resource-xyz');
    await tester.pumpAndSettle();

    expect(find.textContaining('No resources match'), findsOneWidget);
  });

  testWidgets('resource detail bottom sheet opens on long press', (
    WidgetTester tester,
  ) async {
    final storage = MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'admin',
          token: 'test-token',
        ),
      );
    final singleNodeController = AppController(
      storage: storage,
      api: FakeArgoCdApi(
        resourceNodes: const <ArgoResourceNode>[
          ArgoResourceNode(
            group: '',
            version: 'v1',
            kind: 'Service',
            namespace: 'default',
            name: 'test-svc',
            uid: 'uid-single',
            parentUids: <String>[],
            healthStatus: 'Healthy',
            healthMessage: 'Active',
            createdAt: '2026-01-01T00:00:00Z',
          ),
        ],
      ),
      certificateProvider: const CertificateProvider(),
    );
    await singleNodeController.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: ResourceTreeScreen(
          controller: singleNodeController,
          applicationName: 'detail-test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('test-svc'), findsOneWidget);
    await tester.longPress(find.text('test-svc'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Kind'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('test-svc'), findsWidgets);
  });

  testWidgets('kind count badges show in summary header', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('1 Deployment'), findsOneWidget);
    expect(find.text('1 ReplicaSet'), findsOneWidget);
    expect(find.text('1 Pod'), findsOneWidget);
    expect(find.text('1 Service'), findsOneWidget);
    expect(find.text('1 ConfigMap'), findsOneWidget);
  });

  testWidgets('pod logs open without forcing a container name', (
    WidgetTester tester,
  ) async {
    await controller.initialize();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.article_outlined).first);
    await tester.tap(find.byIcon(Icons.article_outlined).first);
    await tester.pumpAndSettle();

    expect(api.lastLogRequest, isNotNull);
    expect(api.lastLogRequest!.podName, 'my-app-abc123-xyz');
    expect(api.lastLogRequest!.containerName, isNull);
    expect(find.text('my-app-abc123-xyz'), findsWidgets);
    expect(find.textContaining('INFO resource tree log line'), findsOneWidget);
  });
}
