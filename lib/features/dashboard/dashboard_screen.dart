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

/// Vertical gap between top-level dashboard sections.
const double _kSectionGap = 28;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.controller,
    required this.onOpenApplication,
    this.onShowSearch,
  });

  final AppController controller;
  final ValueChanged<String> onOpenApplication;
  final VoidCallback? onShowSearch;

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
          (application) => _normalized(application.healthStatus) == 'healthy',
        )
        .length;
    _outOfSyncCount = applications
        .where((application) => _normalized(application.syncStatus) != 'synced')
        .length;
    _degradedCount = applications
        .where(
          (application) => _normalized(application.healthStatus) == 'degraded',
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
          body: RefreshIndicator(
            onRefresh: () => widget.controller.refreshApplications(),
            child: _buildBody(context),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = widget.controller;
    final header = _DashboardHeader(
      controller: controller,
      onRefresh: () => controller.refreshApplications(),
      onShowSearch: widget.onShowSearch,
    );
    final error = controller.errorMessage == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ErrorRetryWidget(
              message: controller.errorMessage!,
              onRetry: () => controller.refreshApplications(),
            ),
          );

    // Empty state when not loading and no apps.
    if (!controller.loadingApplications &&
        controller.hasLoadedApplications &&
        _totalApps == 0) {
      return ListView(
        padding: kPagePadding,
        children: <Widget>[
          header,
          const SizedBox(height: 16),
          _ClusterHealthCard(
            controller: controller,
            totalApps: 0,
            healthyCount: 0,
            outOfSyncCount: 0,
            degradedCount: 0,
            healthSegments: const <StatusSegment>[],
          ),
          const SizedBox(height: 12),
          const EmptyStateCard(
            icon: Icons.cloud_queue_rounded,
            title: 'No applications found',
            subtitle:
                'Your ArgoCD server has no applications yet.\n'
                'Deploy an application to see it here.',
          ),
          ?error,
        ],
      );
    }

    return ListView(
      padding: kPagePadding,
      children: <Widget>[
        header,
        const SizedBox(height: 16),
        _ClusterHealthCard(
          controller: controller,
          totalApps: _totalApps,
          healthyCount: _healthyCount,
          outOfSyncCount: _outOfSyncCount,
          degradedCount: _degradedCount,
          healthSegments: _healthSegments
              .map((s) => StatusSegment(color: s.color, count: s.count))
              .toList(growable: false),
        ),
        const SizedBox(height: _kSectionGap),
        _ResponsiveDashboardPanels(
          totalApps: _totalApps,
          healthSegments: _healthSegments,
          syncSegments: _syncSegments,
          needsAttention: _needsAttention,
          recentlySynced: _recentlySynced,
          controller: controller,
          onOpenApplication: widget.onOpenApplication,
        ),
        if (controller.healthMonitor != null)
          _IncidentFeedSection(
            monitor: controller.healthMonitor!,
            controller: controller,
            onOpenApplication: widget.onOpenApplication,
          ),
        ?error,
        if (controller.loadingApplications &&
            !controller.hasLoadedApplications) ...<Widget>[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.controller,
    required this.onRefresh,
    this.onShowSearch,
  });

  final AppController controller;
  final VoidCallback onRefresh;
  final VoidCallback? onShowSearch;

  @override
  Widget build(BuildContext context) {
    final session = controller.session;

    return AppPageHeader(
      title: 'Dashboard',
      subtitle: session == null
          ? 'No cluster connected'
          : '${session.username} @ ${session.serverUrl}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onShowSearch != null)
            IconButton(
              tooltip: 'Search apps & projects',
              onPressed: onShowSearch,
              icon: const Icon(Icons.search_rounded),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.busy ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cluster health hero
// ---------------------------------------------------------------------------

class _ClusterHealthCard extends StatelessWidget {
  const _ClusterHealthCard({
    required this.controller,
    required this.totalApps,
    required this.healthyCount,
    required this.outOfSyncCount,
    required this.degradedCount,
    required this.healthSegments,
  });

  final AppController controller;
  final int totalApps;
  final int healthyCount;
  final int outOfSyncCount;
  final int degradedCount;
  final List<StatusSegment> healthSegments;

  String _contextLine() {
    if (totalApps == 0) {
      return controller.session == null
          ? 'Connect to ArgoCD to monitor your deployments.'
          : 'Waiting for applications to appear.';
    }
    if (healthyCount == totalApps && outOfSyncCount == 0) {
      return 'Every application is healthy and in sync.';
    }
    return '$healthyCount of $totalApps applications healthy';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final healthyPercent = totalApps == 0
        ? null
        : (healthyCount / totalApps * 100).round();
    final lastRefreshedAt = controller.lastRefreshedAt;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Cluster health',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (lastRefreshedAt != null)
                Text(
                  'Updated ${formatTimeAgo(lastRefreshedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: healthyPercent == null
                ? 'Cluster health unavailable'
                : '$healthyPercent percent of applications healthy',
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: healthyPercent?.toString() ?? '—'),
                    if (healthyPercent != null)
                      TextSpan(
                        text: '%',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: scheme.onSurface,
                  fontFeatures: AppFonts.tabularFigures,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _contextLine(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          StatusSegmentBar(segments: healthSegments),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _HeroStat(label: 'Total apps', value: totalApps),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'Healthy',
                  value: healthyCount,
                  color: AppColors.healthy,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'Drifted',
                  value: outOfSyncCount,
                  color: AppColors.outOfSync,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'Degraded',
                  value: degradedCount,
                  color: AppColors.degraded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A legend-style figure: a small caption (with optional status dot) over a
/// tabular numeral.
class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (color != null) ...<Widget>[
                StatusDot(color: color!, size: 7),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: AppFonts.tabularFigures,
              color: value == 0 && color != null
                  ? AppColors.tertiaryLabel(theme)
                  : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section layout
// ---------------------------------------------------------------------------

class _ResponsiveDashboardPanels extends StatelessWidget {
  const _ResponsiveDashboardPanels({
    required this.totalApps,
    required this.healthSegments,
    required this.syncSegments,
    required this.needsAttention,
    required this.recentlySynced,
    required this.controller,
    required this.onOpenApplication,
  });

  final int totalApps;
  final List<_BreakdownSegment> healthSegments;
  final List<_BreakdownSegment> syncSegments;
  final List<ArgoApplication> needsAttention;
  final List<ArgoApplication> recentlySynced;
  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        // Order matters on phones: actionable items first, stats after.
        final panels = <Widget>[
          _DashboardSection(
            title: 'Needs Attention',
            trailing: needsAttention.isEmpty
                ? null
                : Text(
                    '${needsAttention.length}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFeatures: AppFonts.tabularFigures,
                    ),
                  ),
            child: _NeedsAttentionList(
              applications: needsAttention,
              controller: controller,
              onOpenApplication: onOpenApplication,
            ),
          ),
          _DashboardSection(
            title: 'Health Breakdown',
            child: _BreakdownCard(segments: healthSegments, total: totalApps),
          ),
          _DashboardSection(
            title: 'Sync Status',
            child: _BreakdownCard(segments: syncSegments, total: totalApps),
          ),
          _DashboardSection(
            title: 'Recent Activity',
            child: _RecentActivityTimeline(
              applications: recentlySynced,
              onOpenApplication: onOpenApplication,
            ),
          ),
        ];

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: panels
                .map(
                  (panel) => Padding(
                    padding: const EdgeInsets.only(bottom: _kSectionGap),
                    child: panel,
                  ),
                )
                .toList(growable: false),
          );
        }

        return Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 3, child: panels[0]),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: panels[3]),
              ],
            ),
            const SizedBox(height: _kSectionGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: panels[1]),
                const SizedBox(width: 16),
                Expanded(child: panels[2]),
              ],
            ),
            const SizedBox(height: _kSectionGap),
          ],
        );
      },
    );
  }
}

/// A [SectionHeader] title sitting directly above its content card.
class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: title, trailing: trailing),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Health / sync breakdown
// ---------------------------------------------------------------------------

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.segments, required this.total});

  final List<_BreakdownSegment> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: <Widget>[
          for (final segment in segments)
            _BreakdownRow(
              color: segment.color,
              label: segment.label,
              count: segment.count,
              total: total,
            ),
        ],
      ),
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
    final scheme = theme.colorScheme;
    final fraction = total > 0 ? count / total : 0.0;
    final percentage = (fraction * 100).round();
    final isZero = count == 0;

    return Semantics(
      label: '$label: $count of $total, $percentage percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                StatusDot(color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isZero
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppFonts.tabularFigures,
                    color: isZero
                        ? AppColors.tertiaryLabel(theme)
                        : scheme.onSurface,
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '$percentage%',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: AppFonts.tabularFigures,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: _ThinBar(fraction: fraction, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 4pt capsule track with a proportional fill.
class _ThinBar extends StatelessWidget {
  const _ThinBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.pill,
      child: SizedBox(
        height: 4,
        child: ColoredBox(
          color: AppColors.fill(Theme.of(context)),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ),
        ),
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
    final theme = Theme.of(context);

    if (applications.isEmpty) {
      return SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.statusForeground(theme, AppColors.healthy),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'All applications are healthy and synced!',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
    }

    final visibleApplications = applications.take(10).toList(growable: false);
    final remainingCount = applications.length - visibleApplications.length;
    final hasDrifted = visibleApplications.any((a) => a.isOutOfSync);

    return GroupedList(
      dividerIndent: 38,
      // One shared gesture hint instead of repeating it on every row.
      footer: hasDrifted
          ? 'Swipe a drifted app right to sync · tap for details'
          : null,
      children: <Widget>[
        for (final application in visibleApplications)
          _SwipeableAttentionItem(
            application: application,
            controller: controller,
            onTap: () => onOpenApplication(application.name),
          ),
        if (remainingCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(38, 12, 16, 12),
            child: Text(
              'and $remainingCount more...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({required this.application, required this.onTap});

  final ArgoApplication application;
  final VoidCallback onTap;

  Color _severityColor() {
    final health = _normalized(application.healthStatus);
    if (health == 'degraded') {
      return AppColors.degraded;
    }
    if (health == 'progressing') {
      return AppColors.progressing;
    }
    if (health == 'missing') {
      return AppColors.missing;
    }
    final sync = _normalized(application.syncStatus);
    if (sync != 'synced') {
      return AppColors.outOfSync;
    }
    return AppColors.unknown;
  }

  /// Short status summary shown at the trailing edge of the title line,
  /// e.g. "Degraded · OutOfSync".
  String _statusLabel() {
    final parts = <String>[
      if (_normalized(application.healthStatus) != 'healthy')
        application.healthStatus,
      if (_normalized(application.syncStatus) != 'synced')
        application.syncStatus,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final severity = _severityColor();

    return Semantics(
      label:
          'Application ${application.name}, ${_attentionReason(application)}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
          child: Row(
            children: <Widget>[
              StatusDot(color: severity),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            application.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusLabel(),
                          maxLines: 1,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.statusForeground(theme, severity),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${application.project} / ${application.namespace}'
                      ' · ${application.operationPhase}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const DisclosureChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leading swipe action revealed behind a row ("Sync").
class _SwipeSyncBackground extends StatelessWidget {
  const _SwipeSyncBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ColoredBox(
      color: AppColors.statusTint(theme, scheme.primary),
      child: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: <Widget>[
            Icon(Icons.sync_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Sync',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipeable attention item (swipe right = sync)
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

  @override
  Widget build(BuildContext context) {
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
                SnackBar(content: Text('Syncing ${application.name}...')),
              );
            }
          } on Exception {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to sync ${application.name}')),
              );
            }
          }
        }
        return false; // Don't dismiss — the list rebuilds on refresh.
      },
      background: const _SwipeSyncBackground(),
      child: _AttentionItem(application: application, onTap: onTap),
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

        return Padding(
          padding: const EdgeInsets.only(bottom: _kSectionGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionHeader(
                title: 'Incidents',
                padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
                trailing: TextButton(
                  onPressed: () => monitor.acknowledgeAll(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Clear'),
                ),
              ),
              for (var i = 0; i < events.length && i < 10; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _IncidentCard(
                    event: events[i],
                    index: i,
                    monitor: monitor,
                    controller: controller,
                    onOpenApplication: onOpenApplication,
                  ),
                ),
              if (events.length > 10)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    'and ${events.length - 10} more...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
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
      HealthEventKind.degraded => AppColors.degraded,
      HealthEventKind.drifted => AppColors.outOfSync,
      HealthEventKind.failed => AppColors.degraded,
      HealthEventKind.operationFailed => AppColors.degraded,
      HealthEventKind.recovered => AppColors.healthy,
      HealthEventKind.synced => AppColors.synced,
    };
  }

  IconData get _eventIcon {
    return switch (event.kind) {
      HealthEventKind.degraded => Icons.error_rounded,
      HealthEventKind.drifted => Icons.sync_problem_rounded,
      HealthEventKind.failed => Icons.cancel_rounded,
      HealthEventKind.operationFailed => Icons.cancel_rounded,
      HealthEventKind.recovered => Icons.check_circle_rounded,
      HealthEventKind.synced => Icons.check_circle_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final elapsed = DateTime.now().difference(event.detectedAt);
    final timeAgo = elapsed.inMinutes < 1
        ? 'just now'
        : elapsed.inMinutes < 60
        ? '${elapsed.inMinutes}m ago'
        : '${elapsed.inHours}h ago';

    return ClipRRect(
      borderRadius: AppRadius.md,
      child: Dismissible(
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
        background: const _SwipeSyncBackground(),
        secondaryBackground: ColoredBox(
          color: AppColors.fill(theme),
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  'Dismiss',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.close_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        child: Material(
          color: scheme.surfaceContainerLow,
          child: InkWell(
            onTap: () => onOpenApplication(event.applicationName),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      _eventIcon,
                      color: AppColors.statusForeground(theme, _eventColor),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                event.applicationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeAgo,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontFeatures: AppFonts.tabularFigures,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.summary,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
    final theme = Theme.of(context);

    if (applications.isEmpty) {
      return SectionCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.history_rounded,
              color: AppColors.tertiaryLabel(theme),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'No recent sync activity.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < applications.length; i++)
            _TimelineEntry(
              application: applications[i],
              isLast: i == applications.length - 1,
              onTap: () => onOpenApplication(applications[i].name),
            ),
        ],
      ),
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
    final scheme = theme.colorScheme;
    final syncTime = application.lastSyncedAt;
    final syncColor = AppColors.syncColor(application.syncStatus);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Rail: small status dot with a hairline running to the next entry.
          SizedBox(
            width: 8,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 7),
                StatusDot(color: syncColor),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Container(width: 1, color: scheme.outlineVariant),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Semantics(
              label:
                  'Application ${application.name}, ${application.syncStatus}',
              button: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: AppRadius.sm,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              application.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (syncTime != null && syncTime.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(_formatSyncTime(syncTime), style: secondary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${application.project} / ${application.namespace}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: secondary,
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: application.syncStatus,
                              style: TextStyle(
                                color: AppColors.statusForeground(
                                  theme,
                                  syncColor,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (application.history.isNotEmpty) ...[
                              const TextSpan(text: '  ·  '),
                              TextSpan(
                                text: _shortRevision(
                                  application.history.first.revision,
                                ),
                                style: const TextStyle(
                                  fontFamily: AppFonts.mono,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                            TextSpan(
                              text: '  ·  ${application.operationPhase}',
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: secondary,
                      ),
                    ],
                  ),
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
      color: AppColors.healthy,
      count: applications
          .where(
            (application) => _normalized(application.healthStatus) == 'healthy',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Progressing',
      color: AppColors.progressing,
      count: applications
          .where(
            (application) =>
                _normalized(application.healthStatus) == 'progressing',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Degraded',
      color: AppColors.degraded,
      count: applications
          .where(
            (application) =>
                _normalized(application.healthStatus) == 'degraded',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Missing',
      color: AppColors.missing,
      count: applications
          .where(
            (application) => _normalized(application.healthStatus) == 'missing',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'Unknown',
      color: AppColors.unknown,
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
      color: AppColors.synced,
      count: applications
          .where(
            (application) => _normalized(application.syncStatus) == 'synced',
          )
          .length,
    ),
    _BreakdownSegment(
      label: 'OutOfSync',
      color: AppColors.outOfSync,
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
