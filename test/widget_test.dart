import 'package:argocd_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders ArgoCD overview', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ArgoCdApp());

    expect(find.text('ArgoCD Flutter'), findsOneWidget);
    expect(find.text('GitOps dashboard'), findsOneWidget);
    expect(find.text('Argo CD control plane in your pocket'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
  });
}
