import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/last_updated_text.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final allProjects = widget.controller.projects;
    final projects = allProjects
        .where((project) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return project.name.toLowerCase().contains(normalizedQuery) ||
              project.description.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

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
          padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 20),
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
            if (normalizedQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${projects.length} of ${allProjects.length} projects',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.grey,
                  ),
                ),
              ),
            const SizedBox(height: 20),
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
                filtered: normalizedQuery.isNotEmpty,
                hasProjects: widget.controller.projects.isNotEmpty,
              )
            else
              ...projects.map(
                (project) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ProjectCard(
                    project: project,
                    onTap: () => widget.onOpenProject(project.name),
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
      elevation: 2,
      shadowColor: AppColors.cobalt.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Filter projects...',
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
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cobalt, width: 1.5),
          ),
        ),
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
      padding: const EdgeInsets.all(24),
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
        borderRadius: BorderRadius.circular(28),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Project boundaries',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            session == null
                ? 'Projects define repository and deployment boundaries.'
                : 'Review RBAC scope, source repositories, and target clusters for ${session.username}.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textOnDarkGreen,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
  const _ProjectCard({required this.project, required this.onTap});

  final ArgoProject project;
  final VoidCallback onTap;

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
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              project.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.greyLight,
                            size: 22,
                          ),
                        ],
                      ),
                      if (project.description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          project.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: <Widget>[
                          FactBadge(
                            icon: Icons.code_outlined,
                            label:
                                '${project.sourceRepos.length} source repos',
                          ),
                          FactBadge(
                            icon: Icons.dns_outlined,
                            label:
                                '${project.destinations.length} destinations',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 56, color: AppColors.greyLight),
          const SizedBox(height: 16),
          EmptyStateCard(title: title, subtitle: subtitle),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.textOnDarkGreen),
          const SizedBox(width: 10),
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
              const SizedBox(height: 2),
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
