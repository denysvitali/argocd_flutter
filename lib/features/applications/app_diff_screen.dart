import 'dart:convert';

import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/utils/diff.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

class AppDiffScreen extends StatefulWidget {
  const AppDiffScreen({
    super.key,
    required this.controller,
    required this.applicationName,
  });

  final AppController controller;
  final String applicationName;

  @override
  State<AppDiffScreen> createState() => _AppDiffScreenState();
}

class _AppDiffScreenState extends State<AppDiffScreen> {
  late Future<List<ManagedResource>> _future;
  bool _hideManagedFields = true;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.fetchManagedResources(
      widget.applicationName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Diff: ${widget.applicationName}',
          style: theme.textTheme.titleMedium,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: _hideManagedFields
                ? 'Show managed fields'
                : 'Hide managed fields',
            icon: Icon(
              _hideManagedFields ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                _hideManagedFields = !_hideManagedFields;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _future = widget.controller.fetchManagedResources(
                  widget.applicationName,
                );
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ManagedResource>>(
        future: _future,
        builder: (context, snapshot) {
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
                    Text(snapshot.error.toString()),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _future = widget.controller.fetchManagedResources(
                            widget.applicationName,
                          );
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final resources = snapshot.requireData;
          final diffResources =
              resources.where((r) => r.hasDiff).toList();

          if (diffResources.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: EmptyStateCard(
                  icon: Icons.check_circle_outline,
                  title: 'In Sync',
                  subtitle: 'All resources match their desired state.',
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: diffResources.length,
            itemBuilder: (context, index) {
              return _ResourceDiffCard(
                resource: diffResources[index],
                hideManagedFields: _hideManagedFields,
              );
            },
          );
        },
      ),
    );
  }
}

class _ResourceDiffCard extends StatelessWidget {
  const _ResourceDiffCard({
    required this.resource,
    required this.hideManagedFields,
  });

  final ManagedResource resource;
  final bool hideManagedFields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kindColor = colorForResourceKind(resource.kind);
    final kindIcon = iconForResourceKind(resource.kind);
    final targetYaml = _formatManifest(
      resource.targetState!,
      hideManagedFields,
    );
    final liveYaml = _formatManifest(
      resource.liveState!,
      hideManagedFields,
    );
    final targetLines = _trimTrailing(targetYaml.split('\n'));
    final liveLines = _trimTrailing(liveYaml.split('\n'));
    final sections = computeDiff(targetLines, liveLines);

    // Count stats from all hunk lines.
    var added = 0;
    var removed = 0;
    for (final section in sections) {
      for (final line in section.lines) {
        if (line.kind == DiffLineKind.added) added++;
        if (line.kind == DiffLineKind.removed) removed++;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: theme.dividerColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              color: kindColor.withValues(alpha: 0.06),
              child: Row(
                children: <Widget>[
                  Icon(kindIcon, color: kindColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    resource.kind,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: kindColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${resource.namespace}/${resource.name}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _DiffStats(added: added, removed: removed),
                ],
              ),
            ),
            Container(
              color: theme.colorScheme.surfaceContainerLowest,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final section in sections)
                      if (section.isCollapsed)
                        _CollapsedSection(count: section.collapsedCount)
                      else
                        for (final line in section.lines)
                          _DiffLineWidget(line: line),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffStats extends StatelessWidget {
  const _DiffStats({required this.added, required this.removed});

  final int added;
  final int removed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (added > 0)
          Text(
            '+$added',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (added > 0 && removed > 0) const SizedBox(width: 6),
        if (removed > 0)
          Text(
            '-$removed',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.coral,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _CollapsedSection extends StatelessWidget {
  const _CollapsedSection({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 2000,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Text(
        '\u2022\u2022\u2022 $count unchanged lines \u2022\u2022\u2022',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _DiffLineWidget extends StatelessWidget {
  const _DiffLineWidget({required this.line});

  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color backgroundColor;
    final Color textColor;

    switch (line.kind) {
      case DiffLineKind.added:
        backgroundColor = AppColors.teal.withValues(alpha: 0.10);
        textColor = AppColors.teal;
      case DiffLineKind.removed:
        backgroundColor = AppColors.coral.withValues(alpha: 0.10);
        textColor = AppColors.coral;
      case DiffLineKind.unchanged:
        backgroundColor = Colors.transparent;
        textColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return Container(
      width: 2000,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Text(
        '${line.prefix} ${line.text}',
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: textColor,
          height: 1.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatManifest(String jsonString, bool hideManagedFields) {
  try {
    final parsed = jsonDecode(jsonString);
    if (parsed is Map<String, dynamic>) {
      final cleaned =
          hideManagedFields ? _stripServerFields(parsed) : parsed;
      return jsonToYaml(cleaned);
    }
  } catch (_) {
    // Not valid JSON — return as-is.
  }
  return jsonString;
}

Map<String, dynamic> _stripServerFields(Map<String, dynamic> obj) {
  final result = Map<String, dynamic>.of(obj)..remove('status');
  final metadata = result['metadata'];
  if (metadata is Map<String, dynamic> &&
      metadata.containsKey('managedFields')) {
    result['metadata'] =
        Map<String, dynamic>.of(metadata)..remove('managedFields');
  }
  return result;
}

List<String> _trimTrailing(List<String> lines) {
  final result = List<String>.of(lines);
  while (result.isNotEmpty && result.last.trim().isEmpty) {
    result.removeLast();
  }
  return result;
}
