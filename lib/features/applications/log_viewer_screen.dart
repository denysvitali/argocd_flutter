import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Console.app-style log viewer for a single pod (optionally a container).
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
  final ScrollController _verticalController = ScrollController();
  bool _wrapLines = true;
  bool _follow = false;

  @override
  void initState() {
    super.initState();
    _future = _loadLogs();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  bool get _hasContainer => widget.containerName?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = _hasContainer
        ? '${widget.podName}/${widget.containerName}'
        : widget.podName;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: (theme.appBarTheme.centerTitle ?? false)
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              widget.namespace,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
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
            icon: const Icon(Icons.copy_all, size: 18),
            label: const Text('Copy'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<String>(
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
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: <Widget>[
                EmptyStateCard(
                  icon: Icons.terminal_rounded,
                  title: "Couldn't Load Logs",
                  subtitle: snapshot.error.toString(),
                  action: FilledButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          final logs = snapshot.requireData;
          final lines = logs.isEmpty ? const <String>[] : logs.split('\n');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _LogToolbar(
                lineCount: lines.length,
                applicationName: widget.applicationName,
                containerName: _hasContainer ? widget.containerName : null,
                wrapLines: _wrapLines,
                follow: _follow,
                onToggleWrap: () => setState(() => _wrapLines = !_wrapLines),
                onToggleFollow: _toggleFollow,
              ),
              Expanded(
                child: logs.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: const <Widget>[
                          EmptyStateCard(
                            icon: Icons.notes_rounded,
                            title: 'No Output',
                            subtitle: 'No logs returned.',
                          ),
                        ],
                      )
                    : _buildConsole(theme, lines),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConsole(ThemeData theme, List<String> lines) {
    final scheme = theme.colorScheme;
    final baseStyle = TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: 12.5,
      height: 1.55,
      color: scheme.onSurface,
    );

    final text = SelectableText.rich(
      TextSpan(
        style: baseStyle,
        children: <InlineSpan>[
          for (var i = 0; i < lines.length; i++) ...<InlineSpan>[
            ..._spansForLine(theme, lines[i]),
            if (i < lines.length - 1) const TextSpan(text: '\n'),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.md,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.md,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const padding = EdgeInsets.fromLTRB(14, 12, 14, 12);
              final innerWidth = constraints.maxWidth - padding.horizontal;
              return Scrollbar(
                controller: _verticalController,
                child: SingleChildScrollView(
                  controller: _verticalController,
                  padding: padding,
                  child: _wrapLines
                      ? SizedBox(width: innerWidth, child: text)
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: innerWidth),
                            child: text,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Splits a log line into a muted timestamp, an optional colored level and
  /// the message body.
  List<InlineSpan> _spansForLine(ThemeData theme, String line) {
    final tertiary = AppColors.tertiaryLabel(theme);
    final match = _timestampPattern.firstMatch(line);
    final spans = <InlineSpan>[];
    var rest = line;
    if (match != null) {
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: tertiary),
        ),
      );
      rest = line.substring(match.end);
    }

    final levelMatch = _levelPattern.firstMatch(rest);
    if (levelMatch != null) {
      final leading = rest.substring(0, levelMatch.start);
      final level = levelMatch.group(0)!;
      final levelColor = _levelColor(theme, level);
      if (leading.isNotEmpty) {
        spans.add(TextSpan(text: leading));
      }
      spans.add(
        TextSpan(
          text: level,
          style: TextStyle(color: levelColor, fontWeight: FontWeight.w500),
        ),
      );
      rest = rest.substring(levelMatch.end);
    }

    spans.add(TextSpan(text: rest));
    return spans;
  }

  Color _levelColor(ThemeData theme, String level) {
    final upper = level.toUpperCase();
    if (upper.startsWith('ERR') ||
        upper.startsWith('FATAL') ||
        upper.startsWith('PANIC')) {
      return AppColors.statusForeground(theme, AppColors.degraded);
    }
    if (upper.startsWith('WARN')) {
      return AppColors.statusForeground(theme, AppColors.outOfSync);
    }
    if (upper.startsWith('DEBUG') || upper.startsWith('TRACE')) {
      return AppColors.tertiaryLabel(theme);
    }
    return theme.colorScheme.onSurfaceVariant;
  }

  Future<String> _loadLogs() async {
    final logs = await widget.controller.fetchResourceLogs(
      applicationName: widget.applicationName,
      namespace: widget.namespace,
      podName: widget.podName,
      containerName: widget.containerName,
    );
    _lastLoadedLogs = logs;
    if (_follow) {
      _scheduleScrollToEnd();
    }
    return logs;
  }

  void _refresh() {
    setState(() {
      _future = _loadLogs();
    });
  }

  void _toggleFollow() {
    setState(() => _follow = !_follow);
    if (_follow) {
      _scheduleScrollToEnd();
    }
  }

  void _scheduleScrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalController.hasClients) {
        return;
      }
      _verticalController.animateTo(
        _verticalController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
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

final RegExp _timestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?',
);

final RegExp _levelPattern = RegExp(
  r'^\s*\[?(?:TRACE|DEBUG|INFO|WARN(?:ING)?|ERROR|ERR|FATAL|PANIC)\]?(?=\s|:|$)',
  caseSensitive: false,
);

/// Quiet metadata strip above the console: line count + app on the left,
/// container capsule and view toggles on the right.
class _LogToolbar extends StatelessWidget {
  const _LogToolbar({
    required this.lineCount,
    required this.applicationName,
    required this.containerName,
    required this.wrapLines,
    required this.follow,
    required this.onToggleWrap,
    required this.onToggleFollow,
  });

  final int lineCount;
  final String applicationName;
  final String? containerName;
  final bool wrapLines;
  final bool follow;
  final VoidCallback onToggleWrap;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: AppFonts.tabularFigures,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 8, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: '$lineCount lines'),
                  TextSpan(
                    text: '  ·  ',
                    style: TextStyle(color: AppColors.tertiaryLabel(theme)),
                  ),
                  TextSpan(text: applicationName),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
          ),
          if (containerName != null) ...<Widget>[
            const SizedBox(width: 8),
            _ContainerCapsule(name: containerName!),
            const SizedBox(width: 4),
          ],
          _ToolbarToggle(
            tooltip: follow ? 'Stop following' : 'Follow output',
            icon: Icons.vertical_align_bottom_rounded,
            selected: follow,
            onPressed: onToggleFollow,
          ),
          _ToolbarToggle(
            tooltip: wrapLines ? 'Disable line wrap' : 'Wrap lines',
            icon: Icons.wrap_text_rounded,
            selected: wrapLines,
            onPressed: onToggleWrap,
          ),
        ],
      ),
    );
  }
}

class _ContainerCapsule extends StatelessWidget {
  const _ContainerCapsule({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Container $name',
      child: Container(
        constraints: const BoxConstraints(maxWidth: 140),
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: AppColors.fill(theme),
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              size: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarToggle extends StatelessWidget {
  const _ToolbarToggle({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      isSelected: selected,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      color: theme.colorScheme.onSurfaceVariant,
      selectedIcon: Icon(icon, color: theme.colorScheme.primary),
      onPressed: onPressed,
      icon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
