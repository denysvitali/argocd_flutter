import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

import 'pod_screen.dart';

/// A ReplicaSet (or other direct owner) and the pods it controls.
class PodGroup {
  const PodGroup({required this.owner, required this.pods});

  /// Direct owner of the pods; null for orphan pods.
  final ArgoResourceNode? owner;
  final List<ArgoResourceNode> pods;
}

/// A top-level workload (Deployment, StatefulSet, ...) with its pod groups.
class WorkloadGroup {
  const WorkloadGroup({required this.workload, required this.groups});

  /// Null for pods that have no owner in the tree.
  final ArgoResourceNode? workload;
  final List<PodGroup> groups;

  int get podCount =>
      groups.fold<int>(0, (int sum, PodGroup g) => sum + g.pods.length);
}

/// Groups pods by direct owner (e.g. ReplicaSet) and then by the owner's
/// owner (e.g. Deployment). Pure function so it can be unit tested.
List<WorkloadGroup> groupPodsByWorkload(List<ArgoResourceNode> nodes) {
  final byUid = <String, ArgoResourceNode>{
    for (final n in nodes)
      if (n.uid.isNotEmpty) n.uid: n,
  };
  ArgoResourceNode? parentOf(ArgoResourceNode n) {
    for (final uid in n.parentUids) {
      final parent = byUid[uid];
      if (parent != null) {
        return parent;
      }
    }
    return null;
  }

  // workload key -> owner key -> pods
  final workloads = <String, ArgoResourceNode?>{};
  final owners = <String, ArgoResourceNode?>{};
  final tree = <String, Map<String, List<ArgoResourceNode>>>{};

  for (final pod in nodes.where((n) => n.kind == 'Pod')) {
    final owner = parentOf(pod);
    final workload = owner == null ? null : parentOf(owner);
    // Pods owned directly by a StatefulSet/DaemonSet/Job: owner is the
    // workload and there is no intermediate group.
    final top = workload ?? owner;
    final mid = workload == null ? null : owner;
    final topKey = top?.uid ?? '';
    final midKey = mid?.uid ?? '';
    workloads[topKey] = top;
    owners[midKey] = mid;
    tree
        .putIfAbsent(topKey, () => <String, List<ArgoResourceNode>>{})
        .putIfAbsent(midKey, () => <ArgoResourceNode>[])
        .add(pod);
  }

  int byName(ArgoResourceNode? a, ArgoResourceNode? b) =>
      (a?.name ?? '~').compareTo(b?.name ?? '~');

  final result = <WorkloadGroup>[];
  for (final entry in tree.entries) {
    final groups = <PodGroup>[
      for (final e in entry.value.entries)
        PodGroup(
          owner: owners[e.key],
          pods: e.value..sort((a, b) => a.name.compareTo(b.name)),
        ),
    ]..sort((a, b) => byName(a.owner, b.owner));
    result.add(WorkloadGroup(workload: workloads[entry.key], groups: groups));
  }
  result.sort((a, b) => byName(a.workload, b.workload));
  return result;
}

/// Short pod-facing status: the kubelet reason when ArgoCD reports one
/// (Running, CrashLoopBackOff, Completed, ...) else the health status.
String podStatusLabel(ArgoResourceNode pod) {
  final reason = pod.info['Status Reason'] ?? '';
  return reason.isNotEmpty ? reason : pod.healthStatus;
}

/// kubectl-style age: 45s, 12m, 5h, 3d.
String shortAge(String timestamp) {
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) {
    return '';
  }
  final diff = appClock().difference(parsed);
  if (diff.isNegative) {
    return '';
  }
  if (diff.inMinutes < 1) {
    return '${diff.inSeconds}s';
  }
  if (diff.inHours < 1) {
    return '${diff.inMinutes}m';
  }
  if (diff.inDays < 1) {
    return '${diff.inHours}h';
  }
  return '${diff.inDays}d';
}

/// Strips the owner prefix kubectl-style so "web-7d9f-abcde" under
/// ReplicaSet "web-7d9f" reads as the hash ArgoCD/kubectl users scan for.
String replicaSetRevision(
  ArgoResourceNode replicaSet,
  ArgoResourceNode? deployment,
) {
  final prefix = deployment == null ? '' : '${deployment.name}-';
  return prefix.isNotEmpty && replicaSet.name.startsWith(prefix)
      ? replicaSet.name.substring(prefix.length)
      : replicaSet.name;
}

class PodsScreen extends StatefulWidget {
  const PodsScreen({
    super.key,
    required this.controller,
    required this.applicationName,
  });

  final AppController controller;
  final String applicationName;

  @override
  State<PodsScreen> createState() => _PodsScreenState();
}

class _PodsScreenState extends State<PodsScreen> {
  late Future<List<ArgoResourceNode>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.loadResourceTree(widget.applicationName);
  }

  Future<void> _reload() async {
    final future = widget.controller.loadResourceTree(widget.applicationName);
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // Rendered by the FutureBuilder.
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
            const Text('Pods'),
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
      body: FutureBuilder<List<ArgoResourceNode>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            );
          }
          if (snapshot.hasError) {
            return ErrorRetryWidget(
              message: snapshot.error.toString(),
              onRetry: _reload,
            );
          }
          final nodes = snapshot.data ?? const <ArgoResourceNode>[];
          final workloads = groupPodsByWorkload(nodes);
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.huge,
              ),
              children: <Widget>[
                if (workloads.isEmpty)
                  const EmptyStateCard(
                    icon: Icons.view_in_ar_outlined,
                    title: 'No Pods',
                    subtitle: 'This application has no running pods.',
                  )
                else ...<Widget>[
                  _PodSummary(
                    pods: nodes.where((n) => n.kind == 'Pod').toList(),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  for (final workload in workloads) ...<Widget>[
                    _WorkloadSection(
                      group: workload,
                      onOpenPod: (pod) => _openPod(context, pod),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _openPod(BuildContext context, ArgoResourceNode pod) {
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

/// "3 pods" with a health capsule bar and per-status counts.
class _PodSummary extends StatelessWidget {
  const _PodSummary({required this.pods});

  final List<ArgoResourceNode> pods;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final pod in pods) {
      counts.update(pod.healthStatus, (v) => v + 1, ifAbsent: () => 1);
    }
    final ordered = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '${pods.length}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppFonts.tabularFigures,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                pods.length == 1 ? 'pod' : 'pods',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StatusSegmentBar(
            segments: <StatusSegment>[
              for (final e in ordered)
                StatusSegment(
                  count: e.value,
                  color: AppColors.healthColor(e.key),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final e in ordered)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    StatusDot(color: AppColors.healthColor(e.key)),
                    const SizedBox(width: 6),
                    Text(
                      '${e.value} ${e.key}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: AppFonts.tabularFigures,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkloadSection extends StatelessWidget {
  const _WorkloadSection({required this.group, required this.onOpenPod});

  final WorkloadGroup group;
  final void Function(ArgoResourceNode pod) onOpenPod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workload = group.workload;
    final pods = group.groups.expand((g) => g.pods).toList();
    final healthy = pods.where((p) => p.healthStatus == 'Healthy').length;
    final multipleRevisions =
        group.groups.where((g) => g.owner != null).length > 1;
    final singleOwner = group.groups.length == 1
        ? group.groups.single.owner
        : null;

    final subtitleParts = <String>[
      workload?.kind ?? 'No controller',
      if (singleOwner != null)
        '${singleOwner.kind} ${replicaSetRevision(singleOwner, workload)}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      workload?.name ?? 'Standalone Pods',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$healthy/${pods.length} healthy',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: AppFonts.tabularFigures,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < group.groups.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          if (multipleRevisions)
            _RevisionHeader(group: group.groups[i], workload: workload),
          GroupedList(
            dividerIndent: 36,
            children: <Widget>[
              for (final pod in group.groups[i].pods)
                _PodRow(pod: pod, onTap: () => onOpenPod(pod)),
            ],
          ),
        ],
      ],
    );
  }
}

class _RevisionHeader extends StatelessWidget {
  const _RevisionHeader({required this.group, required this.workload});

  final PodGroup group;
  final ArgoResourceNode? workload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owner = group.owner;
    final label = owner == null
        ? 'Unowned'
        : '${owner.kind} ${replicaSetRevision(owner, workload)}';
    final age = owner == null ? '' : shortAge(owner.createdAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
      child: Text(
        <String>[
          label,
          '${group.pods.length} ${group.pods.length == 1 ? 'pod' : 'pods'}',
          if (age.isNotEmpty) age,
        ].join(' · '),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PodRow extends StatelessWidget {
  const _PodRow({required this.pod, required this.onTap});

  final ArgoResourceNode pod;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = pod.info['Containers'] ?? '';
    final restarts = int.tryParse(pod.info['Restart Count'] ?? '') ?? 0;
    final age = shortAge(pod.createdAt);
    final parts = <String>[
      podStatusLabel(pod),
      if (ready.isNotEmpty) '$ready ready',
      if (restarts > 0) '$restarts ${restarts == 1 ? 'restart' : 'restarts'}',
      if (age.isNotEmpty) age,
    ];
    return GroupedRow(
      leading: Padding(
        padding: const EdgeInsets.only(left: 2, right: 2),
        child: StatusDot(color: AppColors.healthColor(pod.healthStatus)),
      ),
      title: pod.name,
      subtitle: parts.join(' · '),
      onTap: onTap,
    );
  }
}
