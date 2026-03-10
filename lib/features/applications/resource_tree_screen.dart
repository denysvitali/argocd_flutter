import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

import 'log_viewer_screen.dart';
import 'manifest_viewer_screen.dart';

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
        builder: (
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
              _SummaryHeader(nodes: nodes),
              const SizedBox(height: 20),
              SectionCard(
                title: 'Kubernetes Hierarchy',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tree.rootNodes
                      .map(
                        (ArgoResourceNode node) => _ResourceNodeTile(
                          controller: widget.controller,
                          applicationName: widget.applicationName,
                          node: node,
                          tree: tree,
                          depth: 0,
                          isInitiallyExpanded: true,
                          ancestorUids: const <String>{},
                        ),
                      )
                      .toList(growable: false),
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

// ---------------------------------------------------------------------------
// Summary header
// ---------------------------------------------------------------------------

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.nodes});

  final List<ArgoResourceNode> nodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final int total = nodes.length;
    int healthy = 0;
    int degraded = 0;
    int progressing = 0;
    int other = 0;

    for (final ArgoResourceNode node in nodes) {
      switch (node.healthStatus.toLowerCase()) {
        case 'healthy':
          healthy++;
        case 'degraded':
          degraded++;
        case 'progressing':
          progressing++;
        default:
          other++;
      }
    }

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
          Text(
            'Resource Summary',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$total resources',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              if (healthy > 0)
                StatusChip(
                  label: '$healthy Healthy',
                  color: AppColors.healthColor('healthy'),
                ),
              if (degraded > 0)
                StatusChip(
                  label: '$degraded Degraded',
                  color: AppColors.healthColor('degraded'),
                ),
              if (progressing > 0)
                StatusChip(
                  label: '$progressing Progressing',
                  color: AppColors.healthColor('progressing'),
                ),
              if (other > 0)
                StatusChip(
                  label: '$other Other',
                  color: AppColors.grey,
                ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: <Widget>[
                  if (healthy > 0)
                    Expanded(
                      flex: healthy,
                      child: ColoredBox(
                        color: AppColors.healthColor('healthy'),
                      ),
                    ),
                  if (progressing > 0)
                    Expanded(
                      flex: progressing,
                      child: ColoredBox(
                        color: AppColors.healthColor('progressing'),
                      ),
                    ),
                  if (degraded > 0)
                    Expanded(
                      flex: degraded,
                      child: ColoredBox(
                        color: AppColors.healthColor('degraded'),
                      ),
                    ),
                  if (other > 0)
                    Expanded(
                      flex: other,
                      child: const ColoredBox(color: AppColors.grey),
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

// ---------------------------------------------------------------------------
// Tree data
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Node tile
// ---------------------------------------------------------------------------

class _ResourceNodeTile extends StatelessWidget {
  const _ResourceNodeTile({
    required this.controller,
    required this.applicationName,
    required this.node,
    required this.tree,
    required this.depth,
    required this.isInitiallyExpanded,
    required this.ancestorUids,
  });

  final AppController controller;
  final String applicationName;
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
    final bool isPod = node.kind.toLowerCase() == 'pod';
    final theme = Theme.of(context);
    final Color kindColor = colorForResourceKind(node.kind);

    final Widget tile = Padding(
      padding: EdgeInsets.only(left: depth * 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (depth > 0)
            Padding(
              padding: const EdgeInsets.only(top: 18, right: 4),
              child: SizedBox(
                width: 12,
                child: Divider(
                  thickness: 1,
                  color: AppColors.border,
                ),
              ),
            ),
          Expanded(
            child: _NodeCard(
              controller: controller,
              applicationName: applicationName,
              node: node,
              isPod: isPod,
              kindColor: kindColor,
              theme: theme,
            ),
          ),
        ],
      ),
    );

    if (children.isEmpty) {
      return tile;
    }

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: isInitiallyExpanded,
        controlAffinity: ListTileControlAffinity.leading,
        title: tile,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(left: depth * 20 + 10),
            child: CustomPaint(
              painter: _TreeLinePainter(color: AppColors.border),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children
                    .map(
                      (ArgoResourceNode child) => _ResourceNodeTile(
                        controller: controller,
                        applicationName: applicationName,
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
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node card content
// ---------------------------------------------------------------------------

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.controller,
    required this.applicationName,
    required this.node,
    required this.isPod,
    required this.kindColor,
    required this.theme,
  });

  final AppController controller;
  final String applicationName;
  final ArgoResourceNode node;
  final bool isPod;
  final Color kindColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openManifest(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kindColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconForResourceKind(node.kind),
                      size: 20,
                      color: kindColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              TextSpan(
                                text: node.kind,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: '  ${node.name}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Text(
                              'ns: ${node.namespace}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.grey,
                              ),
                            ),
                            if (node.createdAt.isNotEmpty) ...<Widget>[
                              const SizedBox(width: 8),
                              Text(
                                node.createdAt,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.greyLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    label: node.healthStatus,
                    color: AppColors.healthColor(node.healthStatus),
                  ),
                  const SizedBox(width: 4),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: AppColors.greyLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isPod)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 4),
              child: Row(
                children: <Widget>[
                  _SmallActionButton(
                    icon: Icons.article_outlined,
                    label: 'Logs',
                    color: AppColors.teal,
                    onPressed: () => _openLogs(context),
                  ),
                  const SizedBox(width: 8),
                  _SmallActionButton(
                    icon: Icons.data_object,
                    label: 'Manifest',
                    color: AppColors.cobalt,
                    onPressed: () => _openManifest(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openLogs(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogViewerScreen(
          controller: controller,
          applicationName: applicationName,
          namespace: node.namespace,
          podName: node.name,
          containerName: node.name,
        ),
      ),
    );
  }

  void _openManifest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManifestViewerScreen(
          controller: controller,
          applicationName: applicationName,
          namespace: node.namespace,
          resourceName: node.name,
          kind: node.kind,
          group: node.group,
          version: node.version,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small action button for pod actions
// ---------------------------------------------------------------------------

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tree-line painter for visual guides
// ---------------------------------------------------------------------------

class _TreeLinePainter extends CustomPainter {
  _TreeLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_TreeLinePainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
