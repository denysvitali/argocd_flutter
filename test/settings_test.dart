import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/features/auth/sign_in_screen.dart';
import 'package:argocd_flutter/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testSession = AppSession(
    serverUrl: 'https://argocd.example.com',
    username: 'admin',
    token: 'test-token',
  );

  AppController createAuthenticatedController() {
    final storage = _MemorySessionStorage()..seedSession(testSession);
    return AppController(
      storage: storage,
      api: _FakeArgoCdApi.withSeedData(),
      certificateProvider: const CertificateProvider(),
    );
  }

  AppController createUnauthenticatedController({String lastServerUrl = ''}) {
    final storage = _MemorySessionStorage();
    if (lastServerUrl.isNotEmpty) {
      storage.seedServerUrl(lastServerUrl);
    }
    return AppController(
      storage: storage,
      api: _FakeArgoCdApi(),
      certificateProvider: const CertificateProvider(),
    );
  }

  Widget wrapSettings({
    required AppController controller,
    required ThemeController themeController,
  }) {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[controller, themeController]),
        builder: (context, _) {
          return SettingsScreen(
            controller: controller,
            themeController: themeController,
          );
        },
      ),
    );
  }

  Widget wrapSignIn({required AppController controller}) {
    return MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return SignInScreen(controller: controller);
        },
      ),
    );
  }

  group('SettingsScreen', () {
    testWidgets('renders top sections (Appearance and Connection)', (
      WidgetTester tester,
    ) async {
      final controller = createAuthenticatedController();
      await controller.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(
        wrapSettings(controller: controller, themeController: themeController),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Connection'), findsOneWidget);
    });

    testWidgets('renders connection info with server and username', (
      WidgetTester tester,
    ) async {
      final controller = createAuthenticatedController();
      await controller.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(
        wrapSettings(controller: controller, themeController: themeController),
      );
      await tester.pumpAndSettle();

      expect(find.text('https://argocd.example.com'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
      expect(find.text('Authenticated'), findsOneWidget);
    });

    testWidgets('theme picker shows system, light, and dark options', (
      WidgetTester tester,
    ) async {
      final controller = createAuthenticatedController();
      await controller.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(
        wrapSettings(controller: controller, themeController: themeController),
      );
      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('tapping theme card changes theme mode', (
      WidgetTester tester,
    ) async {
      final controller = createAuthenticatedController();
      await controller.initialize();
      final themeController = ThemeController();
      expect(themeController.themeMode, ThemeMode.system);

      await tester.pumpWidget(
        wrapSettings(controller: controller, themeController: themeController),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(themeController.themeMode, ThemeMode.dark);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(themeController.themeMode, ThemeMode.light);
    });

    testWidgets('sign-out button shows confirmation dialog', (
      WidgetTester tester,
    ) async {
      final controller = createAuthenticatedController();
      await controller.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(
        wrapSettings(controller: controller, themeController: themeController),
      );
      await tester.pumpAndSettle();

      // Scroll to the Sign out button
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Are you sure you want to sign out? You will need to '
          'enter your credentials again to reconnect.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      // Dialog title + dialog action button + original button behind = 3
      expect(find.text('Sign out'), findsNWidgets(3));
    });

    testWidgets('cancel on sign-out dialog does not sign out', (
      WidgetTester tester,
    ) async {
      final controller = createAuthenticatedController();
      await controller.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(
        wrapSettings(controller: controller, themeController: themeController),
      );
      await tester.pumpAndSettle();

      // Scroll to the Sign out button
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.stage, AppStage.authenticated);
      expect(controller.session, isNotNull);
    });

    testWidgets('about section shows version info', (
      WidgetTester tester,
    ) async {
      final controller = createAuthenticatedController();
      await controller.initialize();
      final themeController = ThemeController();

      await tester.pumpWidget(
        wrapSettings(controller: controller, themeController: themeController),
      );
      await tester.pumpAndSettle();

      // Scroll to the About section
      await tester.scrollUntilVisible(
        find.text('About'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('About'), findsOneWidget);
      expect(find.text('v1.0.0+1'), findsOneWidget);
    });
  });

  group('SignInScreen', () {
    testWidgets('renders form fields and buttons', (WidgetTester tester) async {
      final controller = createUnauthenticatedController();
      await controller.initialize();

      await tester.pumpWidget(wrapSignIn(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Connect to ArgoCD'), findsOneWidget);
      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Test server'), findsOneWidget);
    });

    testWidgets('form validation shows errors for empty fields', (
      WidgetTester tester,
    ) async {
      final controller = createUnauthenticatedController();
      await controller.initialize();

      await tester.pumpWidget(wrapSignIn(controller: controller));
      await tester.pumpAndSettle();

      // Scroll to the Sign In button and tap
      await tester.scrollUntilVisible(
        find.text('Sign In'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the ArgoCD server URL.'), findsOneWidget);
      expect(find.text('Enter your ArgoCD username.'), findsOneWidget);
      expect(find.text('Enter your ArgoCD password.'), findsOneWidget);
    });

    testWidgets('server URL validation rejects invalid URLs', (
      WidgetTester tester,
    ) async {
      final controller = createUnauthenticatedController();
      await controller.initialize();

      await tester.pumpWidget(wrapSignIn(controller: controller));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Server URL'),
        'not-a-url',
      );

      // Scroll to Sign In button
      await tester.scrollUntilVisible(
        find.text('Sign In'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid HTTP or HTTPS URL.'), findsOneWidget);
    });

    testWidgets('password visibility toggle works', (
      WidgetTester tester,
    ) async {
      final controller = createUnauthenticatedController();
      await controller.initialize();

      await tester.pumpWidget(wrapSignIn(controller: controller));
      await tester.pumpAndSettle();

      // Password field should be obscured initially
      EditableText editableText() => tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(editableText().obscureText, isTrue);

      // Tap the visibility toggle
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();

      // Password should now be visible
      expect(editableText().obscureText, isFalse);

      // Tap again to hide
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();

      expect(editableText().obscureText, isTrue);
    });

    testWidgets('remembered server URL shows bookmark icon', (
      WidgetTester tester,
    ) async {
      final controller = createUnauthenticatedController(
        lastServerUrl: 'https://argocd.example.com',
      );
      await controller.initialize();

      await tester.pumpWidget(wrapSignIn(controller: controller));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip(
          'This URL was saved from your '
          'previous session and will be '
          'pre-filled on future sign-ins',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays app logo area', (WidgetTester tester) async {
      final controller = createUnauthenticatedController();
      await controller.initialize();

      await tester.pumpWidget(wrapSignIn(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('ArgoCD Flutter'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MemorySessionStorage implements SessionStorage {
  AppSession? _session;
  String? _serverUrl;

  @override
  Future<void> clearSession() async {
    _session = null;
  }

  @override
  Future<String?> loadLastServerUrl() async => _serverUrl;

  @override
  Future<AppSession?> loadSession() async => _session;

  @override
  Future<void> saveLastServerUrl(String serverUrl) async {
    _serverUrl = serverUrl;
  }

  @override
  Future<void> saveSession(AppSession session) async {
    _session = session;
    _serverUrl = session.serverUrl;
  }

  void seedSession(AppSession session) {
    _session = session;
    _serverUrl = session.serverUrl;
  }

  void seedServerUrl(String serverUrl) {
    _serverUrl = serverUrl;
  }
}

class _FakeArgoCdApi implements ArgoCdApi {
  _FakeArgoCdApi({
    List<ArgoApplication> applications = const <ArgoApplication>[],
    List<ArgoProject> projects = const <ArgoProject>[],
  }) : _applications = applications,
       _projects = projects;

  _FakeArgoCdApi.withSeedData()
    : _applications = const <ArgoApplication>[
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
          resources: <ArgoResource>[],
          history: <ArgoHistoryEntry>[],
        ),
      ],
      _projects = const <ArgoProject>[
        ArgoProject(
          name: 'platform',
          description: 'Platform services',
          sourceRepos: <String>['https://github.com/example/platform'],
          destinations: <ArgoProjectDestination>[
            ArgoProjectDestination(
              server: 'https://kubernetes.default.svc',
              namespace: 'payments',
              name: 'in-cluster',
            ),
          ],
          clusterResourceWhitelist: <ArgoProjectClusterResource>[],
        ),
      ];

  final List<ArgoApplication> _applications;
  final List<ArgoProject> _projects;

  @override
  Future<ArgoApplication> fetchApplication(
    AppSession session,
    String applicationName, {
    bool refresh = false,
  }) async {
    return _applications.firstWhere(
      (application) => application.name == applicationName,
    );
  }

  @override
  Future<List<ArgoApplication>> fetchApplications(AppSession session) async {
    return _applications;
  }

  @override
  Future<ArgoProject> fetchProject(
    AppSession session,
    String projectName,
  ) async {
    return _projects.firstWhere((project) => project.name == projectName);
  }

  @override
  Future<List<ArgoProject>> fetchProjects(AppSession session) async {
    return _projects;
  }

  @override
  Future<List<ArgoResourceNode>> fetchResourceTree(
    AppSession session,
    String applicationName,
  ) async {
    return const <ArgoResourceNode>[];
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
    return '';
  }

  @override
  Future<void> deleteApplication(
    AppSession session,
    String applicationName, {
    bool cascade = true,
  }) async {}

  @override
  Future<void> rollbackApplication(
    AppSession session,
    String applicationName,
    int historyId,
  ) async {}

  @override
  Future<AppSession> signIn({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    return AppSession(serverUrl: serverUrl, username: username, token: 'token');
  }

  @override
  Future<void> syncApplication(
    AppSession session,
    String applicationName,
  ) async {}

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
    return '';
  }

  @override
  Future<List<ManagedResource>> fetchManagedResources(
    AppSession session,
    String applicationName,
  ) async {
    return const <ManagedResource>[];
  }

  @override
  Future<void> deleteResource(
    AppSession session, {
    required String applicationName,
    required String namespace,
    required String resourceName,
    required String kind,
    required String group,
    required String version,
    bool force = false,
  }) => Future<void>.value();

  @override
  Future<void> verifyServer(String serverUrl) async {}
}
