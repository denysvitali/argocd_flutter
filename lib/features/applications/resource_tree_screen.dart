import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
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

  /// Per-node expansion overrides keyed by tree path; cleared whenever
  /// "Expand All" / "Collapse All" resets the whole tree.
  final Map<String, bool> _expandedOverrides = <String, bool>{};
  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadResourceTree(widget.applicationName);
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: (theme.appBarTheme.centerTitle ?? false)
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Resource Tree'),
            Text(
              widget.applicationName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
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
          const SizedBox(width: 4),
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
                return _buildErrorState(snapshot.error);
              }

              final nodes = snapshot.requireData;

              if (nodes.isEmpty) {
                return _buildEmptyState();
              }

              final tree = _ResourceTreeData(nodes);
              final List<ArgoResourceNode> filteredRoots;
              if (_searchQuery.isEmpty) {
                filteredRoots = tree.rootNodes;
              } else {
                filteredRoots = _filterTree(tree, tree.rootNodes);
              }

              final summary = <Widget>[
                const SectionHeader(title: 'Resource Summary'),
                _SummaryCard(nodes: nodes),
              ];
              final hierarchy = _buildHierarchySection(
                tree: tree,
                filteredRoots: filteredRoots,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 900) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 340,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            children: summary,
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(8, 8, 16, 32),
                            children: hierarchy,
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: <Widget>[
                      ...summary,
                      const SizedBox(height: 28),
                      ...hierarchy,
                    ],
                  );
                },
              );
            },
      ),
    );
  }

  List<Widget> _buildHierarchySection({
    required _ResourceTreeData tree,
    required List<ArgoResourceNode> filteredRoots,
  }) {
    final Widget content;
    if (filteredRoots.isEmpty && _searchQuery.isNotEmpty) {
      content = EmptyStateCard(
        icon: Icons.search_off_rounded,
        title: 'No Results',
        subtitle: 'No resources match "$_searchQuery"',
      );
    } else {
      final rows = <_TreeRow>[];
      for (final root in filteredRoots) {
        _flatten(
          tree,
          root,
          rows,
          depth: 0,
          path: '',
          ancestors: const <String>{},
        );
      }
      for (var i = 0; i < rows.length; i++) {
        final next = i + 1 < rows.length ? rows[i + 1].depth : 0;
        rows[i].continuingLevels = next < rows[i].depth ? next : rows[i].depth;
      }
      content = _HierarchyCard(
        rows: rows,
        controller: widget.controller,
        applicationName: widget.applicationName,
        onToggle: _toggleRow,
        onResourceChanged: _refresh,
      );
    }

    return <Widget>[
      const SectionHeader(title: 'Hierarchy'),
      _buildSearchField(),
      const SizedBox(height: 10),
      content,
    ];
  }

  void _flatten(
    _ResourceTreeData tree,
    ArgoResourceNode node,
    List<_TreeRow> rows, {
    required int depth,
    required String path,
    required Set<String> ancestors,
  }) {
    final nodePath = '$path/${node.uid}';
    final children = tree
        .childrenFor(node.uid)
        .where((ArgoResourceNode child) => !ancestors.contains(child.uid))
        .toList(growable: false);
    final expanded = _expandedOverrides[nodePath] ?? _allExpanded;
    rows.add(
      _TreeRow(
        node: node,
        depth: depth,
        path: nodePath,
        hasChildren: children.isNotEmpty,
        expanded: expanded,
      ),
    );
    if (!expanded) {
      return;
    }
    final nextAncestors = <String>{...ancestors, node.uid};
    for (final child in children) {
      _flatten(
        tree,
        child,
        rows,
        depth: depth + 1,
        path: nodePath,
        ancestors: nextAncestors,
      );
    }
  }

  void _toggleRow(_TreeRow row) {
    setState(() {
      _expandedOverrides[row.path] = !row.expanded;
    });
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _filterController,
      textInputAction: TextInputAction.search,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: 'Filter by name or kind',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.base,
          borderSide: BorderSide.none,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Clear filter',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.cancel_rounded,
                  color: AppColors.tertiaryLabel(Theme.of(context)),
                ),
                onPressed: () {
                  _filterController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
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
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading resources…',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: <Widget>[
        EmptyStateCard(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load resources',
          subtitle: error.toString(),
          action: FilledButton(onPressed: _refresh, child: const Text('Retry')),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: <Widget>[
        EmptyStateCard(
          icon: Icons.account_tree_outlined,
          title: 'No resources found',
          subtitle: 'No resource tree data returned by the ArgoCD API.',
          action: OutlinedButton(
            onPressed: _refresh,
            child: const Text('Refresh'),
          ),
        ),
      ],
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

  Future<void> _refresh() async {
    setState(() {
      _future = widget.controller.loadResourceTree(widget.applicationName);
    });
  }

  void _toggleExpandAll() {
    setState(() {
      _allExpanded = !_allExpanded;
      _expandedOverrides.clear();
    });
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

class _HealthBucket {
  const _HealthBucket(this.label, this.color, this.count);

  final String label;
  final Color color;
  final int count;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.nodes});

  final List<ArgoResourceNode> nodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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

    final buckets = <_HealthBucket>[
      _HealthBucket('Healthy', AppColors.healthColor('healthy'), healthy),
      _HealthBucket(
        'Progressing',
        AppColors.healthColor('progressing'),
        progressing,
      ),
      _HealthBucket('Degraded', AppColors.healthColor('degraded'), degraded),
      _HealthBucket('Other', AppColors.unknown, other),
    ].where((_HealthBucket b) => b.count > 0).toList(growable: false);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '$total',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontFeatures: AppFonts.tabularFigures,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'resources',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final bucket in buckets)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          StatusDot(color: bucket.color),
                          const SizedBox(width: 6),
                          Text(
                            '${bucket.count} ${bucket.label}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface,
                              fontFeatures: AppFonts.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StatusSegmentBar(
            segments: <StatusSegment>[
              for (final bucket in buckets)
                StatusSegment(color: bucket.color, count: bucket.count),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 0.5, thickness: 0.5, color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final MapEntry<String, int> entry in sortedKinds)
                _KindCountCapsule(kind: entry.key, count: entry.value),
            ],
          ),
        ],
      ),
    );
  }
}

/// Neutral capsule: small kind glyph (kind hue) + "2 Pod".
class _KindCountCapsule extends StatelessWidget {
  const _KindCountCapsule({required this.kind, required this.count});

  final String kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: AppColors.fill(theme),
        borderRadius: AppRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            iconForResourceKind(kind),
            size: 14,
            color: AppColors.statusForeground(
              theme,
              colorForResourceKind(kind),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $kind',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontFeatures: AppFonts.tabularFigures,
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
// Hierarchy (flattened outline with indentation guides)
// ---------------------------------------------------------------------------

class _TreeRow {
  _TreeRow({
    required this.node,
    required this.depth,
    required this.path,
    required this.hasChildren,
    required this.expanded,
  });

  final ArgoResourceNode node;
  final int depth;
  final String path;
  final bool hasChildren;
  final bool expanded;

  /// Deepest ancestor level whose guide continues below this row; guides
  /// for deeper levels stop at this row's midpoint (last descendant).
  int continuingLevels = 0;
}

const double _kRowLeadingPadding = 8;
const double _kIndent = 16;
const double _kDisclosureWidth = 20;
const double _kGlyphSize = 18;
const double _kGlyphGap = 9;

class _HierarchyCard extends StatelessWidget {
  const _HierarchyCard({
    required this.rows,
    required this.controller,
    required this.applicationName,
    required this.onToggle,
    required this.onResourceChanged,
  });

  final List<_TreeRow> rows;
  final AppController controller;
  final String applicationName;
  final ValueChanged<_TreeRow> onToggle;
  final Future<void> Function() onResourceChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Most rows share the app's namespace; only call out the exceptions.
    final namespaceCounts = <String, int>{};
    for (final row in rows) {
      namespaceCounts[row.node.namespace] =
          (namespaceCounts[row.node.namespace] ?? 0) + 1;
    }
    final dominantNamespace = namespaceCounts.entries.isEmpty
        ? ''
        : namespaceCounts.entries
              .reduce((a, b) => b.value > a.value ? b : a)
              .key;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(
        _ResourceRow(
          key: ValueKey<String>(rows[i].path),
          row: rows[i],
          showNamespace: rows[i].node.namespace != dominantNamespace,
          controller: controller,
          applicationName: applicationName,
          showSeparator: i < rows.length - 1,
          onToggle: () => onToggle(rows[i]),
          onResourceChanged: onResourceChanged,
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    super.key,
    required this.row,
    required this.showNamespace,
    required this.controller,
    required this.applicationName,
    required this.showSeparator,
    required this.onToggle,
    required this.onResourceChanged,
  });

  final _TreeRow row;
  final bool showNamespace;
  final AppController controller;
  final String applicationName;
  final bool showSeparator;
  final VoidCallback onToggle;
  final Future<void> Function() onResourceChanged;

  ArgoResourceNode get node => row.node;
  bool get _isPod => node.kind.toLowerCase() == 'pod';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final indent = row.depth * _kIndent;
    final textStart =
        _kRowLeadingPadding +
        indent +
        _kDisclosureWidth +
        _kGlyphSize +
        _kGlyphGap;
    final healthColor = AppColors.healthColor(node.healthStatus);
    final caption = <String>[
      if (showNamespace && node.namespace.isNotEmpty) node.namespace,
      if (node.createdAt.isNotEmpty) formatRelativeTime(node.createdAt),
    ];
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return CustomPaint(
      painter: _IndentGuidesPainter(
        depth: row.depth,
        continuingLevels: row.continuingLevels,
        drawsChildGuide: row.hasChildren && row.expanded,
        color: scheme.outlineVariant,
      ),
      child: InkWell(
        onTap: () => _openManifest(context),
        onLongPress: () => _showDetailSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                _kRowLeadingPadding + indent,
                9,
                14,
                9,
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: _kDisclosureWidth,
                    child: row.hasChildren
                        ? Semantics(
                            button: true,
                            label: row.expanded ? 'Collapse' : 'Expand',
                            child: InkResponse(
                              onTap: onToggle,
                              radius: 16,
                              child: AnimatedRotation(
                                turns: row.expanded ? 0.25 : 0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      iconForResourceKind(node.kind),
                      size: _kGlyphSize,
                      color: AppColors.statusForeground(
                        theme,
                        colorForResourceKind(node.kind),
                      ),
                    ),
                  ),
                  const SizedBox(width: _kGlyphGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          node.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: <Widget>[
                            Text(node.kind, style: captionStyle),
                            if (caption.isNotEmpty)
                              Flexible(
                                child: Text(
                                  '  ·  ${caption.join('  ·  ')}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: captionStyle?.copyWith(
                                    color: AppColors.tertiaryLabel(theme),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_isPod) ...<Widget>[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'View logs',
                      style: const ButtonStyle(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      iconSize: 19,
                      onPressed: () => _openLogs(context),
                      icon: const Icon(Icons.article_outlined),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Tooltip(
                    message: node.healthStatus,
                    child: Semantics(
                      label: 'Health: ${node.healthStatus}',
                      child: StatusDot(color: healthColor),
                    ),
                  ),
                ],
              ),
            ),
            if (showSeparator)
              Padding(
                padding: EdgeInsets.only(left: textStart),
                child: Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: scheme.outlineVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        final kindColor = AppColors.statusForeground(
          theme,
          colorForResourceKind(node.kind),
        );
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            final details = <Widget>[
              _DetailRow(label: 'Kind', value: node.kind),
              _DetailRow(label: 'Name', value: node.name),
              _DetailRow(label: 'Namespace', value: node.namespace),
              _DetailRow(label: 'Group', value: node.group),
              _DetailRow(label: 'Version', value: node.version),
              _DetailRow(label: 'UID', value: node.uid, monospace: true),
              _DetailRow(
                label: 'Health Status',
                value: node.healthStatus,
                leading: StatusDot(
                  color: AppColors.healthColor(node.healthStatus),
                ),
              ),
              if (node.healthMessage.isNotEmpty)
                _DetailRow(label: 'Health Message', value: node.healthMessage),
              _DetailRow(
                label: 'Created At',
                value: node.createdAt.isEmpty
                    ? ''
                    : formatTimestampWithRelative(node.createdAt),
              ),
              if (node.parentUids.isNotEmpty)
                _DetailRow(
                  label: 'Parent UIDs',
                  value: node.parentUids.join('\n'),
                  monospace: true,
                ),
            ];

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        iconForResourceKind(node.kind),
                        size: 22,
                        color: kindColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(node.name, style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 2),
                          Text(
                            node.namespace.isEmpty
                                ? node.kind
                                : '${node.kind} in ${node.namespace}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: AppRadius.base,
                  ),
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < details.length; i++) ...<Widget>[
                        if (i > 0)
                          Divider(
                            height: 0.5,
                            thickness: 0.5,
                            color: scheme.outlineVariant,
                          ),
                        details[i],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _openManifest(context);
                        },
                        icon: const Icon(Icons.data_object, size: 18),
                        label: const Text('View Manifest'),
                      ),
                    ),
                    if (_isPod) ...<Widget>[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _openLogs(context);
                          },
                          icon: const Icon(Icons.article_outlined, size: 18),
                          label: const Text('View Logs'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.error,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _confirmDelete(context);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete Resource'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    bool force = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Delete Resource'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Delete '${node.name}'? This will delete the live resource in the cluster.",
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: force,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Force delete'),
                    onChanged: (value) {
                      setState(() {
                        force = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await controller.deleteResource(
        applicationName: applicationName,
        namespace: node.namespace,
        resourceName: node.name,
        kind: node.kind,
        group: node.group,
        version: node.version,
        force: force,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resource deletion requested.')),
      );
      await onResourceChanged();
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
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

/// Hairline indentation guides: one vertical rule per ancestor level,
/// centred under that ancestor's disclosure chevron, plus a short rule
/// dropping from this row's own chevron when it is expanded.
class _IndentGuidesPainter extends CustomPainter {
  _IndentGuidesPainter({
    required this.depth,
    required this.continuingLevels,
    required this.drawsChildGuide,
    required this.color,
  });

  final int depth;
  final int continuingLevels;
  final bool drawsChildGuide;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..isAntiAlias = true;

    double guideX(int level) =>
        _kRowLeadingPadding + level * _kIndent + _kDisclosureWidth / 2;

    for (var level = 0; level < depth; level++) {
      final x = guideX(level);
      final end = level < continuingLevels ? size.height : size.height / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, end), paint);
    }
    if (drawsChildGuide) {
      final x = guideX(depth);
      canvas.drawLine(
        Offset(x, size.height / 2 + 12),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_IndentGuidesPainter oldDelegate) {
    return depth != oldDelegate.depth ||
        continuingLevels != oldDelegate.continuingLevels ||
        drawsChildGuide != oldDelegate.drawsChildGuide ||
        color != oldDelegate.color;
  }
}

// ---------------------------------------------------------------------------
// Detail row for bottom sheet
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.leading,
    this.monospace = false,
  });

  final String label;
  final String value;
  final Widget? leading;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayValue = value.isEmpty ? '—' : value;
    final valueStyle = monospace
        ? TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 12.5,
            height: 1.5,
            color: scheme.onSurface,
          )
        : theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (leading != null) ...<Widget>[
            Padding(padding: const EdgeInsets.only(top: 6), child: leading),
            const SizedBox(width: 6),
          ],
          Expanded(child: SelectableText(displayValue, style: valueStyle)),
        ],
      ),
    );
  }
}
