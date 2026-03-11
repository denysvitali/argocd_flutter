import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/features/applications/application_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  late AppController controller;
  late FakeArgoCdApi api;

  setUp(() async {
    final storage = MemorySessionStorage()
      ..seedSession(
        const AppSession(
          serverUrl: 'https://argocd.example.com',
          username: 'ops',
          token: 'token',
        ),
      );
    api = FakeArgoCdApi(
      applications: const <ArgoApplication>[
        ArgoApplication(
          name: 'payments-api',
          project: 'platform',
          namespace: 'payments',
          cluster: 'https://kubernetes.default.svc',
          repoUrl: 'https://github.com/example/platform',
          path: 'apps/payments-api',
          targetRevision: 'main',
          syncStatus: 'Synced',
          healthStatus: 'Healthy',
          operationPhase: 'Succeeded',
          lastSyncedAt: '2026-03-10T10:00:00Z',
          resources: <ArgoResource>[
            ArgoResource(
              kind: 'Deployment',
              name: 'my-deploy',
              namespace: 'payments',
              group: 'apps',
              version: 'v1',
              status: 'Synced',
              health: 'Healthy',
            ),
            ArgoResource(
              kind: 'Pod',
              name: 'my-pod',
              namespace: 'payments',
              group: '',
              version: 'v1',
              status: 'Synced',
              health: 'Progressing',
            ),
          ],
          history: <ArgoHistoryEntry>[
            ArgoHistoryEntry(
              id: 1,
              revision: 'abc123',
              deployedAt: '2026-03-09T10:00:00Z',
            ),
            ArgoHistoryEntry(
              id: 2,
              revision: 'def456',
              deployedAt: '2026-03-10T10:00:00Z',
            ),
          ],
        ),
      ],
      logsToReturn: '2026-03-10T10:00:00Z INFO payments-api booted',
    );
    controller = AppController(
      storage: storage,
      api: api,
      certificateProvider: const CertificateProvider(),
    );
    await controller.initialize();
  });

  Widget buildApp({String applicationName = 'payments-api'}) {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: ApplicationDetailScreen(
        controller: controller,
        applicationName: applicationName,
      ),
    );
  }

  testWidgets('renders detail screen with application data', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Hero header shows the app name
    expect(find.text('payments-api'), findsWidgets);
    // Health and sync chips are visible
    expect(find.text('Healthy'), findsWidgets);
    expect(find.text('Synced'), findsWidgets);
  });

  testWidgets('tabs are present and overview is default', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tab labels are visible
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Resources'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Overview tab content is visible by default
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
  });

  testWidgets('switches to resources tab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Switch to Resources tab
    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();

    // Resource cards should be visible
    expect(find.text('Deployment'), findsWidgets);
    expect(find.text('my-deploy'), findsOneWidget);
  });

  testWidgets('switches to history tab', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Switch to History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // History timeline entries should be visible
    expect(find.text('Deploy #1'), findsOneWidget);
    expect(find.text('Deploy #2'), findsOneWidget);
    expect(find.textContaining('Current'), findsOneWidget);
    expect(find.text('Rollback'), findsOneWidget);
  });

  testWidgets('action buttons are present in bottom bar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('confirmation dialog appears for delete', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tap the delete icon button
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Delete Application'), findsOneWidget);
    expect(
      find.textContaining('Are you sure you want to delete'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Dismiss the dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Application'), findsNothing);
  });

  testWidgets('confirmation dialog appears for sync', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tap the Sync button in the bottom bar (by its icon)
    await tester.tap(find.byIcon(Icons.sync));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Sync Application'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('rollback confirmation dialog appears from history tab', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Switch to History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // Tap rollback button
    await tester.tap(find.text('Rollback'));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Rollback Application'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('resource cards show kind icons and health status', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Switch to Resources tab
    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();

    // Resource names visible
    expect(find.text('my-deploy'), findsOneWidget);
    expect(find.text('my-pod'), findsOneWidget);

    // Health statuses visible
    expect(find.text('Healthy'), findsWidgets);
    expect(find.text('Progressing'), findsOneWidget);
  });

  testWidgets('pod logs open without forcing container name to pod name', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Logs'));
    await tester.pumpAndSettle();

    expect(api.lastLogRequest, isNotNull);
    expect(api.lastLogRequest!.podName, 'my-pod');
    expect(api.lastLogRequest!.containerName, isNull);
    expect(find.text('my-pod'), findsWidgets);
    expect(find.textContaining('2026-03-10T10:00:00Z INFO'), findsOneWidget);
  });
}

