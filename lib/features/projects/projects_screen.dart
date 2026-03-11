import 'dart:async';

import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
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
      _ProjectFilter.wildcardRepo => projects
          .where((project) => project.sourceRepos.any((repo) => repo.contains('*')))
          .toList(),
      _ProjectFilter.clusterScoped => projects
          .where((project) => project.clusterResourceWhitelist.isNotEmpty)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
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
                    destination.server.toLowerCase().contains(normalizedQuery) ||
                    destination.namespace.toLowerCase().contains(normalizedQuery) ||
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
          .where((project) => project.sourceRepos.any((repo) => repo.contains('*')))
          .length,
      _ProjectFilter.clusterScoped: filtered
          .where((project) => project.clusterResourceWhitelist.isNotEmpty)
          .length,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: widget.controller.busy
                ? null
                : () => widget.controller.refreshProjects(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => widget.controller.refreshProjects(),
        child: ListView(
          padding: kPagePadding,
          children: <Widget>[
            LastUpdatedText(timestamp: widget.controller.lastRefreshedAt),
            _OverviewStrip(
              controller: widget.controller,
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
            const SizedBox(height: 14),
            _SearchBar(
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
            const SizedBox(height: 10),
            _ProjectFilterChips(
              activeFilter: _activeFilter,
              counts: filterCounts,
              onSelected: (filter) {
                setState(() {
                  _activeFilter = filter;
                });
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${projects.length} of ${allProjects.length} projects',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (normalizedQuery.isNotEmpty || _activeFilter != _ProjectFilter.all)
                  TextButton(
                    onPressed: () {
                      _searchController.clear();
                      _debounce?.cancel();
                      setState(() {
                        _query = '';
                        _activeFilter = _ProjectFilter.all;
                      });
                    },
                    child: const Text('Clear'),
                  ),
                _ProjectSortDropdown(
                  value: _sortOption,
                  onChanged: (_SortOption option) {
                    setState(() {
                      _sortOption = option;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.controller.errorMessage != null)
              ErrorRetryWidget(
                message: widget.controller.errorMessage!,
                onRetry: () => widget.controller.refreshProjects(),
              ),
            if (widget.controller.loadingProjects &&
                !widget.controller.hasLoadedProjects)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (projects.isEmpty)
              _EmptyState(
                filtered:
                    normalizedQuery.isNotEmpty ||
                    _activeFilter != _ProjectFilter.all,
                hasProjects: widget.controller.projects.isNotEmpty,
              )
            else
              ...projects.map(
                (project) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ProjectCard(
                    project: project,
                    onTap: () => widget.onOpenProject(project.name),
                    searchQuery: normalizedQuery,
                  ),
                ),
              ),
          ],
        ),
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
    return Material(
      elevation: 1,
      shadowColor: AppColors.cobalt.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search project, description, repo, namespace, cluster',
          prefixIcon: const Icon(Icons.search, color: AppColors.grey),
          suffixIcon: showClear
              ? IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClear,
                  tooltip: 'Clear filter',
                  color: AppColors.grey,
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.cobalt, width: 1.5),
          ),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _buildChip('All', _ProjectFilter.all),
          const SizedBox(width: 8),
          _buildChip('Multi-dest', _ProjectFilter.multiDestination),
          const SizedBox(width: 8),
          _buildChip('Wildcard repo', _ProjectFilter.wildcardRepo),
          const SizedBox(width: 8),
          _buildChip('Cluster rules', _ProjectFilter.clusterScoped),
        ],
      ),
    );
  }

  Widget _buildChip(String label, _ProjectFilter filter) {
    final selected = activeFilter == filter;
    return FilterChip(
      label: Text('$label ${counts[filter] ?? 0}'),
      selected: selected,
      onSelected: (_) => onSelected(filter),
      visualDensity: VisualDensity.compact,
      selectedColor: AppColors.teal.withValues(alpha: 0.16),
      checkmarkColor: AppColors.teal,
      labelStyle: TextStyle(
        color: selected ? AppColors.teal : AppColors.grey,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: selected ? AppColors.teal : AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _ProjectSortDropdown extends StatelessWidget {
  const _ProjectSortDropdown({
    required this.value,
    required this.onChanged,
  });

  final _SortOption value;
  final ValueChanged<_SortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<_SortOption>(
        value: value,
        isDense: true,
        icon: const Icon(Icons.sort_rounded, size: 18),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.grey,
          fontWeight: FontWeight.w600,
        ),
        items: const <DropdownMenuItem<_SortOption>>[
          DropdownMenuItem(
            value: _SortOption.name,
            child: Text('Name'),
          ),
          DropdownMenuItem(
            value: _SortOption.destinations,
            child: Text('Destinations'),
          ),
          DropdownMenuItem(
            value: _SortOption.sourceRepos,
            child: Text('Repos'),
          ),
        ],
        onChanged: (_SortOption? option) {
          if (option != null) {
            onChanged(option);
          }
        },
      ),
    );
  }
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({
    required this.controller,
    required this.totalProjects,
    required this.totalDestinations,
    required this.totalRepositories,
  });

  final AppController controller;
  final int totalProjects;
  final int totalDestinations;
  final int totalRepositories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = controller.session;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.gradientProjectStart,
            AppColors.gradientProjectMid,
            AppColors.teal,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Project boundaries',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            session == null
                ? 'Projects define repository and deployment boundaries.'
                : 'Review RBAC scope, source repositories, and target clusters for ${session.username}.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textOnDarkGreen,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _MetricChip(
                label: 'Projects',
                value: '$totalProjects',
                icon: Icons.folder_special_outlined,
              ),
              _MetricChip(
                label: 'Destinations',
                value: '$totalDestinations',
                icon: Icons.dns_outlined,
              ),
              _MetricChip(
                label: 'Source repos',
                value: '$totalRepositories',
                icon: Icons.code_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    this.searchQuery = '',
  });

  final ArgoProject project;
  final VoidCallback onTap;
  final String searchQuery;

  Color _accentColor() {
    if (project.destinations.length >= 5) {
      return AppColors.coral;
    } else if (project.destinations.length >= 2) {
      return AppColors.teal;
    }
    return AppColors.cobalt;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: accent.withValues(alpha: 0.12),
      highlightColor: accent.withValues(alpha: 0.06),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HighlightedText(
                      text: project.name,
                      query: searchQuery,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.greyLight,
                    size: 20,
                  ),
                ],
              ),
              if (project.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _HighlightedText(
                  text: project.description,
                  query: searchQuery,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Repos: ${_projectRepoPreview(project)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Scope: ${_projectDestinationPreview(project)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _CountBadge(
                    icon: Icons.code_outlined,
                    count: project.sourceRepos.length,
                    label: 'repos',
                    color: AppColors.cobalt,
                  ),
                  _CountBadge(
                    icon: Icons.dns_outlined,
                    count: project.destinations.length,
                    label: 'destinations',
                    color: AppColors.teal,
                  ),
                  if (project.clusterResourceWhitelist.isNotEmpty)
                    _CountBadge(
                      icon: Icons.shield_outlined,
                      count: project.clusterResourceWhitelist.length,
                      label: 'rules',
                      color: AppColors.coral,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
  });

  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

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
            backgroundColor: AppColors.amber.withValues(alpha: 0.3),
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(text: TextSpan(style: style, children: spans));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.hasProjects});

  final bool filtered;
  final bool hasProjects;

  @override
  Widget build(BuildContext context) {
    final icon = filtered
        ? Icons.search_off
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

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 44, color: AppColors.greyLight),
          const SizedBox(height: 12),
          EmptyStateCard(title: title, subtitle: subtitle),
        ],
      ),
    );
  }
}

String _projectRepoPreview(ArgoProject project) {
  if (project.sourceRepos.isEmpty) {
    return 'No repositories';
  }
  final first = project.sourceRepos.first;
  final remaining = project.sourceRepos.length - 1;
  return remaining > 0 ? '$first +$remaining more' : first;
}

String _projectDestinationPreview(ArgoProject project) {
  if (project.destinations.isEmpty) {
    return 'No destinations';
  }
  final first = project.destinations.first;
  final cluster = first.name.isNotEmpty ? first.name : first.server;
  final scope = '$cluster / ${first.namespace}';
  final remaining = project.destinations.length - 1;
  return remaining > 0 ? '$scope +$remaining more' : scope;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.textOnDarkGreen),
          const SizedBox(width: 8),
          Column(
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
              const SizedBox(height: 1),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textOnDarkGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
