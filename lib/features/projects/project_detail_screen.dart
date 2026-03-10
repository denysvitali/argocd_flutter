import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
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
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString()),
              ),
            );
          }

          final project = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _OverviewCard(project: project),
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.project});

  final ArgoProject project;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            project.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _LabeledText(label: 'Description', value: project.description),
        ],
      ),
    );
  }
}

class _SourceRepositoriesCard extends StatelessWidget {
  const _SourceRepositoriesCard({required this.sourceRepos});

  final List<String> sourceRepos;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Source Repositories',
      child: sourceRepos.isEmpty
          ? const Text('No source repositories returned by the ArgoCD API.')
          : Column(
              children: sourceRepos
                  .map(
                    (repo) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.source_outlined),
                      title: Text(repo),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _DestinationsCard extends StatelessWidget {
  const _DestinationsCard({required this.destinations});

  final List<ArgoProjectDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Destinations',
      child: destinations.isEmpty
          ? const Text('No destinations returned by the ArgoCD API.')
          : Column(
              children: destinations
                  .map(
                    (destination) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        destination.name.isEmpty
                            ? destination.server
                            : destination.name,
                      ),
                      subtitle: Text(
                        '${destination.server} • ${destination.namespace}',
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _ClusterResourcesCard extends StatelessWidget {
  const _ClusterResourcesCard({required this.resources});

  final List<ArgoProjectClusterResource> resources;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Cluster Resources',
      child: resources.isEmpty
          ? const Text('No cluster resources returned by the ArgoCD API.')
          : Column(
              children: resources
                  .map(
                    (resource) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(resource.kind),
                      subtitle: Text(resource.group),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EAF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyLarge,
          children: <InlineSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
