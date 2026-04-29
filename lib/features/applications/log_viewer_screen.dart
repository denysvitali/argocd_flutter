import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({
    super.key,
    required this.controller,
    required this.applicationName,
    required this.namespace,
    required this.podName,
    this.containerName,
  });

  final AppController controller;
  final String applicationName;
  final String namespace;
  final String podName;
  final String? containerName;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  late Future<String> _future;
  String? _lastLoadedLogs;

  @override
  void initState() {
    super.initState();
    _future = _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final logColor = isDark ? AppColors.teal : colorScheme.primary;
    final title = widget.containerName == null || widget.containerName!.isEmpty
        ? widget.podName
        : '${widget.podName}/${widget.containerName}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              widget.namespace,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
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
          TextButton.icon(
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy_all),
            label: const Text('Copy'),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.terminal_rounded,
                      size: 48,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
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

          final logs = snapshot.requireData;
          final lineCount = logs.isEmpty ? 0 : logs.split('\n').length;
          final shownLogs = logs.isEmpty ? 'No logs returned.' : logs;

          return Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: isDark ? 0.5 : 0.8,
                  ),
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _LogMetaChip(icon: Icons.notes, label: '$lineCount lines'),
                    _LogMetaChip(
                      icon: Icons.apps_rounded,
                      label: widget.applicationName,
                    ),
                    if (widget.containerName?.isNotEmpty ?? false)
                      _LogMetaChip(
                        icon: Icons.inventory_2_outlined,
                        label: widget.containerName!,
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: isDark
                      ? colorScheme.surfaceContainerLowest
                      : colorScheme.surface,
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.22)
                              : colorScheme.surfaceContainerLowest,
                          borderRadius: AppRadius.base,
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(14),
                            child: SelectableText(
                              shownLogs,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: logColor,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _loadLogs() async {
    final logs = await widget.controller.fetchResourceLogs(
      applicationName: widget.applicationName,
      namespace: widget.namespace,
      podName: widget.podName,
      containerName: widget.containerName,
    );
    _lastLoadedLogs = logs;
    return logs;
  }

  void _refresh() {
    setState(() {
      _future = _loadLogs();
    });
  }

  Future<void> _copyLogs() async {
    final logs = _lastLoadedLogs;
    if (logs == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logs are still loading.')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: logs));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied.')));
  }
}

class _LogMetaChip extends StatelessWidget {
  const _LogMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.pill,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
