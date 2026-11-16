import 'dart:async';

import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

import 'manifest_viewer_screen.dart';
import 'pod_screen.dart';
import 'pods_screen.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// A resource in the map with its children already arranged for display:
/// pods are pulled out into [pods] (rendered as chips), and ReplicaSets that
/// no longer own anything are folded into [olderReplicaSets].
class MapNode {
  MapNode({
    required this.node,
    required this.syncStatus,
    required this.children,
    required this.pods,
    required this.olderReplicaSets,
  });

  final ArgoResourceNode node;

  /// Sync status from `application.status.resources`; null for resources
  /// ArgoCD does not manage directly (ReplicaSets, Pods, EndpointSlices...).
  final String? syncStatus;
  final List<MapNode> children;
  final List<ArgoResourceNode> pods;
  final List<MapNode> olderReplicaSets;

  bool get isOutOfSync => syncStatus != null && syncStatus != 'Synced';

  /// Every resource in this subtree, including this one.
  Iterable<ArgoResourceNode> get subtree sync* {
    yield node;
    yield* pods;
    for (final child in children) {
      yield* child.subtree;
    }
    for (final rs in olderReplicaSets) {
      yield* rs.subtree;
    }
  }
}

class MapSection {
  const MapSection({required this.title, required this.roots});

  final String title;
  final List<MapNode> roots;
}

const List<(String, Set<String>)> _sectionKinds = <(String, Set<String>)>[
  (
    'Workloads',
    <String>{
      'deployment',
      'statefulset',
      'daemonset',
      'replicaset',
      'rollout',
      'job',
      'cronjob',
      'pod',
      'horizontalpodautoscaler',
      'poddisruptionbudget',
    },
  ),
  (
    'Networking',
    <String>{
      'service',
      'ingress',
      'httproute',
      'grpcroute',
      'gateway',
      'networkpolicy',
      'endpoints',
      'endpointslice',
      'certificate',
    },
  ),
  (
    'Storage',
    <String>{'persistentvolumeclaim', 'persistentvolume', 'storageclass'},
  ),
  (
    'Configuration',
    <String>{
      'configmap',
      'secret',
      'sealedsecret',
      'externalsecret',
      'serviceaccount',
      'role',
      'rolebinding',
      'clusterrole',
      'clusterrolebinding',
    },
  ),
];

String _sectionFor(String kind) {
  final lower = kind.toLowerCase();
  for (final (title, kinds) in _sectionKinds) {
    if (kinds.contains(lower)) {
      return title;
    }
  }
  return 'Other';
}

int _kindRank(String kind) {
  const order = <String>[
    'deployment',
    'statefulset',
    'daemonset',
    'rollout',
    'cronjob',
    'job',
    'replicaset',
    'pod',
    'service',
    'ingress',
    'endpointslice',
  ];
  final index = order.indexOf(kind.toLowerCase());
  return index < 0 ? order.length : index;
}

int _compareNodes(ArgoResourceNode a, ArgoResourceNode b) {
  final byKind = _kindRank(a.kind).compareTo(_kindRank(b.kind));
  if (byKind != 0) {
    return byKind;
  }
  final byKindName = a.kind.compareTo(b.kind);
  return byKindName != 0 ? byKindName : a.name.compareTo(b.name);
}

int _revisionOf(ArgoResourceNode node) =>
    int.tryParse(node.info['Revision']?.replaceAll(RegExp(r'\D'), '') ?? '') ??
    -1;

/// Arranges a resource tree into display sections. Pure, so it is tested
/// directly.
List<MapSection> buildResourceMap(
  List<ArgoResourceNode> nodes, {
  List<ArgoResource> managed = const <ArgoResource>[],
}) {
  final byUid = <String, ArgoResourceNode>{
    for (final n in nodes)
      if (n.uid.isNotEmpty) n.uid: n,
  };
  final childrenOf = <String, List<ArgoResourceNode>>{};
  final roots = <ArgoResourceNode>[];
  for (final node in nodes) {
    final parents = node.parentUids.where(byUid.containsKey).toList();
    if (parents.isEmpty) {
      roots.add(node);
    } else {
      for (final parent in parents) {
        childrenOf.putIfAbsent(parent, () => <ArgoResourceNode>[]).add(node);
      }
    }
  }

  final syncByKey = <String, String>{
    for (final r in managed) '${r.kind}/${r.namespace}/${r.name}': r.status,
  };

  MapNode build(ArgoResourceNode node, Set<String> ancestors) {
    final kids =
        (childrenOf[node.uid] ?? const <ArgoResourceNode>[])
            .where((c) => !ancestors.contains(c.uid))
            .toList()
          ..sort(_compareNodes);
    final nextAncestors = <String>{...ancestors, node.uid};
    final pods = <ArgoResourceNode>[];
    final children = <MapNode>[];
    final replicaSets = <MapNode>[];
    for (final kid in kids) {
      if (kid.kind == 'Pod') {
        pods.add(kid);
      } else if (kid.kind == 'ReplicaSet') {
        replicaSets.add(build(kid, nextAncestors));
      } else {
        children.add(build(kid, nextAncestors));
      }
    }

    // Newest revision first; ReplicaSets without pods or children are old
    // rollout history. Keep at least one visible.
    replicaSets.sort((a, b) {
      final byRev = _revisionOf(b.node).compareTo(_revisionOf(a.node));
      return byRev != 0 ? byRev : b.node.createdAt.compareTo(a.node.createdAt);
    });
    final active = replicaSets
        .where((rs) => rs.pods.isNotEmpty || rs.children.isNotEmpty)
        .toList();
    final older = replicaSets.where((rs) => !active.contains(rs)).toList();
    if (active.isEmpty && older.isNotEmpty) {
      active.add(older.removeAt(0));
    }

    pods.sort((a, b) => a.name.compareTo(b.name));
    return MapNode(
      node: node,
      syncStatus: syncByKey['${node.kind}/${node.namespace}/${node.name}'],
      children: <MapNode>[...active, ...children],
      pods: pods,
      olderReplicaSets: older,
    );
  }

  roots.sort(_compareNodes);
  final grouped = <String, List<MapNode>>{};
  for (final root in roots) {
    grouped
        .putIfAbsent(_sectionFor(root.kind), () => <MapNode>[])
        .add(build(root, const <String>{}));
  }
  return <MapSection>[
    for (final title in <String>[..._sectionKinds.map((s) => s.$1), 'Other'])
      if (grouped[title] case final roots?)
        MapSection(title: title, roots: roots),
  ];
}

/// Health states worth surfacing in "Issues only" and in row captions.
bool hasHealthIssue(ArgoResourceNode node) => switch (node.healthStatus) {
  'Degraded' || 'Progressing' || 'Missing' || 'Suspended' => true,
  _ => false,
};

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Mobile take on ArgoCD's application tree: resources grouped by section,
/// children nested under their owner, pods as status chips, and older
/// ReplicaSets folded away. Refreshes itself while on screen.
class ResourceMapScreen extends StatefulWidget {
  const ResourceMapScreen({
    super.key,
    required this.controller,
    required this.applicationName,
    this.refreshInterval = const Duration(seconds: 5),
  });

  final AppController controller;
  final String applicationName;
  final Duration refreshInterval;

  @override
  State<ResourceMapScreen> createState() => _ResourceMapScreenState();
}

class _ResourceMapScreenState extends State<ResourceMapScreen>
    with WidgetsBindingObserver {
  List<ArgoResourceNode>? _nodes;
  ArgoApplication? _application;
  Object? _error;
  bool _loading = true;
  Timer? _timer;
  bool _inForeground = true;

  String _query = '';
  bool _issuesOnly = false;
  final Set<String> _collapsed = <String>{};
  final Set<String> _showOlder = <String>{};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _inForeground) {
      return;
    }
    _inForeground = foreground;
    if (foreground) {
      _load(silent: true);
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _load({bool silent = false}) async {
    _timer?.cancel();
    if (!silent) {
      setState(() {
        _loading = _nodes == null;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        widget.controller.loadResourceTree(widget.applicationName),
        widget.controller.loadApplication(widget.applicationName),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _nodes = results[0] as List<ArgoResourceNode>;
        _application = results[1] as ArgoApplication;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      // Background refresh failures keep the last good map on screen.
      setState(() {
        _error = error;
        _loading = false;
      });
    }
    if (mounted && _inForeground) {
      _timer = Timer(widget.refreshInterval, () => _load(silent: true));
    }
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
            const Text('Resource Map'),
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
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final nodes = _nodes;
    if (nodes == null) {
      if (_loading) {
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: <Widget>[
          EmptyStateCard(
            icon: Icons.error_outline_rounded,
            title: "Couldn't Load Resources",
            subtitle: _error.toString(),
            action: FilledButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    final sections = buildResourceMap(
      nodes,
      managed: _application?.resources ?? const <ArgoResource>[],
    );
    final visible = <MapSection>[
      for (final section in sections)
        MapSection(
          title: section.title,
          roots: section.roots.where(_matches).toList(),
        ),
    ].where((s) => s.roots.isNotEmpty).toList();

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (_application != null)
            _AppStatusHeader(application: _application!, nodes: nodes),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Showing last known state. ${_error.toString()}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.statusForeground(theme, AppColors.warning),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _FilterBar(
            controller: _searchController,
            issuesOnly: _issuesOnly,
            onQueryChanged: (q) => setState(() => _query = q.trim()),
            onIssuesOnlyChanged: (v) => setState(() => _issuesOnly = v),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          if (nodes.isEmpty)
            const EmptyStateCard(
              icon: Icons.account_tree_outlined,
              title: 'No Resources',
              subtitle: 'ArgoCD returned an empty resource tree.',
            )
          else if (visible.isEmpty)
            EmptyStateCard(
              icon: Icons.search_off_rounded,
              title: 'No Matches',
              subtitle: _issuesOnly && _query.isEmpty
                  ? 'Every resource is healthy and in sync.'
                  : 'No resources match the current filter.',
            )
          else
            for (final section in visible) ...<Widget>[
              _SectionView(
                section: section,
                collapsed: _collapsed.contains(section.title),
                onToggle: () => setState(() {
                  if (!_collapsed.remove(section.title)) {
                    _collapsed.add(section.title);
                  }
                }),
                rowBuilder: _buildRoot,
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
        ],
      ),
    );
  }

  bool _matches(MapNode root) {
    if (_issuesOnly &&
        !root.subtree.any(hasHealthIssue) &&
        !_anyOutOfSync(root)) {
      return false;
    }
    if (_query.isEmpty) {
      return true;
    }
    final q = _query.toLowerCase();
    return root.subtree.any(
      (n) =>
          n.name.toLowerCase().contains(q) || n.kind.toLowerCase().contains(q),
    );
  }

  bool _anyOutOfSync(MapNode node) =>
      node.isOutOfSync || node.children.any(_anyOutOfSync);

  Widget _buildRoot(MapNode root) {
    return _MapNodeView(
      mapNode: root,
      depth: 0,
      showOlderFor: _showOlder,
      onToggleOlder: (uid) => setState(() {
        if (!_showOlder.remove(uid)) {
          _showOlder.add(uid);
        }
      }),
      onOpenResource: _openResource,
      onOpenPod: _openPod,
    );
  }

  void _openResource(ArgoResourceNode node) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManifestViewerScreen(
          controller: widget.controller,
          applicationName: widget.applicationName,
          namespace: node.namespace,
          resourceName: node.name,
          kind: node.kind,
          group: node.group,
          version: node.version,
        ),
      ),
    );
  }

  void _openPod(ArgoResourceNode pod) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PodScreen(
          controller: widget.controller,
          applicationName: widget.applicationName,
          pod: pod,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _AppStatusHeader extends StatelessWidget {
  const _AppStatusHeader({required this.application, required this.nodes});

  final ArgoApplication application;
  final List<ArgoResourceNode> nodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final health = application.healthStatus;
    final sync = application.syncStatus;
    final message = application.healthMessage ?? '';
    final podCount = nodes.where((n) => n.kind == 'Pod').length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              StatusChip(
                label: health,
                color: AppColors.healthColor(health),
                icon: healthStatusIcon(health),
              ),
              StatusChip(
                label: sync,
                color: AppColors.syncColor(sync),
                icon: syncStatusIcon(sync),
              ),
            ],
          ),
          if (message.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '${nodes.length} resources · $podCount '
            '${podCount == 1 ? 'pod' : 'pods'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.tertiaryLabel(theme),
              fontFeatures: AppFonts.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.issuesOnly,
    required this.onQueryChanged,
    required this.onIssuesOnlyChanged,
  });

  final TextEditingController controller;
  final bool issuesOnly;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool> onIssuesOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            textAlignVertical: TextAlignVertical.center,
            onChanged: onQueryChanged,
            decoration: const InputDecoration(
              hintText: 'Filter by name or kind',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              prefixIconConstraints: BoxConstraints(minWidth: 36),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        FilterChip(
          label: const Text('Issues'),
          selected: issuesOnly,
          onSelected: onIssuesOnlyChanged,
          showCheckmark: false,
          avatar: Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: issuesOnly
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.collapsed,
    required this.onToggle,
    required this.rowBuilder,
  });

  final MapSection section;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget Function(MapNode root) rowBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final issues = section.roots
        .expand((r) => r.subtree)
        .where(hasHealthIssue)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: !collapsed,
          child: InkWell(
            onTap: onToggle,
            borderRadius: AppRadius.sm,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
              child: Row(
                children: <Widget>[
                  Text(section.title, style: theme.textTheme.titleLarge),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${section.roots.length}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.tertiaryLabel(theme),
                      fontFeatures: AppFonts.tabularFigures,
                    ),
                  ),
                  if (issues > 0) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    StatusDot(color: AppColors.warning),
                  ],
                  const Spacer(),
                  AnimatedRotation(
                    turns: collapsed ? 0 : 0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!collapsed)
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: AppRadius.md,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < section.roots.length; i++) ...<Widget>[
                  if (i > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: scheme.outlineVariant,
                    ),
                  rowBuilder(section.roots[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

const double _kIndent = 22;

class _MapNodeView extends StatelessWidget {
  const _MapNodeView({
    required this.mapNode,
    required this.depth,
    this.parentName,
    required this.showOlderFor,
    required this.onToggleOlder,
    required this.onOpenResource,
    required this.onOpenPod,
  });

  final MapNode mapNode;
  final int depth;
  final String? parentName;
  final Set<String> showOlderFor;
  final ValueChanged<String> onToggleOlder;
  final ValueChanged<ArgoResourceNode> onOpenResource;
  final ValueChanged<ArgoResourceNode> onOpenPod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final node = mapNode.node;
    final showingOlder = showOlderFor.contains(node.uid);
    final olderCount = mapNode.olderReplicaSets.length;
    final childViews = <Widget>[
      for (final child in mapNode.children)
        _MapNodeView(
          mapNode: child,
          depth: depth + 1,
          parentName: node.name,
          showOlderFor: showOlderFor,
          onToggleOlder: onToggleOlder,
          onOpenResource: onOpenResource,
          onOpenPod: onOpenPod,
        ),
      if (olderCount > 0)
        _OlderReplicaSetsRow(
          count: olderCount,
          expanded: showingOlder,
          depth: depth + 1,
          onTap: () => onToggleOlder(node.uid),
        ),
      if (showingOlder)
        for (final rs in mapNode.olderReplicaSets)
          _MapNodeView(
            mapNode: rs,
            depth: depth + 1,
            parentName: node.name,
            showOlderFor: showOlderFor,
            onToggleOlder: onToggleOlder,
            onOpenResource: onOpenResource,
            onOpenPod: onOpenPod,
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ResourceRow(
          mapNode: mapNode,
          depth: depth,
          parentName: parentName,
          onTap: () => onOpenResource(node),
        ),
        if (mapNode.pods.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16 + (depth + 1) * _kIndent,
              0,
              14,
              12,
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final pod in mapNode.pods)
                  _PodChip(
                    pod: pod,
                    ownerName: node.name,
                    onTap: () => onOpenPod(pod),
                  ),
              ],
            ),
          ),
        if (childViews.isNotEmpty)
          Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: childViews,
                ),
              ),
              // Hairline guide under this resource's glyph, spanning its
              // children.
              Positioned(
                left: 16 + depth * _kIndent + 9,
                top: 0,
                bottom: 12,
                child: Container(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.mapNode,
    required this.depth,
    required this.parentName,
    required this.onTap,
  });

  final MapNode mapNode;
  final int depth;
  final String? parentName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final node = mapNode.node;
    // ArgoCD reports this as e.g. "Rev:10".
    final revision = (node.info['Revision'] ?? '').replaceAll(
      RegExp(r'\D'),
      '',
    );
    final age = shortAge(node.createdAt);
    // Under its Deployment a ReplicaSet reads best as its hash.
    final prefix = parentName == null ? '' : '$parentName-';
    final title =
        node.kind == 'ReplicaSet' &&
            prefix.isNotEmpty &&
            node.name.startsWith(prefix)
        ? node.name.substring(prefix.length)
        : node.name;
    final caption = <String>[
      node.kind,
      if (revision.isNotEmpty) 'rev $revision',
      if (mapNode.pods.isNotEmpty)
        '${mapNode.pods.length} ${mapNode.pods.length == 1 ? 'pod' : 'pods'}',
      if (age.isNotEmpty) age,
    ].join(' · ');
    final showHealth = node.healthStatus != 'Unknown' || node.kind == 'Pod';
    final healthColor = AppColors.healthColor(node.healthStatus);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16 + depth * _kIndent, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                iconForResourceKind(node.kind),
                size: 19,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: depth == 0
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (hasHealthIssue(node) &&
                      node.healthMessage.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      node.healthMessage,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.statusForeground(theme, healthColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            if (mapNode.isOutOfSync)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: mapNode.syncStatus!,
                  child: Icon(
                    syncStatusIcon(mapNode.syncStatus!),
                    size: 16,
                    color: AppColors.statusForeground(
                      theme,
                      AppColors.outOfSync,
                    ),
                  ),
                ),
              ),
            if (showHealth)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Tooltip(
                  message: node.healthStatus,
                  child: Semantics(
                    label: 'Health: ${node.healthStatus}',
                    child: StatusDot(color: healthColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Capsule for a pod: health glyph + the pod's unique suffix (+ restarts).
class _PodChip extends StatelessWidget {
  const _PodChip({
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
    final foreground = AppColors.statusForeground(theme, color);
    final prefix = '$ownerName-';
    final label = pod.name.startsWith(prefix) && pod.name.length > prefix.length
        ? pod.name.substring(prefix.length)
        : pod.name;
    final restarts = int.tryParse(pod.info['Restart Count'] ?? '') ?? 0;

    return Semantics(
      button: true,
      label: 'Pod ${pod.name}, ${podStatusLabel(pod)}',
      child: Tooltip(
        message: '${pod.name}\n${podStatusLabel(pod)}',
        child: Material(
          color: AppColors.statusTint(theme, color),
          borderRadius: AppRadius.pill,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.pill,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    healthStatusIcon(pod.healthStatus),
                    size: 13,
                    color: foreground,
                  ),
                  const SizedBox(width: 5),
                  ExcludeSemantics(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontFamily: AppFonts.mono,
                        fontSize: 12,
                        color: foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (restarts > 0) ...<Widget>[
                    const SizedBox(width: 6),
                    Icon(Icons.replay_rounded, size: 12, color: foreground),
                    const SizedBox(width: 2),
                    ExcludeSemantics(
                      child: Text(
                        '$restarts',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foreground,
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
      ),
    );
  }
}

class _OlderReplicaSetsRow extends StatelessWidget {
  const _OlderReplicaSetsRow({
    required this.count,
    required this.expanded,
    required this.depth,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final int depth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16 + depth * _kIndent, 8, 14, 8),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.layers_outlined,
                size: 19,
                color: AppColors.tertiaryLabel(theme),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  expanded
                      ? 'Hide older ReplicaSets'
                      : '$count older ${count == 1 ? 'ReplicaSet' : 'ReplicaSets'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
                color: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
