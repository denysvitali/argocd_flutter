import 'dart:async';

import 'package:argocd_flutter/core/models/pod_details.dart';
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
    this.containers = const <String>[],
    this.followInterval = const Duration(seconds: 3),
  });

  final AppController controller;
  final String applicationName;
  final String namespace;
  final String podName;
  final String? containerName;

  /// All containers of the pod; when more than one, the toolbar offers a
  /// switcher. Discovered automatically if ArgoCD asks for a container.
  final List<String> containers;

  /// How often the tail is re-fetched while following.
  final Duration followInterval;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen>
    with WidgetsBindingObserver {
  /// Distance from the bottom within which the view counts as "at the end"
  /// and keeps sticking to new output.
  static const double _stickThreshold = 48;

  final ScrollController _verticalController = ScrollController();
  bool _wrapLines = true;
  bool _follow = true;
  String? _container;
  List<String> _containers = const <String>[];

  String? _logs;
  Object? _error;
  bool _loading = true;

  /// Last background poll failed; existing output stays on screen.
  bool _pollFailed = false;

  /// New output arrived while the user was scrolled up.
  bool _hasUnseen = false;

  bool _inForeground = true;
  Timer? _pollTimer;

  /// Bumped on every user-initiated load so stale responses are dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _container = widget.containerName;
    _containers = widget.containers;
    _verticalController.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _verticalController.dispose();
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
      _poll();
    } else {
      _pollTimer?.cancel();
    }
  }

  bool get _hasContainer => _container?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = widget.podName;

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
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final logs = _logs;
    if (logs == null) {
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
            icon: Icons.terminal_rounded,
            title: "Couldn't Load Logs",
            subtitle: _error.toString(),
            action: FilledButton(
              onPressed: _reload,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final lines = logs.isEmpty ? const <String>[] : logs.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LogToolbar(
          lineCount: lines.length,
          applicationName: widget.applicationName,
          containerName: _hasContainer ? _container : null,
          containers: _containers,
          onSelectContainer: _selectContainer,
          wrapLines: _wrapLines,
          follow: _follow,
          pollFailed: _pollFailed,
          onToggleWrap: () => setState(() => _wrapLines = !_wrapLines),
          onToggleFollow: _toggleFollow,
        ),
        Expanded(
          child: logs.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: <Widget>[
                    EmptyStateCard(
                      icon: Icons.notes_rounded,
                      title: 'No Output',
                      subtitle: _follow
                          ? 'No logs returned. Waiting for new output…'
                          : 'No logs returned.',
                    ),
                  ],
                )
              : Stack(
                  children: <Widget>[
                    Positioned.fill(child: _buildConsole(theme, lines)),
                    if (_hasUnseen)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 28,
                        child: Center(
                          child: _JumpToLatestButton(onPressed: _jumpToEnd),
                        ),
                      ),
                  ],
                ),
        ),
      ],
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

  Future<String> _fetch() async {
    var logs = await widget.controller.fetchResourceLogs(
      applicationName: widget.applicationName,
      namespace: widget.namespace,
      podName: widget.podName,
      containerName: _container,
    );
    // Multi-container pods need an explicit container; ArgoCD answers with
    // an error string as log content. Pick the first one and retry.
    final discovered = _hasContainer ? null : containersFromLogError(logs);
    if (discovered != null && discovered.isNotEmpty) {
      final container = discovered.first;
      logs = await widget.controller.fetchResourceLogs(
        applicationName: widget.applicationName,
        namespace: widget.namespace,
        podName: widget.podName,
        containerName: container,
      );
      _container = container;
      if (_containers.isEmpty) {
        _containers = discovered;
      }
    }
    return logs;
  }

  /// Foreground load: shows the spinner / error state.
  Future<void> _reload() async {
    _pollTimer?.cancel();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _logs = null;
      _error = null;
      _pollFailed = false;
      _hasUnseen = false;
    });
    try {
      final logs = await _fetch();
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _logs = logs;
        _loading = false;
      });
      _scrollToEnd(animate: false);
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
    _schedulePoll();
  }

  /// Background refresh while following: keeps current output on failure.
  Future<void> _poll() async {
    _pollTimer?.cancel();
    if (!mounted || !_follow || !_inForeground || _logs == null) {
      return;
    }
    final generation = _generation;
    try {
      final logs = await _fetch();
      if (!mounted || generation != _generation) {
        return;
      }
      final changed = logs != _logs;
      final atEnd = _isAtEnd;
      setState(() {
        _pollFailed = false;
        if (changed) {
          _logs = logs;
          if (!atEnd) {
            _hasUnseen = true;
          }
        }
      });
      if (changed && atEnd) {
        _scrollToEnd();
      }
    } catch (_) {
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() => _pollFailed = true);
    }
    _schedulePoll();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (!mounted || !_follow || !_inForeground || _logs == null) {
      return;
    }
    _pollTimer = Timer(widget.followInterval, _poll);
  }

  void _selectContainer(String name) {
    if (name == _container) {
      return;
    }
    _container = name;
    _reload();
  }

  void _refresh() => _reload();

  void _toggleFollow() {
    setState(() => _follow = !_follow);
    if (_follow) {
      _jumpToEnd();
      _poll();
    } else {
      _pollTimer?.cancel();
    }
  }

  bool get _isAtEnd {
    if (!_verticalController.hasClients) {
      return true;
    }
    final position = _verticalController.position;
    return position.maxScrollExtent - position.pixels <= _stickThreshold;
  }

  void _onScroll() {
    if (_hasUnseen && _isAtEnd) {
      setState(() => _hasUnseen = false);
    }
  }

  void _jumpToEnd() {
    setState(() => _hasUnseen = false);
    _scrollToEnd();
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_verticalController.hasClients) {
        return;
      }
      final end = _verticalController.position.maxScrollExtent;
      if (animate) {
        _verticalController.animateTo(
          end,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _verticalController.jumpTo(end);
      }
    });
  }

  Future<void> _copyLogs() async {
    final logs = _logs;
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
    required this.containers,
    required this.onSelectContainer,
    required this.wrapLines,
    required this.follow,
    required this.pollFailed,
    required this.onToggleWrap,
    required this.onToggleFollow,
  });

  final int lineCount;
  final String applicationName;
  final String? containerName;
  final List<String> containers;
  final ValueChanged<String> onSelectContainer;
  final bool wrapLines;
  final bool follow;
  final bool pollFailed;
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
            if (containers.length > 1)
              PopupMenuButton<String>(
                tooltip: 'Switch container',
                initialValue: containerName,
                onSelected: onSelectContainer,
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  for (final name in containers)
                    CheckedPopupMenuItem<String>(
                      value: name,
                      checked: name == containerName,
                      child: Text(name),
                    ),
                ],
                child: _ContainerCapsule(
                  name: containerName!,
                  showChevron: true,
                ),
              )
            else
              _ContainerCapsule(name: containerName!),
            const SizedBox(width: 4),
          ],
          _LiveToggle(
            follow: follow,
            pollFailed: pollFailed,
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
  const _ContainerCapsule({required this.name, this.showChevron = false});

  final String name;
  final bool showChevron;

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
            if (showChevron) ...<Widget>[
              const SizedBox(width: 2),
              Icon(
                Icons.unfold_more_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
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

/// "● Live" / "Paused" capsule that toggles following.
class _LiveToggle extends StatelessWidget {
  const _LiveToggle({
    required this.follow,
    required this.pollFailed,
    required this.onPressed,
  });

  final bool follow;
  final bool pollFailed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = !follow
        ? AppColors.unknown
        : pollFailed
        ? AppColors.warning
        : AppColors.healthy;
    final label = !follow
        ? 'Paused'
        : pollFailed
        ? 'Retrying'
        : 'Live';
    return Tooltip(
      message: follow ? 'Stop following' : 'Follow output',
      child: Semantics(
        button: true,
        toggled: follow,
        label: 'Follow logs',
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.pill,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
            decoration: BoxDecoration(
              color: follow
                  ? AppColors.statusTint(theme, color)
                  : AppColors.fill(theme),
              borderRadius: AppRadius.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (follow)
                  StatusDot(color: color, size: 7)
                else
                  Icon(
                    Icons.pause_rounded,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: follow
                        ? AppColors.statusForeground(theme, color)
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating pill shown when new output arrived while scrolled up.
class _JumpToLatestButton extends StatelessWidget {
  const _JumpToLatestButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary,
      shape: const StadiumBorder(),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.arrow_downward_rounded,
                size: 15,
                color: theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: 5),
              Text(
                'New output',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
