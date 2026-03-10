import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
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
                SectionCard(
                  title: 'Summary',
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: <Widget>[
                      SummaryTile(label: 'Total Apps', value: totalApps),
                      SummaryTile(
                        label: 'Healthy',
                        value: healthyCount,
                        valueColor: const Color(0xFF14B8A6),
                      ),
                      SummaryTile(
                        label: 'Out of Sync',
                        value: outOfSyncCount,
                        valueColor: const Color(0xFFFF6B57),
                      ),
                      SummaryTile(
                        label: 'Degraded',
                        value: degradedCount,
                        valueColor: const Color(0xFFFFC857),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SectionCard(
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
                SectionCard(
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
                SectionCard(
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
                  child: Container(color: segment.color),
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                StatusChip(
                  label: application.syncStatus,
                  color: application.isOutOfSync
                      ? const Color(0xFFFF6B57)
                      : const Color(0xFF1F6FEB),
                ),
                StatusChip(
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
