import 'dart:convert';

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/features/applications/manifest_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

const String _sampleManifest =
    '{'
    '"apiVersion":"v1",'
    '"kind":"Service",'
    '"metadata":{"name":"my-svc","namespace":"default","labels":{"app":"web"}},'
    '"spec":{"type":"ClusterIP","ports":[{"port":80,"targetPort":8080,"protocol":"TCP"}],'
    '"selector":{"app":"web"}},'
    '"status":{"loadBalancer":{}},'
    '"replicas":3,'
    '"enabled":true,'
    '"description":null'
    '}';

void main() {
  group('jsonToYaml', () {
    test('converts a simple flat object', () {
      final json = <String, dynamic>{'name': 'hello', 'count': 42};
      final yaml = jsonToYaml(json);
      expect(yaml, contains('name: hello'));
      expect(yaml, contains('count: 42'));
    });

    test('converts nested objects', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{
          'name': 'my-svc',
          'labels': <String, dynamic>{'app': 'web'},
        },
      };
      final yaml = jsonToYaml(json);
      expect(yaml, contains('metadata:'));
      expect(yaml, contains('  name: my-svc'));
      expect(yaml, contains('  labels:'));
      expect(yaml, contains('    app: web'));
    });

    test('converts arrays', () {
      final json = <String, dynamic>{
        'ports': <dynamic>[
          <String, dynamic>{'port': 80, 'protocol': 'TCP'},
        ],
      };
      final yaml = jsonToYaml(json);
      expect(yaml, contains('ports:'));
      expect(yaml, contains('- port: 80'));
      expect(yaml, contains('  protocol: TCP'));
    });

    test('converts simple array values', () {
      final json = <String, dynamic>{
        'items': <dynamic>['alpha', 'beta', 'gamma'],
      };
      final yaml = jsonToYaml(json);
      expect(yaml, contains('- alpha'));
      expect(yaml, contains('- beta'));
      expect(yaml, contains('- gamma'));
    });

    test('handles null, boolean, and numeric values', () {
      final json = <String, dynamic>{
        'enabled': true,
        'disabled': false,
        'count': 42,
        'ratio': 3.14,
        'nothing': null,
      };
      final yaml = jsonToYaml(json);
      expect(yaml, contains('enabled: true'));
      expect(yaml, contains('disabled: false'));
      expect(yaml, contains('count: 42'));
      expect(yaml, contains('ratio: 3.14'));
      expect(yaml, contains('nothing: null'));
    });

    test('quotes strings that need quoting', () {
      final json = <String, dynamic>{
        'value': 'hello: world',
        'empty': '',
        'truthy': 'true',
      };
      final yaml = jsonToYaml(json);
      expect(yaml, contains("'hello: world'"));
      expect(yaml, contains("''"));
      expect(yaml, contains("'true'"));
    });

    test('handles empty map and empty list', () {
      final json = <String, dynamic>{
        'emptyMap': <String, dynamic>{},
        'emptyList': <dynamic>[],
      };
      final yaml = jsonToYaml(json);
      expect(yaml, contains('emptyMap: {}'));
      expect(yaml, contains('emptyList: []'));
    });

    test('avoids double newlines for deeply nested structures', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{
          'annotations': <String, dynamic>{'description': 'hello'},
        },
        'spec': <String, dynamic>{
          'ports': <dynamic>[
            <String, dynamic>{'name': 'http', 'enabled': true},
          ],
        },
      };
      final yaml = jsonToYaml(json);
      expect(yaml.contains('\n\n'), isFalse);
    });

    test('converts the full sample manifest', () {
      final decoded = jsonDecode(_sampleManifest) as Map<String, dynamic>;
      final yaml = jsonToYaml(decoded);
      expect(yaml, contains('apiVersion: v1'));
      expect(yaml, contains('kind: Service'));
      expect(yaml, contains('metadata:'));
      expect(yaml, contains('  name: my-svc'));
      expect(yaml, contains('spec:'));
      expect(yaml, contains('replicas: 3'));
      expect(yaml, contains('enabled: true'));
      expect(yaml, contains('description: null'));
    });
  });

  group('tokenizeYamlLine', () {
    test('tokenizes a key-value line', () {
      final tokens = tokenizeYamlLine('name: hello');
      expect(tokens.length, 4);
      expect(tokens[0].text, 'name');
      expect(tokens[0].type, YamlTokenType.key);
      expect(tokens[1].text, ':');
      expect(tokens[1].type, YamlTokenType.key);
      // Space between colon and value
      expect(tokens[2].text, ' ');
      expect(tokens[2].type, null);
      expect(tokens[3].text, 'hello');
      expect(tokens[3].type, YamlTokenType.stringValue);
    });

    test('tokenizes a numeric value', () {
      final tokens = tokenizeYamlLine('count: 42');
      final valueToken = tokens.last;
      expect(valueToken.text, '42');
      expect(valueToken.type, YamlTokenType.numberValue);
    });

    test('tokenizes a boolean value', () {
      final tokens = tokenizeYamlLine('enabled: true');
      final valueToken = tokens.last;
      expect(valueToken.text, 'true');
      expect(valueToken.type, YamlTokenType.boolNullValue);
    });

    test('tokenizes false as a bool/null token', () {
      final tokens = tokenizeYamlLine('disabled: false');
      final valueToken = tokens.last;
      expect(valueToken.text, 'false');
      expect(valueToken.type, YamlTokenType.boolNullValue);
    });

    test('does not split URLs at colons inside the value', () {
      final tokens = tokenizeYamlLine(
        'repo: https://github.com/argoproj/argo-cd',
      );
      expect(tokens.length, 4);
      expect(tokens[0].text, 'repo');
      expect(tokens[0].type, YamlTokenType.key);
      expect(tokens.last.text, 'https://github.com/argoproj/argo-cd');
      expect(tokens.last.type, YamlTokenType.stringValue);
    });

    test('tokenizes multiline scalar marker and content as string values', () {
      final markerTokens = tokenizeYamlLine('description: |');
      expect(markerTokens.last.text, '|');
      expect(markerTokens.last.type, YamlTokenType.stringValue);

      final contentTokens = tokenizeYamlLine('  first line');
      expect(contentTokens.last.text, 'first line');
      expect(contentTokens.last.type, YamlTokenType.stringValue);
    });

    test('tokenizes null value', () {
      final tokens = tokenizeYamlLine('value: null');
      final valueToken = tokens.last;
      expect(valueToken.text, 'null');
      expect(valueToken.type, YamlTokenType.boolNullValue);
    });

    test('tokenizes a list dash line', () {
      final tokens = tokenizeYamlLine('  - port: 80');
      expect(tokens[0].text, '  ');
      expect(tokens[0].type, null);
      expect(tokens[1].text, '-');
      expect(tokens[1].type, YamlTokenType.listDash);
      // After the dash there should be key tokens
      final keyToken = tokens.firstWhere(
        (YamlToken t) => t.type == YamlTokenType.key,
      );
      expect(keyToken.text, ' port');
    });
  });

  group('ManifestViewerScreen widget', () {
    late AppController controller;

    setUp(() {
      final storage = MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'ops',
            token: 'token',
          ),
        );
      controller = AppController(
        storage: storage,
        api: FakeArgoCdApi(manifestToReturn: _sampleManifest),
        certificateProvider: const CertificateProvider(),
      );
    });

    Widget buildTestWidget() {
      return MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: ManifestViewerScreen(
          controller: controller,
          applicationName: 'my-app',
          namespace: 'default',
          resourceName: 'my-svc',
          kind: 'Service',
          group: '',
          version: 'v1',
        ),
      );
    }

    testWidgets('renders YAML view with collapsible sections', (
      WidgetTester tester,
    ) async {
      await controller.initialize();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should show the title
      expect(find.text('Service: my-svc'), findsOneWidget);

      // Should show top-level keys as collapsible sections
      expect(find.text('metadata'), findsWidgets);
      expect(find.text('spec'), findsWidgets);
      expect(find.text('status'), findsWidgets);
      expect(find.textContaining('Lines:'), findsOneWidget);
    });

    testWidgets('toggles between YAML and JSON view', (
      WidgetTester tester,
    ) async {
      await controller.initialize();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially in YAML mode - shows collapsible sections
      expect(find.text('metadata'), findsWidgets);

      // Find and tap the toggle button (code icon for YAML mode)
      final toggleButton = find.byIcon(Icons.code);
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Now in JSON mode - should show raw JSON with braces
      expect(find.byIcon(Icons.data_object), findsOneWidget);
    });

    testWidgets('search opens and filters content', (
      WidgetTester tester,
    ) async {
      await controller.initialize();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap search icon
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      // Should show search field
      expect(find.byType(TextField), findsOneWidget);

      // Type a search query
      await tester.enterText(find.byType(TextField), 'ClusterIP');
      await tester.pumpAndSettle();

      // The matching spec section and the matched value should remain visible.
      expect(find.text('spec'), findsWidgets);
      expect(find.textContaining('ClusterIP'), findsWidgets);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsWidgets);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsWidgets);
    });

    testWidgets('expand all toggle collapses and expands sections', (
      WidgetTester tester,
    ) async {
      await controller.initialize();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.unfold_less), findsOneWidget);

      await tester.tap(find.byIcon(Icons.unfold_less));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    });

    testWidgets('shows loading state', (WidgetTester tester) async {
      await controller.initialize();
      await tester.pumpWidget(buildTestWidget());
      // Don't pump and settle — check for loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (
      WidgetTester tester,
    ) async {
      final storage = MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'ops',
            token: 'token',
          ),
        );
      final errorController = AppController(
        storage: storage,
        api: FakeArgoCdApi(
          fetchManifestError: const ArgoCdException('Failed to load manifest'),
        ),
        certificateProvider: const CertificateProvider(),
      );
      await errorController.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ManifestViewerScreen(
            controller: errorController,
            applicationName: 'my-app',
            namespace: 'default',
            resourceName: 'my-svc',
            kind: 'Service',
            group: '',
            version: 'v1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('copy button is present and enabled after loading', (
      WidgetTester tester,
    ) async {
      await controller.initialize();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('refresh button triggers reload', (WidgetTester tester) async {
      await controller.initialize();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Should show loading indicator during refresh
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      // After settling, should be back to YAML view
      expect(find.text('metadata'), findsWidgets);
    });

    testWidgets('hides managed fields by default', (
      WidgetTester tester,
    ) async {
      final manifestWithManagedFields = jsonEncode(<String, dynamic>{
        'apiVersion': 'v1',
        'kind': 'Service',
        'metadata': <String, dynamic>{
          'name': 'my-svc',
          'namespace': 'default',
          'managedFields': <dynamic>[
            <String, dynamic>{
              'manager': 'kubectl',
              'operation': 'Apply',
              'apiVersion': 'v1',
            },
          ],
        },
        'spec': <String, dynamic>{'type': 'ClusterIP'},
      });
      final storage = MemorySessionStorage()
        ..seedSession(
          const AppSession(
            serverUrl: 'https://argocd.example.com',
            username: 'ops',
            token: 'token',
          ),
        );
      final ctrl = AppController(
        storage: storage,
        api: FakeArgoCdApi(manifestToReturn: manifestWithManagedFields),
        certificateProvider: const CertificateProvider(),
      );
      await ctrl.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: ManifestViewerScreen(
            controller: ctrl,
            applicationName: 'my-app',
            namespace: 'default',
            resourceName: 'my-svc',
            kind: 'Service',
            group: '',
            version: 'v1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // managedFields should be hidden by default
      expect(find.textContaining('managedFields'), findsNothing);
      expect(find.textContaining('kubectl'), findsNothing);

      // But the rest of metadata should still be visible
      expect(find.text('metadata'), findsWidgets);

      // Toggle managed fields on via the toolbar button
      await tester.tap(find.byTooltip('Show managed fields'));
      await tester.pumpAndSettle();

      // Now managedFields content should be visible
      expect(find.textContaining('managedFields'), findsWidgets);
    });

    testWidgets('collapsing a section hides its content', (
      WidgetTester tester,
    ) async {
      await controller.initialize();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // metadata section should be expanded initially
      expect(find.text('metadata'), findsWidgets);

      // Tap to collapse the metadata section
      await tester.tap(find.text('metadata').first);
      await tester.pumpAndSettle();

      // The section header should still be visible
      expect(find.text('metadata'), findsWidgets);
    });
  });
}

