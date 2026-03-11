import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.controller,
    required this.projectName,
  });

  final AppController controller;
  final String projectName;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<ArgoProject> _future;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadProject(widget.projectName);
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ArgoProject>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _buildLoadingScaffold();
          }

          if (snapshot.hasError) {
            return _buildErrorScaffold(snapshot.error.toString());
          }

          final project = snapshot.requireData;
          return _buildContent(project);
        },
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          title: Text(widget.projectName),
          pinned: true,
          actions: <Widget>[
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: AppSpacing.xl),
                Text('Loading project details...'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorScaffold(String error) {
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          title: Text(widget.projectName),
          pinned: true,
          actions: <Widget>[
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: ErrorRetryWidget(message: error, onRetry: _refresh),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ArgoProject project) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            title: Text(widget.projectName),
            pinned: true,
            floating: true,
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xl),
              child: _HeaderBanner(project: project),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: <Widget>[
                  const Tab(text: 'Overview'),
                  Tab(
                    child: _TabLabel(
                      label: 'Sources',
                      count: project.sourceRepos.length,
                    ),
                  ),
                  Tab(
                    child: _TabLabel(
                      label: 'Destinations',
                      count: project.destinations.length,
                    ),
                  ),
                  Tab(
                    child: _TabLabel(
                      label: 'Permissions',
                      count: project.clusterResourceWhitelist.length,
                    ),
                  ),
                ],
              ),
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _OverviewTab(project: project),
          _SourcesTab(sourceRepos: project.sourceRepos),
          _DestinationsTab(destinations: project.destinations),
          _PermissionsTab(resources: project.clusterResourceWhitelist),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.controller.loadProject(widget.projectName);
    });
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabBar, required this.color});

  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: color, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || color != oldDelegate.color;
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: AppOpacity.medium),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.project});

  final ArgoProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.headerDarkAlt,
            AppColors.headerDarkGreen,
          ],
        ),
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: AppOpacity.medium),
                  borderRadius: AppRadius.md,
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PROJECT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textOnDarkGreen.withValues(alpha: AppOpacity.prominent),
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      project.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              project.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textOnDarkGreen,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              _BannerChip(
                icon: Icons.code_outlined,
                label: '${project.sourceRepos.length} repos',
              ),
              _BannerChip(
                icon: Icons.dns_outlined,
                label: '${project.destinations.length} destinations',
              ),
              _BannerChip(
                icon: Icons.shield_outlined,
                label:
                    '${project.clusterResourceWhitelist.length} cluster resources',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerChip extends StatelessWidget {
  const _BannerChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: AppOpacity.soft),
        borderRadius: AppRadius.sm,
        border: Border.all(color: Colors.white.withValues(alpha: AppOpacity.moderate)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.textOnDarkGreen),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project});

  final ArgoProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionHeader(
                icon: Icons.info_outline,
                iconColor: AppColors.cobalt,
                title: 'Project Details',
              ),
              const SizedBox(height: 14),
              _DetailRow(label: 'Name', value: project.name),
              const SizedBox(height: 10),
              _DetailRow(
                label: 'Description',
                value: project.description.isNotEmpty
                    ? project.description
                    : 'No description',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: SummaryTile(
                label: 'Source Repos',
                value: project.sourceRepos.length,
                valueColor: AppColors.cobalt,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: SummaryTile(
                label: 'Destinations',
                value: project.destinations.length,
                valueColor: AppColors.teal,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: SummaryTile(
                label: 'Resources',
                value: project.clusterResourceWhitelist.length,
                valueColor: AppColors.coral,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _SourcesTab extends StatelessWidget {
  const _SourcesTab({required this.sourceRepos});

  final List<String> sourceRepos;

  @override
  Widget build(BuildContext context) {
    if (sourceRepos.isEmpty) {
      return const _TabEmptyState(
        icon: Icons.code_off_outlined,
        title: 'No source repositories',
        subtitle: 'This project has no source repositories configured.',
      );
    }

    final theme = Theme.of(context);
    final outlineColor = AppColors.outline(theme);
    final mutedColor = AppColors.mutedText(theme);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      itemCount: sourceRepos.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, index) {
        final repo = sourceRepos[index];
        final isWildcard = repo == '*';
        final repoColor = isWildcard ? AppColors.amber : AppColors.cobalt;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: isWildcard
                ? AppColors.amber.withValues(alpha: AppOpacity.subtle)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isWildcard
                  ? AppColors.amber.withValues(alpha: AppOpacity.bold)
                  : outlineColor,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: repoColor.withValues(alpha: AppOpacity.medium),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isWildcard ? Icons.all_inclusive : Icons.commit_outlined,
                  size: 20,
                  color: repoColor,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            isWildcard ? 'All repositories (wildcard)' : repo,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: repoColor,
                              decoration: isWildcard
                                  ? null
                                  : TextDecoration.underline,
                              decorationColor: AppColors.cobalt.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),
                        if (isWildcard) ...<Widget>[
                          const SizedBox(width: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: AppOpacity.moderate),
                              borderRadius: AppRadius.sm,
                            ),
                            child: Text(
                              'WILDCARD',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.amber,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isWildcard)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          'Any source repository is allowed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DestinationsTab extends StatelessWidget {
  const _DestinationsTab({required this.destinations});

  final List<ArgoProjectDestination> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const _TabEmptyState(
        icon: Icons.dns_outlined,
        title: 'No destinations',
        subtitle: 'This project has no deployment destinations configured.',
      );
    }

    final theme = Theme.of(context);
    final outlineColor = AppColors.outline(theme);
    final mutedColor = AppColors.mutedText(theme);

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      itemCount: destinations.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, index) {
        final destination = destinations[index];

        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: outlineColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: AppOpacity.soft),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.dns_outlined,
                      size: 20,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          destination.name.isNotEmpty
                              ? destination.name
                              : destination.server,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (destination.name.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              destination.server,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (destination.namespace.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cobalt.withValues(alpha: AppOpacity.light),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.folder_outlined,
                          size: 16,
                          color: AppColors.cobalt,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            destination.namespace,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.cobalt,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionsTab extends StatelessWidget {
  const _PermissionsTab({required this.resources});

  final List<ArgoProjectClusterResource> resources;

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) {
      return const _TabEmptyState(
        icon: Icons.shield_outlined,
        title: 'No cluster resources',
        subtitle:
            'This project has no cluster resource whitelist entries configured.',
      );
    }

    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionHeader(
                icon: Icons.shield_outlined,
                iconColor: AppColors.coral,
                title: 'Cluster Resource Whitelist',
                count: resources.length,
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: resources
                    .map((resource) {
                      final kindColor = colorForResourceKind(resource.kind);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: kindColor.withValues(alpha: AppOpacity.light),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: kindColor.withValues(alpha: AppOpacity.strong),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              iconForResourceKind(resource.kind),
                              size: 22,
                              color: kindColor,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  resource.kind.isEmpty ? '*' : resource.kind,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (resource.group.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                                    child: Text(
                                      resource.group,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: AppColors.grey),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.huge),
      children: <Widget>[
        Icon(icon, size: 56, color: AppColors.greyLight),
        const SizedBox(height: AppSpacing.xl),
        EmptyStateCard(title: title, subtitle: subtitle),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.count,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: AppOpacity.medium),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: AppOpacity.soft),
              borderRadius: AppRadius.sm,
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
