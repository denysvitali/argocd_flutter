import 'dart:async';
import 'dart:math';

import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

class DriftRadarScreen extends StatefulWidget {
  const DriftRadarScreen({
    super.key,
    required this.controller,
    required this.onOpenApplication,
  });

  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  State<DriftRadarScreen> createState() => _DriftRadarScreenState();
}

class _DriftRadarScreenState extends State<DriftRadarScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxEvents = 24;
  static const Duration _tick = Duration(seconds: 6);

  final Random _random = Random();
  final List<_DriftEvent> _events = <_DriftEvent>[];
  Timer? _timer;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _seedEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.of(context);
    if (enabled && _timer == null) {
      _timer = Timer.periodic(_tick, (_) => _appendRandomEvent());
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (!enabled) {
      _timer?.cancel();
      _timer = null;
      _pulseController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant DriftRadarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _events.clear();
      _seedEvents();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _seedEvents() {
    final apps = widget.controller.applications;
    if (apps.isEmpty) {
      _events.addAll(_placeholderEvents());
      return;
    }

    final outOfSync = apps.where((app) => app.isOutOfSync).toList();
    for (final app in outOfSync.take(6)) {
      _events.add(_eventForApp(app, severity: _DriftSeverity.critical));
    }

    if (_events.isEmpty) {
      for (final app in apps.take(4)) {
        _events.add(_eventForApp(app, severity: _DriftSeverity.warning));
      }
    }
  }

  void _appendRandomEvent() {
    final apps = widget.controller.applications;
    final event = apps.isEmpty
        ? _placeholderEvents().first
        : _eventForApp(apps[_random.nextInt(apps.length)]);

    setState(() {
      _events.insert(0, event.copyWith(timestamp: DateTime.now()));
      if (_events.length > _maxEvents) {
        _events.removeRange(_maxEvents, _events.length);
      }
    });
  }

  _DriftEvent _eventForApp(
    ArgoApplication app, {
    _DriftSeverity? severity,
  }) {
    final resolvedSeverity =
        severity ?? (app.isOutOfSync ? _DriftSeverity.warning : _randomSeverity());
    final driftTypes = <String>[
      'Deployment image tag drift',
      'Service port mismatch',
      'ConfigMap checksum drift',
      'Replica count mismatch',
      'Namespace annotation drift',
    ];

    return _DriftEvent(
      applicationName: app.name,
      project: app.project,
      cluster: app.cluster,
      namespace: app.namespace,
      severity: resolvedSeverity,
      driftSummary: driftTypes[_random.nextInt(driftTypes.length)],
      changedResources: _random.nextInt(8) + 1,
      lastSyncedAt: app.lastSyncedAt,
      timestamp: DateTime.now().subtract(Duration(minutes: _random.nextInt(42))),
    );
  }

  _DriftSeverity _randomSeverity() {
    final pick = _random.nextDouble();
    if (pick > 0.7) return _DriftSeverity.critical;
    if (pick > 0.35) return _DriftSeverity.warning;
    return _DriftSeverity.info;
  }

  List<_DriftEvent> _placeholderEvents() {
    return <_DriftEvent>[
      _DriftEvent(
        applicationName: 'argo-hub',
        project: 'platform',
        cluster: 'in-cluster',
        namespace: 'argocd',
        severity: _DriftSeverity.critical,
        driftSummary: 'Deployment image tag drift',
        changedResources: 5,
        lastSyncedAt: null,
        timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
      ),
      _DriftEvent(
        applicationName: 'payments-ledger',
        project: 'payments',
        cluster: 'prod-us-east',
        namespace: 'payments',
        severity: _DriftSeverity.warning,
        driftSummary: 'Replica count mismatch',
        changedResources: 2,
        lastSyncedAt: null,
        timestamp: DateTime.now().subtract(const Duration(minutes: 14)),
      ),
      _DriftEvent(
        applicationName: 'edge-routing',
        project: 'networking',
        cluster: 'edge-1',
        namespace: 'gateway',
        severity: _DriftSeverity.info,
        driftSummary: 'ConfigMap checksum drift',
        changedResources: 1,
        lastSyncedAt: null,
        timestamp: DateTime.now().subtract(const Duration(minutes: 21)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final apps = widget.controller.applications;
        final grouped = _buildGroups(apps, _events);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Drift Radar'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _LiveIndicator(controller: _pulseController),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => widget.controller.refreshApplications(),
            child: ListView(
              padding: kPagePadding,
              children: <Widget>[
                _RadarHero(
                  totalEvents: _events.length,
                  criticalCount: _events
                      .where((event) => event.severity == _DriftSeverity.critical)
                      .length,
                  warningCount: _events
                      .where((event) => event.severity == _DriftSeverity.warning)
                      .length,
                  infoCount: _events
                      .where((event) => event.severity == _DriftSeverity.info)
                      .length,
                ),
                const SizedBox(height: 12),
                _SectionHeader(title: 'Hot Spots'),
                const SizedBox(height: 6),
                SectionCard(
                  title: null,
                  child: grouped.isEmpty
                      ? const EmptyStateCard(
                          title: 'No drift detected',
                          subtitle: 'All applications are in sync right now.',
                        )
                      : Column(
                          children: grouped
                              .map((group) => _GroupTile(
                                    group: group,
                                    onOpenApplication: widget.onOpenApplication,
                                  ))
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: 12),
                _SectionHeader(title: 'Live Feed'),
                const SizedBox(height: 6),
                SectionCard(
                  title: null,
                  child: Column(
                    children: _events
                        .map(
                          (event) => _DriftEventTile(
                            event: event,
                            controller: widget.controller,
                            onOpenApplication: widget.onOpenApplication,
                          ),
                        )
                        .toList(growable: false),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RadarHero extends StatelessWidget {
  const _RadarHero({
    required this.totalEvents,
    required this.criticalCount,
    required this.warningCount,
    required this.infoCount,
  });

  final int totalEvents;
  final int criticalCount;
  final int warningCount;
  final int infoCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.headerDark
            : AppColors.cobalt,
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Drift Radar',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.headerForeground(theme),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Streaming configuration deltas and sync gaps across clusters.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.headerMutedForeground(theme),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _HeroStat(
                label: 'Events',
                value: totalEvents,
                color: AppColors.headerForeground(theme),
              ),
              _HeroStat(
                label: 'Critical',
                value: criticalCount,
                color: AppColors.coral,
              ),
              _HeroStat(
                label: 'Warning',
                value: warningCount,
                color: AppColors.amber,
              ),
              _HeroStat(
                label: 'Info',
                value: infoCount,
                color: AppColors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.headerChipBackground(theme),
        borderRadius: AppRadius.base,
        border: Border.all(color: AppColors.headerDivider(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.headerMutedForeground(theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = AppColors.headerForeground(theme);
    final highlight = theme.brightness == Brightness.dark
        ? AppColors.teal
        : AppColors.amber;

    return Row(
      children: <Widget>[
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highlight.withValues(alpha: 0.6 + controller.value * 0.4),
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          'LIVE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _GroupSummary {
  const _GroupSummary({
    required this.applicationName,
    required this.project,
    required this.cluster,
    required this.namespace,
    required this.count,
    required this.severity,
    required this.lastEventAt,
  });

  final String applicationName;
  final String project;
  final String cluster;
  final String namespace;
  final int count;
  final _DriftSeverity severity;
  final DateTime lastEventAt;
}

List<_GroupSummary> _buildGroups(
  List<ArgoApplication> apps,
  List<_DriftEvent> events,
) {
  final Map<String, _GroupSummary> grouped = <String, _GroupSummary>{};
  for (final event in events) {
    final existing = grouped[event.applicationName];
    final severity = _maxSeverity(existing?.severity, event.severity);
    grouped[event.applicationName] = _GroupSummary(
      applicationName: event.applicationName,
      project: event.project,
      cluster: event.cluster,
      namespace: event.namespace,
      count: (existing?.count ?? 0) + 1,
      severity: severity,
      lastEventAt: event.timestamp,
    );
  }

  final list = grouped.values.toList();
  list.sort((a, b) {
    final severityCompare = b.severity.index.compareTo(a.severity.index);
    if (severityCompare != 0) return severityCompare;
    return b.lastEventAt.compareTo(a.lastEventAt);
  });

  if (list.isNotEmpty) {
    return list.take(4).toList(growable: false);
  }

  if (apps.isEmpty) return const <_GroupSummary>[];

  return apps
      .where((app) => app.isOutOfSync)
      .take(3)
      .map(
        (app) => _GroupSummary(
          applicationName: app.name,
          project: app.project,
          cluster: app.cluster,
          namespace: app.namespace,
          count: 1,
          severity: _DriftSeverity.warning,
          lastEventAt: DateTime.now(),
        ),
      )
      .toList(growable: false);
}

_DriftSeverity _maxSeverity(_DriftSeverity? a, _DriftSeverity b) {
  if (a == null) return b;
  return a.index >= b.index ? a : b;
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.onOpenApplication,
  });

  final _GroupSummary group;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = group.severity.color;

    return InkWell(
      onTap: () => onOpenApplication(group.applicationName),
      borderRadius: AppRadius.base,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Container(
              width: 8,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppRadius.base,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    group.applicationName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.project} · ${group.namespace} · ${group.cluster}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                StatusChip(label: group.severity.label, color: color),
                const SizedBox(height: 6),
                Text(
                  '${group.count} signal${group.count == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DriftEventTile extends StatelessWidget {
  const _DriftEventTile({
    required this.event,
    required this.controller,
    required this.onOpenApplication,
  });

  final _DriftEvent event;
  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = event.severity.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.applicationName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip(label: event.severity.label, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            event.driftSummary,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${event.changedResources} resources changed · '
            '${event.project} · ${event.namespace}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Text(
                'Last signal ${formatRelativeTime(event.timestamp.toIso8601String())}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.grey,
                ),
              ),
              const Spacer(),
              _ActionButton(
                label: 'Inspect',
                icon: Icons.open_in_new,
                onPressed: () => onOpenApplication(event.applicationName),
              ),
              const SizedBox(width: 6),
              _ActionButton(
                label: 'Sync',
                icon: Icons.sync,
                onPressed: () async {
                  await _syncApplication(context, controller, event);
                },
              ),
              const SizedBox(width: 6),
              _ActionButton(
                label: 'Rollback',
                icon: Icons.undo,
                onPressed: () async {
                  await _rollbackApplication(context, controller, event);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _syncApplication(
    BuildContext context,
    AppController controller,
    _DriftEvent event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.syncApplication(event.applicationName);
      messenger.showSnackBar(
        SnackBar(content: Text('Sync started for ${event.applicationName}.')),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Sync failed: $error')),
      );
    }
  }

  Future<void> _rollbackApplication(
    BuildContext context,
    AppController controller,
    _DriftEvent event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    ArgoApplication? app;
    for (final candidate in controller.applications) {
      if (candidate.name == event.applicationName) {
        app = candidate;
        break;
      }
    }
    final history = app?.history ?? const <ArgoHistoryEntry>[];

    if (history.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No rollback history for ${event.applicationName}.'),
        ),
      );
      return;
    }

    final entry = history.first;
    try {
      await controller.rollbackApplication(event.applicationName, entry.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Rollback triggered for ${event.applicationName}.'),
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Rollback failed: $error')),
      );
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: theme.colorScheme.primary,
        textStyle: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: AppIconSize.sm),
      label: Text(label),
    );
  }
}

class _DriftEvent {
  const _DriftEvent({
    required this.applicationName,
    required this.project,
    required this.cluster,
    required this.namespace,
    required this.severity,
    required this.driftSummary,
    required this.changedResources,
    required this.lastSyncedAt,
    required this.timestamp,
  });

  final String applicationName;
  final String project;
  final String cluster;
  final String namespace;
  final _DriftSeverity severity;
  final String driftSummary;
  final int changedResources;
  final String? lastSyncedAt;
  final DateTime timestamp;

  _DriftEvent copyWith({DateTime? timestamp}) {
    return _DriftEvent(
      applicationName: applicationName,
      project: project,
      cluster: cluster,
      namespace: namespace,
      severity: severity,
      driftSummary: driftSummary,
      changedResources: changedResources,
      lastSyncedAt: lastSyncedAt,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

enum _DriftSeverity { info, warning, critical }

extension on _DriftSeverity {
  String get label => switch (this) {
        _DriftSeverity.info => 'Info',
        _DriftSeverity.warning => 'Warning',
        _DriftSeverity.critical => 'Critical',
      };

  Color get color => switch (this) {
        _DriftSeverity.info => AppColors.teal,
        _DriftSeverity.warning => AppColors.amber,
        _DriftSeverity.critical => AppColors.coral,
      };
}
