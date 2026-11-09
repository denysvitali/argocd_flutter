import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
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

  Widget _refreshButton() {
    return IconButton(
      tooltip: 'Refresh',
      onPressed: _refresh,
      icon: const Icon(Icons.refresh_rounded),
    );
  }

  Widget _buildLoadingScaffold() {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          title: Text(widget.projectName),
          pinned: true,
          actions: <Widget>[_refreshButton()],
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(strokeWidth: 2.5),
                const SizedBox(height: 16),
                Text(
                  'Loading project details...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
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
          actions: <Widget>[_refreshButton()],
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorRetryWidget(message: error, onRetry: _refresh),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ArgoProject project) {
    final theme = Theme.of(context);
    final applications = widget.controller.applications
        .where((application) => application.project == project.name)
        .toList(growable: false);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            title: innerBoxIsScrolled ? Text(widget.projectName) : null,
            pinned: true,
            actions: <Widget>[_refreshButton()],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _Hero(project: project),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SegmentedHeaderDelegate(
              color: theme.scaffoldBackgroundColor,
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.fill(theme),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Equal-width segments when there is room; on phones the
                        // labels are sized to content so all four fit.
                        final roomy = constraints.maxWidth >= 480;
                        final labelStyle = theme.tabBarTheme.labelStyle
                            ?.copyWith(fontSize: roomy ? 13 : 12);
                        return TabBar(
                          controller: _tabController,
                          isScrollable: !roomy,
                          tabAlignment: roomy
                              ? TabAlignment.fill
                              : TabAlignment.start,
                          labelPadding: EdgeInsets.symmetric(
                            horizontal: roomy ? 8 : 6,
                          ),
                          labelStyle: labelStyle,
                          unselectedLabelStyle: theme
                              .tabBarTheme
                              .unselectedLabelStyle
                              ?.copyWith(fontSize: roomy ? 13 : 12),
                          tabs: <Widget>[
                            const Tab(text: 'Overview'),
                            Tab(
                              text: 'Sources (${project.sourceRepos.length})',
                            ),
                            Tab(
                              text:
                                  'Destinations (${project.destinations.length})',
                            ),
                            Tab(
                              text:
                                  'Permissions (${project.clusterResourceWhitelist.length})',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _OverviewTab(project: project, applications: applications),
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

/// Pins the segmented control below the app bar on the page background.
class _SegmentedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SegmentedHeaderDelegate({required this.child, required this.color});

  static const double _height = 36 + 4 + 12;

  final Widget child;
  final Color color;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_SegmentedHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || color != oldDelegate.color;
  }
}

/// Entity hero: name as Title 1 with the description as a secondary line.
class _Hero extends StatelessWidget {
  const _Hero({required this.project});

  final ArgoProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Project',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(project.name, style: theme.textTheme.headlineMedium),
        if (project.description.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            project.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

const EdgeInsets _tabPadding = EdgeInsets.fromLTRB(16, 10, 16, 32);

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.project, required this.applications});

  final ArgoProject project;
  final List<ArgoApplication> applications;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _tabPadding,
      children: <Widget>[
        _StatsCard(
          stats: <(int, String)>[
            (project.sourceRepos.length, 'Repositories'),
            (project.destinations.length, 'Destinations'),
            (project.clusterResourceWhitelist.length, 'Cluster rules'),
          ],
        ),
        const SizedBox(height: 28),
        const SectionHeader(title: 'Project Details'),
        GroupedList(
          children: <Widget>[
            _DetailRow(label: 'Name', value: project.name),
            _DetailRow(
              label: 'Description',
              value: project.description.isNotEmpty
                  ? project.description
                  : 'No description',
              stacked: true,
            ),
          ],
        ),
        if (applications.isNotEmpty) ...<Widget>[
          const SizedBox(height: 28),
          GroupedList(
            header: 'Applications (${applications.length})',
            dividerIndent: 38,
            children: <Widget>[
              for (final application in applications)
                Semantics(
                  label:
                      'Application: ${application.name}, '
                      '${application.healthStatus}, ${application.syncStatus}',
                  child: ExcludeSemantics(
                    child: GroupedRow(
                      leading: StatusDot(
                        color: AppColors.healthColor(application.healthStatus),
                      ),
                      title: application.name,
                      subtitle: application.namespace,
                      value: _syncLabel(application.syncStatus),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _syncLabel(String status) =>
      status.toLowerCase() == 'outofsync' ? 'Out of sync' : status;
}

/// Compact figures row: tabular numerals over muted captions, separated by
/// hairlines.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final List<(int, String)> stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.md,
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < stats.length; i++) ...<Widget>[
            if (i > 0)
              Container(width: 0.5, height: 36, color: scheme.outlineVariant),
            Expanded(
              child: Semantics(
                label: '${stats[i].$1} ${stats[i].$2}',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${stats[i].$1}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppFonts.tabularFigures,
                        ),
                      ),
                      Text(
                        stats[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Key/value row for a [GroupedList]. Inline (label left, muted value right)
/// by default; [stacked] puts long values on their own line below the label.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.stacked = false,
  });

  final String label;
  final String value;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: stacked
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(value, style: theme.textTheme.bodyLarge),
                  ],
                ),
              )
            : GroupedRow(title: label, value: value),
      ),
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
        icon: Icons.code_off_rounded,
        title: 'No source repositories',
        subtitle: 'This project has no source repositories configured.',
      );
    }

    return ListView(
      padding: _tabPadding,
      children: <Widget>[
        GroupedList(
          header: 'Source repositories',
          footer: 'Applications in this project may deploy from these sources.',
          dividerIndent: 50,
          children: <Widget>[
            for (final repo in sourceRepos)
              Semantics(
                label: repo == '*'
                    ? 'Source repository: All repositories (wildcard)'
                    : 'Source repository: $repo',
                child: ExcludeSemantics(
                  child: repo == '*'
                      ? const GroupedRow(
                          leading: _RowGlyph(Icons.all_inclusive_rounded),
                          title: 'All repositories (wildcard)',
                          subtitle: 'Any source repository is allowed',
                        )
                      : GroupedRow(
                          leading: const _RowGlyph(Icons.commit_rounded),
                          title: repo,
                        ),
                ),
              ),
          ],
        ),
      ],
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

    return ListView(
      padding: _tabPadding,
      children: <Widget>[
        GroupedList(
          header: 'Destinations',
          footer: 'Cluster and namespace pairs this project may deploy to.',
          dividerIndent: 50,
          children: <Widget>[
            for (final destination in destinations)
              Semantics(
                label:
                    'Destination: ${<String>[if (destination.name.isNotEmpty) destination.name, destination.server, if (destination.namespace.isNotEmpty) destination.namespace].join(', ')}',
                child: ExcludeSemantics(
                  child: GroupedRow(
                    leading: const _RowGlyph(Icons.dns_rounded),
                    title: destination.name.isNotEmpty
                        ? destination.name
                        : _clusterLabel(destination.server),
                    subtitle: destination.name.isNotEmpty
                        ? _clusterLabel(destination.server)
                        : null,
                    value: destination.namespace.isNotEmpty
                        ? _scopeLabel(destination.namespace)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
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

    return ListView(
      padding: _tabPadding,
      children: <Widget>[
        GroupedList(
          header: 'Cluster resource whitelist',
          footer: resources.length == 1
              ? '1 cluster-scoped kind may be managed by this project.'
              : '${resources.length} cluster-scoped kinds may be managed by '
                    'this project.',
          dividerIndent: 50,
          children: <Widget>[
            for (final resource in resources)
              Semantics(
                label:
                    'Cluster resource: ${_kindLabel(resource)}'
                    '${resource.group.isNotEmpty ? ' (${resource.group})' : ''}',
                child: ExcludeSemantics(
                  child: GroupedRow(
                    leading: _RowGlyph(iconForResourceKind(resource.kind)),
                    title: _isWildcard(resource) ? 'All kinds' : resource.kind,
                    subtitle: resource.group.isNotEmpty
                        ? resource.group
                        : 'core',
                    value: _isWildcard(resource) ? '*' : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static bool _isWildcard(ArgoProjectClusterResource resource) =>
      resource.kind.isEmpty || resource.kind == '*';

  static String _kindLabel(ArgoProjectClusterResource resource) =>
      resource.kind.isEmpty ? '*' : resource.kind;
}

String _clusterLabel(String server) => server == '*' ? 'Any cluster' : server;

String _scopeLabel(String namespace) =>
    namespace == '*' ? 'All namespaces' : namespace;

/// Muted leading glyph for list rows.
class _RowGlyph extends StatelessWidget {
  const _RowGlyph(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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
      padding: _tabPadding,
      children: <Widget>[
        EmptyStateCard(icon: icon, title: title, subtitle: subtitle),
      ],
    );
  }
}
