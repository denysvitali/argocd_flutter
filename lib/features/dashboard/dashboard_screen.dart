import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onOpenApplication,
  });

  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final applications = controller.applications;
        final totalApps = applications.length;
        final healthyCount = applications
            .where(
              (application) =>
                  _normalized(application.healthStatus) == 'healthy',
            )
            .length;
        final outOfSyncCount = applications
            .where(
              (application) => _normalized(application.syncStatus) != 'synced',
            )
            .length;
        final degradedCount = applications
            .where(
              (application) =>
                  _normalized(application.healthStatus) == 'degraded',
            )
            .length;
        final healthSegments = _buildHealthSegments(applications);
        final syncSegments = _buildSyncSegments(applications);
        final needsAttention = applications
            .where(
              (application) =>
                  _normalized(application.syncStatus) != 'synced' ||
                  _normalized(application.healthStatus) != 'healthy',
            )
            .toList(growable: false);

        return Scaffold(
          appBar: AppBar(title: const Text('Dashboard')),
          body: RefreshIndicator(
            onRefresh: () => controller.refreshApplications(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                _SectionCard(
                  title: 'Summary',
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: <Widget>[
                      _SummaryTile(label: 'Total Apps', value: totalApps),
                      _SummaryTile(
                        label: 'Healthy',
                        value: healthyCount,
                        valueColor: const Color(0xFF14B8A6),
                      ),
                      _SummaryTile(
                        label: 'Out of Sync',
                        value: outOfSyncCount,
                        valueColor: const Color(0xFFFF6B57),
                      ),
                      _SummaryTile(
                        label: 'Degraded',
                        value: degradedCount,
                        valueColor: const Color(0xFFFFC857),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Health Breakdown',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SegmentBar(segments: healthSegments),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: healthSegments
                            .map(
                              (segment) => _LegendItem(
                                color: segment.color,
                                label: segment.label,
                                count: segment.count,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Sync Status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SegmentBar(segments: syncSegments),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: syncSegments
                            .map(
                              (segment) => _LegendItem(
                                color: segment.color,
                                label: segment.label,
                                count: segment.count,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Needs Attention',
                  child: _NeedsAttentionList(
                    applications: needsAttention,
                    onOpenApplication: onOpenApplication,
                  ),
                ),
                if (controller.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    controller.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (controller.loadingApplications &&
                    !controller.hasLoadedApplications) ...<Widget>[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final int value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EAF3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '$value',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.segments});

  final List<_BreakdownSegment> segments;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 24,
        child: Row(
          children: segments
              .where((segment) => segment.count > 0)
              .map(
                (segment) => Expanded(
                  flex: segment.count,
                  child: Semantics(
                    label: '${segment.label}: ${segment.count}',
                    child: Container(color: segment.color),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Text('$label ($count)', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _NeedsAttentionList extends StatelessWidget {
  const _NeedsAttentionList({
    required this.applications,
    required this.onOpenApplication,
  });

  final List<ArgoApplication> applications;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return const Text('All applications are healthy and synced!');
    }

    final visibleApplications = applications.take(10).toList(growable: false);
    final remainingCount = applications.length - visibleApplications.length;

    return Column(
      children: <Widget>[
        ...visibleApplications.map(
          (application) => ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => onOpenApplication(application.name),
            title: Text(
              application.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            trailing: Wrap(
              spacing: 8,
              children: <Widget>[
                _StatusChip(
                  label: application.syncStatus,
                  color: application.isOutOfSync
                      ? const Color(0xFFFF6B57)
                      : const Color(0xFF1F6FEB),
                ),
                _StatusChip(
                  label: application.healthStatus,
                  color: _healthChipColor(application.healthStatus),
                ),
              ],
            ),
          ),
        ),
        if (remainingCount > 0) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'and $remainingCount more...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.24 : 0.12,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BreakdownSegment {
  const _BreakdownSegment({
    required this.label,
    required this.color,
    required this.count,
  });

  final String label;
  final Color color;
  final int count;
}

List<_BreakdownSegment> _buildHealthSegments(
  List<ArgoApplication> applications,
) {
  return <_BreakdownSegment>[
    _BreakdownSegment(
      label: 'Healthy',
      color: const Color(0xFF14B8A6),
      count: applications
          .where(
            (application) => _normalized(application.healthStatus) == 'healthy',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Progressing',
      color: const Color(0xFFFFC857),
      count: applications
          .where(
            (application) =>
                _normalized(application.healthStatus) == 'progressing',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Degraded',
      color: const Color(0xFFFF6B57),
      count: applications
          .where(
            (application) =>
                _normalized(application.healthStatus) == 'degraded',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Missing',
      color: const Color(0xFF9CA3AF),
      count: applications
          .where(
            (application) => _normalized(application.healthStatus) == 'missing',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Unknown',
      color: const Color(0xFF6B7280),
      count: applications
          .where(
            (application) => !_knownHealthStatuses.contains(
              _normalized(application.healthStatus),
            ),
          )
          .length,
    ),
  ];
}

List<_BreakdownSegment> _buildSyncSegments(List<ArgoApplication> applications) {
  return <_BreakdownSegment>[
    _BreakdownSegment(
      label: 'Synced',
      color: const Color(0xFF1F6FEB),
      count: applications
          .where(
            (application) => _normalized(application.syncStatus) == 'synced',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'OutOfSync',
      color: const Color(0xFFFF6B57),
      count: applications
          .where(
            (application) => _normalized(application.syncStatus) != 'synced',
          )
          .length,
    ),
  ];
}

Color _healthChipColor(String healthStatus) {
  return switch (_normalized(healthStatus)) {
    'healthy' => const Color(0xFF14B8A6),
    'progressing' => const Color(0xFFFFC857),
    'degraded' => const Color(0xFFFF6B57),
    'missing' => const Color(0xFF9CA3AF),
    _ => const Color(0xFF6B7280),
  };
}

String _normalized(String value) => value.toLowerCase();

const Set<String> _knownHealthStatuses = <String>{
  'healthy',
  'progressing',
  'degraded',
  'missing',
};
