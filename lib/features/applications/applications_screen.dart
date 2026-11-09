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
  ApplicationSortField _sortField = ApplicationSortField.health;
  ApplicationFilterChip _activeFilter = ApplicationFilterChip.all;
  String? _projectFilter;
  String? _clusterFilter;
  Timer? _debounce;

  bool get _hasActiveControls =>
      _query.trim().isNotEmpty ||
      _activeFilter != ApplicationFilterChip.all ||
      _projectFilter != null ||
      _clusterFilter != null;

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
        ApplicationSortField.health => _compareByAttention(a, b),
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

  /// Problems first: worst health, then drifted before synced, then name.
  static int _compareByAttention(ArgoApplication a, ArgoApplication b) {
    final health =
        _healthSortOrder(a.healthStatus) - _healthSortOrder(b.healthStatus);
    if (health != 0) {
      return health;
    }
    if (a.isOutOfSync != b.isOutOfSync) {
      return a.isOutOfSync ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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

  void _clearAllControls() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _activeFilter = ApplicationFilterChip.all;
      _projectFilter = null;
      _clusterFilter = null;
    });
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedQuery = _query.trim().toLowerCase();
    final allApplications = widget.controller.applications;
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
    final scopedApplications = searchedApplications
        .where(
          (application) =>
              (_projectFilter == null ||
                  application.project == _projectFilter) &&
              (_clusterFilter == null ||
                  _clusterShortName(application.cluster) == _clusterFilter),
        )
        .toList(growable: false);
    final filteredApplications = _applyFilter(scopedApplications);
    final applications = _applySort(filteredApplications);
    final projectOptions =
        allApplications
            .map((application) => application.project)
            .where((project) => project.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final clusterOptions =
        allApplications
            .map((application) => _clusterShortName(application.cluster))
            .where((cluster) => cluster.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final filterCounts = <ApplicationFilterChip, int>{
      ApplicationFilterChip.all: scopedApplications.length,
      ApplicationFilterChip.healthy: scopedApplications
          .where((application) => application.isHealthy)
          .length,
      ApplicationFilterChip.degraded: scopedApplications
          .where(
            (application) =>
                application.healthStatus.toLowerCase() == 'degraded',
          )
          .length,
      ApplicationFilterChip.outOfSync: scopedApplications
          .where((application) => application.isOutOfSync)
          .length,
      ApplicationFilterChip.progressing: scopedApplications
          .where(
            (application) =>
                application.healthStatus.toLowerCase() == 'progressing',
          )
          .length,
    };

    final session = widget.controller.session;
    final lastRefreshedAt = widget.controller.lastRefreshedAt;

    const horizontal = EdgeInsets.symmetric(horizontal: 16);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => widget.controller.refreshApplications(),
        child: ListView(
          padding: EdgeInsets.only(
            top: kPagePadding.top,
            bottom: kPagePadding.bottom,
          ),
          children: <Widget>[
            Padding(
              padding: horizontal,
              child: AppPageHeader(
                title: 'Applications',
                subtitle: session == null
                    ? 'Deployments across clusters'
                    : _host(session.serverUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: _isGridView ? 'List view' : 'Grid view',
                      onPressed: () {
                        setState(() {
                          _isGridView = !_isGridView;
                        });
                      },
                      icon: Icon(
                        _isGridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
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
                bottom: _SearchField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClear: () {
                    _debounce?.cancel();
                    _searchController.clear();
                    setState(() {
                      _query = '';
                    });
                  },
                  showClear: _query.isNotEmpty,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _FilterBar(
              padding: horizontal,
              projectOptions: projectOptions,
              projectValue: _projectFilter,
              onProjectChanged: (value) {
                setState(() {
                  _projectFilter = value;
                });
              },
              clusterOptions: clusterOptions,
              clusterValue: _clusterFilter,
              onClusterChanged: (value) {
                setState(() {
                  _clusterFilter = value;
                });
              },
              activeFilter: _activeFilter,
              counts: filterCounts,
              onFilterSelected: (filter) {
                setState(() {
                  _activeFilter = filter;
                });
              },
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${applications.length} of ${allApplications.length} '
                      'applications',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: AppFonts.tabularFigures,
                      ),
                    ),
                  ),
                  if (_hasActiveControls)
                    _FootnoteButton(
                      label: 'Clear',
                      onPressed: _clearAllControls,
                    ),
                  _SortMenu(
                    value: _sortField,
                    onChanged: (field) {
                      setState(() {
                        _sortField = field;
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                      filtered: _hasActiveControls,
                      hasApps: allApplications.isNotEmpty,
                      onClearFilters: _clearAllControls,
                    )
                  else if (_isGridView)
                    _ApplicationGrid(
                      applications: applications,
                      onOpenApplication: widget.onOpenApplication,
                    )
                  else
                    for (final application in applications)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ApplicationCard(
                          application: application,
                          onTap: () =>
                              widget.onOpenApplication(application.name),
                        ),
                      ),
                ],
              ),
            ),
            if (lastRefreshedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Updated ${formatTimeAgo(lastRefreshedAt)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
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
// Search + filters
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
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
    final muted = theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: muted),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 40,
          ),
          suffixIcon: showClear
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: muted,
                  onPressed: onClear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.padding,
    required this.projectOptions,
    required this.projectValue,
    required this.onProjectChanged,
    required this.clusterOptions,
    required this.clusterValue,
    required this.onClusterChanged,
    required this.activeFilter,
    required this.counts,
    required this.onFilterSelected,
  });

  final EdgeInsetsGeometry padding;
  final List<String> projectOptions;
  final String? projectValue;
  final ValueChanged<String?> onProjectChanged;
  final List<String> clusterOptions;
  final String? clusterValue;
  final ValueChanged<String?> onClusterChanged;
  final ApplicationFilterChip activeFilter;
  final Map<ApplicationFilterChip, int> counts;
  final ValueChanged<ApplicationFilterChip> onFilterSelected;

  static const List<(ApplicationFilterChip, String)> _statusFilters =
      <(ApplicationFilterChip, String)>[
        (ApplicationFilterChip.all, 'All'),
        (ApplicationFilterChip.healthy, 'Healthy'),
        (ApplicationFilterChip.degraded, 'Degraded'),
        (ApplicationFilterChip.outOfSync, 'Out of Sync'),
        (ApplicationFilterChip.progressing, 'Progressing'),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: <Widget>[
          _ScopeMenu(
            label: 'Project',
            allLabel: 'All projects',
            value: projectValue,
            options: projectOptions,
            onChanged: onProjectChanged,
          ),
          const SizedBox(width: 8),
          _ScopeMenu(
            label: 'Cluster',
            allLabel: 'All clusters',
            value: clusterValue,
            options: clusterOptions,
            onChanged: onClusterChanged,
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: theme.colorScheme.outlineVariant,
          ),
          for (final (index, (chip, label)) in _statusFilters.indexed) ...[
            if (index > 0) const SizedBox(width: 8),
            FilterChip(
              label: Text('$label ${counts[chip] ?? 0}'),
              // The theme's state-dependent label style is lost when RawChip
              // merges it with its defaults, so resolve it explicitly here.
              labelStyle: _chipLabelStyle(theme, activeFilter == chip),
              selected: activeFilter == chip,
              onSelected: (_) => onFilterSelected(chip),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
    );
  }
}

TextStyle _chipLabelStyle(ThemeData theme, bool selected) {
  final scheme = theme.colorScheme;
  return TextStyle(
    fontFamily: AppFonts.text,
    fontSize: 13,
    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    letterSpacing: -0.1,
    color: selected ? scheme.surfaceContainerLowest : scheme.onSurface,
    fontFeatures: AppFonts.tabularFigures,
  );
}

/// Compact neutral capsule that opens a menu of scope options. Turns into the
/// inverted "selected" capsule while a value is active, like the chips.
class _ScopeMenu extends StatelessWidget {
  const _ScopeMenu({
    required this.label,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  static const String _allSentinel = '\u0000all';

  final String label;
  final String allLabel;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final active = value != null;
    final background = active ? scheme.onSurface : AppColors.fill(theme);
    final foreground = active
        ? scheme.surfaceContainerLowest
        : scheme.onSurface;

    return PopupMenuButton<String>(
      tooltip: 'Filter by ${label.toLowerCase()}',
      position: PopupMenuPosition.under,
      onSelected: (selected) =>
          onChanged(selected == _allSentinel ? null : selected),
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        CheckedPopupMenuItem<String>(
          value: _allSentinel,
          checked: value == null,
          child: Text(allLabel),
        ),
        if (options.isNotEmpty) const PopupMenuDivider(),
        for (final option in options)
          CheckedPopupMenuItem<String>(
            value: option,
            checked: option == value,
            child: Text(option, overflow: TextOverflow.ellipsis),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: ShapeDecoration(
          color: background,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                value ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _chipLabelStyle(theme, active),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: active ? foreground : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tinted text button used in the footnote row ("Clear").
class _FootnoteButton extends StatelessWidget {
  const _FootnoteButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text(label),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final ApplicationSortField value;
  final ValueChanged<ApplicationSortField> onChanged;

  static String _label(ApplicationSortField field) {
    return switch (field) {
      ApplicationSortField.health => 'Needs attention first',
      ApplicationSortField.name => 'Name',
      ApplicationSortField.lastSynced => 'Last synced',
      ApplicationSortField.project => 'Project',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.colorScheme.primary;

    return PopupMenuButton<ApplicationSortField>(
      tooltip: 'Sort',
      position: PopupMenuPosition.under,
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => <PopupMenuEntry<ApplicationSortField>>[
        for (final field in ApplicationSortField.values)
          CheckedPopupMenuItem<ApplicationSortField>(
            value: field,
            checked: field == value,
            child: Text(_label(field)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.sort_rounded, size: 16, color: tint),
            const SizedBox(width: 4),
            Text(
              _label(value),
              style: theme.textTheme.bodySmall?.copyWith(
                color: tint,
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
// Application rows
// ---------------------------------------------------------------------------

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});

  final ArgoApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final healthColor = AppColors.healthColor(application.healthStatus);
    final syncedAt = application.lastSyncedAt;
    final hasSyncTime = syncedAt != null && syncedAt.isNotEmpty;
    final subtitle = <String>[
      if (application.project.isNotEmpty) application.project,
      if (application.namespace.isNotEmpty) application.namespace,
    ].join(' · ');

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Semantics(
                  label: 'Health: ${application.healthStatus}',
                  child: StatusDot(color: healthColor, size: 9),
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
                            application.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasSyncTime) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            _formatRelativeTime(syncedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        StatusChip(
                          icon: healthStatusIcon(application.healthStatus),
                          label: application.healthStatus,
                          color: healthColor,
                        ),
                        StatusChip(
                          icon: syncStatusIcon(application.syncStatus),
                          label: application.syncStatus,
                          color: AppColors.syncColor(application.syncStatus),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: <Widget>[
                        FactBadge(
                          icon: Icons.dns_rounded,
                          label: _clusterShortName(application.cluster),
                        ),
                        if (application.path.isNotEmpty)
                          FactBadge(
                            icon: Icons.folder_rounded,
                            label: _pathLabel(application.path),
                          ),
                      ],
                    ),
                    if (application.hasOperationError) ...<Widget>[
                      const SizedBox(height: 10),
                      _ErrorFootnote(message: application.operationMessage!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: DisclosureChevron(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorFootnote extends StatelessWidget {
  const _ErrorFootnote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: ExcludeSemantics(
            child: Icon(
              Icons.error_rounded,
              size: 14,
              color: AppColors.statusForeground(theme, AppColors.degraded),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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
        final crossAxisCount = width >= 900
            ? 4
            : width >= 640
            ? 3
            : width >= 300
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 10),
          physics: const NeverScrollableScrollPhysics(),
          itemCount: applications.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 150,
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
    final scheme = theme.colorScheme;
    final syncedAt = application.lastSyncedAt;
    final hasSyncTime = syncedAt != null && syncedAt.isNotEmpty;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      application.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (application.hasOperationError) ...<Widget>[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: application.operationMessage!,
                      child: Icon(
                        Icons.error_rounded,
                        size: 16,
                        color: AppColors.statusForeground(
                          theme,
                          AppColors.degraded,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(
                application.project,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              _DotLabel(
                color: AppColors.healthColor(application.healthStatus),
                label: application.healthStatus,
              ),
              const SizedBox(height: 4),
              _DotLabel(
                color: AppColors.syncColor(application.syncStatus),
                label: application.syncStatus,
              ),
              const SizedBox(height: 10),
              Text(
                hasSyncTime
                    ? _formatRelativeTime(syncedAt)
                    : _clusterShortName(application.cluster),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.tertiaryLabel(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status dot followed by a label — the quiet alternative to a capsule.
class _DotLabel extends StatelessWidget {
  const _DotLabel({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        StatusDot(color: color, size: 8),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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

String _host(String url) {
  final uri = Uri.tryParse(url);
  if (uri != null && uri.host.isNotEmpty) {
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }
  return url;
}

String _clusterShortName(String cluster) {
  // Show just the hostname portion if the cluster is a URL.
  final uri = Uri.tryParse(cluster);
  if (uri != null && uri.host.isNotEmpty) {
    return uri.host == 'kubernetes.default.svc' ? 'in-cluster' : uri.host;
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

// ---------------------------------------------------------------------------
// Empty + loading states
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filtered,
    required this.hasApps,
    required this.onClearFilters,
  });

  final bool filtered;
  final bool hasApps;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (filtered) {
      return EmptyStateCard(
        icon: Icons.search_off_rounded,
        title: 'No applications match this filter',
        subtitle: 'Clear or change the filter to see more applications.',
        action: TextButton(
          onPressed: onClearFilters,
          child: const Text('Clear filters'),
        ),
      );
    }
    if (hasApps) {
      return const EmptyStateCard(
        icon: Icons.visibility_off_rounded,
        title: 'No applications visible',
        subtitle:
            'Your RBAC scope or current project access may be limiting the '
            'visible applications.',
      );
    }
    return const EmptyStateCard(
      icon: Icons.cloud_queue_rounded,
      title: 'No applications loaded',
      subtitle:
          'Connect to ArgoCD, then pull to refresh once your RBAC scope has '
          'visible applications.',
    );
  }
}

class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton({required this.isGrid});

  final bool isGrid;

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.55,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.isGrid ? _buildGrid() : _buildList(),
    );
  }

  Widget _buildList() {
    return Column(
      children: <Widget>[
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _SkeletonCard(compact: false),
          ),
      ],
    );
  }

  Widget _buildGrid() {
    return const Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _SkeletonCard(compact: true)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonCard(compact: true)),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(child: _SkeletonCard(compact: true)),
            SizedBox(width: 10),
            Expanded(child: _SkeletonCard(compact: true)),
          ],
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (compact) {
      return Container(
        height: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.md,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SkeletonLine(width: 110, height: 14),
            SizedBox(height: 8),
            _SkeletonLine(width: 70, height: 10),
            Spacer(),
            _SkeletonLine(width: 80, height: 10),
            SizedBox(height: 8),
            _SkeletonLine(width: 64, height: 10),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.md,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SkeletonLine(width: 9, height: 9, radius: 5),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonLine(width: 160, height: 14),
                SizedBox(height: 8),
                _SkeletonLine(width: 110, height: 10),
                SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    _SkeletonLine(width: 72, height: 20, radius: 10),
                    SizedBox(width: 6),
                    _SkeletonLine(width: 72, height: 20, radius: 10),
                  ],
                ),
                SizedBox(height: 12),
                _SkeletonLine(width: 220, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.height,
    this.radius = 4,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.fill(Theme.of(context)),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
