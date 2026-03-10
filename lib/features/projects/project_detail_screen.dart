import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

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
                SizedBox(height: 16),
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
              padding: const EdgeInsets.all(24),
              child: ErrorRetryWidget(
                message: error,
                onRetry: _refresh,
              ),
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                  Tab(text: 'Sources (${project.sourceRepos.length})'),
                  Tab(text: 'Destinations (${project.destinations.length})'),
                  Tab(
                    text:
                        'Permissions (${project.clusterResourceWhitelist.length})',
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

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.project});

  final ArgoProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  project.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              project.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textOnDarkGreen,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: AppColors.textOnDarkGreen),
          const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
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
              const SizedBox(height: 20),
              _DetailRow(
                label: 'Name',
                value: project.name,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Description',
                value: project.description.isNotEmpty
                    ? project.description
                    : 'No description',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: SummaryTile(
                label: 'Source Repos',
                value: project.sourceRepos.length,
                valueColor: AppColors.cobalt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryTile(
                label: 'Destinations',
                value: project.destinations.length,
                valueColor: AppColors.teal,
              ),
            ),
            const SizedBox(width: 12),
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
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge,
        ),
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

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sourceRepos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final repo = sourceRepos[index];
        final isWildcard = repo == '*';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cobalt.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isWildcard ? Icons.all_inclusive : Icons.commit_outlined,
                  size: 20,
                  color: AppColors.cobalt,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isWildcard ? 'All repositories (wildcard)' : repo,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.cobalt,
                        decoration:
                            isWildcard ? null : TextDecoration.underline,
                        decorationColor:
                            AppColors.cobalt.withValues(alpha: 0.4),
                      ),
                    ),
                    if (isWildcard)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Any source repository is allowed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.grey,
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

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: destinations.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final destination = destinations[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (destination.name.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.label_outline,
                          size: 16,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          destination.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.cloud_outlined,
                    size: 16,
                    color: AppColors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      destination.server,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              if (destination.namespace.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: AppColors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          destination.namespace,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.grey,
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
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
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
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: resources.map(
                  (resource) {
                    final kindColor = colorForResourceKind(resource.kind);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: kindColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: kindColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            iconForResourceKind(resource.kind),
                            size: 18,
                            color: kindColor,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                resource.kind.isEmpty ? '*' : resource.kind,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (resource.group.isNotEmpty)
                                Text(
                                  resource.group,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ).toList(growable: false),
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
      padding: const EdgeInsets.all(32),
      children: <Widget>[
        Icon(icon, size: 56, color: AppColors.greyLight),
        const SizedBox(height: 16),
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
