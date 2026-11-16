import 'dart:math' as math;

import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

import 'pods_screen.dart';
import 'resource_map_screen.dart';

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

const double kGraphNodeWidth = 236;
const double kGraphHeaderHeight = 78;
const double kGraphPodRowHeight = 28;
const double kGraphColumnGap = 64;
const double kGraphRowGap = 16;
const double kGraphPadding = 24;

enum GraphNodeType { application, resource, stack }

/// A positioned card in the graph.
class GraphNode {
  GraphNode._({
    required this.id,
    required this.type,
    this.application,
    this.mapNode,
    this.stackCount = 0,
  });

  final String id;
  final GraphNodeType type;
  final ArgoApplication? application;
  final MapNode? mapNode;

  /// Number of folded ReplicaSets for [GraphNodeType.stack].
  final int stackCount;

  final List<GraphNode> children = <GraphNode>[];

  /// Total children before collapsing, so the handle shows even when hidden.
  int childCount = 0;
  Offset position = Offset.zero;

  ArgoResourceNode? get resource => mapNode?.node;
  List<ArgoResourceNode> get pods =>
      mapNode?.pods ?? const <ArgoResourceNode>[];

  double get height =>
      kGraphHeaderHeight +
      (pods.isEmpty ? 0 : pods.length * kGraphPodRowHeight + 8);

  Rect get rect => position & Size(kGraphNodeWidth, height);

  /// Where edges attach: vertical middle of the header.
  double get anchorY => position.dy + kGraphHeaderHeight / 2;
}

class GraphLayout {
  GraphLayout({required this.root, required this.nodes, required this.size});

  final GraphNode root;
  final List<GraphNode> nodes;
  final Size size;
}

/// Lays the application and its resources out left-to-right, one column per
/// tree depth, parents vertically centred on their children.
///
/// [collapsed] hides a node's children; [expandedStacks] replaces the
/// "N ReplicaSets" stack under a parent with the individual ReplicaSets.
GraphLayout layoutResourceGraph({
  required String applicationName,
  ArgoApplication? application,
  required List<MapSection> sections,
  Set<String> collapsed = const <String>{},
  Set<String> expandedStacks = const <String>{},
}) {
  final all = <GraphNode>[];

  GraphNode fromMapNode(MapNode mapNode) {
    final node = GraphNode._(
      id: mapNode.node.uid.isNotEmpty
          ? mapNode.node.uid
          : '${mapNode.node.kind}/${mapNode.node.namespace}/${mapNode.node.name}',
      type: GraphNodeType.resource,
      mapNode: mapNode,
    );
    final kids = <GraphNode>[
      for (final child in mapNode.children) fromMapNode(child),
    ];
    final older = mapNode.olderReplicaSets;
    if (older.isNotEmpty) {
      if (expandedStacks.contains(node.id)) {
        kids.addAll(older.map(fromMapNode));
      }
      kids.add(
        GraphNode._(
          id: '${node.id}#stack',
          type: GraphNodeType.stack,
          stackCount: older.length,
        ),
      );
    }
    node.childCount = kids.length;
    if (!collapsed.contains(node.id)) {
      node.children.addAll(kids);
    }
    return node;
  }

  final root = GraphNode._(
    id: '#app',
    type: GraphNodeType.application,
    application: application,
  );
  final roots = <GraphNode>[
    for (final section in sections)
      for (final mapNode in section.roots) fromMapNode(mapNode),
  ];
  root.childCount = roots.length;
  if (!collapsed.contains(root.id)) {
    root.children.addAll(roots);
  }

  var maxRight = 0.0;
  var maxBottom = 0.0;

  // Returns the y where the next sibling subtree may start.
  double place(GraphNode node, int depth, double top) {
    all.add(node);
    final x = kGraphPadding + depth * (kGraphNodeWidth + kGraphColumnGap);
    double y;
    double next;
    if (node.children.isEmpty) {
      y = top;
      next = top + node.height + kGraphRowGap;
    } else {
      var cursor = top;
      for (final child in node.children) {
        cursor = place(child, depth + 1, cursor);
      }
      final first = node.children.first.position.dy;
      final last = node.children.last.position.dy;
      y = math.max(top, (first + last) / 2);
      next = math.max(cursor, y + node.height + kGraphRowGap);
    }
    node.position = Offset(x, y);
    maxRight = math.max(maxRight, x + kGraphNodeWidth);
    maxBottom = math.max(maxBottom, y + node.height);
    return next;
  }

  place(root, 0, kGraphPadding);
  return GraphLayout(
    root: root,
    nodes: all,
    size: Size(maxRight + kGraphPadding, maxBottom + kGraphPadding),
  );
}

/// Short kind label under the glyph, kubectl-style.
String shortKind(String kind) => switch (kind.toLowerCase()) {
  'deployment' => 'deploy',
  'replicaset' => 'rs',
  'statefulset' => 'sts',
  'daemonset' => 'ds',
  'service' => 'svc',
  'ingress' => 'ing',
  'configmap' => 'cm',
  'secret' => 'secret',
  'serviceaccount' => 'sa',
  'persistentvolumeclaim' => 'pvc',
  'horizontalpodautoscaler' => 'hpa',
  'poddisruptionbudget' => 'pdb',
  'endpointslice' => 'epslice',
  'endpoints' => 'ep',
  'networkpolicy' => 'netpol',
  'cronjob' => 'cronjob',
  'rolebinding' => 'rb',
  'clusterrolebinding' => 'crb',
  'clusterrole' => 'cr',
  final other => other.length > 8 ? other.substring(0, 8) : other,
};

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

/// Pannable, zoomable resource graph.
class ResourceGraphView extends StatefulWidget {
  const ResourceGraphView({
    super.key,
    required this.applicationName,
    required this.application,
    required this.sections,
    required this.onOpenResource,
    required this.onOpenPod,
  });

  final String applicationName;
  final ArgoApplication? application;
  final List<MapSection> sections;
  final ValueChanged<ArgoResourceNode> onOpenResource;
  final ValueChanged<ArgoResourceNode> onOpenPod;

  @override
  State<ResourceGraphView> createState() => _ResourceGraphViewState();
}

class _ResourceGraphViewState extends State<ResourceGraphView> {
  static const double _minScale = 0.15;
  static const double _maxScale = 2;

  final TransformationController _transform = TransformationController();
  final Set<String> _collapsed = <String>{};
  final Set<String> _expandedStacks = <String>{};
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    super.dispose();
  }

  void _onTransform() => setState(() {});

  double get _scale => _transform.value.entry(0, 0);

  bool _placed = false;

  /// First frame: zoom so the application and its direct resources (two
  /// columns) fill the width, like ArgoCD's default zoom on a phone.
  void _placeInitially() {
    if (_placed || _viewport.isEmpty) {
      return;
    }
    _placed = true;
    const twoColumns =
        kGraphPadding * 2 + kGraphNodeWidth * 2 + kGraphColumnGap + 20;
    final scale = (_viewport.width / twoColumns).clamp(0.5, 1.0);
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  void _zoom(double factor) {
    final target = (_scale * factor).clamp(_minScale, _maxScale);
    final f = target / _scale;
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    _transform.value = Matrix4.translationValues(center.dx, center.dy, 0)
      ..multiply(Matrix4.diagonal3Values(f, f, 1))
      ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0))
      ..multiply(_transform.value);
  }

  void _fit(Size content) {
    if (_viewport.isEmpty) {
      return;
    }
    final scale = math
        .min(_viewport.width / content.width, _viewport.height / content.height)
        .clamp(_minScale, 1.0);
    final dx = (_viewport.width - content.width * scale) / 2;
    _transform.value = Matrix4.translationValues(math.max(0, dx), 0, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
  }

  void _toggle(Set<String> set, String id) {
    setState(() {
      if (!set.remove(id)) {
        set.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = layoutResourceGraph(
      applicationName: widget.applicationName,
      application: widget.application,
      sections: widget.sections,
      collapsed: _collapsed,
      expandedStacks: _expandedStacks,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (!_placed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _placeInitially();
            }
          });
        }
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: const EdgeInsets.all(400),
                  child: SizedBox.fromSize(
                    size: layout.size,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EdgePainter(
                              nodes: layout.nodes,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ),
                        for (final node in layout.nodes) ...<Widget>[
                          Positioned.fromRect(
                            rect: node.rect,
                            child: _buildCard(node),
                          ),
                          if (node.childCount > 0 &&
                              node.type != GraphNodeType.stack)
                            Positioned(
                              left: node.rect.right - 1,
                              top: node.anchorY - 9,
                              child: _CollapseHandle(
                                collapsed: _collapsed.contains(node.id),
                                count: node.childCount,
                                onTap: () => _toggle(_collapsed, node.id),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 16,
              child: _ZoomControls(
                scale: _scale,
                onZoomIn: () => _zoom(1.25),
                onZoomOut: () => _zoom(0.8),
                onFit: () => _fit(layout.size),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(GraphNode node) {
    switch (node.type) {
      case GraphNodeType.application:
        return _AppCard(
          name: widget.applicationName,
          application: widget.application,
        );
      case GraphNodeType.stack:
        final parentId = node.id.substring(0, node.id.length - 6);
        return _StackCard(
          count: node.stackCount,
          expanded: _expandedStacks.contains(parentId),
          onTap: () => _toggle(_expandedStacks, parentId),
        );
      case GraphNodeType.resource:
        return _ResourceCard(
          mapNode: node.mapNode!,
          onTap: () => widget.onOpenResource(node.resource!),
          onOpenPod: widget.onOpenPod,
        );
    }
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter({required this.nodes, required this.color});

  final List<GraphNode> nodes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final parent in nodes) {
      if (parent.children.isEmpty) {
        continue;
      }
      final start = Offset(parent.rect.right + 18, parent.anchorY);
      canvas.drawLine(Offset(parent.rect.right, parent.anchorY), start, paint);
      final elbowX = parent.rect.right + kGraphColumnGap / 2;
      for (final child in parent.children) {
        final end = Offset(child.rect.left, child.anchorY);
        const r = 6.0;
        final path = Path()..moveTo(start.dx, start.dy);
        if ((end.dy - start.dy).abs() < r * 2) {
          path.lineTo(end.dx, end.dy);
        } else {
          final dir = end.dy > start.dy ? 1.0 : -1.0;
          path
            ..lineTo(elbowX - r, start.dy)
            ..quadraticBezierTo(elbowX, start.dy, elbowX, start.dy + r * dir)
            ..lineTo(elbowX, end.dy - r * dir)
            ..quadraticBezierTo(elbowX, end.dy, elbowX + r, end.dy)
            ..lineTo(end.dx, end.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.nodes != nodes || old.color != color;
}

/// Shared card chrome: glyph column with short kind label, then content.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.icon,
    required this.kindLabel,
    required this.child,
    this.onTap,
    this.semanticsLabel,
  });

  final IconData icon;
  final String kindLabel;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.base,
        elevation: theme.brightness == Brightness.light ? 0.6 : 0,
        shadowColor: Colors.black26,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 40,
                  child: Column(
                    children: <Widget>[
                      Icon(icon, size: 24, color: scheme.onSurfaceVariant),
                      const SizedBox(height: 2),
                      Text(
                        kindLabel,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: AppColors.tertiaryLabel(theme),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.mapNode,
    required this.onTap,
    required this.onOpenPod,
  });

  final MapNode mapNode;
  final VoidCallback onTap;
  final ValueChanged<ArgoResourceNode> onOpenPod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = mapNode.node;
    final revision = (node.info['Revision'] ?? '').replaceAll(
      RegExp(r'\D'),
      '',
    );
    final age = shortAge(node.createdAt);
    final hasHealth = node.healthStatus != 'Unknown';

    return _CardShell(
      icon: iconForResourceKind(node.kind),
      kindLabel: shortKind(node.kind),
      onTap: onTap,
      semanticsLabel: '${node.kind} ${node.name}, ${node.healthStatus}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: kGraphHeaderHeight - 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  node.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Row(
                  children: <Widget>[
                    if (hasHealth) ...<Widget>[
                      _StatusGlyph(
                        icon: healthStatusIcon(node.healthStatus),
                        color: AppColors.healthColor(node.healthStatus),
                        tooltip: node.healthMessage.isEmpty
                            ? node.healthStatus
                            : '${node.healthStatus}: ${node.healthMessage}',
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (mapNode.syncStatus != null)
                      _StatusGlyph(
                        icon: syncStatusIcon(mapNode.syncStatus!),
                        color: AppColors.syncColor(mapNode.syncStatus!),
                        tooltip: mapNode.syncStatus!,
                      ),
                    const Spacer(),
                    if (age.isNotEmpty) _Badge(age),
                    if (revision.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 4),
                      _Badge('rev:$revision'),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (mapNode.pods.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            for (final pod in mapNode.pods)
              _PodLine(
                pod: pod,
                ownerName: node.name,
                onTap: () => onOpenPod(pod),
              ),
          ],
        ],
      ),
    );
  }
}

class _PodLine extends StatelessWidget {
  const _PodLine({
    required this.pod,
    required this.ownerName,
    required this.onTap,
  });

  final ArgoResourceNode pod;
  final String ownerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.healthColor(pod.healthStatus);
    final prefix = '$ownerName-';
    final label = pod.name.startsWith(prefix)
        ? pod.name.substring(prefix.length)
        : pod.name;
    final restarts = int.tryParse(pod.info['Restart Count'] ?? '') ?? 0;
    final ready = pod.info['Containers'] ?? '';

    return SizedBox(
      height: kGraphPodRowHeight,
      child: Semantics(
        button: true,
        label: 'Pod ${pod.name}, ${podStatusLabel(pod)}',
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.sm,
          child: Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.fill(theme),
              borderRadius: AppRadius.sm,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    healthStatusIcon(pod.healthStatus),
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFamily: AppFonts.mono,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
                if (ready.isNotEmpty)
                  ExcludeSemantics(
                    child: Text(
                      ready,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: AppFonts.tabularFigures,
                      ),
                    ),
                  ),
                if (restarts > 0) ...<Widget>[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.replay_rounded,
                    size: 11,
                    color: AppColors.statusForeground(theme, AppColors.warning),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      '$restarts',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.statusForeground(
                          theme,
                          AppColors.warning,
                        ),
                        fontFeatures: AppFonts.tabularFigures,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.name, required this.application});

  final String name;
  final ArgoApplication? application;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = application;
    return _CardShell(
      icon: Icons.layers_rounded,
      kindLabel: 'app',
      semanticsLabel: 'Application $name',
      child: SizedBox(
        height: kGraphHeaderHeight - 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (app != null)
              Row(
                children: <Widget>[
                  _StatusGlyph(
                    icon: healthStatusIcon(app.healthStatus),
                    color: AppColors.healthColor(app.healthStatus),
                    tooltip: app.healthStatus,
                  ),
                  const SizedBox(width: 4),
                  _StatusGlyph(
                    icon: syncStatusIcon(app.syncStatus),
                    color: AppColors.syncColor(app.syncStatus),
                    tooltip: app.syncStatus,
                  ),
                  const Spacer(),
                  if (app.lastSyncedAt case final synced?
                      when synced.isNotEmpty)
                    _Badge(shortAge(synced)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StackCard extends StatelessWidget {
  const _StackCard({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = expanded
        ? 'Hide older ReplicaSets'
        : '$count ${count == 1 ? 'ReplicaSet' : 'ReplicaSets'}';
    // Two offset sheets behind the card read as a stack.
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (!expanded)
          for (final offset in <double>[6, 3])
            Positioned(
              left: offset,
              right: -offset,
              top: offset,
              bottom: -offset,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppRadius.base,
                  border: Border.all(color: scheme.outlineVariant, width: 0.5),
                ),
              ),
            ),
        Positioned.fill(
          child: _CardShell(
            icon: Icons.view_module_outlined,
            kindLabel: 'rs',
            onTap: onTap,
            semanticsLabel: label,
            child: SizedBox(
              height: kGraphHeaderHeight - 18,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.unfold_less_rounded
                        : Icons.unfold_more_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 16,
        color: AppColors.statusForeground(Theme.of(context), color),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.fill(theme),
        borderRadius: AppRadius.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurfaceVariant,
          fontFeatures: AppFonts.tabularFigures,
        ),
      ),
    );
  }
}

class _CollapseHandle extends StatelessWidget {
  const _CollapseHandle({
    required this.collapsed,
    required this.count,
    required this.onTap,
  });

  final bool collapsed;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: collapsed ? 'Expand $count children' : 'Collapse children',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 18,
          constraints: const BoxConstraints(minWidth: 18),
          padding: EdgeInsets.symmetric(horizontal: collapsed ? 5 : 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: collapsed ? scheme.primary : scheme.surfaceContainerLow,
            borderRadius: AppRadius.pill,
            border: Border.all(color: scheme.outline.withValues(alpha: 0.55)),
          ),
          child: collapsed
              ? Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Icon(
                  Icons.remove_rounded,
                  size: 12,
                  color: scheme.onSurfaceVariant,
                ),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.scale,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  final double scale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.pill,
      elevation: 2,
      shadowColor: Colors.black26,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Fit to screen',
            onPressed: onFit,
            icon: const Icon(Icons.fit_screen_rounded),
          ),
          IconButton(
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '${(scale * 100).round()}%',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                fontFeatures: AppFonts.tabularFigures,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
