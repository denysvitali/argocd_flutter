import 'dart:convert';

import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/utils/diff.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

export 'package:argocd_flutter/ui/shared_widgets.dart'
    show
        YamlToken,
        YamlTokenType,
        jsonToYaml,
        needsYamlQuoting,
        tokenizeYamlLine,
        yamlTokenColor;

enum _ManifestViewMode { yaml, json, diff }

enum _SourceSyntax { yaml, json, text }

enum _ManifestAction { toggleManagedFields, copy, refresh }

class ManifestViewerScreen extends StatefulWidget {
  const ManifestViewerScreen({
    super.key,
    required this.controller,
    required this.applicationName,
    required this.namespace,
    required this.resourceName,
    required this.kind,
    required this.group,
    required this.version,
  });

  final AppController controller;
  final String applicationName;
  final String namespace;
  final String resourceName;
  final String kind;
  final String group;
  final String version;

  @override
  State<ManifestViewerScreen> createState() => _ManifestViewerScreenState();
}

class _ManifestViewerScreenState extends State<ManifestViewerScreen> {
  static const int _searchContextRadius = 2;

  late Future<String> _future;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final Map<String, bool> _expandedSections = <String, bool>{};
  final Map<String, GlobalKey> _lineKeys = <String, GlobalKey>{};
  final Map<_ManifestViewMode, double> _verticalOffsets =
      <_ManifestViewMode, double>{};
  final Map<_ManifestViewMode, double> _horizontalOffsets =
      <_ManifestViewMode, double>{};

  _ManifestViewMode _viewMode = _ManifestViewMode.yaml;
  bool _showSearch = false;
  bool _wrapLines = false;
  bool _hideManagedFields = true;
  String _searchQuery = '';
  int _currentMatchIndex = 0;
  List<int> _activeMatches = const <int>[];

  @override
  void initState() {
    super.initState();
    _future = _loadManifest();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // ── Code metrics ─────────────────────────────────────────────────────────

  static const double _codeFontSize = 12.5;
  static const double _codeLineHeight = 1.55;
  static const double _gutterWidth = 38;
  static const double _foldColumnWidth = 22;

  TextStyle _codeStyle(ThemeData theme) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: _codeFontSize,
      height: _codeLineHeight,
      color: yamlTokenColorFor(null, theme.brightness),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compactActions = MediaQuery.sizeOf(context).width < 420;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: (theme.appBarTheme.centerTitle ?? false)
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              compactActions
                  ? widget.resourceName
                  : '${widget.kind}: ${widget.resourceName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.namespace.isEmpty
                  ? widget.applicationName
                  : '${widget.namespace} / ${widget.applicationName}',
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
            tooltip: 'Search',
            onPressed: _toggleSearch,
            isSelected: _showSearch,
            icon: const Icon(Icons.search),
          ),
          if (compactActions)
            _buildOverflowMenu()
          else ...<Widget>[
            IconButton(
              tooltip: _hideManagedFields
                  ? 'Show managed fields'
                  : 'Hide managed fields',
              onPressed: _toggleManagedFields,
              icon: Icon(
                _hideManagedFields
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            FutureBuilder<String>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                return IconButton(
                  tooltip: 'Copy',
                  onPressed: snapshot.hasData
                      ? () => _copyManifest(snapshot.requireData)
                      : null,
                  icon: const Icon(Icons.copy),
                );
              },
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refreshManifest,
              icon: const Icon(Icons.refresh),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<String>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
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
                  icon: Icons.description_outlined,
                  title: "Couldn't Load Manifest",
                  subtitle: snapshot.error.toString(),
                  action: FilledButton(
                    onPressed: _refreshManifest,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            );
          }

          final document = _buildDocumentBundle(snapshot.requireData);
          final viewData = _activeViewData(document);
          _activeMatches = viewData.matches;
          _syncCurrentMatch(viewData.matches.length);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildToolbar(document, showLineCount: !compactActions),
              if (_showSearch) _buildSearchBar(),
              Expanded(
                // Instant switch (like a segmented control in Xcode): a
                // cross-fade would attach the shared scroll controllers to
                // two scroll views at once.
                child: KeyedSubtree(
                  key: ValueKey<String>(_viewMode.name),
                  child: _buildModeBody(document, viewData),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverflowMenu() {
    return FutureBuilder<String>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        return PopupMenuButton<_ManifestAction>(
          tooltip: 'More actions',
          icon: const Icon(Icons.more_horiz_rounded),
          itemBuilder: (BuildContext context) {
            return <PopupMenuEntry<_ManifestAction>>[
              CheckedPopupMenuItem<_ManifestAction>(
                value: _ManifestAction.toggleManagedFields,
                checked: _hideManagedFields,
                child: const Text('Hide managed fields'),
              ),
              if (snapshot.hasData)
                const PopupMenuItem<_ManifestAction>(
                  value: _ManifestAction.copy,
                  child: Text('Copy'),
                ),
              const PopupMenuItem<_ManifestAction>(
                value: _ManifestAction.refresh,
                child: Text('Refresh'),
              ),
            ];
          },
          onSelected: (_ManifestAction action) {
            switch (action) {
              case _ManifestAction.toggleManagedFields:
                _toggleManagedFields();
              case _ManifestAction.copy:
                if (snapshot.hasData) {
                  _copyManifest(snapshot.requireData);
                }
              case _ManifestAction.refresh:
                _refreshManifest();
            }
          },
        );
      },
    );
  }

  /// Mode picker (YAML / JSON / Diff) plus editor options.
  Widget _buildToolbar(
    _ManifestDocumentBundle document, {
    required bool showLineCount,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lineCount = switch (_viewMode) {
      _ManifestViewMode.yaml => document.yamlLines.length,
      _ManifestViewMode.json => document.jsonLines.length,
      _ManifestViewMode.diff => document.diff?.lines.length ?? 0,
    };
    final hasExpandableSections = document.sections.any(
      (_YamlSection section) => section.expandable,
    );
    final allExpanded = _allExpandableSectionsExpanded(document);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
      child: Row(
        children: <Widget>[
          _SegmentedControl<_ManifestViewMode>(
            value: _viewMode,
            onChanged: _setViewMode,
            segments: const <_Segment<_ManifestViewMode>>[
              _Segment<_ManifestViewMode>(
                value: _ManifestViewMode.yaml,
                icon: Icons.code,
                label: 'YAML',
              ),
              _Segment<_ManifestViewMode>(
                value: _ManifestViewMode.json,
                icon: Icons.data_object,
                label: 'JSON',
              ),
              _Segment<_ManifestViewMode>(
                value: _ManifestViewMode.diff,
                icon: Icons.compare_arrows,
                label: 'Diff',
              ),
            ],
          ),
          const Spacer(),
          if (showLineCount) ...<Widget>[
            Text(
              'Lines: $lineCount',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: AppFonts.tabularFigures,
              ),
            ),
            const SizedBox(width: 6),
          ],
          IconButton(
            tooltip: allExpanded
                ? 'Collapse all sections'
                : 'Expand all sections',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            onPressed:
                _viewMode == _ManifestViewMode.yaml && hasExpandableSections
                ? () => _toggleAllSections(document)
                : null,
            icon: Icon(allExpanded ? Icons.unfold_less : Icons.unfold_more),
          ),
          IconButton(
            tooltip: _wrapLines ? 'Disable word wrap' : 'Enable word wrap',
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            isSelected: _wrapLines,
            onPressed: () {
              setState(() {
                _wrapLines = !_wrapLines;
              });
            },
            selectedIcon: Icon(Icons.wrap_text_rounded, color: scheme.primary),
            icon: Icon(Icons.wrap_text_rounded, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final matchCount = _activeMatchCount;
    final currentLabel = matchCount == 0
        ? '0/0'
        : '${_currentMatchIndex + 1}/$matchCount';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search manifest',
                isDense: true,
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.base,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 9,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.cancel_rounded,
                          color: AppColors.tertiaryLabel(theme),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _currentMatchIndex = 0;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (String value) {
                setState(() {
                  _searchQuery = value;
                  _currentMatchIndex = 0;
                });
                _scheduleEnsureCurrentMatch();
              },
            ),
          ),
          const SizedBox(width: 10),
          Text(
            currentLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: AppFonts.tabularFigures,
            ),
          ),
          IconButton(
            tooltip: 'Previous match',
            visualDensity: VisualDensity.compact,
            onPressed: matchCount == 0 ? null : _goToPreviousMatch,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: 'Next match',
            visualDensity: VisualDensity.compact,
            onPressed: matchCount == 0 ? null : _goToNextMatch,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBody(
    _ManifestDocumentBundle document,
    _ManifestViewData viewData,
  ) {
    switch (_viewMode) {
      case _ManifestViewMode.json:
        return _buildJsonView(document, viewData);
      case _ManifestViewMode.yaml:
        return _buildYamlView(document, viewData);
      case _ManifestViewMode.diff:
        if (document.diff == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: const <Widget>[
              EmptyStateCard(
                icon: Icons.compare_arrows_rounded,
                title: 'No Diff Available',
                subtitle:
                    'Desired/live diff is not available for this manifest '
                    'response.',
              ),
            ],
          );
        }
        return _buildDiffView(document, viewData);
    }
  }

  Widget _buildJsonView(
    _ManifestDocumentBundle document,
    _ManifestViewData viewData,
  ) {
    return _buildCodeCard(
      lineCount: viewData.lines.length,
      matches: viewData.matches,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < viewData.lines.length; i++)
            _buildCodeLine(
              keyId: '${_viewMode.name}-$i',
              lineNumber: i + 1,
              line: viewData.lines[i],
              syntax: document.sourceSyntax == _SourceSyntax.yaml
                  ? _SourceSyntax.json
                  : document.sourceSyntax,
              isMatch: viewData.matches.contains(i),
              isCurrentMatch:
                  viewData.matches.isNotEmpty &&
                  viewData.matches[_currentMatchIndex] == i,
            ),
        ],
      ),
    );
  }

  Widget _buildYamlView(
    _ManifestDocumentBundle document,
    _ManifestViewData viewData,
  ) {
    final visibleLineIndices = _visibleLineIndices(
      lines: document.yamlLines,
      query: viewData.query,
      contextRadius: _searchContextRadius,
    );

    if (document.sections.isEmpty) {
      // Unstructured payloads (plain text, top-level lists) have no
      // sections; render them as a flat listing.
      return _buildCodeCard(
        lineCount: document.yamlLines.length,
        matches: viewData.matches,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < document.yamlLines.length; i++)
              if (visibleLineIndices.contains(i))
                _buildCodeLine(
                  keyId: 'yaml-$i',
                  lineNumber: i + 1,
                  line: document.yamlLines[i],
                  syntax: document.sourceSyntax,
                  isMatch: viewData.matches.contains(i),
                  isCurrentMatch:
                      viewData.matches.isNotEmpty &&
                      viewData.matches[_currentMatchIndex] == i,
                ),
          ],
        ),
      );
    }

    return _buildCodeCard(
      lineCount: document.yamlLines.length,
      matches: viewData.matches,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final section in document.sections)
            _buildSection(document, section, viewData, visibleLineIndices),
        ],
      ),
    );
  }

  Widget _buildDiffView(
    _ManifestDocumentBundle document,
    _ManifestViewData viewData,
  ) {
    final diff = document.diff!;
    return _buildCodeCard(
      lineCount: diff.lines.length,
      matches: viewData.matches,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < diff.lines.length; i++)
            _buildDiffLine(
              keyId: '${_viewMode.name}-$i',
              lineNumber: i + 1,
              line: diff.lines[i],
              isMatch: viewData.matches.contains(i),
              isCurrentMatch:
                  viewData.matches.isNotEmpty &&
                  viewData.matches[_currentMatchIndex] == i,
            ),
        ],
      ),
    );
  }

  /// The code "editor": a rounded card on the grouped background with
  /// vertical (and, without wrapping, horizontal) scrolling plus a slim
  /// search-match ruler along the right edge.
  Widget _buildCodeCard({
    required int lineCount,
    required List<int> matches,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.md,
        ),
        child: ClipRRect(
          borderRadius: AppRadius.md,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const padding = EdgeInsets.fromLTRB(0, 10, 10, 10);
              Widget content = SingleChildScrollView(
                controller: _verticalScrollController,
                padding: padding,
                child: _wrapLines ? child : IntrinsicWidth(child: child),
              );

              if (!_wrapLines) {
                content = SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: content,
                  ),
                );
              }

              return Stack(
                children: <Widget>[
                  Positioned.fill(child: content),
                  Positioned(
                    top: 8,
                    right: 3,
                    bottom: 8,
                    child: _MiniMap(
                      lineCount: lineCount,
                      matches: matches,
                      currentMatchLine: matches.isEmpty
                          ? null
                          : matches[_currentMatchIndex],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    _ManifestDocumentBundle document,
    _YamlSection section,
    _ManifestViewData viewData,
    Set<int> visibleLineIndices,
  ) {
    final theme = Theme.of(context);
    final visibleLines = section.visibleLineIndices(
      visibleDocumentLines: visibleLineIndices,
      query: viewData.query,
    );

    if (viewData.query.isNotEmpty &&
        visibleLines.isEmpty &&
        !visibleLineIndices.contains(section.startLine)) {
      return const SizedBox.shrink();
    }

    final isMatch = viewData.matches.contains(section.startLine);
    final isCurrentMatch =
        viewData.matches.isNotEmpty &&
        viewData.matches[_currentMatchIndex] == section.startLine;

    // Scalars and empty collections render as a single ordinary line.
    if (!section.expandable || section.lineCount <= 1) {
      return _buildCodeLine(
        keyId: 'yaml-${section.startLine}',
        lineNumber: section.startLine + 1,
        line: document.yamlLines[section.startLine],
        syntax: _SourceSyntax.yaml,
        isMatch: isMatch,
        isCurrentMatch: isCurrentMatch,
      );
    }

    final userExpanded = _expandedSections[section.key] ?? true;
    final isExpanded = viewData.query.isNotEmpty ? true : userExpanded;
    final codeStyle = _codeStyle(theme);
    final secondary = theme.colorScheme.onSurfaceVariant;

    final header = InkWell(
      onTap: () {
        setState(() {
          _expandedSections[section.key] = !userExpanded;
        });
      },
      child: _buildLineFrame(
        keyId: 'yaml-${section.startLine}',
        lineNumber: section.startLine + 1,
        isMatch: isMatch,
        isCurrentMatch: isCurrentMatch,
        fold: AnimatedRotation(
          turns: isExpanded ? 0.25 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Icon(Icons.chevron_right_rounded, size: 16, color: secondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              section.key,
              style: codeStyle.copyWith(
                color: yamlTokenColorFor(YamlTokenType.key, theme.brightness),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(':', style: codeStyle),
            if (!isExpanded) ...<Widget>[
              const SizedBox(width: 8),
              _CollapsedBadge(
                label:
                    '${section.lineCount - 1} '
                    '${section.lineCount - 1 == 1 ? 'line' : 'lines'}',
              ),
            ],
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        header,
        // AnimatedSize (not AnimatedCrossFade): the cross-fade positions its
        // hidden child, which would drop out of the IntrinsicWidth used for
        // horizontal scrolling and overflow mid-animation.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topLeft,
          child: isExpanded
              ? _buildExpandableSectionBody(
                  document: document,
                  section: section,
                  viewData: viewData,
                  visibleLines: visibleLines,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCodeLine({
    required String keyId,
    required int lineNumber,
    required String line,
    required _SourceSyntax syntax,
    required bool isMatch,
    required bool isCurrentMatch,
  }) {
    final theme = Theme.of(context);

    return _buildLineFrame(
      keyId: keyId,
      lineNumber: lineNumber,
      isMatch: isMatch,
      isCurrentMatch: isCurrentMatch,
      child: Text.rich(
        softWrap: _wrapLines,
        TextSpan(
          style: _codeStyle(theme).copyWith(
            color: syntax == _SourceSyntax.text
                ? theme.colorScheme.onSurface
                : null,
          ),
          children: _buildSourceLineSpans(
            line,
            syntax,
            brightness: theme.brightness,
            overrideColor: syntax == _SourceSyntax.text
                ? theme.colorScheme.onSurface
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildYamlLine({
    required String keyId,
    required int lineNumber,
    required String line,
    required bool isMatch,
    required bool isCurrentMatch,
  }) {
    return _buildCodeLine(
      keyId: keyId,
      lineNumber: lineNumber,
      line: line,
      syntax: _SourceSyntax.yaml,
      isMatch: isMatch,
      isCurrentMatch: isCurrentMatch,
    );
  }

  Widget _buildDiffLine({
    required String keyId,
    required int lineNumber,
    required DiffLine line,
    required bool isMatch,
    required bool isCurrentMatch,
  }) {
    final theme = Theme.of(context);
    final codeStyle = _codeStyle(theme);
    final (Color? background, Color prefixColor) = switch (line.kind) {
      DiffLineKind.added => (
        AppColors.statusTint(theme, AppColors.healthy),
        AppColors.statusForeground(theme, AppColors.healthy),
      ),
      DiffLineKind.removed => (
        AppColors.statusTint(theme, AppColors.degraded),
        AppColors.statusForeground(theme, AppColors.degraded),
      ),
      DiffLineKind.unchanged => (null, AppColors.tertiaryLabel(theme)),
    };

    return _buildLineFrame(
      keyId: keyId,
      lineNumber: lineNumber,
      isMatch: isMatch,
      isCurrentMatch: isCurrentMatch,
      background: background,
      fold: Text(
        line.prefix,
        style: codeStyle.copyWith(
          color: prefixColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: Text.rich(
        softWrap: _wrapLines,
        TextSpan(
          style: codeStyle,
          children: _buildSourceLineSpans(
            line.text,
            _SourceSyntax.yaml,
            brightness: theme.brightness,
          ),
        ),
      ),
    );
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

  List<TextSpan> _buildSourceLineSpans(
    String line,
    _SourceSyntax syntax, {
    required Brightness brightness,
    Color? overrideColor,
  }) {
    return <TextSpan>[
      for (final token in _tokenizeSourceLine(line, syntax))
        TextSpan(
          text: token.text,
          style: TextStyle(
            color: _sourceTokenColor(
              token,
              brightness: brightness,
              overrideColor: overrideColor,
            ),
          ),
        ),
    ];
  }

  /// Maps YAML and JSON token kinds onto the shared Xcode-style palette.
  Color _sourceTokenColor(
    _SourceToken token, {
    required Brightness brightness,
    Color? overrideColor,
  }) {
    if (overrideColor != null && token.type == null) {
      return overrideColor;
    }

    final YamlTokenType? type = switch (token.type) {
      'key' || 'jsonKey' => YamlTokenType.key,
      'listDash' => YamlTokenType.listDash,
      'stringValue' || 'jsonString' => YamlTokenType.stringValue,
      'numberValue' || 'jsonNumber' => YamlTokenType.numberValue,
      'boolNullValue' || 'jsonLiteral' => YamlTokenType.boolNullValue,
      'comment' => YamlTokenType.comment,
      _ => null,
    };
    return yamlTokenColorFor(type, brightness);
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

  /// One editor row: muted line-number gutter, a narrow fold/prefix column,
  /// then the code. Search matches tint the full row.
  Widget _buildLineFrame({
    required String keyId,
    required int? lineNumber,
    required bool isMatch,
    required bool isCurrentMatch,
    required Widget child,
    Widget? fold,
    Color? background,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final key = _lineKeys.putIfAbsent(keyId, GlobalKey.new);

    final rowColor = isCurrentMatch
        ? AppColors.missing.withValues(alpha: isDark ? 0.32 : 0.26)
        : isMatch
        ? scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10)
        : background;

    return Container(
      key: key,
      color: rowColor,
      constraints: const BoxConstraints(
        minHeight: _codeFontSize * _codeLineHeight,
      ),
      child: Row(
        mainAxisSize: _wrapLines ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _gutterWidth,
            child: Text(
              lineNumber == null ? '' : '$lineNumber',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 11,
                // Match the code line box so numbers sit on the same row.
                height: (_codeFontSize * _codeLineHeight) / 11,
                color: AppColors.tertiaryLabel(theme),
              ),
            ),
          ),
          SizedBox(
            width: _foldColumnWidth,
            height: _codeFontSize * _codeLineHeight,
            child: fold == null ? null : Center(child: fold),
          ),
          if (_wrapLines) Expanded(child: child) else child,
        ],
      ),
    );
  }

  _ManifestDocumentBundle _buildDocumentBundle(String payload) {
    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return _ManifestDocumentBundle(
        yamlLines: payload.split('\n'),
        yamlSections: const <_YamlSection>[],
        jsonLines: payload.split('\n'),
        sourceSyntax: _SourceSyntax.text,
        diff: null,
      );
    }

    final responseMap = decoded is Map<String, dynamic> ? decoded : null;
    final manifestPayload =
        _extractManifestText(
          responseMap?['manifest'] ??
              (responseMap?['resource'] is Map<String, dynamic>
                  ? (responseMap?['resource']
                        as Map<String, dynamic>)['manifest']
                  : null),
        ) ??
        payload;

    dynamic manifestDecoded;
    try {
      manifestDecoded = jsonDecode(manifestPayload);
    } catch (_) {
      final diffSource = responseMap;
      return _ManifestDocumentBundle(
        yamlLines: manifestPayload.split('\n'),
        yamlSections: const <_YamlSection>[],
        jsonLines: manifestPayload.split('\n'),
        sourceSyntax: _SourceSyntax.text,
        diff: diffSource == null ? null : _extractDiffDocument(diffSource),
      );
    }

    String formattedJson;
    try {
      formattedJson = const JsonEncoder.withIndent(
        '  ',
      ).convert(manifestDecoded);
    } catch (_) {
      formattedJson = manifestPayload;
    }

    final jsonLines = formattedJson.split('\n');

    if (manifestDecoded is! Map<String, dynamic>) {
      final diffSource = responseMap;
      final syntax = manifestDecoded is List
          ? _SourceSyntax.yaml
          : _SourceSyntax.json;
      return _ManifestDocumentBundle(
        yamlLines: jsonLines,
        yamlSections: const <_YamlSection>[],
        jsonLines: jsonLines,
        sourceSyntax: syntax,
        diff: diffSource == null ? null : _extractDiffDocument(diffSource),
      );
    }

    if (_hideManagedFields) {
      manifestDecoded = _stripServerFields(manifestDecoded);
    }

    final yamlText = jsonToYaml(manifestDecoded);
    final yamlLines = _trimTrailingEmptyLine(yamlText.split('\n'));
    final sections = _buildSections(manifestDecoded, yamlLines);
    final diffSource = responseMap ?? manifestDecoded;

    return _ManifestDocumentBundle(
      yamlLines: yamlLines,
      yamlSections: sections,
      jsonLines: jsonLines,
      sourceSyntax: _SourceSyntax.yaml,
      diff: _extractDiffDocument(diffSource),
    );
  }

  _DiffDocument? _extractDiffDocument(Map<String, dynamic> decoded) {
    final resource = decoded['resource'];
    final resourceMap = resource is Map<String, dynamic> ? resource : null;
    final desired = _extractManifestText(
      decoded['desiredManifest'] ??
          decoded['desired'] ??
          decoded['targetState'] ??
          (resourceMap?['targetState'] ?? resourceMap?['desired']) ??
          (decoded['target'] ?? resourceMap?['target']),
    );
    final live = _extractManifestText(
      decoded['liveManifest'] ??
          decoded['live'] ??
          decoded['liveState'] ??
          (resourceMap?['liveState'] ?? resourceMap?['live']),
    );
    if (desired == null || live == null) {
      return null;
    }
    final desiredFormatted = _formatForDiff(desired);
    final liveFormatted = _formatForDiff(live);
    return _DiffDocument(
      computeDiffLines(
        _trimTrailingEmptyLine(desiredFormatted.split('\n')),
        _trimTrailingEmptyLine(liveFormatted.split('\n')),
      ),
    );
  }

  /// Normalizes a manifest string to pretty-printed YAML for readable diffs.
  /// Compact JSON from ArgoCD would otherwise compare as single-line blobs.
  String _formatForDiff(String text) {
    try {
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) {
        final cleaned = _hideManagedFields
            ? _stripServerFields(parsed)
            : parsed;
        return jsonToYaml(cleaned);
      }
    } catch (_) {
      // Not JSON — return as-is (already YAML or plain text).
    }
    return text;
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

  String? _extractManifestText(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    if (value is Map<String, dynamic> || value is List) {
      try {
        return jsonToYaml(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  List<_YamlSection> _buildSections(
    Map<String, dynamic> decoded,
    List<String> yamlLines,
  ) {
    final sections = <_YamlSection>[];
    var currentLine = 0;

    for (final entry in decoded.entries) {
      final yamlText = jsonToYaml(<String, dynamic>{entry.key: entry.value});
      final lines = _trimTrailingEmptyLine(yamlText.split('\n'));
      final summaryText = _buildSectionSummary(
        entry.value,
        yamlLines[currentLine],
      );
      sections.add(
        _YamlSection(
          key: entry.key,
          startLine: currentLine,
          endLine: currentLine + lines.length - 1,
          expandable:
              entry.value is Map<String, dynamic> || entry.value is List,
          summaryText: summaryText,
        ),
      );
      currentLine += lines.length;
    }

    return sections;
  }

  _ManifestViewData _activeViewData(_ManifestDocumentBundle document) {
    final query = _searchQuery.trim().toLowerCase();
    return switch (_viewMode) {
      _ManifestViewMode.yaml => _ManifestViewData(
        lines: document.yamlLines,
        matches: _matchIndices(document.yamlLines, query),
        query: query,
      ),
      _ManifestViewMode.json => _ManifestViewData(
        lines: document.jsonLines,
        matches: _matchIndices(document.jsonLines, query),
        query: query,
      ),
      _ManifestViewMode.diff => _ManifestViewData(
        lines:
            document.diff?.lines
                .map((line) => line.text)
                .toList(growable: false) ??
            const <String>[],
        matches: _matchIndices(
          document.diff?.lines
                  .map((line) => '${line.prefix} ${line.text}')
                  .toList(growable: false) ??
              const <String>[],
          query,
        ),
        query: query,
      ),
    };
  }

  List<int> _matchIndices(List<String> lines, String query) {
    if (query.isEmpty) {
      return const <int>[];
    }
    return <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i].toLowerCase().contains(query)) i,
    ];
  }

  Set<int> _visibleLineIndices({
    required List<String> lines,
    required String query,
    required int contextRadius,
  }) {
    if (query.isEmpty) {
      return <int>{for (var i = 0; i < lines.length; i++) i};
    }

    final indices = <int>{};
    for (final match in _matchIndices(lines, query)) {
      final first = match - contextRadius < 0 ? 0 : match - contextRadius;
      final last = match + contextRadius >= lines.length
          ? lines.length - 1
          : match + contextRadius;
      for (var i = first; i <= last; i++) {
        indices.add(i);
      }
    }
    return indices;
  }

  Widget _buildExpandableSectionBody({
    required _ManifestDocumentBundle document,
    required _YamlSection section,
    required _ManifestViewData viewData,
    required List<int> visibleLines,
  }) {
    final contentLines = visibleLines
        .where((int index) => index > section.startLine)
        .toList(growable: false);
    if (contentLines.isEmpty) {
      return const SizedBox.shrink();
    }

    final widgets = <Widget>[];
    for (var i = 0; i < contentLines.length; i++) {
      final globalIndex = contentLines[i];
      widgets.add(
        _buildYamlLine(
          keyId: 'yaml-$globalIndex',
          lineNumber: globalIndex + 1,
          line: document.yamlLines[globalIndex],
          isMatch: viewData.matches.contains(globalIndex),
          isCurrentMatch:
              viewData.matches.isNotEmpty &&
              viewData.matches[_currentMatchIndex] == globalIndex,
        ),
      );
      if (i == contentLines.length - 1) {
        continue;
      }
      final nextIndex = contentLines[i + 1];
      if (nextIndex - globalIndex > 1) {
        widgets.add(
          _buildGapIndicator(
            hiddenLineCount: nextIndex - globalIndex - 1,
            startLine: globalIndex + 2,
            endLine: nextIndex,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget _buildGapIndicator({
    required int hiddenLineCount,
    required int startLine,
    required int endLine,
  }) {
    final theme = Theme.of(context);
    final tertiary = AppColors.tertiaryLabel(theme);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: theme.colorScheme.surfaceContainerHigh,
      child: _buildLineFrame(
        keyId: 'gap-$startLine-$endLine',
        lineNumber: null,
        isMatch: false,
        isCurrentMatch: false,
        fold: Icon(Icons.more_horiz_rounded, size: 14, color: tertiary),
        child: Text(
          '$hiddenLineCount lines hidden between $startLine and $endLine',
          style: _codeStyle(theme).copyWith(fontSize: 11, color: tertiary),
        ),
      ),
    );
  }

  String _scalarValueForLine(String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1 || colonIndex + 1 >= line.length) {
      return line;
    }
    return line.substring(colonIndex + 1).trimLeft();
  }

  String? _buildSectionSummary(dynamic value, String yamlLine) {
    if (value is Map && value.isEmpty) {
      return '{}';
    }
    if (value is List && value.isEmpty) {
      return '[]';
    }
    if (value is Map<String, dynamic> || value is List) {
      return null;
    }
    return _scalarValueForLine(yamlLine);
  }

  bool _allExpandableSectionsExpanded(_ManifestDocumentBundle document) {
    final expandableSections = document.sections.where(
      (_YamlSection section) => section.expandable,
    );
    if (expandableSections.isEmpty) {
      return true;
    }
    return expandableSections.every(
      (_YamlSection section) => _expandedSections[section.key] ?? true,
    );
  }

  void _toggleAllSections(_ManifestDocumentBundle document) {
    final nextExpanded = !_allExpandableSectionsExpanded(document);
    setState(() {
      for (final section in document.sections) {
        if (!section.expandable) {
          continue;
        }
        _expandedSections[section.key] = nextExpanded;
      }
    });
  }

  int get _activeMatchCount {
    if (_searchQuery.trim().isEmpty) {
      return 0;
    }
    return _activeMatches.length;
  }

  void _syncCurrentMatch(int matchCount) {
    if (matchCount == 0) {
      _currentMatchIndex = 0;
      return;
    }
    if (_currentMatchIndex >= matchCount) {
      _currentMatchIndex = matchCount - 1;
    }
  }

  void _scheduleEnsureCurrentMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _ensureCurrentMatchVisible();
    });
  }

  void _ensureCurrentMatchVisible() {
    if (_searchQuery.trim().isEmpty || _activeMatches.isEmpty) {
      return;
    }
    final lineIndex = _activeMatches[_currentMatchIndex];
    final keyId = _viewMode == _ManifestViewMode.yaml
        ? 'yaml-$lineIndex'
        : '${_viewMode.name}-$lineIndex';
    final targetKey = _lineKeys[keyId];
    final context = targetKey?.currentContext;
    if (context == null) {
      return;
    }
    // Reveal vertically only — Scrollable.ensureVisible would also scroll
    // the horizontal code viewport and hide the start of the lines.
    final renderObject = context.findRenderObject();
    if (renderObject == null || !_verticalScrollController.hasClients) {
      return;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      return;
    }
    final position = _verticalScrollController.position;
    final target = viewport
        .getOffsetToReveal(renderObject, 0.2)
        .offset
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    _verticalScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchQuery = '';
        _searchController.clear();
        _currentMatchIndex = 0;
      }
    });
  }

  void _setViewMode(_ManifestViewMode mode) {
    if (mode == _viewMode) {
      return;
    }
    _storeCurrentScrollOffsets();
    setState(() {
      _viewMode = mode;
    });
    _restoreScrollOffsets();
  }

  void _toggleManagedFields() {
    setState(() {
      _hideManagedFields = !_hideManagedFields;
    });
  }

  void _goToPreviousMatch() {
    if (_activeMatches.isEmpty) {
      return;
    }
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _activeMatches.length) %
          _activeMatches.length;
    });
    _scheduleEnsureCurrentMatch();
  }

  void _goToNextMatch() {
    if (_activeMatches.isEmpty) {
      return;
    }
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _activeMatches.length;
    });
    _scheduleEnsureCurrentMatch();
  }

  Future<String> _loadManifest() {
    return widget.controller.fetchResourceManifest(
      applicationName: widget.applicationName,
      namespace: widget.namespace,
      resourceName: widget.resourceName,
      kind: widget.kind,
      group: widget.group,
      version: widget.version,
    );
  }

  void _refreshManifest() {
    _storeCurrentScrollOffsets();
    setState(() {
      _future = _loadManifest();
      _currentMatchIndex = 0;
      _lineKeys.clear();
    });
  }

  Future<void> _copyManifest(String manifest) async {
    String textToCopy;
    switch (_viewMode) {
      case _ManifestViewMode.json:
        try {
          final decoded = jsonDecode(manifest);
          textToCopy = const JsonEncoder.withIndent('  ').convert(decoded);
        } catch (_) {
          textToCopy = manifest;
        }
        break;
      case _ManifestViewMode.yaml:
        try {
          final decoded = jsonDecode(manifest);
          textToCopy = decoded is Map<String, dynamic>
              ? jsonToYaml(decoded)
              : manifest;
        } catch (_) {
          textToCopy = manifest;
        }
        break;
      case _ManifestViewMode.diff:
        final document = _buildDocumentBundle(manifest);
        textToCopy = document.diff == null
            ? manifest
            : document.diff!.lines
                  .map((line) => '${line.prefix} ${line.text}')
                  .join('\n');
        break;
    }

    await Clipboard.setData(ClipboardData(text: textToCopy));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  void _storeCurrentScrollOffsets() {
    if (_verticalScrollController.hasClients) {
      _verticalOffsets[_viewMode] = _verticalScrollController.offset;
    }
    if (_horizontalScrollController.hasClients) {
      _horizontalOffsets[_viewMode] = _horizontalScrollController.offset;
    }
  }

  void _restoreScrollOffsets() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final verticalOffset = _verticalOffsets[_viewMode];
      if (verticalOffset != null && _verticalScrollController.hasClients) {
        final maxScrollExtent =
            _verticalScrollController.position.maxScrollExtent;
        _verticalScrollController.jumpTo(
          verticalOffset > maxScrollExtent ? maxScrollExtent : verticalOffset,
        );
      }
      final horizontalOffset = _horizontalOffsets[_viewMode];
      if (horizontalOffset != null && _horizontalScrollController.hasClients) {
        final maxScrollExtent =
            _horizontalScrollController.position.maxScrollExtent;
        _horizontalScrollController.jumpTo(
          horizontalOffset > maxScrollExtent
              ? maxScrollExtent
              : horizontalOffset,
        );
      }
      _ensureCurrentMatchVisible();
    });
  }
}

List<String> _trimTrailingEmptyLine(List<String> lines) {
  if (lines.isNotEmpty && lines.last.isEmpty) {
    return lines.sublist(0, lines.length - 1);
  }
  return lines;
}

class _ManifestDocumentBundle {
  const _ManifestDocumentBundle({
    required this.yamlLines,
    required List<_YamlSection> yamlSections,
    required this.jsonLines,
    required this.sourceSyntax,
    required this.diff,
  }) : sections = yamlSections;

  final List<String> yamlLines;
  final List<_YamlSection> sections;
  final List<String> jsonLines;
  final _SourceSyntax sourceSyntax;
  final _DiffDocument? diff;
}

class _ManifestViewData {
  const _ManifestViewData({
    required this.lines,
    required this.matches,
    required this.query,
  });

  final List<String> lines;
  final List<int> matches;
  final String query;
}

class _YamlSection {
  const _YamlSection({
    required this.key,
    required this.startLine,
    required this.endLine,
    required this.expandable,
    required this.summaryText,
  });

  final String key;
  final int startLine;
  final int endLine;
  final bool expandable;
  final String? summaryText;

  int get lineCount => endLine - startLine + 1;

  List<int> visibleLineIndices({
    required Set<int> visibleDocumentLines,
    required String query,
  }) {
    final firstVisibleLine = expandable ? startLine + 1 : startLine;
    if (query.isEmpty) {
      return <int>[for (var i = firstVisibleLine; i <= endLine; i++) i];
    }

    return <int>[
      for (var i = firstVisibleLine; i <= endLine; i++)
        if (visibleDocumentLines.contains(i)) i,
    ];
  }
}

class _SourceToken {
  const _SourceToken(this.text, this.type);

  final String text;
  final String? type;
}

class _DiffDocument {
  const _DiffDocument(this.lines);

  final List<DiffLine> lines;
}

/// Slim search ruler along the right edge of the code card: one tick per
/// match, the current match highlighted.
class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.lineCount,
    required this.matches,
    required this.currentMatchLine,
  });

  final int lineCount;
  final List<int> matches;
  final int? currentMatchLine;

  @override
  Widget build(BuildContext context) {
    if (lineCount <= 0 || matches.isEmpty) {
      return const SizedBox(width: 4);
    }

    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 4,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final height = constraints.maxHeight;
          return Stack(
            children: <Widget>[
              for (final match in matches)
                Positioned(
                  left: 0,
                  right: 0,
                  top: (match / lineCount) * (height - 6),
                  child: Container(
                    height: currentMatchLine == match ? 6 : 3,
                    decoration: BoxDecoration(
                      color: currentMatchLine == match
                          ? AppColors.missing
                          : scheme.primary.withValues(alpha: 0.7),
                      borderRadius: AppRadius.pill,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Neutral "12 lines" capsule shown after a folded section key.
class _CollapsedBadge extends StatelessWidget {
  const _CollapsedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.fill(theme),
        borderRadius: AppRadius.xs,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 11,
          height: 1.4,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Segment<T> {
  const _Segment({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final IconData icon;
  final String label;
}

/// iOS-style segmented control: neutral track with a sliding raised thumb.
class _SegmentedControl<T> extends StatelessWidget {
  const _SegmentedControl({
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<_Segment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  static const double _segmentWidth = 76;
  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final count = segments.length;
    final selectedIndex = segments.indexWhere(
      (_Segment<T> segment) => segment.value == value,
    );

    return Container(
      height: _height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.fill(theme),
        borderRadius: BorderRadius.circular(9),
      ),
      child: SizedBox(
        width: _segmentWidth * count,
        child: Stack(
          children: <Widget>[
            if (selectedIndex >= 0)
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  count == 1 ? 0 : -1 + 2 * selectedIndex / (count - 1),
                  0,
                ),
                child: Container(
                  width: _segmentWidth,
                  height: _height - 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF636366) : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: isDark
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 1,
                              offset: const Offset(0, 0.5),
                            ),
                          ],
                  ),
                ),
              ),
            Row(
              children: <Widget>[
                for (var i = 0; i < count; i++)
                  _buildSegment(theme, scheme, segments[i], i == selectedIndex),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(
    ThemeData theme,
    ColorScheme scheme,
    _Segment<T> segment,
    bool selected,
  ) {
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: segment.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(segment.value),
        child: SizedBox(
          width: _segmentWidth,
          height: _height - 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(segment.icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                segment.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 13,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
