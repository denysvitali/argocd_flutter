import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

class ResourceTreeScreen extends StatefulWidget {
  const ResourceTreeScreen({
    super.key,
    required this.controller,
    required this.applicationName,
  });

  final AppController controller;
  final String applicationName;

  @override
  State<ResourceTreeScreen> createState() => _ResourceTreeScreenState();
}

class _ResourceTreeScreenState extends State<ResourceTreeScreen> {
  late Future<List<ArgoResourceNode>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadResourceTree(widget.applicationName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Resource Tree'),
            Text(
              widget.applicationName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ArgoResourceNode>>(
        future: _future,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<ArgoResourceNode>> snapshot,
            ) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final nodes = snapshot.requireData;
              final tree = _ResourceTreeData(nodes);

              if (nodes.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No resource tree data returned by the ArgoCD API.',
                    ),
                  ),
                );
              }

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
                        Text(
                          'Kubernetes Hierarchy',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${nodes.length} resources',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...tree.rootNodes.map(
                          (ArgoResourceNode node) => _ResourceNodeTile(
                            node: node,
                            tree: tree,
                            depth: 0,
                            isInitiallyExpanded: true,
                            ancestorUids: <String>{},
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }

  void _refresh() {
    setState(() {
      _future = widget.controller.loadResourceTree(widget.applicationName);
    });
  }
}

class _ResourceTreeData {
  _ResourceTreeData(List<ArgoResourceNode> nodes)
    : nodes = List<ArgoResourceNode>.unmodifiable(nodes),
      _childrenByParentUid = _buildChildrenByParentUid(nodes),
      rootNodes = _buildRootNodes(nodes);

  final List<ArgoResourceNode> nodes;
  final Map<String, List<ArgoResourceNode>> _childrenByParentUid;
  final List<ArgoResourceNode> rootNodes;

  List<ArgoResourceNode> childrenFor(String uid) {
    return _childrenByParentUid[uid] ?? const <ArgoResourceNode>[];
  }

  static Map<String, List<ArgoResourceNode>> _buildChildrenByParentUid(
    List<ArgoResourceNode> nodes,
  ) {
    final byParentUid = <String, List<ArgoResourceNode>>{};
    for (final ArgoResourceNode node in nodes) {
      for (final String parentUid in node.parentUids) {
        byParentUid
            .putIfAbsent(parentUid, () => <ArgoResourceNode>[])
            .add(node);
      }
    }

    for (final List<ArgoResourceNode> children in byParentUid.values) {
      children.sort(_compareNodes);
    }

    return byParentUid;
  }

  static List<ArgoResourceNode> _buildRootNodes(List<ArgoResourceNode> nodes) {
    final roots = nodes.where((ArgoResourceNode node) => node.isRoot).toList();
    roots.sort(_compareNodes);
    if (roots.isNotEmpty) {
      return roots;
    }

    final fallback = List<ArgoResourceNode>.from(nodes);
    fallback.sort(_compareNodes);
    return fallback;
  }

  static int _compareNodes(ArgoResourceNode a, ArgoResourceNode b) {
    final kindComparison = a.kind.toLowerCase().compareTo(b.kind.toLowerCase());
    if (kindComparison != 0) {
      return kindComparison;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}

class _ResourceNodeTile extends StatelessWidget {
  const _ResourceNodeTile({
    required this.node,
    required this.tree,
    required this.depth,
    required this.isInitiallyExpanded,
    required this.ancestorUids,
  });

  final ArgoResourceNode node;
  final _ResourceTreeData tree;
  final int depth;
  final bool isInitiallyExpanded;
  final Set<String> ancestorUids;

  @override
  Widget build(BuildContext context) {
    final children = tree
        .childrenFor(node.uid)
        .where((ArgoResourceNode child) => !ancestorUids.contains(child.uid))
        .toList(growable: false);
    final nextAncestors = <String>{...ancestorUids, node.uid};
    final subtitleParts = <String>[
      'ns: ${node.namespace}',
      node.healthStatus,
      if (node.healthMessage.isNotEmpty) node.healthMessage,
    ];

    return Padding(
      padding: EdgeInsets.only(left: depth * 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: isInitiallyExpanded,
          leading: Icon(
            _iconForKind(node.kind),
            color: AppColors.cobalt,
          ),
          title: Text('${node.kind}: ${node.name}'),
          subtitle: Text(subtitleParts.join(' • ')),
          trailing: _HealthDot(status: node.healthStatus),
          children: children
              .map(
                (ArgoResourceNode child) => _ResourceNodeTile(
                  node: child,
                  tree: tree,
                  depth: depth + 1,
                  isInitiallyExpanded: false,
                  ancestorUids: nextAncestors,
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  IconData _iconForKind(String kind) {
    switch (kind.toLowerCase()) {
      case 'application':
        return Icons.apps;
      case 'deployment':
        return Icons.storage;
      case 'service':
        return Icons.dns;
      case 'replicaset':
        return Icons.view_module;
      case 'pod':
        return Icons.memory;
      case 'configmap':
      case 'secret':
        return Icons.settings;
      case 'ingress':
        return Icons.public;
      default:
        return Icons.widgets;
    }
  }
}

class _HealthDot extends StatelessWidget {
  const _HealthDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _colorForStatus(status),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _colorForStatus(String healthStatus) {
    return AppColors.healthColor(healthStatus);
  }
}
