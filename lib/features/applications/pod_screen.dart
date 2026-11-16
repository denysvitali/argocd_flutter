import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/core/models/pod_details.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

import 'log_viewer_screen.dart';
import 'manifest_viewer_screen.dart';
import 'pods_screen.dart';

/// Status colour for a single container.
Color containerColor(PodContainer c) {
  switch (c.state) {
    case ContainerRunState.running:
      return c.ready ? AppColors.healthy : AppColors.progressing;
    case ContainerRunState.waiting:
      return c.reason == 'ContainerCreating' || c.reason == 'PodInitializing'
          ? AppColors.progressing
          : AppColors.degraded;
    case ContainerRunState.terminated:
      return c.completedOk ? AppColors.unknown : AppColors.degraded;
    case ContainerRunState.unknown:
      return AppColors.unknown;
  }
}

/// One-line container status: "Running", "Running · not ready",
/// "CrashLoopBackOff · 12 restarts", "Completed", "Error (exit 1)".
String containerStatusLabel(PodContainer c) {
  final base = switch (c.state) {
    ContainerRunState.running => c.ready ? 'Running' : 'Running · not ready',
    ContainerRunState.waiting => c.reason.isNotEmpty ? c.reason : 'Waiting',
    ContainerRunState.terminated =>
      '${c.reason.isNotEmpty ? c.reason : 'Terminated'}'
          '${c.completedOk ? '' : ' (exit ${c.exitCode ?? '?'})'}',
    ContainerRunState.unknown => 'Pending',
  };
  if (c.restartCount == 0) {
    return base;
  }
  return '$base · ${c.restartCount} '
      '${c.restartCount == 1 ? 'restart' : 'restarts'}';
}

/// Pod detail: status, containers (tap for logs), placement and manifest.
class PodScreen extends StatefulWidget {
  const PodScreen({
    super.key,
    required this.controller,
    required this.applicationName,
    required this.pod,
  });

  final AppController controller;
  final String applicationName;
  final ArgoResourceNode pod;

  @override
  State<PodScreen> createState() => _PodScreenState();
}

class _PodScreenState extends State<PodScreen> {
  late Future<PodDetails> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PodDetails> _load() async {
    final payload = await widget.controller.fetchResourceManifest(
      applicationName: widget.applicationName,
      namespace: widget.pod.namespace,
      resourceName: widget.pod.name,
      kind: 'Pod',
      group: widget.pod.group,
      version: widget.pod.version.isEmpty ? 'v1' : widget.pod.version,
    );
    return PodDetails.fromManifestPayload(payload);
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // Rendered by the FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pod = widget.pod;
    return Scaffold(
      appBar: AppBar(title: const Text('Pod')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<PodDetails>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final details = snapshot.data;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.huge,
              ),
              children: <Widget>[
                _PodHeader(pod: pod, details: details),
                const SizedBox(height: AppSpacing.xxxl),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                else if (snapshot.hasError)
                  EmptyStateCard(
                    icon: Icons.inventory_2_outlined,
                    title: "Couldn't Load Containers",
                    subtitle: snapshot.error.toString(),
                    action: FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  )
                else if (details != null) ...<Widget>[
                  if (details.appContainers.isNotEmpty)
                    _ContainerList(
                      header: 'Containers',
                      containers: details.appContainers,
                      onOpen: (c) => _openLogs(context, details, c),
                    ),
                  if (details.initContainers.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxxl),
                    _ContainerList(
                      header: 'Init Containers',
                      containers: details.initContainers,
                      onOpen: (c) => _openLogs(context, details, c),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxxl),
                  _DetailsList(pod: pod, details: details),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                GroupedList(
                  children: <Widget>[
                    GroupedRow(
                      leading: Icon(
                        Icons.description_outlined,
                        size: AppIconSize.md,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: 'Manifest',
                      onTap: () => _openManifest(context),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openLogs(BuildContext context, PodDetails details, PodContainer c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogViewerScreen(
          controller: widget.controller,
          applicationName: widget.applicationName,
          namespace: widget.pod.namespace,
          podName: widget.pod.name,
          containerName: c.name,
          containers: <String>[for (final c in details.containers) c.name],
        ),
      ),
    );
  }

  void _openManifest(BuildContext context) {
    final pod = widget.pod;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ManifestViewerScreen(
          controller: widget.controller,
          applicationName: widget.applicationName,
          namespace: pod.namespace,
          resourceName: pod.name,
          kind: pod.kind,
          group: pod.group,
          version: pod.version,
        ),
      ),
    );
  }
}

class _PodHeader extends StatelessWidget {
  const _PodHeader({required this.pod, required this.details});

  final ArgoResourceNode pod;
  final PodDetails? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.healthColor(pod.healthStatus);
    final restarts =
        details?.restartCount ??
        int.tryParse(pod.info['Restart Count'] ?? '') ??
        0;
    final age = shortAge(pod.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SelectableText(
            pod.name,
            style: theme.textTheme.titleLarge?.copyWith(height: 1.25),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              StatusChip(
                label: podStatusLabel(pod),
                color: color,
                icon: healthStatusIcon(pod.healthStatus),
              ),
              if (restarts > 0)
                StatusChip(
                  label: '$restarts ${restarts == 1 ? 'restart' : 'restarts'}',
                  color: AppColors.warning,
                ),
              if (age.isNotEmpty)
                Text(
                  'Age $age',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (pod.healthMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              pod.healthMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContainerList extends StatelessWidget {
  const _ContainerList({
    required this.header,
    required this.containers,
    required this.onOpen,
  });

  final String header;
  final List<PodContainer> containers;
  final void Function(PodContainer container) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GroupedList(
      header: header,
      footer: 'Tap a container to view its logs.',
      dividerIndent: 36,
      children: <Widget>[
        for (final c in containers)
          InkWell(
            onTap: () => onOpen(c),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
              child: Row(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: StatusDot(color: containerColor(c)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              containerStatusLabel(c),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    c.state == ContainerRunState.running &&
                                        c.ready
                                    ? theme.colorScheme.onSurfaceVariant
                                    : AppColors.statusForeground(
                                        theme,
                                        containerColor(c),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        if (c.image.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            c.image,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: AppFonts.mono,
                              fontSize: 11.5,
                              color: AppColors.tertiaryLabel(theme),
                            ),
                          ),
                        ],
                        if (c.message.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            c.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Icon(
                    Icons.notes_rounded,
                    size: AppIconSize.sm,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Logs',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailsList extends StatelessWidget {
  const _DetailsList({required this.pod, required this.details});

  final ArgoResourceNode pod;
  final PodDetails details;

  @override
  Widget build(BuildContext context) {
    return GroupedList(
      header: 'Details',
      children: <Widget>[
        GroupedRow(title: 'Namespace', value: pod.namespace),
        GroupedRow(title: 'Phase', value: details.phase),
        if (details.nodeName.isNotEmpty)
          GroupedRow(title: 'Node', value: details.nodeName),
        if (details.podIp.isNotEmpty)
          GroupedRow(title: 'Pod IP', value: details.podIp),
        if (details.startTime.isNotEmpty)
          GroupedRow(
            title: 'Started',
            value: formatRelativeTime(details.startTime),
          ),
      ],
    );
  }
}
