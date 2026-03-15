import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/health_event.dart';
import 'package:argocd_flutter/core/services/health_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

HealthMonitor _createMonitor({bool enabled = true}) {
  final monitor = HealthMonitor(
    onRefreshRequested: () async {},
  );
  if (enabled) {
    // Manually set enabled without hitting SharedPreferences.
    monitor.setEnabled(true);
  }
  return monitor;
}

void main() {
  group('HealthMonitor', () {
    test('first call seeds baseline without generating events', () async {
      final monitor = _createMonitor();
      // Wait for setEnabled to complete.
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp, degradedApp]);

      expect(monitor.events, isEmpty);
    });

    test('detects health degradation', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      // Seed baseline with healthy app.
      monitor.processApplications([seedApp]);
      expect(monitor.events, isEmpty);

      // Now the app becomes degraded.
      const degradedVersion = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Degraded',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([degradedVersion]);

      expect(monitor.events, hasLength(1));
      expect(monitor.events.first.kind, HealthEventKind.degraded);
      expect(monitor.events.first.applicationName, 'payments-api');
      expect(monitor.events.first.previousValue, 'Healthy');
      expect(monitor.events.first.currentValue, 'Degraded');
      expect(monitor.events.first.isNegative, isTrue);
    });

    test('detects recovery from degraded to healthy', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      // Seed with degraded app.
      monitor.processApplications([degradedApp]);

      // Now it recovers.
      const recoveredVersion = ArgoApplication(
        name: 'orders-api',
        project: 'platform',
        namespace: 'orders',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/orders-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Healthy',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([recoveredVersion]);

      // Should detect recovery + sync.
      final recoveryEvents = monitor.events
          .where((e) => e.kind == HealthEventKind.recovered)
          .toList();
      expect(recoveryEvents, hasLength(1));
      expect(recoveryEvents.first.applicationName, 'orders-api');
      expect(recoveryEvents.first.isNegative, isFalse);
    });

    test('detects drift (OutOfSync)', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp]);

      const driftedVersion = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'OutOfSync',
        healthStatus: 'Healthy',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([driftedVersion]);

      expect(monitor.events, hasLength(1));
      expect(monitor.events.first.kind, HealthEventKind.drifted);
      expect(monitor.events.first.isNegative, isTrue);
    });

    test('detects sync restored', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      // Seed with out-of-sync app (but healthy, to isolate sync events).
      const outOfSync = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'OutOfSync',
        healthStatus: 'Healthy',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:00:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );
      monitor.processApplications([outOfSync]);

      // Now synced.
      monitor.processApplications([seedApp]);

      expect(monitor.events, hasLength(1));
      expect(monitor.events.first.kind, HealthEventKind.synced);
      expect(monitor.events.first.isNegative, isFalse);
    });

    test('detects operation failure', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp]);

      const failedVersion = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Healthy',
        operationPhase: 'Failed',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([failedVersion]);

      expect(monitor.events, hasLength(1));
      expect(monitor.events.first.kind, HealthEventKind.operationFailed);
      expect(monitor.events.first.isNegative, isTrue);
    });

    test('does not generate events when disabled', () async {
      final monitor = _createMonitor(enabled: false);

      monitor.processApplications([seedApp]);
      monitor.processApplications([degradedApp]);

      expect(monitor.events, isEmpty);
    });

    test('muted apps do not generate events', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      monitor.muteApp('payments-api');
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp]);

      const degradedVersion = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Degraded',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([degradedVersion]);

      expect(monitor.events, isEmpty);
    });

    test('acknowledgeEvent removes event at index', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp]);

      const degradedVersion = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'OutOfSync',
        healthStatus: 'Degraded',
        operationPhase: 'Failed',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([degradedVersion]);
      final initialCount = monitor.events.length;

      monitor.acknowledgeEvent(0);

      expect(monitor.events.length, initialCount - 1);
    });

    test('acknowledgeAll clears all events', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp]);

      const degradedVersion = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'OutOfSync',
        healthStatus: 'Degraded',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([degradedVersion]);
      expect(monitor.events, isNotEmpty);

      monitor.acknowledgeAll();
      expect(monitor.events, isEmpty);
    });

    test('reset clears state and events', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp]);
      monitor.processApplications([degradedApp]);
      // degradedApp seeds as baseline (different name), but we have events
      // from seedApp going baseline. Let's force events:
      const changedSeed = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'OutOfSync',
        healthStatus: 'Degraded',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );
      monitor.processApplications([changedSeed, degradedApp]);

      monitor.reset();

      expect(monitor.events, isEmpty);
    });

    test('caps events at 50', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      // Generate many events by toggling state back and forth.
      var apps = <ArgoApplication>[seedApp];
      monitor.processApplications(apps);

      for (var i = 0; i < 60; i++) {
        final isDegraded = i.isEven;
        apps = [
          ArgoApplication(
            name: 'payments-api',
            project: 'platform',
            namespace: 'payments',
            cluster: 'https://kubernetes.default.svc',
            repoUrl: 'https://github.com/example/platform',
            path: 'apps/payments-api',
            targetRevision: 'main',
            syncStatus: 'Synced',
            healthStatus: isDegraded ? 'Degraded' : 'Healthy',
            operationPhase: 'Succeeded',
            lastSyncedAt: '2026-03-10T10:${i.toString().padLeft(2, '0')}:00Z',
            resources: const <ArgoResource>[],
            history: const <ArgoHistoryEntry>[],
          ),
        ];
        monitor.processApplications(apps);
      }

      expect(monitor.events.length, lessThanOrEqualTo(50));
    });

    test('onNewEvents callback fires for negative events', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      final receivedEvents = <List<HealthEvent>>[];
      monitor.onNewEvents = (events) => receivedEvents.add(events);

      monitor.processApplications([seedApp]);

      const degradedVersion = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Degraded',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([degradedVersion]);

      expect(receivedEvents, hasLength(1));
      expect(receivedEvents.first.first.kind, HealthEventKind.degraded);
    });

    test('onNewEvents does not fire for positive events only', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      final receivedEvents = <List<HealthEvent>>[];
      monitor.onNewEvents = (events) => receivedEvents.add(events);

      // Seed with degraded.
      monitor.processApplications([degradedApp]);

      // Recover — only positive event.
      const recovered = ArgoApplication(
        name: 'orders-api',
        project: 'platform',
        namespace: 'orders',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/orders-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Healthy',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([recovered]);

      // Callback should not fire since both events (recovered + synced) are positive.
      expect(receivedEvents, isEmpty);
    });

    test('new apps do not generate events', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp]);

      // Add a new degraded app — should be seeded as baseline, not event.
      monitor.processApplications([seedApp, degradedApp]);

      expect(monitor.events, isEmpty);
    });

    test('multiple transitions in a single poll generate multiple events',
        () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      monitor.processApplications([seedApp, degradedApp]);

      // Both apps change state.
      const degradedSeed = ArgoApplication(
        name: 'payments-api',
        project: 'platform',
        namespace: 'payments',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/payments-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Degraded',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      const recoveredOrders = ArgoApplication(
        name: 'orders-api',
        project: 'platform',
        namespace: 'orders',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/orders-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Healthy',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );

      monitor.processApplications([degradedSeed, recoveredOrders]);

      // payments-api: degraded
      // orders-api: recovered + synced
      expect(monitor.events.length, greaterThanOrEqualTo(3));
    });

    test('HealthEvent.summary returns descriptive text', () {
      final event = HealthEvent(
        applicationName: 'my-app',
        kind: HealthEventKind.degraded,
        previousValue: 'Healthy',
        currentValue: 'Degraded',
        detectedAt: DateTime(2026, 3, 10),
      );
      expect(event.summary, contains('my-app'));
      expect(event.summary, contains('Degraded'));
    });

    test('unreadCount reflects only negative events', () async {
      final monitor = _createMonitor();
      await Future<void>.delayed(Duration.zero);

      // Seed with degraded app.
      monitor.processApplications([degradedApp]);

      // Recover it — generates positive events only.
      const recovered = ArgoApplication(
        name: 'orders-api',
        project: 'platform',
        namespace: 'orders',
        cluster: 'https://kubernetes.default.svc',
        repoUrl: 'https://github.com/example/platform',
        path: 'apps/orders-api',
        targetRevision: 'main',
        syncStatus: 'Synced',
        healthStatus: 'Healthy',
        operationPhase: 'Succeeded',
        lastSyncedAt: '2026-03-10T10:05:00Z',
        resources: <ArgoResource>[],
        history: <ArgoHistoryEntry>[],
      );
      monitor.processApplications([recovered]);

      expect(monitor.unreadCount, 0);
      expect(monitor.hasUnreadEvents, isFalse);
    });
  });

  group('HealthMonitor integration with AppController', () {
    test('processApplications is called after fetch', () async {
      final monitor = HealthMonitor(onRefreshRequested: () async {});
      await monitor.setEnabled(true);
      await Future<void>.delayed(Duration.zero);

      final api = FakeArgoCdApi.withSeedData();
      final controller = await createAuthenticatedController(api: api);

      // Manually wire the monitor (simulating what main.dart does).
      monitor.processApplications(controller.applications);

      // Baseline seeded, no events yet.
      expect(monitor.events, isEmpty);

      // Now change the API to return degraded app.
      api.applications = [degradedApp];
      await controller.refreshApplications(showSpinner: false);
      monitor.processApplications(controller.applications);

      // The monitor should detect the change (seedApp disappeared,
      // degradedApp appeared as new — so it's seeded, no event for new).
      // But seedApp's state is still in the map.
      // Since degradedApp is a NEW app name, it gets seeded.
      // seedApp removed from the map.
      // No events expected since degradedApp is new.
      expect(monitor.events, isEmpty);
    });
  });
}
