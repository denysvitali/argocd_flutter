import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

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
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Text(snapshot.error.toString()),
              ),
            );
          }

          final application = snapshot.requireData;
          return _DetailBody(
            controller: widget.controller,
            application: application,
            tabController: _tabController,
            actionInFlight: _actionInFlight,
            onRefresh: _refresh,
            onSync: _sync,
            onDelete: _confirmDelete,
            onRolledBack: _refresh,
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

    return Column(
      children: <Widget>[
        Expanded(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  forceElevated: innerBoxIsScrolled,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _HeroHeader(application: application),
                  ),
                  title: innerBoxIsScrolled
                      ? Text(
                          application.name,
                          style: theme.textTheme.titleMedium,
                        )
                      : null,
                  bottom: TabBar(
                    controller: tabController,
                    labelColor: theme.colorScheme.onSurface,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    indicatorColor: AppColors.cobalt,
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
          ),
        ),
        _BottomActionBar(
          actionInFlight: actionInFlight,
          onRefresh: onRefresh,
          onSync: onSync,
          onDelete: onDelete,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero header
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 52,
        left: 16,
        right: 16,
        bottom: 52,
      ),
      decoration: const BoxDecoration(
        color: AppColors.headerDark,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            application.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${application.project}  \u2022  ${application.namespace}  \u2022  ${_shortCluster(application.cluster)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              StatusChip(
                label: application.healthStatus,
                color: AppColors.healthColor(application.healthStatus),
              ),
              StatusChip(
                label: application.syncStatus,
                color: AppColors.syncColor(application.syncStatus),
              ),
              if (application.lastSyncedAt != null)
                StatusChip(
                  label:
                      'Synced ${formatRelativeTime(application.lastSyncedAt!)}',
                  color: AppColors.grey,
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
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: <Widget>[
        _SummarySection(application: application),
        const SizedBox(height: AppSpacing.xxl),
        _SourceSection(application: application),
        const SizedBox(height: AppSpacing.xxl),
        _DestinationSection(application: application),
        const SizedBox(height: AppSpacing.xxl),
        _ResourceTreeCard(
          controller: controller,
          applicationName: application.name,
        ),
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
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              DetailPill(label: 'Project', value: application.project),
              DetailPill(label: 'Namespace', value: application.namespace),
              DetailPill(label: 'Phase', value: application.operationPhase),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              StatusIndicator(
                label: 'Health',
                value: application.healthStatus,
                color: AppColors.healthColor(application.healthStatus),
              ),
              const SizedBox(width: 24),
              StatusIndicator(
                label: 'Sync',
                value: application.syncStatus,
                color: AppColors.syncColor(application.syncStatus),
              ),
            ],
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
    return SectionCard(
      title: 'Source',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LabeledText(label: 'Repository', value: application.repoUrl),
          LabeledText(label: 'Path', value: application.path),
          LabeledText(
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
          LabeledText(label: 'Cluster', value: application.cluster),
          LabeledText(label: 'Namespace', value: application.namespace),
          if (application.lastSyncedAt != null)
            LabeledText(
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
          ),
          child: Row(
            children: <Widget>[
              const IconBadge(
                icon: Icons.account_tree,
                color: AppColors.cobalt,
                backgroundColor: AppColors.cobaltLight,
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
          padding: EdgeInsets.all(AppSpacing.xxxl),
          child: Text('No resources returned by the ArgoCD API.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final resource = resources[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
            border: Border.all(color: kindColor.withValues(alpha: AppOpacity.bold)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kindColor.withValues(alpha: AppOpacity.medium),
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
                            color: kindColor.withValues(alpha: AppOpacity.medium),
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
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: healthColor,
                            shape: BoxShape.circle,
                          ),
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
          padding: EdgeInsets.all(AppSpacing.xxxl),
          child: Text('No deployment history returned by the ArgoCD API.'),
        ),
      );
    }

    final currentEntry = history.last;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    final dotColor = isCurrent ? AppColors.teal : AppColors.grey;

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
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(
                            color: dotColor.withValues(alpha: AppOpacity.heavy),
                            width: 2,
                          )
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
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.md,
                border: Border.all(
                  color: isCurrent
                      ? AppColors.teal.withValues(alpha: AppOpacity.bold)
                      : theme.dividerColor,
                ),
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
                            color: AppColors.teal,
                          ),
                        ),
                      Text(
                        'Deploy #${entry.id}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                    const SizedBox(height: 12),
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
// Bottom action bar (used by _DetailBody)
// ---------------------------------------------------------------------------

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.actionInFlight,
    required this.onRefresh,
    required this.onSync,
    required this.onDelete,
  });

  final bool actionInFlight;
  final VoidCallback onRefresh;
  final VoidCallback onSync;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: actionInFlight ? null : onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.cobalt),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: actionInFlight ? null : onSync,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sync'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Delete',
            onPressed: actionInFlight ? null : onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: actionInFlight
                  ? theme.disabledColor
                  : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
