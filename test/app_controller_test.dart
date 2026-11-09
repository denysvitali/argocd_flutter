import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  test('SSO signs in and persists the returned session', () async {
    final storage = MemorySessionStorage();
    final controller = AppController(
      storage: storage,
      api: FakeArgoCdApi.withSeedData(),
      certificateProvider: const CertificateProvider(),
      ssoSignIn: (url) async {
        expect(url, testSession.serverUrl);
        return testSession;
      },
    );
    await controller.initialize();
    await controller.signInWithSso(serverUrl: ' ${testSession.serverUrl} ');
    expect(controller.stage, AppStage.authenticated);
    expect((await storage.loadSession())?.token, testSession.token);
    expect(controller.applications, isNotEmpty);
  });

  test('SSO failure remains signed out and displays the error', () async {
    final controller = AppController(
      storage: MemorySessionStorage(),
      api: FakeArgoCdApi(),
      certificateProvider: const CertificateProvider(),
      ssoSignIn: (_) async => throw const ArgoCdException('SSO failed'),
    );
    await controller.initialize();
    await expectLater(
      controller.signInWithSso(serverUrl: testSession.serverUrl),
      throwsA(isA<ArgoCdException>()),
    );
    expect(controller.stage, AppStage.unauthenticated);
    expect(controller.errorMessage, 'SSO failed');
    expect(controller.busy, isFalse);
  });

  test('initial state is AppStage.booting', () {
    final controller = createTestController();
    expect(controller.stage, AppStage.booting);
    expect(controller.busy, isFalse);
    expect(controller.applications, isEmpty);
    expect(controller.projects, isEmpty);
    expect(controller.session, isNull);
    expect(controller.errorMessage, isNull);
  });

  test(
    'initialize() with no saved session transitions to unauthenticated',
    () async {
      final controller = createTestController();

      await controller.initialize();

      expect(controller.stage, AppStage.unauthenticated);
      expect(controller.session, isNull);
      expect(controller.applications, isEmpty);
      expect(controller.projects, isEmpty);
    },
  );

  test('initialize() with saved session transitions to authenticated '
      'and loads data', () async {
    final storage = MemorySessionStorage()..seedSession(testSession);
    final api = FakeArgoCdApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final controller = createTestController(storage: storage, api: api);

    await controller.initialize();

    expect(controller.stage, AppStage.authenticated);
    expect(controller.session, isNotNull);
    expect(controller.session!.serverUrl, testSession.serverUrl);
    expect(controller.applications, hasLength(1));
    expect(controller.applications.first.name, 'payments-api');
    expect(controller.projects, hasLength(1));
    expect(controller.projects.first.name, 'platform');
    expect(controller.hasLoadedApplications, isTrue);
    expect(controller.hasLoadedProjects, isTrue);
  });

  test(
    'signIn() with valid credentials transitions to authenticated',
    () async {
      final api = FakeArgoCdApi(
        applications: <ArgoApplication>[seedApp],
        projects: <ArgoProject>[seedProject],
      );
      final storage = MemorySessionStorage();
      final controller = createTestController(storage: storage, api: api);
      await controller.initialize();

      expect(controller.stage, AppStage.unauthenticated);

      await controller.signIn(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        password: 'password',
      );

      expect(controller.stage, AppStage.authenticated);
      expect(controller.session, isNotNull);
      expect(controller.session!.token, 'fake-token');
      expect(controller.applications, hasLength(1));
      expect(controller.projects, hasLength(1));
      expect(controller.errorMessage, isNull);
      expect(controller.busy, isFalse);

      // Verify session was persisted
      final savedSession = await storage.loadSession();
      expect(savedSession, isNotNull);
      expect(savedSession!.token, 'fake-token');
    },
  );

  test('signIn() with invalid credentials sets error message', () async {
    final api = FakeArgoCdApi(
      signInError: const ArgoCdException('Invalid username or password'),
    );
    final controller = createTestController(api: api);
    await controller.initialize();

    expect(
      () => controller.signIn(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        password: 'wrong',
      ),
      throwsA(isA<ArgoCdException>()),
    );

    // Wait for microtasks to settle
    await Future<void>.delayed(Duration.zero);

    expect(controller.stage, AppStage.unauthenticated);
    expect(controller.errorMessage, 'Invalid username or password');
    expect(controller.busy, isFalse);
    expect(controller.session, isNull);
  });

  test('signOut() clears session and transitions to unauthenticated', () async {
    final storage = MemorySessionStorage()..seedSession(testSession);
    final api = FakeArgoCdApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final controller = createTestController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.stage, AppStage.authenticated);

    await controller.signOut();

    expect(controller.stage, AppStage.unauthenticated);
    expect(controller.session, isNull);
    expect(controller.applications, isEmpty);
    expect(controller.projects, isEmpty);
    expect(controller.hasLoadedApplications, isFalse);
    expect(controller.hasLoadedProjects, isFalse);
    expect(controller.errorMessage, isNull);

    // Verify session was cleared from storage
    final savedSession = await storage.loadSession();
    expect(savedSession, isNull);
  });

  test('refreshApplications() updates the application list', () async {
    final api = FakeArgoCdApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = MemorySessionStorage()..seedSession(testSession);
    final controller = createTestController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.applications, hasLength(1));

    // Update the API to return a second application
    api.applications = <ArgoApplication>[seedApp, degradedApp];

    await controller.refreshApplications();

    expect(controller.applications, hasLength(2));
    expect(controller.applications[1].name, 'orders-api');
    expect(controller.busy, isFalse);
    expect(controller.loadingApplications, isFalse);
    expect(controller.hasLoadedApplications, isTrue);
  });

  test('refreshProjects() updates the project list', () async {
    final api = FakeArgoCdApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = MemorySessionStorage()..seedSession(testSession);
    final controller = createTestController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.projects, hasLength(1));

    const secondProject = ArgoProject(
      name: 'staging',
      description: 'Staging project',
      sourceRepos: <String>['*'],
      destinations: <ArgoProjectDestination>[],
      clusterResourceWhitelist: <ArgoProjectClusterResource>[],
    );
    api.projects = <ArgoProject>[seedProject, secondProject];

    await controller.refreshProjects();

    expect(controller.projects, hasLength(2));
    expect(controller.projects[1].name, 'staging');
    expect(controller.busy, isFalse);
    expect(controller.loadingProjects, isFalse);
    expect(controller.hasLoadedProjects, isTrue);
  });

  test('syncApplication() calls the API correctly', () async {
    final api = FakeArgoCdApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = MemorySessionStorage()..seedSession(testSession);
    final controller = createTestController(storage: storage, api: api);
    await controller.initialize();

    await controller.syncApplication('payments-api');

    expect(api.syncedApplications, contains('payments-api'));
    expect(controller.busy, isFalse);
    // Applications should have been refreshed after sync
    expect(controller.hasLoadedApplications, isTrue);
  });

  test('deleteApplication() removes from list on success', () async {
    final api = FakeArgoCdApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final storage = MemorySessionStorage()..seedSession(testSession);
    final controller = createTestController(storage: storage, api: api);
    await controller.initialize();

    expect(controller.applications, hasLength(1));

    // Configure the fake to remove the app on delete and return empty list
    api.onDelete = (String name) {
      api.applications = <ArgoApplication>[];
    };

    await controller.deleteApplication('payments-api');

    expect(api.deletedApplications, contains('payments-api'));
    expect(controller.applications, isEmpty);
    expect(controller.busy, isFalse);
  });

  test(
    'initialize() with expired saved session falls back to unauthenticated',
    () async {
      final storage = MemorySessionStorage()..seedSession(testSession);
      final api = FakeArgoCdApi(
        fetchApplicationsError: const ArgoCdException('Unauthorized'),
      );
      final controller = createTestController(storage: storage, api: api);

      await controller.initialize();

      expect(controller.stage, AppStage.unauthenticated);
      expect(controller.session, isNull);
      expect(controller.errorMessage, 'Saved session expired. Sign in again.');
    },
  );

  test('concurrent busy action throws ArgoCdException', () async {
    final storage = MemorySessionStorage()..seedSession(testSession);
    final api = FakeArgoCdApi(
      applications: <ArgoApplication>[seedApp],
      projects: <ArgoProject>[seedProject],
    );
    final controller = createTestController(storage: storage, api: api);
    await controller.initialize();

    // First call starts the busy action
    final firstCall = controller.refreshApplications(showSpinner: true);

    // Second call while busy should throw
    expect(
      () => controller.refreshApplications(showSpinner: true),
      throwsA(isA<ArgoCdException>()),
    );

    // Let the first call finish
    await firstCall;
    expect(controller.busy, isFalse);
  });
}
