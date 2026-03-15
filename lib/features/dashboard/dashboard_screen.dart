import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/health_event.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/health_monitor.dart';
import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/last_updated_text.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onOpenApplication,
  });

  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Cached computations — only recomputed when the applications list
  // reference actually changes, not on every notifyListeners() call.
  List<ArgoApplication>? _cachedApplications;
  late int _totalApps;
  late int _healthyCount;
  late int _outOfSyncCount;
  late int _degradedCount;
  late List<_BreakdownSegment> _healthSegments;
  late List<_BreakdownSegment> _syncSegments;
  late List<ArgoApplication> _needsAttention;
  late List<ArgoApplication> _recentlySynced;

  void _recompute(List<ArgoApplication> applications) {
    _totalApps = applications.length;
    _healthyCount = applications
        .where(
          (application) =>
              _normalized(application.healthStatus) == 'healthy',
        )
        .length;
    _outOfSyncCount = applications
        .where(
          (application) => _normalized(application.syncStatus) != 'synced',
        )
        .length;
    _degradedCount = applications
        .where(
          (application) =>
              _normalized(application.healthStatus) == 'degraded',
        )
        .length;
    _healthSegments = _buildHealthSegments(applications);
    _syncSegments = _buildSyncSegments(applications);
    _needsAttention = _prioritizeAttention(applications);
    _recentlySynced = _buildRecentlySynced(applications);
    _cachedApplications = applications;
  }

  void _ensureFresh(List<ArgoApplication> applications) {
    if (!identical(applications, _cachedApplications)) {
      _recompute(applications);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final applications = widget.controller.applications;
        _ensureFresh(applications);

        return Scaffold(
          appBar: AppBar(title: const Text('Dashboard')),
          body: RefreshIndicator(
            onRefresh: () => widget.controller.refreshApplications(),
            child: _buildBody(
              context,
              totalApps: _totalApps,
              healthyCount: _healthyCount,
              outOfSyncCount: _outOfSyncCount,
              degradedCount: _degradedCount,
              healthSegments: _healthSegments,
              syncSegments: _syncSegments,
              needsAttention: _needsAttention,
              recentlySynced: _recentlySynced,
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
    if (!widget.controller.loadingApplications &&
        widget.controller.hasLoadedApplications &&
        totalApps == 0) {
      return ListView(
        padding: kPagePadding,
        children: <Widget>[
          LastUpdatedText(timestamp: widget.controller.lastRefreshedAt),
          _HeroBanner(
            controller: widget.controller,
            totalApps: 0,
            healthyCount: 0,
            outOfSyncCount: 0,
            degradedCount: 0,
          ),
          const SizedBox(height: 10),
          _EmptyDashboard(),
          if (widget.controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ErrorRetryWidget(
                message: widget.controller.errorMessage!,
                onRetry: () => widget.controller.refreshApplications(),
              ),
            ),
        ],
      );
    }

    return ListView(
      padding: kPagePadding,
      children: <Widget>[
        LastUpdatedText(timestamp: widget.controller.lastRefreshedAt),
        _HeroBanner(
          controller: widget.controller,
          totalApps: totalApps,
          healthyCount: healthyCount,
          outOfSyncCount: outOfSyncCount,
          degradedCount: degradedCount,
        ),
        const SizedBox(height: 10),
        _SectionHeader(title: 'Health Breakdown'),
        const SizedBox(height: 6),
        SectionCard(
          title: null,
          child: _CompactBreakdownSection(
            segments: healthSegments,
            total: totalApps,
          ),
        ),
        const SizedBox(height: 10),
        _SectionHeader(title: 'Sync Status'),
        const SizedBox(height: 6),
        SectionCard(
          title: null,
          child: _CompactBreakdownSection(
            segments: syncSegments,
            total: totalApps,
          ),
        ),
        if (widget.controller.healthMonitor != null)
          _IncidentFeedSection(
            monitor: widget.controller.healthMonitor!,
            controller: widget.controller,
            onOpenApplication: widget.onOpenApplication,
          ),
        const SizedBox(height: 10),
        _SectionHeader(title: 'Needs Attention'),
        const SizedBox(height: 6),
        SectionCard(
          title: null,
          child: _NeedsAttentionList(
            applications: needsAttention,
            controller: widget.controller,
            onOpenApplication: widget.onOpenApplication,
          ),
        ),
        const SizedBox(height: 10),
        _SectionHeader(title: 'Recent Activity'),
        const SizedBox(height: 6),
        SectionCard(
          title: null,
          child: _RecentActivityTimeline(
            applications: recentlySynced,
            onOpenApplication: widget.onOpenApplication,
          ),
        ),
        if (widget.controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ErrorRetryWidget(
              message: widget.controller.errorMessage!,
              onRetry: () => widget.controller.refreshApplications(),
            ),
          ),
        if (widget.controller.loadingApplications &&
            !widget.controller.hasLoadedApplications) ...<Widget>[
          const SizedBox(height: 10),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 10),
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
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.cobalt,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.mutedText(theme),
            letterSpacing: 0.2,
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.base,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.cloud_queue_rounded,
            size: 48,
            color: AppColors.greyLight,
            semanticLabel: 'No applications',
          ),
          const SizedBox(height: 10),
          Text(
            'No applications found',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your ArgoCD server has no applications yet.\n'
            'Deploy an application to see it here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey),
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

    return SectionCard(
      title: 'Cluster Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            session == null
                ? 'Connect to ArgoCD to monitor your deployments.'
                : '${session.username} @ ${session.serverUrl}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.mutedText(theme),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: SummaryTile(label: 'Total', value: totalApps)),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryTile(label: 'Healthy', value: healthyCount),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryTile(
                  label: 'Drifted',
                  value: outOfSyncCount,
                  valueColor: outOfSyncCount > 0 ? AppColors.amber : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SummaryTile(
                  label: 'Degraded',
                  value: degradedCount,
                  valueColor: degradedCount > 0 ? AppColors.coral : null,
                ),
              ),
            ],
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
  const _CompactBreakdownSection({required this.segments, required this.total});

  final List<_BreakdownSegment> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: segments
          .map(
            (segment) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
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

    return Semantics(
      label: '$label: $count of $total, ${percentage.round()} percent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ExcludeSemantics(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
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
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: AppRadius.sm,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Needs attention list
// ---------------------------------------------------------------------------

class _NeedsAttentionList extends StatelessWidget {
  const _NeedsAttentionList({
    required this.applications,
    required this.controller,
    required this.onOpenApplication,
  });

  final List<ArgoApplication> applications;
  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    if (applications.isEmpty) {
      return Row(
        children: <Widget>[
          Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('All applications are healthy and synced!'),
          ),
        ],
      );
    }

    final visibleApplications = applications.take(10).toList(growable: false);
    final remainingCount = applications.length - visibleApplications.length;

    return Column(
      children: <Widget>[
        ...visibleApplications.map(
          (application) => _SwipeableAttentionItem(
            application: application,
            controller: controller,
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
    this.hint,
  });

  final ArgoApplication application;
  final VoidCallback onTap;
  final String? hint;

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
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        label:
            'Application ${application.name}, ${_attentionReason(application)}',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.base,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  _severityColor().withValues(alpha: 0.10),
                  _severityColor().withValues(alpha: 0.03),
                ],
              ),
              borderRadius: AppRadius.base,
              border: Border(
                left: BorderSide(color: _severityColor(), width: 3),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _severityColor().withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                if (hint != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.greyLight,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipeable attention item (swipe right = sync, swipe left = view detail)
// ---------------------------------------------------------------------------

class _SwipeableAttentionItem extends StatelessWidget {
  const _SwipeableAttentionItem({
    required this.application,
    required this.controller,
    required this.onTap,
  });

  final ArgoApplication application;
  final AppController controller;
  final VoidCallback onTap;

  String get _swipeHint {
    if (application.isOutOfSync) {
      return 'Swipe right to sync';
    }
    return 'Tap to view details';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey<String>('attention-${application.name}'),
      direction: application.isOutOfSync
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd &&
            application.isOutOfSync) {
          try {
            await controller.syncApplication(application.name);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Syncing ${application.name}...'),
                  backgroundColor: AppColors.cobalt,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } on Exception {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to sync ${application.name}'),
                  backgroundColor: AppColors.coral,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
        return false; // Don't dismiss — the list rebuilds on refresh.
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.cobalt.withValues(alpha: 0.15),
          borderRadius: AppRadius.base,
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.sync, color: AppColors.cobalt, size: 20),
            const SizedBox(width: 8),
            Text(
              'Sync',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.cobalt,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: _AttentionItem(
        application: application,
        onTap: onTap,
        hint: _swipeHint,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incident feed section (live events from HealthMonitor)
// ---------------------------------------------------------------------------

class _IncidentFeedSection extends StatelessWidget {
  const _IncidentFeedSection({
    required this.monitor,
    required this.controller,
    required this.onOpenApplication,
  });

  final HealthMonitor monitor;
  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: monitor,
      builder: (context, _) {
        if (!monitor.enabled || monitor.events.isEmpty) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final events = monitor.events;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _SectionHeader(title: 'Incidents'),
                const Spacer(),
                if (events.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => monitor.acknowledgeAll(),
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SectionCard(
              title: null,
              child: Column(
                children: <Widget>[
                  for (var i = 0; i < events.length && i < 10; i++)
                    _IncidentCard(
                      event: events[i],
                      index: i,
                      monitor: monitor,
                      controller: controller,
                      onOpenApplication: onOpenApplication,
                    ),
                  if (events.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'and ${events.length - 10} more...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.event,
    required this.index,
    required this.monitor,
    required this.controller,
    required this.onOpenApplication,
  });

  final HealthEvent event;
  final int index;
  final HealthMonitor monitor;
  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  Color get _eventColor {
    return switch (event.kind) {
      HealthEventKind.degraded => AppColors.coral,
      HealthEventKind.drifted => AppColors.amber,
      HealthEventKind.failed => AppColors.coral,
      HealthEventKind.operationFailed => AppColors.coral,
      HealthEventKind.recovered => AppColors.teal,
      HealthEventKind.synced => AppColors.cobalt,
    };
  }

  IconData get _eventIcon {
    return switch (event.kind) {
      HealthEventKind.degraded => Icons.error_outline,
      HealthEventKind.drifted => Icons.sync_problem,
      HealthEventKind.failed => Icons.cancel_outlined,
      HealthEventKind.operationFailed => Icons.cancel_outlined,
      HealthEventKind.recovered => Icons.check_circle_outline,
      HealthEventKind.synced => Icons.check_circle_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = DateTime.now().difference(event.detectedAt);
    final timeAgo = elapsed.inMinutes < 1
        ? 'just now'
        : elapsed.inMinutes < 60
            ? '${elapsed.inMinutes}m ago'
            : '${elapsed.inHours}h ago';

    return Dismissible(
      key: ValueKey<String>(
        'incident-${event.applicationName}-${event.detectedAt.toIso8601String()}',
      ),
      direction: event.kind == HealthEventKind.drifted
          ? DismissDirection.startToEnd
          : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd &&
            event.kind == HealthEventKind.drifted) {
          try {
            await controller.syncApplication(event.applicationName);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Syncing ${event.applicationName}...'),
                  backgroundColor: AppColors.cobalt,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } on Exception {
            // Error handled by controller.
          }
        } else if (direction == DismissDirection.endToStart) {
          monitor.acknowledgeEvent(index);
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          color: AppColors.cobalt.withValues(alpha: 0.15),
          borderRadius: AppRadius.base,
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.sync, color: AppColors.cobalt, size: 18),
            const SizedBox(width: 6),
            Text(
              'Sync',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.cobalt,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.grey.withValues(alpha: 0.12),
          borderRadius: AppRadius.base,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              'Dismiss',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.close, color: AppColors.grey, size: 18),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          onTap: () => onOpenApplication(event.applicationName),
          borderRadius: AppRadius.base,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  _eventColor.withValues(alpha: 0.10),
                  _eventColor.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: AppRadius.base,
              border: Border(
                left: BorderSide(color: _eventColor, width: 3),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(_eventIcon, color: _eventColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        event.applicationName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.greyLight,
                  ),
                ),
              ],
            ),
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
          Icon(Icons.history_rounded, color: AppColors.greyLight),
          const SizedBox(width: 12),
          Text(
            'No recent sync activity.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.grey),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 32,
          child: Column(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: AppColors.cobalt,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cobalt.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 1,
                  height: 24,
                  color: AppColors.outline(theme),
                ),
            ],
          ),
        ),
        Expanded(
            child: Semantics(
              label:
                  'Application ${application.name}, ${application.syncStatus}',
              button: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.sm,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
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
          ),
        ],
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

List<ArgoApplication> _buildRecentlySynced(List<ArgoApplication> applications) {
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
  return formatRelativeTime(isoTimestamp);
}
