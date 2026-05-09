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
    final narrow = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Diff: ${widget.applicationName}',
          style: theme.textTheme.titleMedium,
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(narrow ? 92 : 60),
          child: _DiffCommandBar(
            viewMode: _viewMode,
            ignoreWhitespace: _ignoreWhitespace,
            hideManagedFields: _hideManagedFields,
            onToggleMode: _toggleMode,
            onToggleWhitespace: _toggleWhitespace,
            onToggleManagedFields: _toggleManagedFields,
            onRefresh: _refresh,
          ),
        ),
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
          final diffResources = resources.where((r) => r.hasDiff).toList();

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

          return Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.35 : 0.55,
                ),
                child: Text(
                  '${diffResources.length} resources with drift',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: diffResources.length,
                  itemBuilder: (context, index) {
                    return _ResourceDiffCard(
                      resource: diffResources[index],
                      hideManagedFields: _hideManagedFields,
                      ignoreWhitespace: _ignoreWhitespace,
                      viewMode: _viewMode,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleMode() {
    setState(() {
      _viewMode = _viewMode == _DiffViewMode.unified
          ? _DiffViewMode.sideBySide
          : _DiffViewMode.unified;
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
    required this.viewMode,
    required this.ignoreWhitespace,
    required this.hideManagedFields,
    required this.onToggleMode,
    required this.onToggleWhitespace,
    required this.onToggleManagedFields,
    required this.onRefresh,
  });

  final _DiffViewMode viewMode;
  final bool ignoreWhitespace;
  final bool hideManagedFields;
  final VoidCallback onToggleMode;
  final VoidCallback onToggleWhitespace;
  final VoidCallback onToggleManagedFields;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SegmentedButton<_DiffViewMode>(
            segments: const <ButtonSegment<_DiffViewMode>>[
              ButtonSegment<_DiffViewMode>(
                value: _DiffViewMode.unified,
                icon: Icon(Icons.subject),
                label: Text('Unified'),
              ),
              ButtonSegment<_DiffViewMode>(
                value: _DiffViewMode.sideBySide,
                icon: Icon(Icons.view_week),
                label: Text('Split'),
              ),
            ],
            selected: <_DiffViewMode>{viewMode},
            onSelectionChanged: (_) => onToggleMode(),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium),
            ),
          ),
          Tooltip(
            message: ignoreWhitespace
                ? 'Compare whitespace'
                : 'Ignore whitespace',
            child: FilterChip(
              avatar: const Icon(Icons.format_line_spacing, size: 16),
              label: const Text('Whitespace'),
              selected: ignoreWhitespace,
              onSelected: (_) => onToggleWhitespace(),
            ),
          ),
          Tooltip(
            message: hideManagedFields
                ? 'Show managed fields'
                : 'Hide managed fields',
            child: FilterChip(
              avatar: Icon(
                hideManagedFields ? Icons.visibility_off : Icons.visibility,
                size: 16,
              ),
              label: const Text('Managed fields'),
              selected: hideManagedFields,
              onSelected: (_) => onToggleManagedFields(),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
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
    final kindColor = colorForResourceKind(resource.kind);
    final kindIcon = iconForResourceKind(resource.kind);
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
                  _DiffStats(stats: stats),
                ],
              ),
            ),
            Container(
              color: theme.colorScheme.surfaceContainerLowest,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: stats.hasChanges
                  ? _DiffBody(
                      sections: sections,
                      sideBySideSections: sideBySideSections,
                      viewMode: viewMode,
                    )
                  : const _NoVisibleDiff(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffStats extends StatelessWidget {
  const _DiffStats({required this.stats});

  final DiffStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (stats.changed > 0)
          Text(
            '~${stats.changed}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (stats.changed > 0 && (stats.added > 0 || stats.removed > 0))
          const SizedBox(width: 6),
        if (stats.added > 0)
          Text(
            '+${stats.added}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (stats.added > 0 && stats.removed > 0) const SizedBox(width: 6),
        if (stats.removed > 0)
          Text(
            '-${stats.removed}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.coral,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _DiffBody extends StatelessWidget {
  const _DiffBody({
    required this.sections,
    required this.sideBySideSections,
    required this.viewMode,
  });

  final List<DiffSection> sections;
  final List<DiffSideBySideSection> sideBySideSections;
  final _DiffViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: viewMode == _DiffViewMode.sideBySide
            ? _buildSideBySideChildren()
            : _buildUnifiedChildren(),
      ),
    );
  }

  List<Widget> _buildUnifiedChildren() {
    return <Widget>[
      for (final section in sections)
        if (section.isCollapsed)
          _CollapsedSection(count: section.collapsedCount)
        else
          for (final line in section.lines) _DiffLineWidget(line: line),
    ];
  }

  List<Widget> _buildSideBySideChildren() {
    return <Widget>[
      for (final section in sideBySideSections)
        if (section.isCollapsed)
          _CollapsedSection(count: section.collapsedCount, width: 1440)
        else
          for (final row in section.rows) _SideBySideRow(row: row),
    ];
  }
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
  const _CollapsedSection({required this.count, this.width = 2000});

  final int count;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        children: <Widget>[
          _LineNumber(value: line.oldLineNumber),
          _LineNumber(value: line.newLineNumber),
          SizedBox(
            width: 24,
            child: Text(
              line.prefix,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: textColor,
                height: 1.5,
              ),
            ),
          ),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: textColor,
                height: 1.5,
              ),
              children: <TextSpan>[
                ..._buildSourceLineSpans(
                  line.text,
                  _sourceSyntaxForDiffLine(line.text),
                  fallbackColor: textColor,
                  isDark: theme.brightness == Brightness.dark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideBySideRow extends StatelessWidget {
  const _SideBySideRow({required this.row});

  final DiffSideBySideRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _SideBySideCell(line: row.oldLine, isOldSide: true),
        _SideBySideCell(line: row.newLine, isOldSide: false),
      ],
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
    final isChanged = line != null && line!.kind != DiffLineKind.unchanged;
    final backgroundColor = line == null
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : switch (line!.kind) {
            DiffLineKind.added => AppColors.teal.withValues(alpha: 0.10),
            DiffLineKind.removed => AppColors.coral.withValues(alpha: 0.10),
            DiffLineKind.unchanged => Colors.transparent,
          };
    final textColor = line == null
        ? theme.colorScheme.onSurfaceVariant
        : switch (line!.kind) {
            DiffLineKind.added => AppColors.teal,
            DiffLineKind.removed => AppColors.coral,
            DiffLineKind.unchanged => theme.colorScheme.onSurface.withValues(
              alpha: 0.65,
            ),
          };

    return Container(
      width: 720,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        children: <Widget>[
          _LineNumber(
            value: isOldSide ? line?.oldLineNumber : line?.newLineNumber,
          ),
          SizedBox(
            width: 24,
            child: Text(
              line?.prefix ?? ' ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: textColor,
                fontWeight: isChanged ? FontWeight.w600 : null,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: textColor,
                  fontWeight: isChanged ? FontWeight.w600 : null,
                  height: 1.5,
                ),
                children: <TextSpan>[
                  ..._buildSourceLineSpans(
                    line?.text ?? '',
                    _sourceSyntaxForDiffLine(line?.text ?? ''),
                    fallbackColor: textColor,
                    isDark: theme.brightness == Brightness.dark,
                  ),
                ],
              ),
              overflow: TextOverflow.visible,
              softWrap: false,
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
      width: 48,
      child: Text(
        value?.toString() ?? '',
        textAlign: TextAlign.right,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          height: 1.5,
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
  required bool isDark,
}) {
  return <TextSpan>[
    for (final token in _tokenizeSourceLine(line, syntax))
      TextSpan(
        text: token.text,
        style: TextStyle(
          color: _sourceTokenColor(
            token,
            baseColor: fallbackColor,
            isDark: isDark,
          ),
        ),
      ),
  ];
}

List<_SourceToken> _tokenizeSourceLine(String line, _SourceSyntax syntax) {
  return switch (syntax) {
    _SourceSyntax.yaml => tokenizeYamlLine(line)
        .map((_token) => _SourceToken(_token.text, _token.type?.name))
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
  required bool isDark,
}) {
  return switch (token.type) {
    'key' => AppColors.yamlKey,
    'stringValue' => AppColors.yamlString,
    'numberValue' => AppColors.yamlNumber,
    'boolNullValue' => AppColors.yamlNumber,
    'listDash' => AppColors.yamlKey,
    'comment' => AppColors.yamlComment,
    'jsonKey' => AppColors.yamlString,
    'jsonString' => AppColors.yamlString,
    'jsonNumber' => AppColors.yamlNumber,
    'jsonLiteral' => AppColors.yamlKey,
    'jsonPunctuation' => AppColors.yamlPunctuation,
    null => isDark ? baseColor : baseColor.withValues(alpha: 0.92),
    _ => baseColor,
  };
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
