import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const ArgoCdApp());
}

class ArgoCdApp extends StatelessWidget {
  const ArgoCdApp({super.key});

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFFF6F9FC);
    const ink = Color(0xFF0E1726);
    const cobalt = Color(0xFF1F6FEB);
    const teal = Color(0xFF14B8A6);

    final baseTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.light(
        primary: cobalt,
        secondary: teal,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ink,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme().copyWith(
        bodyMedium: GoogleFonts.dmSans(color: ink, fontSize: 16),
        bodyLarge: GoogleFonts.dmSans(color: ink, fontSize: 18),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ArgoCD Flutter',
      theme: baseTheme.copyWith(
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: const ArgoCdHomePage(),
    );
  }
}

class ArgoCdHomePage extends StatelessWidget {
  const ArgoCdHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 880;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF6F9FC),
              Color(0xFFE9F2FF),
              Color(0xFFFFF4E8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const _HeroBanner(),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      for (final card in _overviewCards)
                        SizedBox(
                          width: isWide ? 364 : double.infinity,
                          child: _OverviewCard(card: card),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Expanded(child: _PipelinePanel()),
                        SizedBox(width: 20),
                        Expanded(child: _ReleasePanel()),
                      ],
                    )
                  else
                    const Column(
                      children: [
                        _PipelinePanel(),
                        SizedBox(height: 20),
                        _ReleasePanel(),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Argo CD control plane in your pocket',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This starter app gives you a branded shell, local '
                    'devenv setup, and GitHub Actions ready for analysis, '
                    'tests, APK builds, and web builds.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF465467),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF0E1726),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0E1726),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0x1FFFFFFF),
            ),
            child: Text(
              'GitOps dashboard',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ArgoCD Flutter',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Track sync health, review rollout status, and surface delivery '
            'risk without being tied to the desktop UI.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFFD8E5FF),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(
                label: 'Managed clusters',
                value: '12',
                accent: Color(0xFF14B8A6),
              ),
              _MetricChip(
                label: 'Apps in sync',
                value: '184',
                accent: Color(0xFF1F6FEB),
              ),
              _MetricChip(
                label: 'Needs review',
                value: '7',
                accent: Color(0xFFFF6B57),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0x1AFFFFFF),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFD8E5FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.card});

  final _OverviewCardData card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE3EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(card.icon, color: card.tint, size: 28),
          const SizedBox(height: 20),
          Text(
            card.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF526071),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            card.stat,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: card.tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelinePanel extends StatelessWidget {
  const _PipelinePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promotion flow',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          for (final step in _pipelineSteps) ...[
            _PipelineStep(step: step),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  const _PipelineStep({required this.step});

  final _PipelineStepData step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: step.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF526071),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReleasePanel extends StatelessWidget {
  const _ReleasePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF5FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Release watch',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          const _StatusRow(
            label: 'edge-eu-west-1',
            status: 'Healthy',
            color: Color(0xFF14B8A6),
          ),
          const Divider(height: 28),
          const _StatusRow(
            label: 'payments-prod',
            status: 'Progressing',
            color: Color(0xFF1F6FEB),
          ),
          const Divider(height: 28),
          const _StatusRow(
            label: 'checkout-canary',
            status: 'Degraded',
            color: Color(0xFFFF6B57),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.status,
    required this.color,
  });

  final String label;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewCardData {
  const _OverviewCardData({
    required this.icon,
    required this.title,
    required this.description,
    required this.stat,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String description;
  final String stat;
  final Color tint;
}

class _PipelineStepData {
  const _PipelineStepData({
    required this.title,
    required this.description,
    required this.color,
  });

  final String title;
  final String description;
  final Color color;
}

const List<_OverviewCardData> _overviewCards = [
  _OverviewCardData(
    icon: Icons.hub_rounded,
    title: 'Application graph',
    description:
        'Cluster, namespace, and app rollouts grouped for fast '
        'triage when sync drift starts spreading.',
    stat: '23 apps changed in the last hour',
    tint: Color(0xFF1F6FEB),
  ),
  _OverviewCardData(
    icon: Icons.rule_folder_outlined,
    title: 'Policy signals',
    description:
        'Surface blocked promotions, failed health checks, and '
        'manual sync requests before they hit production.',
    stat: '4 policy gates waiting on approval',
    tint: Color(0xFFFF6B57),
  ),
  _OverviewCardData(
    icon: Icons.lock_clock_outlined,
    title: 'Audit clarity',
    description:
        'Keep a clean record of who synced what, when the revision '
        'changed, and which environments moved together.',
    stat: '99.98% successful syncs this week',
    tint: Color(0xFF14B8A6),
  ),
];

const List<_PipelineStepData> _pipelineSteps = [
  _PipelineStepData(
    title: 'Commit merged',
    description:
        'Track the Git revision that triggered the latest manifest '
        'reconciliation cycle.',
    color: Color(0xFF1F6FEB),
  ),
  _PipelineStepData(
    title: 'Preview synced',
    description:
        'Verify rollout timing and health probes before promotion '
        'moves to production.',
    color: Color(0xFF14B8A6),
  ),
  _PipelineStepData(
    title: 'Manual hold',
    description:
        'Pause risky changes with a visible approval checkpoint for '
        'operators on call.',
    color: Color(0xFFFF6B57),
  ),
];
