import 'dart:math' as math;

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
  String _searchQuery = '';
  bool _allExpanded = true;

  /// Incremented to signal a global expand/collapse reset.
  int _expandGeneration = 0;

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
            tooltip: _allExpanded ? 'Collapse All' : 'Expand All',
            onPressed: _toggleExpandAll,
            icon: Icon(
              _allExpanded
                  ? Icons.unfold_less_rounded
                  : Icons.unfold_more_rounded,
            ),
          ),
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
                return _buildLoadingState(theme);
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error, theme);
              }

              final nodes = snapshot.requireData;

              if (nodes.isEmpty) {
                return _buildEmptyState(theme);
              }

              final tree = _ResourceTreeData(nodes);
              final List<ArgoResourceNode> filteredRoots;
              if (_searchQuery.isEmpty) {
                filteredRoots = tree.rootNodes;
              } else {
                filteredRoots = _filterTree(tree, tree.rootNodes);
              }

              return ListView(
                padding: const EdgeInsets.all(14),
                children: <Widget>[
                  _SummaryHeader(nodes: nodes),
                  const SizedBox(height: 10),
                  _buildSearchBar(theme),
                  const SizedBox(height: 10),
                  if (filteredRoots.isEmpty && _searchQuery.isNotEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: <Widget>[
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: AppColors.greyLight,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No resources match "$_searchQuery"',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SectionCard(
                      title: 'Kubernetes Hierarchy',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (int i = 0; i < filteredRoots.length; i++)
                            _ResourceNodeTile(
                              key: ValueKey<String>(
                                '${filteredRoots[i].uid}_$_expandGeneration',
                              ),
                              controller: widget.controller,
                              applicationName: widget.applicationName,
                              node: filteredRoots[i],
                              tree: tree,
                              depth: 0,
                              isInitiallyExpanded: _allExpanded,
                              ancestorUids: const <String>{},
                              isLastChild: i == filteredRoots.length - 1,
                              searchQuery: _searchQuery,
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

  Widget _buildSearchBar(ThemeData theme) {
    final outlineColor = AppColors.outline(theme);
    final mutedColor = AppColors.mutedText(theme);

    return TextField(
      decoration: InputDecoration(
        hintText: 'Filter by name or kind...',
        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
        prefixIcon: Icon(Icons.search, size: 20, color: mutedColor),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                tooltip: 'Clear filter',
                color: mutedColor,
              )
            : null,
        filled: true,
        fillColor: AppColors.inputFill(theme),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.cobalt, width: 1.5),
        ),
      ),
      onChanged: (String value) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      },
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading resource tree...',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 56, color: AppColors.coral),
            const SizedBox(height: 16),
            Text(
              'Failed to load resources',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 20),
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.account_tree_outlined,
              size: 64,
              color: AppColors.greyLight,
            ),
            const SizedBox(height: 16),
            Text(
              'No resources found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No resource tree data returned by the ArgoCD API.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  List<ArgoResourceNode> _filterTree(
    _ResourceTreeData tree,
    List<ArgoResourceNode> nodes,
  ) {
    final List<ArgoResourceNode> result = <ArgoResourceNode>[];
    for (final ArgoResourceNode node in nodes) {
      if (_nodeMatchesSearch(node) ||
          _hasMatchingDescendant(tree, node, <String>{})) {
        result.add(node);
      }
    }
    return result;
  }

  bool _nodeMatchesSearch(ArgoResourceNode node) {
    return node.name.toLowerCase().contains(_searchQuery) ||
        node.kind.toLowerCase().contains(_searchQuery);
  }

  bool _hasMatchingDescendant(
    _ResourceTreeData tree,
    ArgoResourceNode node,
    Set<String> visited,
  ) {
    final children = tree.childrenFor(node.uid);
    for (final ArgoResourceNode child in children) {
      if (visited.contains(child.uid)) {
        continue;
      }
      if (_nodeMatchesSearch(child)) {
        return true;
      }
      if (_hasMatchingDescendant(tree, child, <String>{
        ...visited,
        child.uid,
      })) {
        return true;
      }
    }
    return false;
  }

  void _refresh() {
    setState(() {
      _future = widget.controller.loadResourceTree(widget.applicationName);
    });
  }

  void _toggleExpandAll() {
    setState(() {
      _allExpanded = !_allExpanded;
      _expandGeneration++;
    });
  }
}

// ---------------------------------------------------------------------------
// Summary header with donut chart
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

    final kindCounts = <String, int>{};

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
      kindCounts[node.kind] = (kindCounts[node.kind] ?? 0) + 1;
    }

    final sortedKinds = kindCounts.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );

    final healthSegments = <_DonutSegment>[
      if (healthy > 0)
        _DonutSegment(
          value: healthy.toDouble(),
          color: AppColors.healthColor('healthy'),
          label: 'Healthy',
        ),
      if (progressing > 0)
        _DonutSegment(
          value: progressing.toDouble(),
          color: AppColors.healthColor('progressing'),
          label: 'Progressing',
        ),
      if (degraded > 0)
        _DonutSegment(
          value: degraded.toDouble(),
          color: AppColors.healthColor('degraded'),
          label: 'Degraded',
        ),
      if (other > 0)
        _DonutSegment(
          value: other.toDouble(),
          color: AppColors.grey,
          label: 'Other',
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Resource Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _DonutChartPainter(
                  segments: healthSegments,
                  total: total.toDouble(),
                  bgRingColor: theme.dividerColor.withValues(alpha: 0.3),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$total',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'resources',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: <Widget>[
              for (final _DonutSegment segment in healthSegments)
                _LegendItem(
                  color: segment.color,
                  label: '${segment.value.toInt()} ${segment.label}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Resources by Kind',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final MapEntry<String, int> entry in sortedKinds)
                _KindCountBadge(kind: entry.key, count: entry.value),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Donut chart painter
// ---------------------------------------------------------------------------

class _DonutSegment {
  const _DonutSegment({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.segments,
    required this.total,
    required this.bgRingColor,
  });

  final List<_DonutSegment> segments;
  final double total;
  final Color bgRingColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || segments.isEmpty) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 20.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final bgPaint = Paint()
      ..color = bgRingColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bgPaint);

    const gapAngle = 0.04;
    final totalGap = gapAngle * segments.length;
    final availableSweep = 2 * math.pi - totalGap;

    double startAngle = -math.pi / 2;

    for (final _DonutSegment segment in segments) {
      final sweepAngle = (segment.value / total) * availableSweep;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) {
    return segments != oldDelegate.segments ||
        total != oldDelegate.total ||
        bgRingColor != oldDelegate.bgRingColor;
  }
}

// ---------------------------------------------------------------------------
// Legend and badge widgets
// ---------------------------------------------------------------------------

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _KindCountBadge extends StatelessWidget {
  const _KindCountBadge({required this.kind, required this.count});

  final String kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color kindColor = colorForResourceKind(kind);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: kindColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: kindColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(iconForResourceKind(kind), size: 14, color: kindColor),
          const SizedBox(width: 4),
          Text(
            '$count $kind',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: kindColor,
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
// Node tile with tree connectors
// ---------------------------------------------------------------------------

class _ResourceNodeTile extends StatefulWidget {
  const _ResourceNodeTile({
    super.key,
    required this.controller,
    required this.applicationName,
    required this.node,
    required this.tree,
    required this.depth,
    required this.isInitiallyExpanded,
    required this.ancestorUids,
    required this.isLastChild,
    this.searchQuery = '',
  });

  final AppController controller;
  final String applicationName;
  final ArgoResourceNode node;
  final _ResourceTreeData tree;
  final int depth;
  final bool isInitiallyExpanded;
  final Set<String> ancestorUids;
  final bool isLastChild;
  final String searchQuery;

  @override
  State<_ResourceNodeTile> createState() => _ResourceNodeTileState();
}

class _ResourceNodeTileState extends State<_ResourceNodeTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isInitiallyExpanded;
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.tree
        .childrenFor(widget.node.uid)
        .where(
          (ArgoResourceNode child) => !widget.ancestorUids.contains(child.uid),
        )
        .toList(growable: false);
    final nextAncestors = <String>{...widget.ancestorUids, widget.node.uid};
    final bool hasChildren = children.isNotEmpty;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (widget.depth > 0)
                SizedBox(
                  width: 24,
                  child: CustomPaint(
                    painter: _NodeConnectorPainter(
                      color: theme.dividerColor,
                      isLastChild: widget.isLastChild,
                    ),
                  ),
                ),
              if (hasChildren)
                GestureDetector(
                  onTap: _toggleExpanded,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.grey,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 20),
              Expanded(
                child: _NodeCard(
                  controller: widget.controller,
                  applicationName: widget.applicationName,
                  node: widget.node,
                  isPod: widget.node.kind.toLowerCase() == 'pod',
                  kindColor: colorForResourceKind(widget.node.kind),
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
        if (hasChildren && _expanded)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(left: widget.depth > 0 ? 24.0 : 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < children.length; i++)
                    _ResourceNodeTile(
                      key: ValueKey<String>(children[i].uid),
                      controller: widget.controller,
                      applicationName: widget.applicationName,
                      node: children[i],
                      tree: widget.tree,
                      depth: widget.depth + 1,
                      isInitiallyExpanded: widget.isInitiallyExpanded,
                      ancestorUids: nextAncestors,
                      isLastChild: i == children.length - 1,
                      searchQuery: widget.searchQuery,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Node connector painter (vertical + horizontal lines)
// ---------------------------------------------------------------------------

class _NodeConnectorPainter extends CustomPainter {
  _NodeConnectorPainter({required this.color, required this.isLastChild});

  final Color color;
  final bool isLastChild;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final double midX = size.width / 2;
    final double midY = 20;

    canvas.drawLine(Offset(midX, 0), Offset(midX, midY), paint);

    canvas.drawLine(Offset(midX, midY), Offset(size.width, midY), paint);

    if (!isLastChild) {
      _drawDashedLine(
        canvas,
        Offset(midX, midY),
        Offset(midX, size.height),
        paint,
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
  ) {
    const double dashLength = 4.0;
    const double gapLength = 3.0;
    final double totalLength = (end - start).distance;
    final Offset direction = (end - start) / totalLength;
    double drawn = 0.0;

    while (drawn < totalLength) {
      final double segEnd = math.min(drawn + dashLength, totalLength);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * segEnd,
        paint,
      );
      drawn = segEnd + gapLength;
    }
  }

  @override
  bool shouldRepaint(_NodeConnectorPainter oldDelegate) {
    return color != oldDelegate.color || isLastChild != oldDelegate.isLastChild;
  }
}

// ---------------------------------------------------------------------------
// Node card content with left color strip
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _openManifest(context),
        onLongPress: () => _showDetailSheet(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: kindColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: kindColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      iconForResourceKind(node.kind),
                      size: 18,
                      color: kindColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          node.kind,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kindColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          node.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        _MetadataRow(node: node, theme: theme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: node.healthStatus,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.healthColor(node.healthStatus),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                if (isPod)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: _SmallActionButton(
                        icon: Icons.article_outlined,
                        label: 'Logs',
                        color: AppColors.teal,
                        onPressed: () => _openLogs(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kindColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        iconForResourceKind(node.kind),
                        color: kindColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            node.kind,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: kindColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            node.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                _DetailRow(label: 'Kind', value: node.kind),
                _DetailRow(label: 'Name', value: node.name),
                _DetailRow(label: 'Namespace', value: node.namespace),
                _DetailRow(label: 'Group', value: node.group),
                _DetailRow(label: 'Version', value: node.version),
                _DetailRow(label: 'UID', value: node.uid),
                _DetailRow(
                  label: 'Health Status',
                  value: node.healthStatus,
                  valueColor: AppColors.healthColor(node.healthStatus),
                ),
                if (node.healthMessage.isNotEmpty)
                  _DetailRow(
                    label: 'Health Message',
                    value: node.healthMessage,
                  ),
                _DetailRow(label: 'Created At', value: node.createdAt),
                if (node.parentUids.isNotEmpty)
                  _DetailRow(
                    label: 'Parent UIDs',
                    value: node.parentUids.join(', '),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openManifest(context);
                        },
                        icon: const Icon(Icons.data_object, size: 18),
                        label: const Text('View Manifest'),
                      ),
                    ),
                    if (isPod) ...<Widget>[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _openLogs(context);
                          },
                          icon: const Icon(Icons.article_outlined, size: 18),
                          label: const Text('View Logs'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        );
      },
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
// Metadata row (namespace, version, age)
// ---------------------------------------------------------------------------

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.node, required this.theme});

  final ArgoResourceNode node;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.mutedText(theme),
      fontSize: 11,
    );
    final dotStyle = TextStyle(color: AppColors.mutedText(theme), fontSize: 11);
    final pieces = <Widget>[
      Text(node.namespace, style: style, overflow: TextOverflow.ellipsis),
    ];

    void addSeparator() {
      pieces.add(Text('\u00b7', style: dotStyle));
    }

    if (node.version.isNotEmpty) {
      addSeparator();
      pieces.add(
        Text(node.version, style: style, overflow: TextOverflow.ellipsis),
      );
    }

    if (node.createdAt.isNotEmpty) {
      addSeparator();
      pieces.add(
        Text(node.createdAt, style: style, overflow: TextOverflow.ellipsis),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: pieces,
    );
  }
}

// ---------------------------------------------------------------------------
// Detail row for bottom sheet
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = value.isEmpty ? '-' : value;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: theme.textTheme.bodySmall?.copyWith(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(4),
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
