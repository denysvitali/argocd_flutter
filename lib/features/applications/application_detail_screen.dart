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
  bool _actionInFlight = false;
  ArgoApplication? _cachedApplication;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadApplication(widget.applicationName);
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ArgoApplication>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _cachedApplication = snapshot.requireData;
          }

          if (snapshot.hasError && _cachedApplication == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString()),
              ),
            );
          }

          final application = snapshot.data ?? _cachedApplication;
          if (application == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final showLoadingOverlay =
              snapshot.connectionState != ConnectionState.done;

          return Stack(
            children: <Widget>[
              _DetailBody(
                controller: widget.controller,
                application: application,
                tabController: _tabController,
                actionInFlight: _actionInFlight,
                onRefresh: _refresh,
                onSync: _sync,
                onDelete: _confirmDelete,
                onRolledBack: _refresh,
              ),
              if (showLoadingOverlay)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.4),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
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
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: cascade,
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
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: colorScheme.error),
                  ),
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
    required this.actionInFlight,
    required this.onRefresh,
    required this.onSync,
    required this.onDelete,
    required this.onRolledBack,
  });

  final AppController controller;
  final ArgoApplication application;
  final TabController tabController;
  final bool actionInFlight;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSync;
  final Future<void> Function() onDelete;
  final Future<void> Function() onRolledBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(
                application: application,
                actionInFlight: actionInFlight,
                onRefresh: onRefresh,
                onSync: onSync,
                onDelete: onDelete,
                onDiff: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AppDiffScreen(
                        controller: controller,
                        applicationName: application.name,
                      ),
                    ),
                  );
                },
              ),
            ),
            title: innerBoxIsScrolled
                ? Text(
                    application.name,
                    style: theme.textTheme.titleMedium,
                  )
                : null,
            actions: innerBoxIsScrolled
                ? <Widget>[
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: actionInFlight ? null : onRefresh,
                    ),
                    IconButton(
                      tooltip: 'Sync',
                      icon: const Icon(Icons.sync, size: 20),
                      onPressed: actionInFlight ? null : onSync,
                    ),
                    IconButton(
                      tooltip: 'Diff',
                      icon: const Icon(Icons.compare_arrows, size: 20),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AppDiffScreen(
                              controller: controller,
                              applicationName: application.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ]
                : null,
            bottom: TabBar(
              controller: tabController,
              labelColor: theme.colorScheme.onSurface,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: theme.textTheme.labelLarge,
              indicatorColor: AppColors.teal,
              tabs: const <Widget>[
                Tab(text: 'Overview'),
                Tab(text: 'Resources'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: tabController,
        children: <Widget>[
          _OverviewTab(controller: controller, application: application),
          _ResourcesTab(
            controller: controller,
            applicationName: application.name,
            resources: application.resources,
          ),
          _HistoryTab(
            controller: controller,
            applicationName: application.name,
            history: application.history,
            onRolledBack: onRolledBack,
          ),
        ],
      ),
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 56,
        left: 16,
        right: 16,
        bottom: 54,
      ),
      decoration: BoxDecoration(
        color: AppColors.headerSurface(theme),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // App name + project badge row
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  application.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.headerForeground(theme),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.headerChipBackground(theme),
                  borderRadius: AppRadius.sm,
                ),
                child: Text(
                  application.project,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.headerMutedForeground(theme),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Status badges row
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              StatusChip(
                icon: healthStatusIcon(application.healthStatus),
                label: application.healthStatus,
                color: AppColors.healthColor(application.healthStatus),
              ),
              StatusChip(
                icon: syncStatusIcon(application.syncStatus),
                label: application.syncStatus,
                color: AppColors.syncColor(application.syncStatus),
              ),
              if (application.lastSyncedAt != null)
                StatusChip(
                  icon: Icons.schedule,
                  label:
                      'Synced ${formatRelativeTime(application.lastSyncedAt!)}',
                  color: AppColors.grey,
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons toolbar row (like ArgoCD's SYNC/REFRESH/DELETE/DIFF)
          Row(
            children: <Widget>[
              _ToolbarButton(
                icon: Icons.sync,
                label: 'Sync',
                onPressed: actionInFlight ? null : onSync,
                isPrimary: true,
              ),
              const SizedBox(width: 6),
              _ToolbarButton(
                icon: Icons.refresh,
                label: 'Refresh',
                onPressed: actionInFlight ? null : onRefresh,
              ),
              const SizedBox(width: 6),
              _ToolbarButton(
                icon: Icons.compare_arrows,
                label: 'Diff',
                onPressed: onDiff,
              ),
              const SizedBox(width: 6),
              _ToolbarButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onPressed: actionInFlight ? null : onDelete,
                isDanger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortCluster(String cluster) {
    final uri = Uri.tryParse(cluster);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return cluster;
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color fg;
    final Color bg;

    if (isDanger) {
      fg = onPressed != null ? AppColors.degraded : theme.disabledColor;
      bg = fg.withValues(alpha: 0.1);
    } else if (isPrimary) {
      fg = onPressed != null ? AppColors.teal : theme.disabledColor;
      bg = fg.withValues(alpha: 0.15);
    } else {
      fg = onPressed != null
          ? AppColors.headerForeground(theme)
          : theme.disabledColor;
      bg = AppColors.headerChipBackground(theme, alpha: 0.08);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.sm,
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
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
// Overview tab
// ---------------------------------------------------------------------------

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller, required this.application});

  final AppController controller;
  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        _SummarySection(application: application),
        const SizedBox(height: 14),
        _SourceSection(application: application),
        const SizedBox(height: 14),
        _DestinationSection(application: application),
        const SizedBox(height: 14),
        _ResourceTreeCard(
          controller: controller,
          applicationName: application.name,
        ),
        if (application.resources.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          _InlineResourceSummary(resources: application.resources),
        ],
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _DetailPill(label: 'Project', value: application.project),
              _DetailPill(label: 'Namespace', value: application.namespace),
              _DetailPill(label: 'Phase', value: application.operationPhase),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _StatusIndicator(
                label: 'Health',
                value: application.healthStatus,
                color: AppColors.healthColor(application.healthStatus),
                icon: healthStatusIcon(application.healthStatus),
              ),
              const SizedBox(width: 24),
              _StatusIndicator(
                label: 'Sync',
                value: application.syncStatus,
                color: AppColors.syncColor(application.syncStatus),
                icon: syncStatusIcon(application.syncStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SourceSection extends StatelessWidget {
  const _SourceSection({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Source',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LabeledText(label: 'Repository', value: application.repoUrl),
          _LabeledText(label: 'Path', value: application.path),
          _LabeledText(
            label: 'Target revision',
            value: application.targetRevision,
          ),
        ],
      ),
    );
  }
}

class _DestinationSection extends StatelessWidget {
  const _DestinationSection({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Destination',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _LabeledText(label: 'Cluster', value: application.cluster),
          _LabeledText(label: 'Namespace', value: application.namespace),
          if (application.lastSyncedAt != null)
            _LabeledText(
              label: 'Last reconciled',
              value: application.lastSyncedAt!,
            ),
        ],
      ),
    );
  }
}

class _ResourceTreeCard extends StatelessWidget {
  const _ResourceTreeCard({
    required this.controller,
    required this.applicationName,
  });

  final AppController controller;
  final String applicationName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.md,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ResourceTreeScreen(
                controller: controller,
                applicationName: applicationName,
              ),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: theme.dividerColor),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: AppRadius.base,
                ),
                child: const ExcludeSemantics(
                  child: Icon(Icons.account_tree, color: AppColors.cobalt),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'View Resource Tree',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inspect the Kubernetes resource hierarchy for this application.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No resources returned by the ArgoCD API.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ResourceCard(
            controller: controller,
            applicationName: applicationName,
            resource: resource,
          ),
        );
      },
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
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
    final kindColor = colorForResourceKind(resource.kind);
    final kindIcon = iconForResourceKind(resource.kind);
    final healthColor = AppColors.healthColor(resource.health);
    final isPod = resource.kind.toLowerCase() == 'pod';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.md,
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
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.md,
            border: Border.all(color: theme.dividerColor),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kindColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.base,
                ),
                child: Icon(kindIcon, color: kindColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kindColor.withValues(alpha: 0.12),
                            borderRadius: AppRadius.xs,
                          ),
                          child: Text(
                            resource.kind,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: kindColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          healthStatusIcon(resource.health),
                          size: 14,
                          color: healthColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          resource.health,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: healthColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      resource.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${resource.namespace} \u2022 ${resource.status}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPod)
                IconButton(
                  tooltip: 'Logs',
                  icon: const Icon(
                    Icons.article_outlined,
                    color: AppColors.cobalt,
                  ),
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
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No deployment history returned by the ArgoCD API.'),
        ),
      );
    }

    final currentEntry = history.last;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[history.length - 1 - index];
        final isCurrent = identical(entry, currentEntry);
        final isLast = index == history.length - 1;

        return _TimelineEntry(
          controller: controller,
          applicationName: applicationName,
          entry: entry,
          isCurrent: isCurrent,
          isLast: isLast,
          onRolledBack: onRolledBack,
        );
      },
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.controller,
    required this.applicationName,
    required this.entry,
    required this.isCurrent,
    required this.isLast,
    required this.onRolledBack,
  });

  final AppController controller;
  final String applicationName;
  final ArgoHistoryEntry entry;
  final bool isCurrent;
  final bool isLast;
  final Future<void> Function() onRolledBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relativeTime = formatRelativeTime(entry.deployedAt);
    final dotColor = isCurrent ? AppColors.healthy : AppColors.grey;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 32,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 4),
                Container(
                  width: isCurrent ? 12 : 10,
                  height: isCurrent ? 12 : 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(
                            color: dotColor.withValues(alpha: 0.4),
                            width: 2,
                          )
                        : null,
                    boxShadow: isCurrent
                        ? <BoxShadow>[
                            BoxShadow(
                              color: dotColor.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: theme.dividerColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppColors.healthy.withValues(alpha: 0.04)
                    : theme.colorScheme.surface,
                borderRadius: AppRadius.md,
                border: Border.all(
                  color: isCurrent
                      ? AppColors.healthy.withValues(alpha: 0.5)
                      : theme.dividerColor,
                  width: isCurrent ? 1.5 : 1.0,
                ),
                boxShadow: <BoxShadow>[
                  if (isCurrent)
                    BoxShadow(
                      color: AppColors.healthy.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  else
                    BoxShadow(
                      color:
                          theme.colorScheme.shadow.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (isCurrent)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: StatusChip(
                            label: 'Current',
                            color: AppColors.healthy,
                          ),
                        ),
                      Text(
                        'Deploy #${entry.id}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isCurrent
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isCurrent ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.commit,
                          size: 16,
                          color: AppColors.grey,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          entry.revision,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppColors.greyLight,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        relativeTime,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (!isCurrent) ...<Widget>[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _confirmRollback(context),
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('Rollback'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.amber,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRollback(BuildContext context) async {
    final warningColor = AppColors.amber;
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
              child: Text('Rollback', style: TextStyle(color: warningColor)),
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

// ---------------------------------------------------------------------------
// Inline resource summary (ArgoCD-style resource kind counts)
// ---------------------------------------------------------------------------

class _InlineResourceSummary extends StatelessWidget {
  const _InlineResourceSummary({required this.resources});

  final List<ArgoResource> resources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Group by kind
    final kindCounts = <String, int>{};
    var healthyCount = 0;
    var degradedCount = 0;
    var progressingCount = 0;
    for (final r in resources) {
      kindCounts[r.kind] = (kindCounts[r.kind] ?? 0) + 1;
      switch (r.health.toLowerCase()) {
        case 'healthy':
          healthyCount++;
        case 'degraded':
          degradedCount++;
        case 'progressing':
          progressingCount++;
      }
    }
    final otherCount =
        resources.length - healthyCount - degradedCount - progressingCount;

    return SectionCard(
      title: 'Resource Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Health breakdown row
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              _ResourceCountBadge(
                icon: Icons.favorite,
                label: 'Healthy',
                count: healthyCount,
                color: AppColors.healthy,
              ),
              _ResourceCountBadge(
                icon: Icons.autorenew,
                label: 'Progressing',
                count: progressingCount,
                color: AppColors.progressing,
              ),
              _ResourceCountBadge(
                icon: Icons.heart_broken,
                label: 'Degraded',
                count: degradedCount,
                color: AppColors.degraded,
              ),
              if (otherCount > 0)
                _ResourceCountBadge(
                  icon: Icons.help_outline,
                  label: 'Other',
                  count: otherCount,
                  color: AppColors.grey,
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Text(
            'Resources by Kind',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final entry in kindCounts.entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorForResourceKind(entry.key)
                        .withValues(alpha: 0.1),
                    borderRadius: AppRadius.sm,
                  ),
                  child: Text(
                    '${entry.key} (${entry.value})',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorForResourceKind(entry.key),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourceCountBadge extends StatelessWidget {
  const _ResourceCountBadge({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.base,
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.6),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 1, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
