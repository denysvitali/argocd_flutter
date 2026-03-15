@Tags(<String>['golden'])
library;

import 'package:argocd_flutter/ui/app_root.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'golden_test_helpers.dart';

void main() {
  testGoldens('shared widgets match light theme', (WidgetTester tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'StatusChip — Healthy',
        const StatusChip(label: 'Healthy', color: Color(0xFF14B8A6)),
      )
      ..addScenario(
        'StatusChip — Degraded',
        const StatusChip(label: 'Degraded', color: Color(0xFFFF6B57)),
      )
      ..addScenario(
        'StatusChip — Synced',
        const StatusChip(label: 'Synced', color: Color(0xFF1F6FEB)),
      )
      ..addScenario(
        'SectionCard — with title',
        const SectionCard(
          title: 'Summary',
          child: Text('Section child content goes here.'),
        ),
      )
      ..addScenario(
        'SectionCard — without title',
        const SectionCard(child: Text('Card with no title.')),
      )
      ..addScenario(
        'EmptyStateCard',
        const EmptyStateCard(
          title: 'No Applications',
          subtitle: 'Deploy your first application to get started.',
        ),
      )
      ..addScenario(
        'SummaryTile — with color',
        const SummaryTile(
          label: 'Healthy',
          value: 12,
          valueColor: Color(0xFF14B8A6),
        ),
      )
      ..addScenario(
        'SummaryTile — zero value',
        const SummaryTile(label: 'Degraded', value: 0),
      )
      ..addScenario(
        'FactBadge — cluster',
        const FactBadge(
          icon: Icons.dns_outlined,
          label: 'in-cluster',
        ),
      )
      ..addScenario(
        'FactBadge — path',
        const FactBadge(
          icon: Icons.folder_outlined,
          label: 'apps/payments-api',
        ),
      )
      ..addScenario(
        'ErrorRetryWidget',
        ErrorRetryWidget(
          message: 'Failed to connect to ArgoCD server.',
          onRetry: () {},
        ),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: (Widget child) => MaterialApp(
        theme: buildLightAppTheme(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
      surfaceSize: const Size(430, 1800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'shared_widgets_light');
  });

  testGoldens('shared widgets match dark theme', (WidgetTester tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'StatusChip — Healthy',
        const StatusChip(label: 'Healthy', color: Color(0xFF14B8A6)),
      )
      ..addScenario(
        'StatusChip — Degraded',
        const StatusChip(label: 'Degraded', color: Color(0xFFFF6B57)),
      )
      ..addScenario(
        'StatusChip — Synced',
        const StatusChip(label: 'Synced', color: Color(0xFF1F6FEB)),
      )
      ..addScenario(
        'SectionCard — with title',
        const SectionCard(
          title: 'Summary',
          child: Text('Section child content goes here.'),
        ),
      )
      ..addScenario(
        'SectionCard — without title',
        const SectionCard(child: Text('Card with no title.')),
      )
      ..addScenario(
        'EmptyStateCard',
        const EmptyStateCard(
          title: 'No Applications',
          subtitle: 'Deploy your first application to get started.',
        ),
      )
      ..addScenario(
        'SummaryTile — with color',
        const SummaryTile(
          label: 'Healthy',
          value: 12,
          valueColor: Color(0xFF14B8A6),
        ),
      )
      ..addScenario(
        'SummaryTile — zero value',
        const SummaryTile(label: 'Degraded', value: 0),
      )
      ..addScenario(
        'FactBadge — cluster',
        const FactBadge(
          icon: Icons.dns_outlined,
          label: 'in-cluster',
        ),
      )
      ..addScenario(
        'FactBadge — path',
        const FactBadge(
          icon: Icons.folder_outlined,
          label: 'apps/payments-api',
        ),
      )
      ..addScenario(
        'ErrorRetryWidget',
        ErrorRetryWidget(
          message: 'Failed to connect to ArgoCD server.',
          onRetry: () {},
        ),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: (Widget child) => MaterialApp(
        themeMode: ThemeMode.dark,
        theme: buildLightAppTheme(),
        darkTheme: buildDarkAppTheme(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
      surfaceSize: const Size(430, 1800),
    );
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'shared_widgets_dark');
  });
}
