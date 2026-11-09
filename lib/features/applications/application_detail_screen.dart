import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

import 'app_diff_screen.dart';
import 'log_viewer_screen.dart';
import 'manifest_viewer_screen.dart';
import 'resource_tree_screen.dart';

/// Vertical gap between top-level sections.
const double _kSectionGap = 28;

/// Scroll offset after which the app name moves into the navigation bar.
const double _kTitleRevealOffset = 44;

class ApplicationDetailScreen extends StatefulWidget {
  const ApplicationDetailScreen({
    super.key,
    required this.controller,
    required this.applicationName,
  });

  final AppController controller;
  final String applicationName;

  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<ArgoApplication> _future;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _titleVisible = ValueNotifier<bool>(false);
  bool _actionInFlight = false;
  ArgoApplication? _cachedApplication;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadApplication(widget.applicationName);
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _titleVisible.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    _titleVisible.value =
        _scrollController.hasClients &&
        _scrollController.offset > _kTitleRevealOffset;
  }

  void _openDiff() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppDiffScreen(
          controller: widget.controller,
          applicationName: widget.applicationName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<bool>(
          valueListenable: _titleVisible,
          builder: (context, visible, _) {
            return AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Text(
                widget.applicationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        actions: <Widget>[
          ValueListenableBuilder<bool>(
            valueListenable: _titleVisible,
            builder: (context, visible, _) {
              if (!visible || _cachedApplication == null) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _actionInFlight ? null : _refresh,
                  ),
                  IconButton(
                    tooltip: 'Sync',
                    icon: const Icon(Icons.sync_rounded),
                    onPressed: _actionInFlight ? null : _sync,
                  ),
                  IconButton(
                    tooltip: 'Diff',
                    icon: const Icon(Icons.compare_arrows_rounded),
                    onPressed: _openDiff,
                  ),
                  const SizedBox(width: 4),
                ],
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<ArgoApplication>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedApplication = snapshot.requireData;
          }

          if (snapshot.hasError && _cachedApplication == null) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: EmptyStateCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Couldn’t Load Application',
                  subtitle: snapshot.error.toString(),
                  action: OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Try Again'),
                  ),
                ),
              ),
            );
          }

          final application = snapshot.data ?? _cachedApplication;
          if (application == null) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            );
          }

          final reloading = snapshot.connectionState != ConnectionState.done;

          return Stack(
            children: <Widget>[
              _DetailBody(
                controller: widget.controller,
                application: application,
                tabController: _tabController,
                scrollController: _scrollController,
                actionInFlight: _actionInFlight,
                onRefresh: _refresh,
                onSync: _sync,
                onDelete: _confirmDelete,
                onDiff: _openDiff,
                onRolledBack: _refresh,
              ),
              if (reloading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _reload() {
    setState(() {
      _future = widget.controller.loadApplication(widget.applicationName);
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _actionInFlight = true;
      _future = widget.controller.loadApplication(
        widget.applicationName,
        refresh: true,
      );
    });

    try {
      await _future;
    } finally {
      if (mounted) {
        setState(() {
          _actionInFlight = false;
        });
      }
    }
  }

  Future<void> _sync() async {
    if (_actionInFlight) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sync Application'),
          content: Text(
            'Sync \'${widget.applicationName}\'? '
            'This will trigger a new sync operation.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sync'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _actionInFlight = true;
    });

    try {
      await widget.controller.syncApplication(widget.applicationName);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sync requested.')));
      _future = widget.controller.loadApplication(
        widget.applicationName,
        refresh: true,
      );
      await _future;
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _actionInFlight = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (_actionInFlight) {
      return;
    }

    bool cascade = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Delete Application'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Are you sure you want to delete '${widget.applicationName}'? This action cannot be undone.",
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: cascade,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Cascade delete (remove child resources)',
                    ),
                    onChanged: (value) {
                      setState(() {
                        cascade = value ?? true;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      setState(() {
        _actionInFlight = true;
      });
      await widget.controller.deleteApplication(
        widget.applicationName,
        cascade: cascade,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application deleted.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _actionInFlight = false;
        });
      }
    }
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.controller,
    required this.application,
    required this.tabController,
    required this.scrollController,
    required this.actionInFlight,
    required this.onRefresh,
    required this.onSync,
    required this.onDelete,
    required this.onDiff,
    required this.onRolledBack,
  });

  final AppController controller;
  final ArgoApplication application;
  final TabController tabController;
  final ScrollController scrollController;
  final bool actionInFlight;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSync;
  final Future<void> Function() onDelete;
  final VoidCallback onDiff;
  final Future<void> Function() onRolledBack;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListenableBuilder(
      listenable: tabController,
      builder: (context, _) {
        final Widget tab = switch (tabController.index) {
          1 => _ResourcesTab(
            controller: controller,
            applicationName: application.name,
            resources: application.resources,
          ),
          2 => _HistoryTab(
            controller: controller,
            applicationName: application.name,
            history: application.history,
            onRolledBack: onRolledBack,
          ),
          _ => _OverviewTab(controller: controller, application: application),
        };

        return CustomScrollView(
          controller: scrollController,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _HeroHeader(
                application: application,
                actionInFlight: actionInFlight,
                onRefresh: onRefresh,
                onSync: onSync,
                onDelete: onDelete,
                onDiff: onDiff,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SegmentedHeaderDelegate(tabController: tabController),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + bottomInset),
              sliver: SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: ValueKey<int>(tabController.index),
                  child: tab,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Hero header
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.application,
    required this.actionInFlight,
    required this.onRefresh,
    required this.onSync,
    required this.onDelete,
    required this.onDiff,
  });

  final ArgoApplication application;
  final bool actionInFlight;
  final VoidCallback onRefresh;
  final VoidCallback onSync;
  final VoidCallback onDelete;
  final VoidCallback onDiff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lastSynced = application.lastSyncedAt == null
        ? null
        : formatRelativeTime(application.lastSyncedAt!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            application.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 2),
          Text(
            application.project,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _StatusLabel(
                label: application.healthStatus,
                color: AppColors.healthColor(application.healthStatus),
              ),
              _StatusLabel(
                label: application.syncStatus,
                color: AppColors.syncColor(application.syncStatus),
              ),
              if (application.operationPhase.toLowerCase() == 'failed')
                const _StatusLabel(
                  label: 'Op Failed',
                  color: AppColors.degraded,
                ),
            ],
          ),
          if (lastSynced != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Last synced $lastSynced',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          ConstrainedBox(
            // On tablets the four actions stay compact instead of stretching.
            constraints: const BoxConstraints(maxWidth: 520),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _ActionButton(
                    icon: Icons.sync,
                    label: 'Sync',
                    onPressed: actionInFlight ? null : onSync,
                    style: _ActionStyle.prominent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh',
                    onPressed: actionInFlight ? null : onRefresh,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.compare_arrows_rounded,
                    label: 'Diff',
                    onPressed: onDiff,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onPressed: actionInFlight ? null : onDelete,
                    style: _ActionStyle.destructive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "● Healthy" — a status dot followed by the status in its readable hue.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        StatusDot(color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.statusForeground(theme, color),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

enum _ActionStyle { standard, prominent, destructive }

/// iOS "contact card" style action: an equal-width rounded tile with a glyph
/// above a short label.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.style = _ActionStyle.standard,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final _ActionStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;

    final Color background;
    final Color foreground;
    if (!enabled) {
      background = scheme.surfaceContainerLow;
      foreground = AppColors.tertiaryLabel(theme);
    } else {
      switch (style) {
        case _ActionStyle.prominent:
          background = scheme.primary;
          foreground = scheme.onPrimary;
        case _ActionStyle.destructive:
          background = scheme.surfaceContainerLow;
          foreground = scheme.error;
        case _ActionStyle.standard:
          background = scheme.surfaceContainerLow;
          foreground = scheme.primary;
      }
    }

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: background,
        borderRadius: AppRadius.base,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 21, color: foreground),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
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

/// Pinned iOS segmented control (Overview / Resources / History).
class _SegmentedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SegmentedHeaderDelegate({required this.tabController});

  final TabController tabController;

  static const double _height = 52;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stuck = shrinkOffset > 0 || overlapsContent;
    final barColor =
        WidgetStateProperty.resolveAs<Color?>(
          theme.appBarTheme.backgroundColor,
          <WidgetState>{WidgetState.scrolledUnder},
        ) ??
        scheme.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: stuck ? barColor : scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: stuck ? scheme.outlineVariant : Colors.transparent,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            // iOS caps segmented controls on wide layouts.
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              height: 36,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.fill(theme),
                borderRadius: BorderRadius.circular(11),
              ),
              child: TabBar(
                controller: tabController,
                tabs: const <Widget>[
                  Tab(height: 32, text: 'Overview'),
                  Tab(height: 32, text: 'Resources'),
                  Tab(height: 32, text: 'History'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SegmentedHeaderDelegate oldDelegate) {
    return oldDelegate.tabController != tabController;
  }
}

// ---------------------------------------------------------------------------
// Overview tab
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller, required this.application});

  final AppController controller;
  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final primary = <Widget>[
          if (application.hasOperationError) ...<Widget>[
            _OperationErrorCard(application: application),
            const SizedBox(height: _kSectionGap),
          ],
          _StatusSection(application: application),
          const SizedBox(height: _kSectionGap),
          _ResourcesSection(controller: controller, application: application),
        ];
        final secondary = <Widget>[
          _SourceSection(application: application),
          const SizedBox(height: _kSectionGap),
          _DestinationSection(application: application),
        ];

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ...primary,
              const SizedBox(height: _kSectionGap),
              ...secondary,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: primary,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: secondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OperationErrorCard extends StatelessWidget {
  const _OperationErrorCard({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final errorForeground = AppColors.statusForeground(
      theme,
      AppColors.degraded,
    );

    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(Icons.error_rounded, size: 20, color: errorForeground),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Last sync operation failed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: errorForeground,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  application.operationMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    return GroupedList(
      header: 'Status',
      children: <Widget>[
        GroupedRow(
          title: 'Health',
          trailing: _StatusValue(
            label: application.healthStatus,
            color: AppColors.healthColor(application.healthStatus),
          ),
        ),
        GroupedRow(
          title: 'Sync',
          trailing: _StatusValue(
            label: application.syncStatus,
            color: AppColors.syncColor(application.syncStatus),
          ),
        ),
        GroupedRow(title: 'Project', value: application.project),
        GroupedRow(title: 'Namespace', value: application.namespace),
        GroupedRow(title: 'Phase', value: application.operationPhase),
      ],
    );
  }
}

/// Trailing row value for a status: dot + muted label.
class _StatusValue extends StatelessWidget {
  const _StatusValue({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        StatusDot(color: color),
        const SizedBox(width: 7),
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ResourcesSection extends StatelessWidget {
  const _ResourcesSection({
    required this.controller,
    required this.application,
  });

  final AppController controller;
  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GroupedList(
      header: 'Resources',
      children: <Widget>[
        if (application.resources.isNotEmpty)
          _ResourceHealthSummary(resources: application.resources),
        GroupedRow(
          leading: IconWell(
            icon: Icons.account_tree_rounded,
            color: theme.colorScheme.primary,
          ),
          title: 'Resource Tree',
          subtitle: 'Kubernetes resource hierarchy',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ResourceTreeScreen(
                  controller: controller,
                  applicationName: application.name,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Health distribution of the application's resources: a thin capsule bar,
/// a dot legend and a one-line breakdown by kind.
class _ResourceHealthSummary extends StatelessWidget {
  const _ResourceHealthSummary({required this.resources});

  final List<ArgoResource> resources;

  static const List<String> _healthOrder = <String>[
    'Healthy',
    'Progressing',
    'Suspended',
    'Missing',
    'Degraded',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final healthCounts = <String, int>{};
    final kindCounts = <String, int>{};
    for (final resource in resources) {
      final known = _healthOrder.firstWhere(
        (h) => h.toLowerCase() == resource.health.toLowerCase(),
        orElse: () => 'Unknown',
      );
      healthCounts[known] = (healthCounts[known] ?? 0) + 1;
      kindCounts[resource.kind] = (kindCounts[resource.kind] ?? 0) + 1;
    }
    final buckets = <MapEntry<String, int>>[
      for (final health in <String>[..._healthOrder, 'Unknown'])
        if ((healthCounts[health] ?? 0) > 0)
          MapEntry<String, int>(health, healthCounts[health]!),
    ];
    final count = resources.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$count ${count == 1 ? 'resource' : 'resources'}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          StatusSegmentBar(
            segments: <StatusSegment>[
              for (final bucket in buckets)
                StatusSegment(
                  color: AppColors.healthColor(bucket.key),
                  count: bucket.value,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: <Widget>[
              for (final bucket in buckets)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    StatusDot(
                      color: AppColors.healthColor(bucket.key),
                      size: 7,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${bucket.value} ${bucket.key}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: AppFonts.tabularFigures,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kindCounts.entries
                .map((entry) => '${entry.value} ${entry.key}')
                .join('  ·  '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.tertiaryLabel(theme),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceSection extends StatelessWidget {
  const _SourceSection({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    return GroupedList(
      header: 'Source',
      children: <Widget>[
        _FactRow(label: 'Repository', value: application.repoUrl),
        _FactRow(label: 'Path', value: application.path),
        _FactRow(label: 'Target revision', value: application.targetRevision),
      ],
    );
  }
}

class _DestinationSection extends StatelessWidget {
  const _DestinationSection({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    return GroupedList(
      header: 'Destination',
      children: <Widget>[
        _FactRow(label: 'Cluster', value: application.cluster),
        _FactRow(label: 'Namespace', value: application.namespace),
        if (application.lastSyncedAt != null)
          _FactRow(
            label: 'Last reconciled',
            value: formatTimestampWithRelative(application.lastSyncedAt!),
          ),
      ],
    );
  }
}

/// Key/value row for potentially long values (URLs, timestamps): label on
/// the left, muted value right-aligned and allowed to wrap onto two lines.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.bodyLarge),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resources tab
// ---------------------------------------------------------------------------

class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab({
    required this.controller,
    required this.applicationName,
    required this.resources,
  });

  final AppController controller;
  final String applicationName;
  final List<ArgoResource> resources;

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.inventory_2_outlined,
        title: 'No Resources',
        subtitle: 'No resources returned by the ArgoCD API.',
      );
    }

    final groups = _groupByKind(resources);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < groups.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          _ResourceGroup(
            key: ValueKey<String>('resource-kind-${groups[i].kind}'),
            controller: controller,
            applicationName: applicationName,
            kind: groups[i].kind,
            resources: groups[i].resources,
          ),
        ],
      ],
    );
  }

  static List<_ResourceGroupData> _groupByKind(List<ArgoResource> resources) {
    final byKind = <String, List<ArgoResource>>{};
    for (final resource in resources) {
      byKind.putIfAbsent(resource.kind, () => <ArgoResource>[]).add(resource);
    }
    final entries = byKind.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return <_ResourceGroupData>[
      for (final entry in entries)
        _ResourceGroupData(
          kind: entry.key,
          resources: List<ArgoResource>.of(entry.value)
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ),
        ),
    ];
  }
}

class _ResourceGroupData {
  const _ResourceGroupData({required this.kind, required this.resources});

  final String kind;
  final List<ArgoResource> resources;
}

const int _kCollapsedGroupThreshold = 2;

/// Leading inset of resource rows so they align with the group title text.
const double _kResourceRowInset = 52;

class _ResourceGroup extends StatefulWidget {
  const _ResourceGroup({
    super.key,
    required this.controller,
    required this.applicationName,
    required this.kind,
    required this.resources,
  });

  final AppController controller;
  final String applicationName;
  final String kind;
  final List<ArgoResource> resources;

  @override
  State<_ResourceGroup> createState() => _ResourceGroupState();
}

class _ResourceGroupState extends State<_ResourceGroup> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.resources.length <= _kCollapsedGroupThreshold;
  }

  @override
  void didUpdateWidget(covariant _ResourceGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resources.length != oldWidget.resources.length) {
      _expanded = widget.resources.length <= _kCollapsedGroupThreshold;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  String _labelForCount(int count) {
    return '$count ${count == 1 ? 'resource' : 'resources'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final divider = Divider(
      height: 0.5,
      indent: _kResourceRowInset,
      color: scheme.outlineVariant,
    );

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              key: ValueKey<String>('resource-group-${widget.kind}'),
              onTap: _toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: _kResourceRowInset - 16,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ExcludeSemantics(
                          child: Icon(
                            iconForResourceKind(widget.kind),
                            size: 22,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: widget.kind,
                              style: theme.textTheme.titleMedium,
                            ),
                            TextSpan(
                              text:
                                  ' (${_labelForCount(widget.resources.length)})',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const DisclosureChevron(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final resource in widget.resources) ...<Widget>[
                        divider,
                        _ResourceRow(
                          controller: widget.controller,
                          applicationName: widget.applicationName,
                          resource: resource,
                        ),
                      ],
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.controller,
    required this.applicationName,
    required this.resource,
  });

  final AppController controller;
  final String applicationName;
  final ArgoResource resource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final healthColor = AppColors.healthColor(resource.health);
    final isPod = resource.kind.toLowerCase() == 'pod';
    final meta = <String>[
      if (resource.status.isNotEmpty) resource.status,
      if (resource.namespace.isNotEmpty) resource.namespace,
    ].join(' · ');

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ManifestViewerScreen(
              controller: controller,
              applicationName: applicationName,
              namespace: resource.namespace,
              resourceName: resource.name,
              kind: resource.kind,
              group: resource.group,
              version: resource.version,
            ),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _kResourceRowInset,
          10,
          isPod ? 4 : 14,
          10,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    resource.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      StatusDot(color: healthColor, size: 7),
                      const SizedBox(width: 6),
                      Text(
                        resource.health,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.statusForeground(theme, healthColor),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Flexible(
                          child: Text(
                            ' · $meta',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (isPod)
              IconButton(
                tooltip: 'Logs',
                icon: const Icon(Icons.article_outlined, size: 21),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LogViewerScreen(
                        controller: controller,
                        applicationName: applicationName,
                        namespace: resource.namespace,
                        podName: resource.name,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(width: 4),
            const DisclosureChevron(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History tab
// ---------------------------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.controller,
    required this.applicationName,
    required this.history,
    required this.onRolledBack,
  });

  final AppController controller;
  final String applicationName;
  final List<ArgoHistoryEntry> history;
  final Future<void> Function() onRolledBack;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.history_rounded,
        title: 'No History',
        subtitle: 'No deployment history returned by the ArgoCD API.',
      );
    }

    final currentEntry = history.last;

    return GroupedList(
      header: 'Deployments',
      footer: 'Most recent first. Rolling back re-applies an earlier revision.',
      children: <Widget>[
        for (final entry in history.reversed)
          _HistoryRow(
            controller: controller,
            applicationName: applicationName,
            entry: entry,
            isCurrent: identical(entry, currentEntry),
            onRolledBack: onRolledBack,
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.controller,
    required this.applicationName,
    required this.entry,
    required this.isCurrent,
    required this.onRolledBack,
  });

  final AppController controller;
  final String applicationName;
  final ArgoHistoryEntry entry;
  final bool isCurrent;
  final Future<void> Function() onRolledBack;

  static final RegExp _fullSha = RegExp(r'^[0-9a-f]{40}$');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final revision = _fullSha.hasMatch(entry.revision)
        ? entry.revision.substring(0, 7)
        : entry.revision;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, isCurrent ? 16 : 8, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Deploy #${entry.id}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontFeatures: AppFonts.tabularFigures,
                        ),
                      ),
                      if (isCurrent) ...<Widget>[
                        const SizedBox(width: 8),
                        const StatusChip(
                          label: 'Current',
                          color: AppColors.healthy,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          revision,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: AppFonts.mono,
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '  ·  ${formatRelativeTime(entry.deployedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isCurrent)
              TextButton(
                onPressed: () => _confirmRollback(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Rollback'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRollback(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rollback Application'),
          content: Text(
            "Roll back '$applicationName' to revision ${entry.revision} (deploy #${entry.id})?",
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Rollback'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await controller.rollbackApplication(applicationName, entry.id);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Rollback to revision ${entry.revision} initiated.'),
        ),
      );
      await onRolledBack();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}
