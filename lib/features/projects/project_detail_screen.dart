import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
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

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Future<ArgoProject> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadProject(widget.projectName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<ArgoProject>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading project details...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorRetryWidget(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                ),
              ),
            );
          }

          final project = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _HeaderBanner(project: project),
              const SizedBox(height: 20),
              _SourceRepositoriesCard(sourceRepos: project.sourceRepos),
              const SizedBox(height: 20),
              _DestinationsCard(destinations: project.destinations),
              const SizedBox(height: 20),
              _ClusterResourcesCard(
                resources: project.clusterResourceWhitelist,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.controller.loadProject(widget.projectName);
    });
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

class _SourceRepositoriesCard extends StatelessWidget {
  const _SourceRepositoriesCard({required this.sourceRepos});

  final List<String> sourceRepos;

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
          _SectionHeader(
            icon: Icons.code_outlined,
            iconColor: AppColors.cobalt,
            title: 'Source Repositories',
            count: sourceRepos.length,
          ),
          const SizedBox(height: 20),
          if (sourceRepos.isEmpty)
            const Text('No source repositories returned by the ArgoCD API.')
          else
            ...sourceRepos.map(
              (repo) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Icon(
                      repo == '*'
                          ? Icons.all_inclusive
                          : Icons.commit_outlined,
                      size: 18,
                      color: AppColors.cobalt,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        repo,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.cobalt,
                          decoration: repo == '*'
                              ? null
                              : TextDecoration.underline,
                          decorationColor: AppColors.cobalt.withValues(
                            alpha: 0.4,
                          ),
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
  }
}

class _DestinationsCard extends StatelessWidget {
  const _DestinationsCard({required this.destinations});

  final List<ArgoProjectDestination> destinations;

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
          _SectionHeader(
            icon: Icons.dns_outlined,
            iconColor: AppColors.teal,
            title: 'Destinations',
            count: destinations.length,
          ),
          const SizedBox(height: 20),
          if (destinations.isEmpty)
            const Text('No destinations returned by the ArgoCD API.')
          else
            ...destinations.map(
              (destination) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.canvasSubtle,
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
                              const Icon(
                                Icons.label_outline,
                                size: 16,
                                color: AppColors.teal,
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClusterResourcesCard extends StatelessWidget {
  const _ClusterResourcesCard({required this.resources});

  final List<ArgoProjectClusterResource> resources;

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
          _SectionHeader(
            icon: Icons.shield_outlined,
            iconColor: AppColors.coral,
            title: 'Cluster Resources',
            count: resources.length,
          ),
          const SizedBox(height: 20),
          if (resources.isEmpty)
            const Text('No cluster resources returned by the ArgoCD API.')
          else
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
    );
  }
}
