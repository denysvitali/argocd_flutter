import 'dart:async';

import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/last_updated_text.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

enum ApplicationSortField { name, health, lastSynced, project }

enum ApplicationFilterChip { all, healthy, degraded, outOfSync, progressing }

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({
    super.key,
    required this.controller,
    required this.onOpenApplication,
  });

  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isGridView = false;
  ApplicationSortField _sortField = ApplicationSortField.name;
  ApplicationFilterChip _activeFilter = ApplicationFilterChip.all;
  Timer? _debounce;

  bool get _hasActiveControls =>
      _query.trim().isNotEmpty || _activeFilter != ApplicationFilterChip.all;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = value;
        });
      }
    });
  }

  List<ArgoApplication> _applyFilter(List<ArgoApplication> applications) {
    return switch (_activeFilter) {
      ApplicationFilterChip.all => applications,
      ApplicationFilterChip.healthy =>
        applications.where((a) => a.isHealthy).toList(growable: false),
      ApplicationFilterChip.degraded =>
        applications
            .where((a) => a.healthStatus.toLowerCase() == 'degraded')
            .toList(growable: false),
      ApplicationFilterChip.outOfSync =>
        applications.where((a) => a.isOutOfSync).toList(growable: false),
      ApplicationFilterChip.progressing =>
        applications
            .where((a) => a.healthStatus.toLowerCase() == 'progressing')
            .toList(growable: false),
    };
  }

  List<ArgoApplication> _applySort(List<ArgoApplication> applications) {
    final sorted = List<ArgoApplication>.of(applications);
    sorted.sort((ArgoApplication a, ArgoApplication b) {
      return switch (_sortField) {
        ApplicationSortField.name => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
        ApplicationSortField.health =>
          _healthSortOrder(a.healthStatus) - _healthSortOrder(b.healthStatus),
        ApplicationSortField.lastSynced => (b.lastSyncedAt ?? '').compareTo(
          a.lastSyncedAt ?? '',
        ),
        ApplicationSortField.project => a.project.toLowerCase().compareTo(
          b.project.toLowerCase(),
        ),
      };
    });
    return sorted;
  }

  static int _healthSortOrder(String status) {
    return switch (status.toLowerCase()) {
      'degraded' => 0,
      'progressing' => 1,
      'missing' => 2,
      'healthy' => 3,
      _ => 4,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final allApplications = widget.controller.applications;
    final unhealthyCount = allApplications
        .where((application) => !application.isHealthy)
        .length;
    final outOfSyncCount = allApplications
        .where((application) => application.isOutOfSync)
        .length;
    final healthSegments = <StatusSegment>[
      StatusSegment(
        color: AppColors.healthy,
        count: allApplications.where((a) => a.isHealthy).length,
      ),
      StatusSegment(
        color: AppColors.progressing,
        count: allApplications
            .where((a) => a.healthStatus.toLowerCase() == 'progressing')
            .length,
      ),
      StatusSegment(
        color: AppColors.degraded,
        count: allApplications
            .where((a) => a.healthStatus.toLowerCase() == 'degraded')
            .length,
      ),
      StatusSegment(
        color: AppColors.missing,
        count: allApplications
            .where((a) => a.healthStatus.toLowerCase() == 'missing')
            .length,
      ),
      StatusSegment(
        color: AppColors.unknown,
        count: allApplications.length -
            allApplications
                .where(
                  (a) => const <String>{
                    'healthy',
                    'progressing',
                    'degraded',
                    'missing',
                  }.contains(a.healthStatus.toLowerCase()),
                )
                .length,
      ),
    ];
    final searchedApplications = allApplications
        .where((application) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return application.name.toLowerCase().contains(normalizedQuery) ||
              application.project.toLowerCase().contains(normalizedQuery) ||
              application.namespace.toLowerCase().contains(normalizedQuery) ||
              application.cluster.toLowerCase().contains(normalizedQuery) ||
              application.repoUrl.toLowerCase().contains(normalizedQuery) ||
              application.path.toLowerCase().contains(normalizedQuery) ||
              application.targetRevision.toLowerCase().contains(
                normalizedQuery,
              );
        })
        .toList(growable: false);
    final filteredApplications = _applyFilter(searchedApplications);
    final applications = _applySort(filteredApplications);
    final filterCounts = <ApplicationFilterChip, int>{
      ApplicationFilterChip.all: searchedApplications.length,
      ApplicationFilterChip.healthy: searchedApplications
          .where((application) => application.isHealthy)
          .length,
      ApplicationFilterChip.degraded: searchedApplications
          .where(
            (application) =>
                application.healthStatus.toLowerCase() == 'degraded',
          )
          .length,
      ApplicationFilterChip.outOfSync: searchedApplications
          .where((application) => application.isOutOfSync)
          .length,
      ApplicationFilterChip.progressing: searchedApplications
          .where(
            (application) =>
                application.healthStatus.toLowerCase() == 'progressing',
          )
          .length,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        actions: <Widget>[
          IconButton(
            tooltip: _isGridView ? 'List view' : 'Grid view',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: widget.controller.busy
                ? null
                : () => widget.controller.refreshApplications(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => widget.controller.refreshApplications(),
        child: ListView(
          padding: kPagePadding,
          children: <Widget>[
            LastUpdatedText(timestamp: widget.controller.lastRefreshedAt),
            _OverviewStrip(
              controller: widget.controller,
              totalApplications: allApplications.length,
              unhealthyCount: unhealthyCount,
              outOfSyncCount: outOfSyncCount,
              healthSegments: healthSegments,
            ),
            const SizedBox(height: 8),
            _SearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onClear: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                });
              },
              showClear: _query.isNotEmpty,
            ),
            const SizedBox(height: 8),
            _FilterChips(
              activeFilter: _activeFilter,
              counts: filterCounts,
              onSelected: (filter) {
                setState(() {
                  _activeFilter = filter;
                });
              },
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final stackedControls = constraints.maxWidth < 700;
                final summaryText =
                    '${applications.length} of ${allApplications.length} applications';
                final clearButton = _hasActiveControls
                    ? TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _activeFilter = ApplicationFilterChip.all;
                          });
                        },
                        child: const Text('Clear'),
                      )
                    : null;
                final sortDropdown = _SortDropdown(
                  value: _sortField,
                  onChanged: (field) {
                    setState(() {
                      _sortField = field;
                    });
                  },
                );

                if (!stackedControls) {
                  return Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          summaryText,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (clearButton != null) clearButton,
                      sortDropdown,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      summaryText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        if (clearButton != null) clearButton,
                        sortDropdown,
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            if (widget.controller.errorMessage != null)
              ErrorRetryWidget(
                message: widget.controller.errorMessage!,
                onRetry: () => widget.controller.refreshApplications(),
              ),
            if (widget.controller.loadingApplications &&
                !widget.controller.hasLoadedApplications)
              _LoadingSkeleton(isGrid: _isGridView)
            else if (applications.isEmpty)
              _EmptyState(
                filtered:
                    normalizedQuery.isNotEmpty ||
                    _activeFilter != ApplicationFilterChip.all,
                hasApps: widget.controller.applications.isNotEmpty,
              )
            else if (_isGridView)
              _ApplicationGrid(
                applications: applications,
                onOpenApplication: widget.onOpenApplication,
              )
            else
              ...applications.map(
                (application) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ApplicationCard(
                    application: application,
                    onTap: () => widget.onOpenApplication(application.name),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.activeFilter,
    required this.counts,
    required this.onSelected,
  });

  final ApplicationFilterChip activeFilter;
  final Map<ApplicationFilterChip, int> counts;
  final ValueChanged<ApplicationFilterChip> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _buildChip(context, ApplicationFilterChip.all, 'All'),
          const SizedBox(width: 6),
          _buildChip(context, ApplicationFilterChip.healthy, 'Healthy'),
          const SizedBox(width: 6),
          _buildChip(context, ApplicationFilterChip.degraded, 'Degraded'),
          const SizedBox(width: 6),
          _buildChip(context, ApplicationFilterChip.outOfSync, 'Out of Sync'),
          const SizedBox(width: 6),
          _buildChip(context, ApplicationFilterChip.progressing, 'Progressing'),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    ApplicationFilterChip chip,
    String label,
  ) {
    final isSelected = activeFilter == chip;
    final chipColor = _chipColor(chip);

    return FilterChip(
      label: Text('$label ${counts[chip] ?? 0}'),
      selected: isSelected,
      onSelected: (_) => onSelected(chip),
      selectedColor: chipColor.withValues(alpha: 0.15),
      checkmarkColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected ? chipColor : AppColors.grey,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: isSelected ? chipColor : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
      visualDensity: VisualDensity.compact,
    );
  }

  static Color _chipColor(ApplicationFilterChip chip) {
    return switch (chip) {
      ApplicationFilterChip.all => AppColors.teal,
      ApplicationFilterChip.healthy => AppColors.healthy,
      ApplicationFilterChip.degraded => AppColors.degraded,
      ApplicationFilterChip.outOfSync => AppColors.outOfSync,
      ApplicationFilterChip.progressing => AppColors.progressing,
    };
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final ApplicationSortField value;
  final ValueChanged<ApplicationSortField> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<ApplicationSortField>(
        value: value,
        icon: const Icon(Icons.sort_rounded, size: 20),
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.grey,
          fontWeight: FontWeight.w600,
        ),
        items: const <DropdownMenuItem<ApplicationSortField>>[
          DropdownMenuItem(
            value: ApplicationSortField.name,
            child: Text('Sort by name'),
          ),
          DropdownMenuItem(
            value: ApplicationSortField.health,
            child: Text('Sort by health'),
          ),
          DropdownMenuItem(
            value: ApplicationSortField.lastSynced,
            child: Text('Sort by last synced'),
          ),
          DropdownMenuItem(
            value: ApplicationSortField.project,
            child: Text('Sort by project'),
          ),
        ],
        onChanged: (ApplicationSortField? field) {
          if (field != null) {
            onChanged(field);
          }
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineColor = AppColors.outline(theme);
    final mutedColor = AppColors.mutedText(theme);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill(theme),
        borderRadius: AppRadius.base,
        border: Border.all(color: outlineColor),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search name, project, namespace, repo, cluster, revision',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.search_rounded, color: mutedColor),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: showClear
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: mutedColor,
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({
    required this.controller,
    required this.totalApplications,
    required this.unhealthyCount,
    required this.outOfSyncCount,
    required this.healthSegments,
  });

  final AppController controller;
  final int totalApplications;
  final int unhealthyCount;
  final int outOfSyncCount;
  final List<StatusSegment> healthSegments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = controller.session;
    final fg = AppColors.headerForeground(theme);
    final muted = AppColors.headerMutedForeground(theme);
    final chipBg = AppColors.headerChipBackground(theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.headerSurface(theme),
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Title row
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(
                  Icons.apps_rounded,
                  size: 16,
                  color: fg,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Applications',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (session != null)
                Flexible(
                  child: Text(
                    session.serverUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Metric chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetricChip(
                value: totalApplications,
                label: 'Total',
                background: chipBg,
                fg: fg,
                muted: muted,
              ),
              _MetricChip(
                value: outOfSyncCount,
                label: 'Drifted',
                background: outOfSyncCount > 0
                    ? AppColors.outOfSync.withValues(alpha: 0.22)
                    : chipBg,
                fg: outOfSyncCount > 0 ? AppColors.outOfSync : fg,
                muted: muted,
              ),
              _MetricChip(
                value: unhealthyCount,
                label: 'Unhealthy',
                background: unhealthyCount > 0
                    ? AppColors.degraded.withValues(alpha: 0.22)
                    : chipBg,
                fg: unhealthyCount > 0 ? AppColors.degraded : fg,
                muted: muted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Health segment bar
          StatusSegmentBar(segments: healthSegments),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.value,
    required this.label,
    required this.background,
    required this.fg,
    required this.muted,
  });

  final int value;
  final String label;
  final Color background;
  final Color fg;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$value $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$value',
              style: theme.textTheme.titleSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _factBadgeColor(IconData icon) {
  if (icon == Icons.route_outlined) {
    return AppColors.cobalt;
  } else if (icon == Icons.commit_outlined) {
    return AppColors.teal;
  }
  return AppColors.amber;
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});

  final ArgoApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthColor = AppColors.healthColor(application.healthStatus);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.base,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.base,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: AppRadius.base,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.base,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: healthColor, width: 5)),
              ),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              application.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              application.project,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          StatusChip(
                            icon: healthStatusIcon(application.healthStatus),
                            label: application.healthStatus,
                            color: healthColor,
                          ),
                          const SizedBox(height: 6),
                          StatusChip(
                            icon: syncStatusIcon(application.syncStatus),
                            label: application.syncStatus,
                            color: AppColors.syncColor(application.syncStatus),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Cluster + namespace metadata row
                  Row(
                    children: <Widget>[
                      ExcludeSemantics(
                        child: Icon(
                          Icons.dns_outlined,
                          size: 12,
                          color: AppColors.mutedText(theme),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _clusterShortName(application.cluster),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.mutedText(theme),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '\u2022',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.greyLight,
                          ),
                        ),
                      ),
                      ExcludeSemantics(
                        child: Icon(
                          Icons.view_in_ar_outlined,
                          size: 12,
                          color: AppColors.mutedText(theme),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          application.namespace,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.mutedText(theme),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      if (application.lastSyncedAt != null &&
                          application.lastSyncedAt!.isNotEmpty)
                        Text(
                          'Synced ${_formatRelativeTime(application.lastSyncedAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.greyLight,
                          ),
                        ),
                      Text(
                        application.operationPhase,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _shortRevision(application.targetRevision),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      _ColoredFactBadge(
                        icon: Icons.route_outlined,
                        label: _pathLabel(application.path),
                      ),
                      _ColoredFactBadge(
                        icon: Icons.link_rounded,
                        label: _repoLabel(application.repoUrl),
                      ),
                    ],
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

class _ApplicationGrid extends StatelessWidget {
  const _ApplicationGrid({
    required this.applications,
    required this.onOpenApplication,
  });

  final List<ArgoApplication> applications;
  final ValueChanged<String> onOpenApplication;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 980
            ? 3
            : width >= 620
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: applications.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 2.45 : 1.28,
          ),
          itemBuilder: (BuildContext context, int index) {
            final application = applications[index];
            return _ApplicationGridCard(
              application: application,
              onTap: () => onOpenApplication(application.name),
            );
          },
        );
      },
    );
  }
}

class _ApplicationGridCard extends StatelessWidget {
  const _ApplicationGridCard({required this.application, required this.onTap});

  final ArgoApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final healthColor = AppColors.healthColor(application.healthStatus);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.base,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.base,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: AppRadius.base,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.base,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: healthColor, width: 5)),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    application.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${application.project} / ${application.namespace}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  StatusChip(
                    icon: healthStatusIcon(application.healthStatus),
                    label: application.healthStatus,
                    color: healthColor,
                  ),
                  const SizedBox(height: 4),
                  StatusChip(
                    icon: syncStatusIcon(application.syncStatus),
                    label: application.syncStatus,
                    color: AppColors.syncColor(application.syncStatus),
                  ),
                  if (application.lastSyncedAt != null &&
                      application.lastSyncedAt!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      '${_shortRevision(application.targetRevision)} • ${_repoHost(application.repoUrl)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.greyLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRelativeTime(String isoTimestamp) {
  final dateTime = DateTime.tryParse(isoTimestamp);
  if (dateTime == null) {
    return isoTimestamp;
  }
  return formatTimeAgo(dateTime);
}

String _repoLabel(String repoUrl) {
  final uri = Uri.tryParse(repoUrl);
  if (uri != null && uri.host.isNotEmpty) {
    return '${uri.host}${uri.path}';
  }
  return repoUrl;
}

String _repoHost(String repoUrl) {
  final uri = Uri.tryParse(repoUrl);
  if (uri != null && uri.host.isNotEmpty) {
    return uri.host;
  }
  return repoUrl;
}

String _clusterShortName(String cluster) {
  // Show just the hostname portion if the cluster is a URL.
  final uri = Uri.tryParse(cluster);
  if (uri != null && uri.host.isNotEmpty) {
    return uri.host;
  }
  // Already a short name or an in-cluster reference.
  return cluster.isEmpty ? 'in-cluster' : cluster;
}

String _pathLabel(String path) {
  final segments = path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length <= 2) {
    return path;
  }
  return '${segments[segments.length - 2]}/${segments.last}';
}

String _shortRevision(String revision) {
  return revision.length <= 10 ? revision : revision.substring(0, 10);
}

class _ColoredFactBadge extends StatelessWidget {
  const _ColoredFactBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _factBadgeColor(icon);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.sm,
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.hasApps});

  final bool filtered;
  final bool hasApps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final IconData icon;
    final String title;
    final String subtitle;

    if (filtered) {
      icon = Icons.search_off_rounded;
      title = 'No applications match this filter';
      subtitle = 'Clear or change the filter to see more applications.';
    } else if (hasApps) {
      icon = Icons.visibility_off_rounded;
      title = 'No applications visible';
      subtitle =
          'Your RBAC scope or current project access may be limiting the '
          'visible applications.';
    } else {
      icon = Icons.cloud_queue_rounded;
      title = 'No applications loaded';
      subtitle =
          'Connect to ArgoCD, then pull to refresh once your RBAC scope has '
          'visible applications.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.base,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 36, color: AppColors.greyLight),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.isGrid});

  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _SkeletonCard(delay: 0, compact: true)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonCard(delay: 120, compact: true)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _SkeletonCard(delay: 240, compact: true)),
              const SizedBox(width: 12),
              Expanded(child: _SkeletonCard(delay: 360, compact: true)),
            ],
          ),
        ],
      );
    }

    return Column(
      children: List<Widget>.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SkeletonCard(delay: index * 120, compact: false),
        );
      }),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard({required this.delay, required this.compact});

  final int delay;
  final bool compact;

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: 0.04,
      end: 0.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skeletonColor = AppColors.skeleton(theme, alpha: _animation.value);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        if (widget.compact) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.base,
              border: Border.all(color: theme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _SkeletonLine(
                            width: 100,
                            height: 16,
                            alpha: _animation.value,
                          ),
                          const SizedBox(height: 6),
                          _SkeletonLine(
                            width: 70,
                            height: 12,
                            alpha: _animation.value,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    _SkeletonLine(
                      width: 60,
                      height: 22,
                      alpha: _animation.value,
                      borderRadius: 4,
                    ),
                    const SizedBox(width: 6),
                    _SkeletonLine(
                      width: 60,
                      height: 22,
                      alpha: _animation.value,
                      borderRadius: 4,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.base,
            border: Border.all(color: theme.dividerColor),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.base,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: skeletonColor, width: 3),
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SkeletonLine(
                    width: 180,
                    height: 16,
                    alpha: _animation.value,
                  ),
                  const SizedBox(height: 6),
                  _SkeletonLine(
                    width: 220,
                    height: 12,
                    alpha: _animation.value,
                  ),
                  const SizedBox(height: 4),
                  _SkeletonLine(
                    width: 280,
                    height: 12,
                    alpha: _animation.value,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _SkeletonLine(
                        width: 64,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 4,
                      ),
                      const SizedBox(width: 6),
                      _SkeletonLine(
                        width: 64,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 4,
                      ),
                      const Spacer(),
                      _SkeletonLine(
                        width: 50,
                        height: 12,
                        alpha: _animation.value,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      _SkeletonLine(
                        width: 72,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 4,
                      ),
                      const SizedBox(width: 8),
                      _SkeletonLine(
                        width: 72,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 4,
                      ),
                      const SizedBox(width: 8),
                      _SkeletonLine(
                        width: 72,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.height,
    required this.alpha,
    this.borderRadius = 4,
  });

  final double width;
  final double height;
  final double alpha;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeleton(theme, alpha: alpha),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
