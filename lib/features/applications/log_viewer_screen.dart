import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';

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
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _future = _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.pixels >= position.maxScrollExtent - 80;
    if (_showScrollToBottom == atBottom) {
      setState(() {
        _showScrollToBottom = !atBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? colorScheme.surfaceContainerHighest : colorScheme.surface;
    final logColor = isDark ? AppColors.teal : colorScheme.primary;
    final title =
        widget.containerName == null || widget.containerName!.isEmpty
            ? widget.podName
            : '${widget.podName}/${widget.containerName}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
      floatingActionButton: _showScrollToBottom
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              tooltip: 'Scroll to bottom',
              child: const Icon(Icons.keyboard_arrow_down),
            )
          : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: backgroundColor,
        child: FutureBuilder<String>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colorScheme.error.withValues(alpha: AppOpacity.prominent),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Failed to load logs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        snapshot.error.toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final logs = snapshot.requireData;
            if (logs.isEmpty) {
              return Center(
                child: Text(
                  'No logs returned.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            final lines = logs.split('\n');
            final lineNumberWidth = '${lines.length}'.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildPodInfoHeader(theme, colorScheme, isDark),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    itemCount: lines.length,
                    itemBuilder: (context, i) {
                      return _LogLine(
                        key: ValueKey<int>(i),
                        lineNumber: i + 1,
                        lineNumberWidth: lineNumberWidth,
                        text: lines[i],
                        logColor: logColor,
                        theme: theme,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPodInfoHeader(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final headerColor =
        isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: AppOpacity.opaque)
            : colorScheme.surfaceContainerHighest.withValues(alpha: AppOpacity.intense);
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: 10),
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.terminal, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <TextSpan>[
                  TextSpan(
                    text: 'pod/',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextSpan(
                    text: widget.podName,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.containerName != null &&
                      widget.containerName!.isNotEmpty) ...<TextSpan>[
                    TextSpan(
                      text: '  container/',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: widget.containerName,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: AppOpacity.soft),
              borderRadius: AppRadius.sm,
            ),
            child: Text(
              widget.namespace,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

class _LogLine extends StatelessWidget {
  const _LogLine({
    super.key,
    required this.lineNumber,
    required this.lineNumberWidth,
    required this.text,
    required this.logColor,
    required this.theme,
  });

  final int lineNumber;
  final int lineNumberWidth;
  final String text;
  final Color logColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final gutterColor =
        isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerHighest.withValues(alpha: AppOpacity.dense);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 16.0 + lineNumberWidth * 8.5,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 1),
          decoration: BoxDecoration(
            color: gutterColor,
            border: Border(right: BorderSide(color: AppColors.outline(theme))),
          ),
          child: Text(
            '$lineNumber',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withValues(alpha: AppOpacity.dense),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: SelectableText(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: logColor,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
