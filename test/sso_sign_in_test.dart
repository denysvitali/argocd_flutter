import 'dart:async';

import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/features/auth/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

class _SsoController extends AppController {
  _SsoController()
    : super(
        storage: MemorySessionStorage(),
        api: FakeArgoCdApi(),
        certificateProvider: const CertificateProvider(),
      );

  String? submittedServer;
  final completion = Completer<void>();

  @override
  bool get busy => submittedServer != null && !completion.isCompleted;

  @override
  Future<void> signInWithSso({required String serverUrl}) async {
    submittedServer = serverUrl;
    notifyListeners();
    await completion.future;
    notifyListeners();
  }
}

void main() {
  testWidgets('SSO validates server without requiring username or password', (
    tester,
  ) async {
    final controller = _SsoController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => SignInScreen(controller: controller),
        ),
      ),
    );

    final sso = find.widgetWithText(OutlinedButton, 'Sign in with SSO');
    await tester.ensureVisible(sso);
    await tester.tap(sso);
    await tester.pump();
    expect(controller.submittedServer, isNull);
    expect(find.text('Enter the ArgoCD server URL.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).first,
      'https://argocd.example.com',
    );
    await tester.ensureVisible(sso);
    await tester.tap(sso);
    await tester.pump();
    expect(controller.submittedServer, 'https://argocd.example.com');
    expect(find.text('Enter your ArgoCD username.'), findsNothing);
    expect(find.text('Enter your ArgoCD password.'), findsNothing);
    expect(tester.widget<OutlinedButton>(sso).onPressed, isNull);
    controller.completion.complete();
    await tester.pumpAndSettle();
  });
}
