import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

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

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  late Future<ArgoApplication> _future;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadApplication(widget.applicationName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.applicationName),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _actionInFlight ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sync',
            onPressed: _actionInFlight ? null : _sync,
            icon: const Icon(Icons.sync),
          ),
          PopupMenuButton<_ApplicationMenuAction>(
            tooltip: 'More actions',
            onSelected: (value) {
              if (value == _ApplicationMenuAction.delete) {
                _confirmDelete();
              }
            },
            itemBuilder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return <PopupMenuEntry<_ApplicationMenuAction>>[
                PopupMenuItem<_ApplicationMenuAction>(
                  value: _ApplicationMenuAction.delete,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.delete_outline, color: colorScheme.error),
                      const SizedBox(width: 12),
                      Text(
                        'Delete Application',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: FutureBuilder<ArgoApplication>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString()),
              ),
            );
          }

          final application = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _SummaryCard(application: application),
              const SizedBox(height: 20),
              _ResourceTreeCard(
                controller: widget.controller,
                applicationName: application.name,
              ),
              const SizedBox(height: 20),
              _ResourcesCard(
                controller: widget.controller,
                applicationName: application.name,
                resources: application.resources,
              ),
              const SizedBox(height: 20),
              _HistoryCard(
                controller: widget.controller,
                applicationName: application.name,
                history: application.history,
                onRolledBack: _refresh,
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
            'Sync \'${widget.applicationName}\' with its target revision?',
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

enum _ApplicationMenuAction { delete }

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
        borderRadius: BorderRadius.circular(24),
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.cobaltLight,
                  borderRadius: BorderRadius.circular(16),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.application});

  final ArgoApplication application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            application.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _DetailPill(label: 'Project', value: application.project),
              _DetailPill(label: 'Namespace', value: application.namespace),
              _DetailPill(label: 'Cluster', value: application.cluster),
              _DetailPill(label: 'Sync', value: application.syncStatus),
              _DetailPill(label: 'Health', value: application.healthStatus),
              _DetailPill(
                label: 'Operation',
                value: application.operationPhase,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LabeledText(label: 'Repository', value: application.repoUrl),
          _LabeledText(label: 'Path', value: application.path),
          _LabeledText(
            label: 'Target revision',
            value: application.targetRevision,
          ),
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

class _ResourcesCard extends StatelessWidget {
  const _ResourcesCard({
    required this.controller,
    required this.applicationName,
    required this.resources,
  });

  final AppController controller;
  final String applicationName;
  final List<ArgoResource> resources;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Resources',
      child: resources.isEmpty
          ? const Text('No resources returned by the ArgoCD API.')
          : Column(
              children: resources.map((resource) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${resource.kind} \u2022 ${resource.name}'),
                  subtitle: Text(
                    '${resource.namespace} \u2022 ${resource.status} \u2022 ${resource.health}',
                  ),
                  trailing: const ExcludeSemantics(
                    child: Icon(Icons.chevron_right),
                  ),
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
                );
              }).toList(growable: false),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
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
    final currentEntry = history.isEmpty ? null : history.last;

    return SectionCard(
      title: 'Deployment history',
      child: history.isEmpty
          ? const Text('No deployment history returned by the ArgoCD API.')
          : Column(
              children: history
                  .map(
                    (entry) => _HistoryEntryTile(
                      controller: controller,
                      applicationName: applicationName,
                      entry: entry,
                      isCurrent: identical(entry, currentEntry),
                      onRolledBack: onRolledBack,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  const _HistoryEntryTile({
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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(entry.revision),
      subtitle: Text('ID ${entry.id} \u2022 ${entry.deployedAt}'),
      trailing: isCurrent
          ? const StatusChip(label: 'Current', color: AppColors.teal)
          : TextButton.icon(
              onPressed: () => _confirmRollback(context),
              icon: const Icon(Icons.restore),
              label: const Text('Rollback'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.amber,
              ),
            ),
      onTap: isCurrent ? null : () => _confirmRollback(context),
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

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
