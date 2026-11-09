import 'dart:convert';

import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/utils/diff.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

enum _DiffViewMode { unified, sideBySide }

enum _SourceSyntax { yaml, json, text }

/// Code metrics shared by every diff line.
const double _kCodeFontSize = 12.5;
const double _kCodeLineHeight = 1.55;
const double _kLineNumberWidth = 40;
const double _kPrefixWidth = 20;
const double _kCodePadding = 12;

TextStyle _codeStyle(ThemeData theme) => TextStyle(
  fontFamily: AppFonts.mono,
  fontSize: _kCodeFontSize,
  height: _kCodeLineHeight,
  color: theme.colorScheme.onSurface,
);

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
  bool _ignoreWhitespace = false;
  _DiffViewMode _viewMode = _DiffViewMode.unified;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.fetchManagedResources(widget.applicationName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      appBar: AppBar(
        title: Text('Diff: ${widget.applicationName}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(narrow ? 96 : 54),
          child: _DiffCommandBar(
            narrow: narrow,
            viewMode: _viewMode,
            ignoreWhitespace: _ignoreWhitespace,
            hideManagedFields: _hideManagedFields,
            onModeChanged: _setMode,
            onToggleWhitespace: _toggleWhitespace,
            onToggleManagedFields: _toggleManagedFields,
          ),
        ),
      ),
      body: FutureBuilder<List<ManagedResource>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: EmptyStateCard(
                  icon: Icons.error_outline_rounded,
                  title: 'Couldn’t Load Diff',
                  subtitle: snapshot.error.toString(),
                  action: OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ),
              ),
            );
          }

          final resources = snapshot.requireData;
          final diffResources = resources.where((r) => r.hasDiff).toList();

          if (diffResources.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EmptyStateCard(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'In Sync',
                  subtitle: 'All resources match their desired state.',
                ),
              ),
            );
          }

          final count = diffResources.length;
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: count + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    '$count ${count == 1 ? 'resource' : 'resources'} with drift'
                    ' · desired → live',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ResourceDiffCard(
                  resource: diffResources[index - 1],
                  hideManagedFields: _hideManagedFields,
                  ignoreWhitespace: _ignoreWhitespace,
                  viewMode: _viewMode,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _setMode(_DiffViewMode mode) {
    setState(() {
      _viewMode = mode;
    });
  }

  void _toggleWhitespace() {
    setState(() {
      _ignoreWhitespace = !_ignoreWhitespace;
    });
  }

  void _toggleManagedFields() {
    setState(() {
      _hideManagedFields = !_hideManagedFields;
    });
  }

  void _refresh() {
    setState(() {
      _future = widget.controller.fetchManagedResources(widget.applicationName);
    });
  }
}

class _DiffCommandBar extends StatelessWidget {
  const _DiffCommandBar({
    required this.narrow,
    required this.viewMode,
    required this.ignoreWhitespace,
    required this.hideManagedFields,
    required this.onModeChanged,
    required this.onToggleWhitespace,
    required this.onToggleManagedFields,
  });

  final bool narrow;
  final _DiffViewMode viewMode;
  final bool ignoreWhitespace;
  final bool hideManagedFields;
  final ValueChanged<_DiffViewMode> onModeChanged;
  final VoidCallback onToggleWhitespace;
  final VoidCallback onToggleManagedFields;

  @override
  Widget build(BuildContext context) {
    final modeControl = _ModeControl(value: viewMode, onChanged: onModeChanged);
    final filters = <Widget>[
      Tooltip(
        message: ignoreWhitespace ? 'Compare whitespace' : 'Ignore whitespace',
        child: FilterChip(
          label: const Text('Ignore whitespace'),
          selected: ignoreWhitespace,
          onSelected: (_) => onToggleWhitespace(),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: hideManagedFields
            ? 'Show managed fields'
            : 'Hide managed fields',
        child: FilterChip(
          label: const Text('Hide managed fields'),
          selected: hideManagedFields,
          onSelected: (_) => onToggleManagedFields(),
        ),
      ),
    ];

    if (narrow) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            modeControl,
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: filters),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: <Widget>[
          SizedBox(width: 240, child: modeControl),
          const Spacer(),
          ...filters,
        ],
      ),
    );
  }
}

/// iOS segmented control: a raised thumb on a neutral track.
class _ModeControl extends StatelessWidget {
  const _ModeControl({required this.value, required this.onChanged});

  final _DiffViewMode value;
  final ValueChanged<_DiffViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Widget segment(_DiffViewMode mode, String label) {
      final selected = mode == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? (isDark ? const Color(0xFF636366) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: selected && !isDark
                    ? <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 13,
                  color: scheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.fill(theme),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: <Widget>[
          segment(_DiffViewMode.unified, 'Unified'),
          segment(_DiffViewMode.sideBySide, 'Split'),
        ],
      ),
    );
  }
}

class _ResourceDiffCard extends StatelessWidget {
  const _ResourceDiffCard({
    required this.resource,
    required this.hideManagedFields,
    required this.ignoreWhitespace,
    required this.viewMode,
  });

  final ManagedResource resource;
  final bool hideManagedFields;
  final bool ignoreWhitespace;
  final _DiffViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final targetYaml = _formatManifest(
      resource.targetState!,
      hideManagedFields,
    );
    final liveYaml = _formatManifest(resource.liveState!, hideManagedFields);
    final targetLines = _trimTrailing(targetYaml.split('\n'));
    final liveLines = _trimTrailing(liveYaml.split('\n'));
    final diffLines = computeDiffLines(
      targetLines,
      liveLines,
      ignoreWhitespace: ignoreWhitespace,
    );
    final stats = computeDiffStats(diffLines);
    final sections = computeDiff(
      targetLines,
      liveLines,
      ignoreWhitespace: ignoreWhitespace,
    );
    final sideBySideSections = computeSideBySideDiff(
      targetLines,
      liveLines,
      ignoreWhitespace: ignoreWhitespace,
    );
    final maxChars = <String>[
      ...targetLines,
      ...liveLines,
    ].fold<int>(0, (max, line) => line.length > max ? line.length : max);
    final title = resource.namespace.isEmpty
        ? resource.name
        : '${resource.namespace}/${resource.name}';

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    iconForResourceKind(resource.kind),
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        resource.kind,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _DiffStats(stats: stats),
              ],
            ),
          ),
          Divider(height: 0.5, color: scheme.outlineVariant),
          if (stats.hasChanges)
            _DiffBody(
              sections: sections,
              sideBySideSections: sideBySideSections,
              viewMode: viewMode,
              maxChars: maxChars,
            )
          else
            const _NoVisibleDiff(),
        ],
      ),
    );
  }
}

/// GitHub-style change summary: "+3 −2" plus a five-block ratio bar.
class _DiffStats extends StatelessWidget {
  const _DiffStats({required this.stats});

  final DiffStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final added = stats.added + stats.changed;
    final removed = stats.removed + stats.changed;
    final total = added + removed;
    final addFg = AppColors.statusForeground(theme, AppColors.healthy);
    final removeFg = AppColors.statusForeground(theme, AppColors.degraded);
    final style = theme.textTheme.labelMedium?.copyWith(
      fontFamily: AppFonts.mono,
      fontWeight: FontWeight.w600,
      fontFeatures: AppFonts.tabularFigures,
    );

    var addBlocks = total == 0 ? 0 : (added / total * 5).round();
    if (added > 0 && addBlocks == 0) addBlocks = 1;
    if (removed > 0 && addBlocks == 5) addBlocks = 4;
    final removeBlocks = total == 0 ? 0 : 5 - addBlocks;

    return Semantics(
      label: '$added additions, $removed deletions',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (added > 0)
              Text('+$added', style: style?.copyWith(color: addFg)),
            if (added > 0 && removed > 0) const SizedBox(width: 6),
            if (removed > 0)
              Text('−$removed', style: style?.copyWith(color: removeFg)),
            const SizedBox(width: 8),
            for (var i = 0; i < 5; i++)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1.5),
                  color: i < addBlocks
                      ? AppColors.healthy
                      : i < addBlocks + removeBlocks
                      ? AppColors.degraded
                      : AppColors.fill(theme),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiffBody extends StatelessWidget {
  const _DiffBody({
    required this.sections,
    required this.sideBySideSections,
    required this.viewMode,
    required this.maxChars,
  });

  final List<DiffSection> sections;
  final List<DiffSideBySideSection> sideBySideSections;
  final _DiffViewMode viewMode;
  final int maxChars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final charWidth = _monoCharWidth(_codeStyle(theme));

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final sideBySide = viewMode == _DiffViewMode.sideBySide;
        final textWidth = maxChars * charWidth + _kCodePadding * 2;
        final double contentWidth;
        final double cellWidth;
        if (sideBySide) {
          cellWidth = _max(
            available / 2,
            _kLineNumberWidth + _kPrefixWidth + textWidth,
          );
          contentWidth = cellWidth * 2;
        } else {
          cellWidth = 0;
          contentWidth = _max(
            available,
            _kLineNumberWidth * 2 + _kPrefixWidth + textWidth,
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: sideBySide
                    ? <Widget>[
                        for (final section in sideBySideSections)
                          if (section.isCollapsed)
                            _CollapsedSection(count: section.collapsedCount)
                          else
                            for (final row in section.rows)
                              _SideBySideRow(row: row, cellWidth: cellWidth),
                      ]
                    : <Widget>[
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
        );
      },
    );
  }
}

double _max(double a, double b) => a > b ? a : b;

/// A lighter version of [AppColors.fill] for bands inside code blocks.
Color _softFill(ThemeData theme) {
  final fill = AppColors.fill(theme);
  return fill.withValues(alpha: fill.a * 0.6);
}

final Map<String, double> _charWidthCache = <String, double>{};

double _monoCharWidth(TextStyle style) {
  final key = '${style.fontFamily}/${style.fontSize}';
  return _charWidthCache.putIfAbsent(key, () {
    final painter = TextPainter(
      text: TextSpan(text: 'MMMMMMMMMM', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width / 10;
    painter.dispose();
    return width;
  });
}

class _NoVisibleDiff extends StatelessWidget {
  const _NoVisibleDiff();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No visible diff with the current filters.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CollapsedSection extends StatelessWidget {
  const _CollapsedSection({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppColors.tertiaryLabel(theme);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: _softFill(theme),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: _kLineNumberWidth * 2,
            child: Icon(Icons.unfold_more_rounded, size: 16, color: muted),
          ),
          const SizedBox(width: _kPrefixWidth),
          Text(
            '$count unchanged ${count == 1 ? 'line' : 'lines'}',
            style: theme.textTheme.labelMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// Background / gutter / glyph colors for a diff line.
class _LineColors {
  const _LineColors({
    required this.background,
    required this.gutter,
    required this.prefix,
  });

  factory _LineColors.of(ThemeData theme, DiffLineKind? kind) {
    final hue = switch (kind) {
      DiffLineKind.added => AppColors.healthy,
      DiffLineKind.removed => AppColors.degraded,
      _ => null,
    };
    if (hue == null) {
      return _LineColors(
        background: Colors.transparent,
        gutter: Colors.transparent,
        prefix: AppColors.tertiaryLabel(theme),
      );
    }
    final tint = AppColors.statusTint(theme, hue);
    return _LineColors(
      background: tint,
      gutter: tint,
      prefix: AppColors.statusForeground(theme, hue),
    );
  }

  final Color background;
  final Color gutter;
  final Color prefix;
}

class _DiffLineWidget extends StatelessWidget {
  const _DiffLineWidget({required this.line});

  final DiffLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _LineColors.of(theme, line.kind);
    final style = _codeStyle(theme);

    return ColoredBox(
      color: colors.background,
      child: Row(
        children: <Widget>[
          ColoredBox(
            color: colors.gutter,
            child: Row(
              children: <Widget>[
                _LineNumber(value: line.oldLineNumber),
                _LineNumber(value: line.newLineNumber),
              ],
            ),
          ),
          SizedBox(
            width: _kPrefixWidth,
            child: Text(
              line.prefix,
              textAlign: TextAlign.center,
              style: style.copyWith(color: colors.prefix),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: _kCodePadding),
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: _buildSourceLineSpans(
                    line.text,
                    _sourceSyntaxForDiffLine(line.text),
                    fallbackColor: theme.colorScheme.onSurface,
                    brightness: theme.brightness,
                  ),
                ),
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideBySideRow extends StatelessWidget {
  const _SideBySideRow({required this.row, required this.cellWidth});

  final DiffSideBySideRow row;
  final double cellWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: cellWidth,
            child: _SideBySideCell(line: row.oldLine, isOldSide: true),
          ),
          VerticalDivider(width: 0.5, color: scheme.outlineVariant),
          SizedBox(
            width: cellWidth - 0.5,
            child: _SideBySideCell(line: row.newLine, isOldSide: false),
          ),
        ],
      ),
    );
  }
}

class _SideBySideCell extends StatelessWidget {
  const _SideBySideCell({required this.line, required this.isOldSide});

  final DiffLine? line;
  final bool isOldSide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _LineColors.of(theme, line?.kind);
    final style = _codeStyle(theme);
    final background = line == null ? _softFill(theme) : colors.background;

    return ColoredBox(
      color: background,
      child: Row(
        children: <Widget>[
          ColoredBox(
            color: line == null ? Colors.transparent : colors.gutter,
            child: _LineNumber(
              value: isOldSide ? line?.oldLineNumber : line?.newLineNumber,
            ),
          ),
          SizedBox(
            width: _kPrefixWidth,
            child: Text(
              line?.prefix ?? ' ',
              textAlign: TextAlign.center,
              style: style.copyWith(color: colors.prefix),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: style,
                children: _buildSourceLineSpans(
                  line?.text ?? '',
                  _sourceSyntaxForDiffLine(line?.text ?? ''),
                  fallbackColor: theme.colorScheme.onSurface,
                  brightness: theme.brightness,
                ),
              ),
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}

class _LineNumber extends StatelessWidget {
  const _LineNumber({required this.value});

  final int? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _kLineNumberWidth,
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(
          value?.toString() ?? '',
          textAlign: TextAlign.right,
          style: _codeStyle(
            theme,
          ).copyWith(fontSize: 11.5, color: AppColors.tertiaryLabel(theme)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<TextSpan> _buildSourceLineSpans(
  String line,
  _SourceSyntax syntax, {
  required Color fallbackColor,
  required Brightness brightness,
}) {
  return <TextSpan>[
    for (final token in _tokenizeSourceLine(line, syntax))
      TextSpan(
        text: token.text,
        style: TextStyle(
          color: _sourceTokenColor(
            token,
            baseColor: fallbackColor,
            brightness: brightness,
          ),
        ),
      ),
  ];
}

List<_SourceToken> _tokenizeSourceLine(String line, _SourceSyntax syntax) {
  return switch (syntax) {
    _SourceSyntax.yaml =>
      tokenizeYamlLine(line)
          .map((token) => _SourceToken(token.text, token.type?.name))
          .toList(growable: false),
    _SourceSyntax.json => _tokenizeJsonLine(line),
    _SourceSyntax.text => <_SourceToken>[_SourceToken(line, null)],
  };
}

List<_SourceToken> _tokenizeJsonLine(String line) {
  const tokenPattern =
      r'"([^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|[{}\[\]:,]';
  final matcher = RegExp(tokenPattern).allMatches(line);
  final tokens = <_SourceToken>[];
  var cursor = 0;

  for (final match in matcher) {
    if (match.start > cursor) {
      tokens.add(_SourceToken(line.substring(cursor, match.start), null));
    }

    final tokenText = match.group(0)!;
    tokens.add(
      _SourceToken(
        tokenText,
        _jsonTokenType(tokenText, line.substring(match.end).trimLeft()),
      ),
    );

    cursor = match.end;
  }

  if (cursor < line.length) {
    tokens.add(_SourceToken(line.substring(cursor), null));
  }

  return tokens;
}

String? _jsonTokenType(String tokenText, String restOfLine) {
  if (tokenText == '{' ||
      tokenText == '}' ||
      tokenText == '[' ||
      tokenText == ']' ||
      tokenText == ':' ||
      tokenText == ',') {
    return 'jsonPunctuation';
  }

  if (tokenText == 'true' || tokenText == 'false' || tokenText == 'null') {
    return 'jsonLiteral';
  }

  final numeric = num.tryParse(tokenText);
  if (numeric != null) {
    return 'jsonNumber';
  }

  if (tokenText.startsWith('"')) {
    return restOfLine.startsWith(':') ? 'jsonKey' : 'jsonString';
  }

  return null;
}

Color _sourceTokenColor(
  _SourceToken token, {
  required Color baseColor,
  required Brightness brightness,
}) {
  final YamlTokenType? yamlType = switch (token.type) {
    'key' || 'listDash' || 'jsonLiteral' => YamlTokenType.key,
    'stringValue' || 'jsonKey' || 'jsonString' => YamlTokenType.stringValue,
    'numberValue' ||
    'boolNullValue' ||
    'jsonNumber' => YamlTokenType.numberValue,
    'comment' => YamlTokenType.comment,
    _ => null,
  };
  if (yamlType == null) {
    // Punctuation and plain text use the neutral palette entry; anything
    // unrecognised keeps the line's base color.
    return token.type == 'jsonPunctuation'
        ? yamlTokenColorFor(null, brightness)
        : baseColor;
  }
  return yamlTokenColorFor(yamlType, brightness);
}

class _SourceToken {
  const _SourceToken(this.text, this.type);

  final String text;
  final String? type;
}

_SourceSyntax _sourceSyntaxForDiffLine(String text) {
  final trimmed = text.trimLeft();
  if (trimmed.isEmpty) {
    return _SourceSyntax.text;
  }
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    return _SourceSyntax.json;
  }
  return _SourceSyntax.yaml;
}

String _formatManifest(String jsonString, bool hideManagedFields) {
  try {
    final parsed = jsonDecode(jsonString);
    if (parsed is Map<String, dynamic>) {
      final cleaned = hideManagedFields ? _stripServerFields(parsed) : parsed;
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
    result['metadata'] = Map<String, dynamic>.of(metadata)
      ..remove('managedFields');
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
