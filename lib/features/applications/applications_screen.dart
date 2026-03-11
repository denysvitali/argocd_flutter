import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/last_updated_text.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
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

  bool get _hasActiveControls =>
      _query.trim().isNotEmpty || _activeFilter != ApplicationFilterChip.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final normalizedQuery = _query.trim().toLowerCase();
    final allApplications = widget.controller.applications;
    final unhealthyCount = allApplications
        .where((application) => !application.isHealthy)
        .length;
    final outOfSyncCount = allApplications
        .where((application) => application.isOutOfSync)
        .length;
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
            ),
            SizedBox(height: AppSpacing.lg),
            _SearchBar(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
              onClear: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                });
              },
              showClear: _query.isNotEmpty,
            ),
            SizedBox(height: AppSpacing.lg),
            _FilterChips(
              activeFilter: _activeFilter,
              counts: filterCounts,
              onSelected: (filter) {
                setState(() {
                  _activeFilter = filter;
                });
              },
            ),
            SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final stackedControls = constraints.maxWidth < 700;
                final summaryText =
                    '${applications.length} of ${allApplications.length} applications';
                final clearButton = _hasActiveControls
                    ? TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _activeFilter = ApplicationFilterChip.all;
                          });
                        },
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        label: const Text('Clear'),
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
                        child: _SummaryLabel(text: summaryText),
                      ),
                      ?clearButton,
                      SizedBox(width: AppSpacing.md),
                      sortDropdown,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _SummaryLabel(text: summaryText),
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        ?clearButton,
                        sortDropdown,
                      ],
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: AppSpacing.lg),
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
                  padding: EdgeInsets.only(bottom: AppSpacing.lg),
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

class _SummaryLabel extends StatelessWidget {
  const _SummaryLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
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
          SizedBox(width: AppSpacing.md),
          _buildChip(context, ApplicationFilterChip.healthy, 'Healthy'),
          SizedBox(width: AppSpacing.md),
          _buildChip(context, ApplicationFilterChip.degraded, 'Degraded'),
          SizedBox(width: AppSpacing.md),
          _buildChip(context, ApplicationFilterChip.outOfSync, 'Out of Sync'),
          SizedBox(width: AppSpacing.md),
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
    final count = counts[chip] ?? 0;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.cobalt.withValues(alpha: 0.15)
                  : AppColors.grey.withValues(alpha: AppOpacity.soft),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.cobalt : AppColors.grey,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(chip),
      selectedColor: AppColors.cobalt.withValues(alpha: AppOpacity.medium),
      checkmarkColor: AppColors.cobalt,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.cobalt : AppColors.grey,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.cobalt : AppColors.border,
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final ApplicationSortField value;
  final ValueChanged<ApplicationSortField> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.outline(theme)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ApplicationSortField>(
          value: value,
          icon: const Icon(Icons.sort_rounded, size: 18),
          isDense: true,
          borderRadius: AppRadius.md,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
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
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outlineColor = _isFocused
        ? AppColors.cobalt
        : AppColors.outline(theme);
    final mutedColor = AppColors.mutedText(theme);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.inputFill(theme),
        borderRadius: AppRadius.md,
        border: Border.all(
          color: outlineColor,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.cobalt.withValues(alpha: AppOpacity.soft),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          hintText: 'Search name, project, namespace, repo, cluster, revision',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Icon(
              Icons.search_rounded,
              color: _isFocused ? AppColors.cobalt : mutedColor,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: widget.showClear
              ? IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: mutedColor,
                  onPressed: widget.onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
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
  });

  final AppController controller;
  final int totalApplications;
  final int unhealthyCount;
  final int outOfSyncCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = controller.session;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.headerDark,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Application control plane',
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            session == null
                ? 'Connect to ArgoCD to inspect application health.'
                : '${session.username} on ${session.serverUrl}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textOnDarkMuted,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              _HeaderMetric(
                value: '$totalApplications',
                label: 'apps',
                color: Colors.white,
              ),
              _HeaderMetric(
                value: '$outOfSyncCount',
                label: 'drifted',
                color: outOfSyncCount > 0
                    ? AppColors.amber
                    : AppColors.textOnDarkMuted,
              ),
              _HeaderMetric(
                value: '$unhealthyCount',
                label: 'unhealthy',
                color: unhealthyCount > 0
                    ? AppColors.coral
                    : AppColors.textOnDarkMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RichText(
      text: TextSpan(
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
        children: <InlineSpan>[
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(color: color.withValues(alpha: 0.92)),
          ),
        ],
      ),
    );
  }
}

IconData _healthIcon(String status) {
  return switch (status.toLowerCase()) {
    'healthy' => Icons.check_circle_rounded,
    'progressing' => Icons.sync_rounded,
    'degraded' => Icons.error_rounded,
    'missing' => Icons.help_outline_rounded,
    _ => Icons.circle_outlined,
  };
}

IconData _syncIcon(String status) {
  return switch (status.toLowerCase()) {
    'synced' => Icons.cloud_done_rounded,
    _ => Icons.cloud_off_rounded,
  };
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
      borderRadius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        splashColor: AppColors.cobalt.withValues(alpha: AppOpacity.subtle),
        highlightColor: AppColors.cobalt.withValues(alpha: 0.04),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: AppRadius.md,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.md,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: healthColor, width: 3)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          application.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (application.lastSyncedAt != null &&
                          application.lastSyncedAt!.isNotEmpty)
                        Text(
                          _formatRelativeTime(application.lastSyncedAt!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.greyLight,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    '${application.project} / ${application.namespace}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      StatusChip(
                        label: application.healthStatus,
                        color: healthColor,
                      ),
                      SizedBox(width: AppSpacing.md),
                      StatusChip(
                        label: application.syncStatus,
                        color: AppColors.syncColor(application.syncStatus),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Text(
                        application.operationPhase,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _shortRevision(application.targetRevision),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
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
      borderRadius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        splashColor: AppColors.cobalt.withValues(alpha: AppOpacity.subtle),
        highlightColor: AppColors.cobalt.withValues(alpha: 0.04),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: AppRadius.md,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.md,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: healthColor, width: 3)),
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
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    '${application.project} / ${application.namespace}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Icon(
                        _healthIcon(application.healthStatus),
                        size: 16,
                        color: healthColor,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      StatusChip(
                        label: application.healthStatus,
                        color: healthColor,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Icon(
                        _syncIcon(application.syncStatus),
                        size: 16,
                        color: AppColors.syncColor(application.syncStatus),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      StatusChip(
                        label: application.syncStatus,
                        color: AppColors.syncColor(application.syncStatus),
                      ),
                    ],
                  ),
                  if (application.lastSyncedAt != null &&
                      application.lastSyncedAt!.isNotEmpty) ...<Widget>[
                    SizedBox(height: AppSpacing.sm),
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
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.light),
        borderRadius: AppRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
          SizedBox(width: AppSpacing.sm),
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.greyLight.withValues(alpha: AppOpacity.soft),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: AppColors.greyLight),
          ),
          SizedBox(height: AppSpacing.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          SizedBox(
            width: 320,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.grey,
                height: 1.4,
              ),
            ),
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
              SizedBox(width: AppSpacing.lg),
              Expanded(child: _SkeletonCard(delay: 120, compact: true)),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _SkeletonCard(delay: 240, compact: true)),
              SizedBox(width: AppSpacing.lg),
              Expanded(child: _SkeletonCard(delay: 360, compact: true)),
            ],
          ),
        ],
      );
    }

    return Column(
      children: List<Widget>.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.lg),
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
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: AppRadius.md,
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
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _SkeletonLine(
                            width: 100,
                            height: 16,
                            alpha: _animation.value,
                          ),
                          SizedBox(height: AppSpacing.md),
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
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    _SkeletonLine(
                      width: 60,
                      height: 22,
                      alpha: _animation.value,
                      borderRadius: 8,
                    ),
                    SizedBox(width: AppSpacing.md),
                    _SkeletonLine(
                      width: 60,
                      height: 22,
                      alpha: _animation.value,
                      borderRadius: 8,
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
            borderRadius: AppRadius.md,
            border: Border.all(color: theme.dividerColor),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.md,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: skeletonColor, width: 3),
                ),
              ),
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _SkeletonLine(
                    width: 180,
                    height: 16,
                    alpha: _animation.value,
                  ),
                  SizedBox(height: AppSpacing.md),
                  _SkeletonLine(
                    width: 220,
                    height: 12,
                    alpha: _animation.value,
                  ),
                  SizedBox(height: AppSpacing.sm),
                  _SkeletonLine(
                    width: 280,
                    height: 12,
                    alpha: _animation.value,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      _SkeletonLine(
                        width: 64,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 8,
                      ),
                      SizedBox(width: AppSpacing.md),
                      _SkeletonLine(
                        width: 64,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 8,
                      ),
                      const Spacer(),
                      _SkeletonLine(
                        width: 50,
                        height: 12,
                        alpha: _animation.value,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      _SkeletonLine(
                        width: 72,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 8,
                      ),
                      SizedBox(width: AppSpacing.md),
                      _SkeletonLine(
                        width: 72,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 8,
                      ),
                      SizedBox(width: AppSpacing.md),
                      _SkeletonLine(
                        width: 72,
                        height: 22,
                        alpha: _animation.value,
                        borderRadius: 8,
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
