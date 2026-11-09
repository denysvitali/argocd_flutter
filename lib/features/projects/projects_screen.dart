import 'dart:async';

import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/last_updated_text.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

enum _SortOption { name, destinations, sourceRepos }

enum _ProjectFilter { all, multiDestination, wildcardRepo, clusterScoped }

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.controller,
    required this.onOpenProject,
  });

  final AppController controller;
  final ValueChanged<String> onOpenProject;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _SortOption _sortOption = _SortOption.name;
  _ProjectFilter _activeFilter = _ProjectFilter.all;
  Timer? _debounce;

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

  List<ArgoProject> _sortProjects(List<ArgoProject> projects) {
    final sorted = List<ArgoProject>.of(projects);
    switch (_sortOption) {
      case _SortOption.name:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _SortOption.destinations:
        sorted.sort(
          (a, b) => b.destinations.length.compareTo(a.destinations.length),
        );
      case _SortOption.sourceRepos:
        sorted.sort(
          (a, b) => b.sourceRepos.length.compareTo(a.sourceRepos.length),
        );
    }
    return sorted;
  }

  List<ArgoProject> _applyFilter(List<ArgoProject> projects) {
    return switch (_activeFilter) {
      _ProjectFilter.all => projects,
      _ProjectFilter.multiDestination =>
        projects.where((project) => project.destinations.length > 1).toList(),
      _ProjectFilter.wildcardRepo =>
        projects
            .where(
              (project) =>
                  project.sourceRepos.any((repo) => repo.contains('*')),
            )
            .toList(),
      _ProjectFilter.clusterScoped =>
        projects
            .where((project) => project.clusterResourceWhitelist.isNotEmpty)
            .toList(),
    };
  }

  void _clearAll() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() {
      _query = '';
      _activeFilter = _ProjectFilter.all;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final normalizedQuery = _query.trim().toLowerCase();
    final allProjects = widget.controller.projects;
    final filtered = allProjects
        .where((project) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return project.name.toLowerCase().contains(normalizedQuery) ||
              project.description.toLowerCase().contains(normalizedQuery) ||
              project.sourceRepos.any(
                (repo) => repo.toLowerCase().contains(normalizedQuery),
              ) ||
              project.destinations.any(
                (destination) =>
                    destination.server.toLowerCase().contains(
                      normalizedQuery,
                    ) ||
                    destination.namespace.toLowerCase().contains(
                      normalizedQuery,
                    ) ||
                    destination.name.toLowerCase().contains(normalizedQuery),
              );
        })
        .toList(growable: false);
    final filteredProjects = _applyFilter(filtered);
    final projects = _sortProjects(filteredProjects);
    final filterCounts = <_ProjectFilter, int>{
      _ProjectFilter.all: filtered.length,
      _ProjectFilter.multiDestination: filtered
          .where((project) => project.destinations.length > 1)
          .length,
      _ProjectFilter.wildcardRepo: filtered
          .where(
            (project) => project.sourceRepos.any((repo) => repo.contains('*')),
          )
          .length,
      _ProjectFilter.clusterScoped: filtered
          .where((project) => project.clusterResourceWhitelist.isNotEmpty)
          .length,
    };
    final isFiltering =
        normalizedQuery.isNotEmpty || _activeFilter != _ProjectFilter.all;
    final appsByProject = <String, List<ArgoApplication>>{};
    for (final application in widget.controller.applications) {
      appsByProject
          .putIfAbsent(application.project, () => <ArgoApplication>[])
          .add(application);
    }
    final lastRefreshedAt = widget.controller.lastRefreshedAt;
    final footnoteStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => widget.controller.refreshProjects(),
        child: ListView(
          padding: kPagePadding,
          children: <Widget>[
            AppPageHeader(
              title: 'Projects',
              subtitle: widget.controller.session == null
                  ? 'Access scopes and destinations'
                  : widget.controller.session!.serverUrl,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ProjectSortMenu(
                    value: _sortOption,
                    onChanged: (_SortOption option) {
                      setState(() {
                        _sortOption = option;
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    color: scheme.primary,
                    onPressed: widget.controller.busy
                        ? null
                        : () => widget.controller.refreshProjects(),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              bottom: _SearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onClear: () {
                  _searchController.clear();
                  _debounce?.cancel();
                  setState(() {
                    _query = '';
                  });
                },
                showClear: _query.isNotEmpty,
              ),
            ),
            const SizedBox(height: 12),
            _ProjectFilterChips(
              activeFilter: _activeFilter,
              counts: filterCounts,
              onSelected: (filter) {
                setState(() {
                  _activeFilter = filter;
                });
              },
            ),
            const SizedBox(height: 20),
            _OverviewStrip(
              totalProjects: allProjects.length,
              totalDestinations: allProjects.fold<int>(
                0,
                (count, project) => count + project.destinations.length,
              ),
              totalRepositories: allProjects.fold<int>(
                0,
                (count, project) => count + project.sourceRepos.length,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Row(
                  children: <Widget>[
                    Text(
                      '${projects.length} of ${allProjects.length} projects',
                      style: footnoteStyle,
                    ),
                    if (lastRefreshedAt != null)
                      Flexible(
                        child: Text(
                          '  ·  Updated ${formatTimeAgo(lastRefreshedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: footnoteStyle,
                        ),
                      ),
                    const Spacer(),
                    if (isFiltering)
                      TextButton(
                        onPressed: _clearAll,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.controller.errorMessage != null)
              ErrorRetryWidget(
                message: widget.controller.errorMessage!,
                onRetry: () => widget.controller.refreshProjects(),
              ),
            if (widget.controller.loadingProjects &&
                !widget.controller.hasLoadedProjects)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (projects.isEmpty)
              _EmptyState(
                filtered: isFiltering,
                hasProjects: widget.controller.projects.isNotEmpty,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  Widget cardFor(ArgoProject project) => _ProjectCard(
                    project: project,
                    applications:
                        appsByProject[project.name] ??
                        const <ArgoApplication>[],
                    onTap: () => widget.onOpenProject(project.name),
                    searchQuery: normalizedQuery,
                  );

                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: <Widget>[
                        for (var i = 0; i < projects.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(height: 10),
                          cardFor(projects[i]),
                        ],
                      ],
                    );
                  }

                  // Two-column layout on wide screens; each row sizes to its
                  // tallest card so neighbours stay aligned.
                  return Column(
                    children: <Widget>[
                      for (var i = 0; i < projects.length; i += 2) ...<Widget>[
                        if (i > 0) const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Expanded(child: cardFor(projects[i])),
                              const SizedBox(width: 12),
                              Expanded(
                                child: i + 1 < projects.length
                                    ? cardFor(projects[i + 1])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

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
    final scheme = theme.colorScheme;

    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search projects, repos, clusters',
          filled: true,
          fillColor: AppColors.fill(theme),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: AppRadius.base,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.base,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.base,
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          suffixIcon: showClear
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 18),
                  onPressed: onClear,
                  tooltip: 'Clear filter',
                  color: AppColors.tertiaryLabel(theme),
                )
              : null,
        ),
      ),
    );
  }
}

class _ProjectFilterChips extends StatelessWidget {
  const _ProjectFilterChips({
    required this.activeFilter,
    required this.counts,
    required this.onSelected,
  });

  final _ProjectFilter activeFilter;
  final Map<_ProjectFilter, int> counts;
  final ValueChanged<_ProjectFilter> onSelected;

  static const List<(String, _ProjectFilter)> _filters =
      <(String, _ProjectFilter)>[
        ('All', _ProjectFilter.all),
        ('Multi-dest', _ProjectFilter.multiDestination),
        ('Wildcard repo', _ProjectFilter.wildcardRepo),
        ('Cluster rules', _ProjectFilter.clusterScoped),
      ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < _filters.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            ChoiceChip(
              label: Text('${_filters[i].$1} ${counts[_filters[i].$2] ?? 0}'),
              selected: activeFilter == _filters[i].$2,
              onSelected: (_) => onSelected(_filters[i].$2),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectSortMenu extends StatelessWidget {
  const _ProjectSortMenu({required this.value, required this.onChanged});

  final _SortOption value;
  final ValueChanged<_SortOption> onChanged;

  static const List<(String, _SortOption)> _options = <(String, _SortOption)>[
    ('Name', _SortOption.name),
    ('Destinations', _SortOption.destinations),
    ('Repos', _SortOption.sourceRepos),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_SortOption>(
      tooltip: 'Sort',
      initialValue: value,
      onSelected: onChanged,
      icon: Icon(Icons.sort_rounded, color: scheme.primary),
      itemBuilder: (context) => <PopupMenuEntry<_SortOption>>[
        for (final option in _options)
          CheckedPopupMenuItem<_SortOption>(
            value: option.$2,
            checked: option.$2 == value,
            child: Text(option.$1),
          ),
      ],
    );
  }
}

/// Fleet-wide totals: three evenly spaced figures separated by hairlines.
class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({
    required this.totalProjects,
    required this.totalDestinations,
    required this.totalRepositories,
  });

  final int totalProjects;
  final int totalDestinations;
  final int totalRepositories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget divider() =>
        Container(width: 0.5, height: 32, color: scheme.outlineVariant);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Metric(value: totalProjects, label: 'projects'),
          ),
          divider(),
          Expanded(
            child: _Metric(value: totalDestinations, label: 'destinations'),
          ),
          divider(),
          Expanded(
            child: _Metric(value: totalRepositories, label: 'repos'),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: AppFonts.tabularFigures,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.applications,
    required this.onTap,
    this.searchQuery = '',
  });

  final ArgoProject project;
  final List<ArgoApplication> applications;
  final VoidCallback onTap;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final footnote = theme.textTheme.bodySmall?.copyWith(color: muted);

    final counts = <String>[
      if (applications.isNotEmpty) _plural(applications.length, 'app', 'apps'),
      _plural(project.sourceRepos.length, 'repo', 'repos'),
      _plural(project.destinations.length, 'destination', 'destinations'),
      if (project.clusterResourceWhitelist.isNotEmpty)
        _plural(project.clusterResourceWhitelist.length, 'rule', 'rules'),
    ];

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _HighlightedText(
                      text: project.name,
                      query: searchQuery,
                      maxLines: 1,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (project.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      _HighlightedText(
                        text: project.description,
                        query: searchQuery,
                        maxLines: 2,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    FactBadge(
                      icon: Icons.code_rounded,
                      label: _projectRepoPreview(project),
                    ),
                    const SizedBox(height: 4),
                    FactBadge(
                      icon: Icons.dns_rounded,
                      label: _projectDestinationPreview(project),
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 0.5, color: scheme.outlineVariant),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            counts.join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: footnote,
                          ),
                        ),
                        if (applications.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          _HealthRollup(applications: applications),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const DisclosureChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact per-project health summary: a dot and count for each health
/// state present among the project's applications.
class _HealthRollup extends StatelessWidget {
  const _HealthRollup({required this.applications});

  final List<ArgoApplication> applications;

  static const List<String> _order = <String>[
    'Healthy',
    'Progressing',
    'Degraded',
    'Suspended',
    'Missing',
    'Unknown',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final application in applications) {
      final status = _order.firstWhere(
        (s) => s.toLowerCase() == application.healthStatus.toLowerCase(),
        orElse: () => 'Unknown',
      );
      counts[status] = (counts[status] ?? 0) + 1;
    }
    final present = _order.where(counts.containsKey).toList(growable: false);

    return Semantics(
      label: present.map((s) => '${counts[s]} $s').join(', '),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var i = 0; i < present.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 10),
              StatusDot(color: AppColors.healthColor(present[i]), size: 7),
              const SizedBox(width: 4),
              Text(
                '${counts[present[i]]}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppFonts.tabularFigures,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final theme = Theme.of(context);
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: AppColors.statusTint(theme, AppColors.missing),
            color: theme.colorScheme.onSurface,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.merge(style),
        children: spans,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.hasProjects});

  final bool filtered;
  final bool hasProjects;

  @override
  Widget build(BuildContext context) {
    final icon = filtered
        ? Icons.search_off_rounded
        : hasProjects
        ? Icons.visibility_off_outlined
        : Icons.folder_off_outlined;
    final title = filtered
        ? 'No projects match this filter'
        : hasProjects
        ? 'No projects visible'
        : 'No projects loaded';
    final subtitle = filtered
        ? 'Clear or change the filter to see more projects.'
        : hasProjects
        ? 'Your RBAC scope may not expose any additional ArgoCD projects.'
        : 'Connect to ArgoCD, then pull to refresh once your RBAC scope has visible projects.';

    return EmptyStateCard(icon: icon, title: title, subtitle: subtitle);
  }
}

String _plural(int count, String singular, String plural) =>
    '$count ${count == 1 ? singular : plural}';

String _projectRepoPreview(ArgoProject project) {
  if (project.sourceRepos.isEmpty) {
    return 'No repositories';
  }
  final repo = project.sourceRepos.first;
  final first = repo == '*' ? 'All repositories' : _withoutScheme(repo);
  final remaining = project.sourceRepos.length - 1;
  return remaining > 0 ? '$first  +$remaining more' : first;
}

String _projectDestinationPreview(ArgoProject project) {
  if (project.destinations.isEmpty) {
    return 'No destinations';
  }
  final first = project.destinations.first;
  final cluster = first.name.isNotEmpty
      ? first.name
      : first.server == '*'
      ? 'Any cluster'
      : _withoutScheme(first.server);
  final namespace = first.namespace == '*' ? 'all namespaces' : first.namespace;
  final scope = '$cluster / $namespace';
  final remaining = project.destinations.length - 1;
  return remaining > 0 ? '$scope  +$remaining more' : scope;
}

String _withoutScheme(String url) =>
    url.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://'), '');
