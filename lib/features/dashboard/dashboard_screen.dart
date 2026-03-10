import 'dart:math' as math;

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
        final needsAttention = applications
            .where(
              (application) =>
                  _normalized(application.syncStatus) != 'synced' ||
                  _normalized(application.healthStatus) != 'healthy',
            )
            .toList(growable: false);

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
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          LastUpdatedText(timestamp: controller.lastRefreshedAt),
          _HeroBanner(
            controller: controller,
            totalApps: 0,
            healthyCount: 0,
            outOfSyncCount: 0,
            degradedCount: 0,
          ),
          const SizedBox(height: 32),
          _EmptyDashboard(),
          if (controller.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: ErrorRetryWidget(
                message: controller.errorMessage!,
                onRetry: () => controller.refreshApplications(),
              ),
            ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        LastUpdatedText(timestamp: controller.lastRefreshedAt),
        _HeroBanner(
          controller: controller,
          totalApps: totalApps,
          healthyCount: healthyCount,
          outOfSyncCount: outOfSyncCount,
          degradedCount: degradedCount,
        ),
        const SizedBox(height: 24),
        _SectionHeader(title: 'Summary'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: <Widget>[
            _EnhancedSummaryTile(
              label: 'Total Apps',
              value: totalApps,
              totalApps: totalApps,
              icon: Icons.apps_rounded,
              accentColor: AppColors.cobalt,
              gradientColors: const <Color>[
                Color(0xFFEAF2FF),
                Color(0xFFD6E4FF),
              ],
            ),
            _EnhancedSummaryTile(
              label: 'Healthy',
              value: healthyCount,
              totalApps: totalApps,
              icon: Icons.check_circle_outline_rounded,
              accentColor: AppColors.teal,
              gradientColors: const <Color>[
                Color(0xFFE6FAF7),
                Color(0xFFCCF5EF),
              ],
            ),
            _EnhancedSummaryTile(
              label: 'Out of Sync',
              value: outOfSyncCount,
              totalApps: totalApps,
              icon: Icons.sync_problem_rounded,
              accentColor: AppColors.coral,
              gradientColors: const <Color>[
                Color(0xFFFFF0EE),
                Color(0xFFFFE0DB),
              ],
            ),
            _EnhancedSummaryTile(
              label: 'Degraded',
              value: degradedCount,
              totalApps: totalApps,
              icon: Icons.warning_amber_rounded,
              accentColor: AppColors.amber,
              gradientColors: const <Color>[
                Color(0xFFFFF8E6),
                Color(0xFFFFF1CC),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Health Breakdown'),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Health',
          child: _DonutChartSection(
            segments: healthSegments,
            total: totalApps,
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(title: 'Sync Status'),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Sync',
          child: _DonutChartSection(
            segments: syncSegments,
            total: totalApps,
          ),
        ),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Needs Attention'),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Issues',
          child: _NeedsAttentionList(
            applications: needsAttention,
            onOpenApplication: onOpenApplication,
          ),
        ),
        const SizedBox(height: 28),
        _SectionHeader(title: 'Recent Activity'),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Recently Synced',
          child: _RecentActivityTimeline(
            applications: recentlySynced,
            onOpenApplication: onOpenApplication,
          ),
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ErrorRetryWidget(
              message: controller.errorMessage!,
              onRetry: () => controller.refreshApplications(),
            ),
          ),
        if (controller.loadingApplications &&
            !controller.hasLoadedApplications) ...<Widget>[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.cloud_queue_rounded,
            size: 64,
            color: AppColors.greyLight,
          ),
          const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(24),
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
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cluster dashboard',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            session == null
                ? 'Connect to ArgoCD to monitor your deployments.'
                : 'Signed in as ${session.username} on ${session.serverUrl}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
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
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textOnDarkMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enhanced summary tile with gradient, progress ring, animated counter
// ---------------------------------------------------------------------------

class _EnhancedSummaryTile extends StatelessWidget {
  const _EnhancedSummaryTile({
    required this.label,
    required this.value,
    required this.totalApps,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
  });

  final String label;
  final int value;
  final int totalApps;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = totalApps > 0 ? value / totalApps : 0.0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? <Color>[
                  accentColor.withValues(alpha: 0.12),
                  accentColor.withValues(alpha: 0.06),
                ]
              : gradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: fraction),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedFraction, _) {
                          return CustomPaint(
                            size: const Size(44, 44),
                            painter: _ProgressRingPainter(
                              fraction: animatedFraction,
                              color: accentColor,
                              trackColor: accentColor.withValues(alpha: 0.15),
                            ),
                          );
                        },
                      ),
                      Icon(
                        icon,
                        color: accentColor,
                        size: 22,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: value),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedValue, _) {
                    return Text(
                      '$animatedValue',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress ring painter for summary tiles
// ---------------------------------------------------------------------------

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 2;
    const strokeWidth = 3.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (fraction > 0) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * fraction;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      color != oldDelegate.color ||
      trackColor != oldDelegate.trackColor;
}

// ---------------------------------------------------------------------------
// Donut chart section (replaces segment bar)
// ---------------------------------------------------------------------------

class _DonutChartSection extends StatelessWidget {
  const _DonutChartSection({
    required this.segments,
    required this.total,
  });

  final List<_BreakdownSegment> segments;
  final int total;

  @override
  Widget build(BuildContext context) {
    final activeSegments =
        segments.where((segment) => segment.count > 0).toList(growable: false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 120,
          height: 120,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, animProgress, _) {
              return CustomPaint(
                size: const Size(120, 120),
                painter: _DonutChartPainter(
                  segments: activeSegments,
                  total: total,
                  animationProgress: animProgress,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: segments
                .map(
                  (segment) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _LegendItem(
                      color: segment.color,
                      label: segment.label,
                      count: segment.count,
                      total: total,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Donut chart painter
// ---------------------------------------------------------------------------

class _DonutChartPainter extends CustomPainter {
  const _DonutChartPainter({
    required this.segments,
    required this.total,
    required this.animationProgress,
  });

  final List<_BreakdownSegment> segments;
  final int total;
  final double animationProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 4;
    const strokeWidth = 20.0;
    const gapAngle = 0.04;

    if (total == 0 || segments.isEmpty) {
      final emptyPaint = Paint()
        ..color = AppColors.greyLight.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, emptyPaint);
      return;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);
    var startAngle = -math.pi / 2;
    final totalGap = gapAngle * segments.length;
    final availableAngle = 2 * math.pi - totalGap;

    for (final segment in segments) {
      final sweepAngle =
          (segment.count / total) * availableAngle * animationProgress;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) =>
      animationProgress != oldDelegate.animationProgress ||
      total != oldDelegate.total ||
      segments != oldDelegate.segments;
}

// ---------------------------------------------------------------------------
// Legend item with percentage
// ---------------------------------------------------------------------------

class _LegendItem extends StatelessWidget {
  const _LegendItem({
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
    final percentage = total > 0 ? (count / total * 100).round() : 0;

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
        Text(
          '$label ($count)',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        if (total > 0) ...<Widget>[
          const SizedBox(width: 4),
          Text(
            '$percentage%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.greyLight,
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _severityColor().withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: _severityColor(),
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  application.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip(
                label: application.syncStatus,
                color: AppColors.syncColor(application.syncStatus),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: application.healthStatus,
                color: AppColors.healthColor(application.healthStatus),
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
                  bottom: 16,
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
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        StatusChip(
                          label: application.syncStatus,
                          color: AppColors.syncColor(application.syncStatus),
                        ),
                        const SizedBox(width: 8),
                        if (syncTime != null && syncTime.isNotEmpty)
                          Expanded(
                            child: Text(
                              _formatSyncTime(syncTime),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.greyLight,
                              ),
                              overflow: TextOverflow.ellipsis,
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
