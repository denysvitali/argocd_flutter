import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/error_retry_widget.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

import 'log_viewer_screen.dart';

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
    _load();
  }

  void _load() {
    _future = widget.controller.loadResourceTree(widget.applicationName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pods'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_load),
          ),
        ],
      ),
      body: FutureBuilder<List<ArgoResourceNode>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorRetryWidget(
              message: snapshot.error.toString(),
              onRetry: () => setState(_load),
            );
          }
          final groups = groupPodsByWorkload(snapshot.data ?? const []);
          if (groups.isEmpty) {
            return const Center(child: Text('No pods in this application'));
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              for (final g in groups) ...<Widget>[
                _WorkloadSection(
                  group: g,
                  onOpenLogs: (pod) => _openLogs(context, pod),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openLogs(BuildContext context, ArgoResourceNode pod) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogViewerScreen(
          controller: widget.controller,
          applicationName: widget.applicationName,
          namespace: pod.namespace,
          podName: pod.name,
        ),
      ),
    );
  }
}

class _WorkloadSection extends StatelessWidget {
  const _WorkloadSection({required this.group, required this.onOpenLogs});

  final WorkloadGroup group;
  final void Function(ArgoResourceNode pod) onOpenLogs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = group.workload;
    final title = w == null ? 'Standalone pods' : '${w.kind}  ${w.name}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '$title · ${group.podCount}',
        ),
        for (final g in group.groups) ...<Widget>[
          GroupedList(
            header: g.owner == null
                ? null
                : '${g.owner!.kind} ${g.owner!.name}',
            children: <Widget>[
              for (final pod in g.pods)
                GroupedRow(
                  leading: StatusDot(
                    color: AppColors.healthColor(pod.healthStatus),
                  ),
                  title: pod.name,
                  subtitle: pod.healthMessage.isEmpty
                      ? pod.healthStatus
                      : '${pod.healthStatus} · ${pod.healthMessage}',
                  trailing: Icon(
                    Icons.article_outlined,
                    size: AppIconSize.md,
                    color: theme.colorScheme.primary,
                  ),
                  onTap: () => onOpenLogs(pod),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}
