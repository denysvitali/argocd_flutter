import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/last_updated_text.dart';
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
        final needsAttention = _prioritizeAttention(applications);

        final recentlySynced = _buildRecentlySynced(applications);

        return Scaffold(
          appBar: AppBar(title: const Text('Dashboard')),
          body: RefreshIndicator(
            onRefresh: () => controller.refreshApplications(),
            child: _buildBody(
              context,
              totalApps: totalApps,
              healthyCount: healthyCount,
              outOfSyncCount: outOfSyncCount,
              degradedCount: degradedCount,
              healthSegments: healthSegments,
              syncSegments: syncSegments,
              needsAttention: needsAttention,
              recentlySynced: recentlySynced,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required int totalApps,
    required int healthyCount,
    required int outOfSyncCount,
    required int degradedCount,
    required List<_BreakdownSegment> healthSegments,
    required List<_BreakdownSegment> syncSegments,
    required List<ArgoApplication> needsAttention,
    required List<ArgoApplication> recentlySynced,
  }) {
    // Empty state when not loading and no apps
    if (!controller.loadingApplications &&
        controller.hasLoadedApplications &&
        totalApps == 0) {
      return ListView(
        padding: kPagePadding,
        children: <Widget>[
          LastUpdatedText(timestamp: controller.lastRefreshedAt),
          _HeroBanner(
            controller: controller,
            totalApps: 0,
            healthyCount: 0,
            outOfSyncCount: 0,
            degradedCount: 0,
          ),
          const SizedBox(height: 20),
          _EmptyDashboard(),
          if (controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ErrorRetryWidget(
                message: controller.errorMessage!,
                onRetry: () => controller.refreshApplications(),
              ),
            ),
        ],
      );
    }

    return ListView(
      padding: kPagePadding,
      children: <Widget>[
        LastUpdatedText(timestamp: controller.lastRefreshedAt),
        _HeroBanner(
          controller: controller,
          totalApps: totalApps,
          healthyCount: healthyCount,
          outOfSyncCount: outOfSyncCount,
          degradedCount: degradedCount,
        ),
        const SizedBox(height: 16),
        _SectionHeader(title: 'Health Breakdown'),
        const SizedBox(height: 8),
        SectionCard(
          title: null,
          child: _CompactBreakdownSection(
            segments: healthSegments,
            total: totalApps,
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(title: 'Sync Status'),
        const SizedBox(height: 8),
        SectionCard(
          title: null,
          child: _CompactBreakdownSection(
            segments: syncSegments,
            total: totalApps,
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(title: 'Needs Attention'),
        const SizedBox(height: 8),
        SectionCard(
          title: null,
          child: _NeedsAttentionList(
            applications: needsAttention,
            onOpenApplication: onOpenApplication,
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(title: 'Recent Activity'),
        const SizedBox(height: 8),
        SectionCard(
          title: null,
          child: _RecentActivityTimeline(
            applications: recentlySynced,
            onOpenApplication: onOpenApplication,
          ),
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ErrorRetryWidget(
              message: controller.errorMessage!,
              onRetry: () => controller.refreshApplications(),
            ),
          ),
        if (controller.loadingApplications &&
            !controller.hasLoadedApplications) ...<Widget>[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section header with subtle divider
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.grey,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(
            color: theme.dividerColor,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty dashboard state
// ---------------------------------------------------------------------------

class _EmptyDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.cloud_queue_rounded,
            size: 52,
            color: AppColors.greyLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No applications found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ArgoCD server has no applications yet.\n'
            'Deploy an application to see it here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero banner
// ---------------------------------------------------------------------------

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.controller,
    required this.totalApps,
    required this.healthyCount,
    required this.outOfSyncCount,
    required this.degradedCount,
  });

  final AppController controller;
  final int totalApps;
  final int healthyCount;
  final int outOfSyncCount;
  final int degradedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = controller.session;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.gradientAppStart,
            AppColors.gradientAppMid,
            AppColors.cobalt,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Cluster dashboard',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$degradedCount degraded • $outOfSyncCount drifted',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            session == null
                ? 'Connect to ArgoCD to monitor your deployments.'
                : '${session.username} on ${session.serverUrl}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MetricChip(label: 'Total', value: '$totalApps'),
              _MetricChip(label: 'Healthy', value: '$healthyCount'),
              _MetricChip(label: 'Out of sync', value: '$outOfSyncCount'),
              _MetricChip(label: 'Degraded', value: '$degradedCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Donut chart section (replaces segment bar)
// ---------------------------------------------------------------------------

class _CompactBreakdownSection extends StatelessWidget {
  const _CompactBreakdownSection({
    required this.segments,
    required this.total,
  });

  final List<_BreakdownSegment> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: segments
          .map(
            (segment) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _BreakdownRow(
                color: segment.color,
                label: segment.label,
                count: segment.count,
                total: total,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
  });

  final Color color;
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage.round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.greyLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : count / total,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Needs attention list
// ---------------------------------------------------------------------------

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
      return Row(
        children: <Widget>[
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.teal,
          ),
          const SizedBox(width: 12),
          const Text('All applications are healthy and synced!'),
        ],
      );
    }

    final visibleApplications = applications.take(10).toList(growable: false);
    final remainingCount = applications.length - visibleApplications.length;

    return Column(
      children: <Widget>[
        ...visibleApplications.map(
          (application) => _AttentionItem(
            application: application,
            onTap: () => onOpenApplication(application.name),
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
              ).textTheme.bodyMedium?.copyWith(color: AppColors.grey),
            ),
          ),
        ],
      ],
    );
  }
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({
    required this.application,
    required this.onTap,
  });

  final ArgoApplication application;
  final VoidCallback onTap;

  Color _severityColor() {
    final health = _normalized(application.healthStatus);
    if (health == 'degraded') {
      return AppColors.coral;
    }
    if (health == 'progressing' || health == 'missing') {
      return AppColors.amber;
    }
    final sync = _normalized(application.syncStatus);
    if (sync != 'synced') {
      return AppColors.cobalt;
    }
    return AppColors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _severityColor().withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(
                color: _severityColor(),
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      application.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: application.syncStatus,
                    color: AppColors.syncColor(application.syncStatus),
                  ),
                  const SizedBox(width: 6),
                  StatusChip(
                    label: application.healthStatus,
                    color: AppColors.healthColor(application.healthStatus),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${application.project} / ${application.namespace} • ${_attentionReason(application)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent activity timeline
// ---------------------------------------------------------------------------

class _RecentActivityTimeline extends StatelessWidget {
  const _RecentActivityTimeline({
    required this.applications,
    required this.onOpenApplication,
  });

  final List<ArgoApplication> applications;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return Row(
        children: <Widget>[
          Icon(
            Icons.history_rounded,
            color: AppColors.greyLight,
          ),
          const SizedBox(width: 12),
          Text(
            'No recent sync activity.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        for (var i = 0; i < applications.length; i++)
          _TimelineEntry(
            application: applications[i],
            isLast: i == applications.length - 1,
            onTap: () => onOpenApplication(applications[i].name),
          ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.application,
    required this.isLast,
    required this.onTap,
  });

  final ArgoApplication application;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncTime = application.lastSyncedAt;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Column(
              children: <Widget>[
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cobalt,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.cobalt.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 8,
                  bottom: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      application.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${application.project} / ${application.namespace}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        StatusChip(
                          label: application.syncStatus,
                          color: AppColors.syncColor(application.syncStatus),
                        ),
                        if (application.history.isNotEmpty)
                          Text(
                            'rev ${_shortRevision(application.history.first.revision)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          application.operationPhase,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.grey,
                          ),
                        ),
                        if (syncTime != null && syncTime.isNotEmpty)
                          Text(
                            _formatSyncTime(syncTime),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.greyLight,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data helpers
// ---------------------------------------------------------------------------

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

List<ArgoApplication> _prioritizeAttention(List<ArgoApplication> applications) {
  final issues = applications
      .where(
        (application) =>
            _normalized(application.syncStatus) != 'synced' ||
            _normalized(application.healthStatus) != 'healthy',
      )
      .toList();
  issues.sort((a, b) {
    final severity = _attentionSeverity(a).compareTo(_attentionSeverity(b));
    if (severity != 0) {
      return severity;
    }
    return (b.lastSyncedAt ?? '').compareTo(a.lastSyncedAt ?? '');
  });
  return issues;
}

int _attentionSeverity(ArgoApplication application) {
  final health = _normalized(application.healthStatus);
  if (health == 'degraded') {
    return 0;
  }
  if (health == 'progressing' || health == 'missing') {
    return 1;
  }
  if (_normalized(application.syncStatus) != 'synced') {
    return 2;
  }
  return 3;
}

String _attentionReason(ArgoApplication application) {
  if (_normalized(application.healthStatus) != 'healthy') {
    return '${application.healthStatus} • ${application.operationPhase}';
  }
  if (_normalized(application.syncStatus) != 'synced') {
    return 'Drift detected • ${application.operationPhase}';
  }
  return application.operationPhase;
}

String _shortRevision(String revision) {
  return revision.length <= 8 ? revision : revision.substring(0, 8);
}

List<_BreakdownSegment> _buildHealthSegments(
  List<ArgoApplication> applications,
) {
  return <_BreakdownSegment>[
    _BreakdownSegment(
      label: 'Healthy',
      color: AppColors.teal,
      count: applications
          .where(
            (application) => _normalized(application.healthStatus) == 'healthy',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Progressing',
      color: AppColors.amber,
      count: applications
          .where(
            (application) =>
                _normalized(application.healthStatus) == 'progressing',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Degraded',
      color: AppColors.coral,
      count: applications
          .where(
            (application) =>
                _normalized(application.healthStatus) == 'degraded',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Missing',
      color: AppColors.greyLight,
      count: applications
          .where(
            (application) => _normalized(application.healthStatus) == 'missing',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Unknown',
      color: AppColors.grey,
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
      color: AppColors.cobalt,
      count: applications
          .where(
            (application) => _normalized(application.syncStatus) == 'synced',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'OutOfSync',
      color: AppColors.coral,
      count: applications
          .where(
            (application) => _normalized(application.syncStatus) != 'synced',
          )
          .length,
    ),
  ];
}

String _normalized(String value) => value.toLowerCase();

const Set<String> _knownHealthStatuses = <String>{
  'healthy',
  'progressing',
  'degraded',
  'missing',
};

List<ArgoApplication> _buildRecentlySynced(
  List<ArgoApplication> applications,
) {
  final withSync = applications
      .where(
        (application) =>
            application.lastSyncedAt != null &&
            application.lastSyncedAt!.isNotEmpty,
      )
      .toList();

  withSync.sort((a, b) {
    final aTime = DateTime.tryParse(a.lastSyncedAt ?? '');
    final bTime = DateTime.tryParse(b.lastSyncedAt ?? '');
    if (aTime == null && bTime == null) {
      return 0;
    }
    if (aTime == null) {
      return 1;
    }
    if (bTime == null) {
      return -1;
    }
    return bTime.compareTo(aTime);
  });

  return withSync.take(5).toList(growable: false);
}

String _formatSyncTime(String isoTimestamp) {
  final dateTime = DateTime.tryParse(isoTimestamp);
  if (dateTime == null) {
    return isoTimestamp;
  }

  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'just now';
  } else if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes min${minutes == 1 ? '' : 's'} ago';
  } else if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  } else {
    final days = difference.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
}
