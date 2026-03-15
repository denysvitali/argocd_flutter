import 'dart:convert';

import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';
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

enum _ManifestAction {
  wrap,
  toggleFormat,
  toggleDiff,
  toggleSections,
  toggleManagedFields,
  copy,
  refresh,
}

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
  _ManifestViewMode _lastNonDiffMode = _ManifestViewMode.yaml;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactActions = MediaQuery.sizeOf(context).width < 420;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          compactActions
              ? widget.resourceName
              : '${widget.kind}: ${widget.resourceName}',
        ),
        actions: <Widget>[
          FutureBuilder<String>(
            future: _future,
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final document = _buildDocumentBundle(snapshot.requireData);
              final lineCount = switch (_viewMode) {
                _ManifestViewMode.yaml => document.yamlLines.length,
                _ManifestViewMode.json => document.jsonLines.length,
                _ManifestViewMode.diff => document.diff?.lines.length ?? 0,
              };
              final hasExpandableSections = document.sections.any(
                (_YamlSection section) => section.expandable,
              );
              final allExpanded = _allExpandableSectionsExpanded(document);

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!compactActions)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? 0.55
                                  : 0.9,
                            ),
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        'Lines: $lineCount',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (!compactActions)
                    IconButton(
                      tooltip: allExpanded
                          ? 'Collapse all sections'
                          : 'Expand all sections',
                      onPressed:
                          _viewMode == _ManifestViewMode.yaml &&
                              snapshot.hasData &&
                              hasExpandableSections
                          ? () => _toggleAllSections(document)
                          : null,
                      icon: Icon(
                        allExpanded ? Icons.unfold_less : Icons.unfold_more,
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: _toggleSearch,
            icon: const Icon(Icons.search),
          ),
          if (compactActions)
            FutureBuilder<String>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                final document = snapshot.hasData
                    ? _buildDocumentBundle(snapshot.requireData)
                    : null;
                final hasExpandableSections =
                    document?.sections.any(
                      (_YamlSection section) => section.expandable,
                    ) ??
                    false;
                final allExpanded = document == null
                    ? false
                    : _allExpandableSectionsExpanded(document);

                return PopupMenuButton<_ManifestAction>(
                  tooltip: 'More actions',
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuEntry<_ManifestAction>>[
                      if (snapshot.hasData)
                        CheckedPopupMenuItem<_ManifestAction>(
                          value: _ManifestAction.wrap,
                          checked: _wrapLines,
                          child: Text(
                            _wrapLines
                                ? 'Disable word wrap'
                                : 'Enable word wrap',
                          ),
                        ),
                      if (snapshot.hasData)
                        PopupMenuItem<_ManifestAction>(
                          value: _ManifestAction.toggleFormat,
                          child: Text(
                            _viewMode == _ManifestViewMode.json
                                ? 'Show YAML'
                                : 'Show JSON',
                          ),
                        ),
                      if (snapshot.hasData)
                        PopupMenuItem<_ManifestAction>(
                          value: _ManifestAction.toggleDiff,
                          child: Text(
                            _viewMode == _ManifestViewMode.diff
                                ? 'Hide diff'
                                : 'Show diff',
                          ),
                        ),
                      if (hasExpandableSections)
                        PopupMenuItem<_ManifestAction>(
                          value: _ManifestAction.toggleSections,
                          child: Text(
                            allExpanded
                                ? 'Collapse all sections'
                                : 'Expand all sections',
                          ),
                        ),
                      if (snapshot.hasData)
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
                      case _ManifestAction.wrap:
                        setState(() {
                          _wrapLines = !_wrapLines;
                        });
                      case _ManifestAction.toggleFormat:
                        if (snapshot.hasData) {
                          _toggleJsonYamlMode();
                        }
                      case _ManifestAction.toggleDiff:
                        if (snapshot.hasData) {
                          _toggleDiffMode();
                        }
                      case _ManifestAction.toggleSections:
                        if (document != null) {
                          _toggleAllSections(document);
                        }
                      case _ManifestAction.toggleManagedFields:
                        setState(() {
                          _hideManagedFields = !_hideManagedFields;
                        });
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
            )
          else ...<Widget>[
            IconButton(
              tooltip: _wrapLines ? 'Disable word wrap' : 'Enable word wrap',
              onPressed: () {
                setState(() {
                  _wrapLines = !_wrapLines;
                });
              },
              icon: Icon(_wrapLines ? Icons.wrap_text : Icons.notes),
            ),
            FutureBuilder<String>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                return IconButton(
                  tooltip: _viewMode == _ManifestViewMode.json
                      ? 'Show YAML'
                      : 'Show JSON',
                  onPressed: snapshot.hasData ? _toggleJsonYamlMode : null,
                  icon: Icon(
                    _viewMode == _ManifestViewMode.json
                        ? Icons.data_object
                        : Icons.code,
                  ),
                );
              },
            ),
            FutureBuilder<String>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                return IconButton(
                  tooltip: _viewMode == _ManifestViewMode.diff
                      ? 'Hide diff'
                      : 'Show diff',
                  onPressed: snapshot.hasData ? _toggleDiffMode : null,
                  icon: const Icon(Icons.compare_arrows),
                );
              },
            ),
            IconButton(
              tooltip: _hideManagedFields
                  ? 'Show managed fields'
                  : 'Hide managed fields',
              onPressed: () {
                setState(() {
                  _hideManagedFields = !_hideManagedFields;
                });
              },
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
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_showSearch) _buildSearchBar(),
          Expanded(
            child: FutureBuilder<String>(
              future: _future,
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
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
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _refreshManifest,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final manifest = snapshot.requireData;
                final document = _buildDocumentBundle(manifest);
                final viewData = _activeViewData(document);
                _activeMatches = viewData.matches;
                _syncCurrentMatch(viewData.matches.length);

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: Container(
                    key: ValueKey<String>(_viewMode.name),
                    color: theme.colorScheme.surface,
                    child: switch (_viewMode) {
                      _ManifestViewMode.json => _buildJsonView(viewData),
                      _ManifestViewMode.yaml => _buildYamlView(
                        document,
                        viewData,
                      ),
                      _ManifestViewMode.diff => _buildDiffView(
                        document,
                        viewData,
                      ),
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final matchCount = _activeMatchCount;
    final currentLabel = matchCount == 0
        ? '0/0'
        : '${_currentMatchIndex + 1}/$matchCount';

    return Container(
      color: colorScheme.surfaceContainerHighest.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.65 : 0.9,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _searchController,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search manifest...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: colorScheme.onSurfaceVariant,
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
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.md,
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
          const SizedBox(width: 8),
          Text(
            currentLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          IconButton(
            tooltip: 'Previous match',
            onPressed: matchCount == 0 ? null : _goToPreviousMatch,
            icon: const Icon(Icons.keyboard_arrow_up),
            color: colorScheme.onSurfaceVariant,
          ),
          IconButton(
            tooltip: 'Next match',
            onPressed: matchCount == 0 ? null : _goToNextMatch,
            icon: const Icon(Icons.keyboard_arrow_down),
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildJsonView(_ManifestViewData viewData) {
    return _buildScrollableSurface(
      lineCount: viewData.lines.length,
      matches: viewData.matches,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < viewData.lines.length; i++)
              _buildPlainLine(
                keyId: '${_viewMode.name}-$i',
                lineNumber: i + 1,
                line: viewData.lines[i],
                isMatch: viewData.matches.contains(i),
                isCurrentMatch:
                    viewData.matches.isNotEmpty &&
                    viewData.matches[_currentMatchIndex] == i,
              ),
          ],
        ),
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

    return _buildScrollableSurface(
      lineCount: document.yamlLines.length,
      matches: viewData.matches,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < document.sections.length; i++)
              _buildSection(
                document,
                document.sections[i],
                viewData,
                visibleLineIndices,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffView(
    _ManifestDocumentBundle document,
    _ManifestViewData viewData,
  ) {
    if (document.diff == null) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Desired/live diff is not available for this manifest response.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final diff = document.diff!;
    return _buildScrollableSurface(
      lineCount: diff.lines.length,
      matches: viewData.matches,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
      ),
    );
  }

  Widget _buildScrollableSurface({
    required int lineCount,
    required List<int> matches,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        Widget content = SingleChildScrollView(
          controller: _verticalScrollController,
          padding: const EdgeInsets.only(right: 18),
          child: child,
        );

        if (!_wrapLines) {
          content = SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 18),
              child: content,
            ),
          );
        }

        return Stack(
          children: <Widget>[
            Positioned.fill(child: content),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
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
    );
  }

  Widget _buildSection(
    _ManifestDocumentBundle document,
    _YamlSection section,
    _ManifestViewData viewData,
    Set<int> visibleLineIndices,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleLines = section.visibleLineIndices(
      visibleDocumentLines: visibleLineIndices,
      query: viewData.query,
    );

    if (viewData.query.isNotEmpty &&
        visibleLines.isEmpty &&
        !visibleLineIndices.contains(section.startLine)) {
      return const SizedBox.shrink();
    }

    final userExpanded = _expandedSections[section.key] ?? true;
    final isExpanded = viewData.query.isNotEmpty ? true : userExpanded;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: section.expandable
                ? () {
                    setState(() {
                      _expandedSections[section.key] = !userExpanded;
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    section.expandable
                        ? (isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right)
                        : Icons.drag_handle,
                    size: 16,
                    color: section.expandable
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    section.key,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeInCubic,
            sizeCurve: Curves.easeInOutCubic,
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded && section.expandable
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: EdgeInsets.zero,
              child: _buildExpandableSectionBody(
                document: document,
                section: section,
                viewData: viewData,
                visibleLines: visibleLines,
              ),
            ),
            secondChild: section.expandable
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
                    child: _buildScalarSectionLine(document, section, viewData),
                  ),
          ),
        ],
      );
  }


  Widget _buildYamlLine({
    required String keyId,
    required int lineNumber,
    required String line,
    required bool isMatch,
    required bool isCurrentMatch,
  }) {
    final theme = Theme.of(context);
    final tokens = tokenizeYamlLine(line);
    return _buildLineFrame(
      keyId: keyId,
      lineNumber: lineNumber,
      isMatch: isMatch,
      isCurrentMatch: isCurrentMatch,
      child: Wrap(
        spacing: 0,
        runSpacing: 0,
        children: <Widget>[
          for (final token in tokens)
            Text(
              token.text,
              softWrap: _wrapLines,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: yamlTokenColor(token.type).withValues(
                  alpha: theme.brightness == Brightness.dark ? 1 : 0.92,
                ),
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlainLine({
    required String keyId,
    required int lineNumber,
    required String line,
    required bool isMatch,
    required bool isCurrentMatch,
  }) {
    final theme = Theme.of(context);
    return _buildLineFrame(
      keyId: keyId,
      lineNumber: lineNumber,
      isMatch: isMatch,
      isCurrentMatch: isCurrentMatch,
      child: Text(
        line,
        softWrap: _wrapLines,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildDiffLine({
    required String keyId,
    required int lineNumber,
    required _DiffLine line,
    required bool isMatch,
    required bool isCurrentMatch,
  }) {
    final theme = Theme.of(context);
    final lineColor = switch (line.kind) {
      _DiffKind.added => AppColors.teal,
      _DiffKind.removed => AppColors.coral,
      _DiffKind.changed => AppColors.amber,
      _DiffKind.unchanged => theme.colorScheme.onSurface,
    };

    return _buildLineFrame(
      keyId: keyId,
      lineNumber: lineNumber,
      isMatch: isMatch,
      isCurrentMatch: isCurrentMatch,
      child: Text(
        '${line.prefix} ${line.text}',
        softWrap: _wrapLines,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: lineColor,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildLineFrame({
    required String keyId,
    required int lineNumber,
    required bool isMatch,
    required bool isCurrentMatch,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final key = _lineKeys.putIfAbsent(keyId, GlobalKey.new);

    return Container(
      key: key,
      color: isCurrentMatch
          ? AppColors.amber.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.22 : 0.28,
            )
          : isMatch
          ? colorScheme.primary.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.16 : 0.12,
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisSize: _wrapLines ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 48,
            child: Text(
              '$lineNumber',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
        diff: null,
      );
    }

    final responseMap = decoded is Map<String, dynamic> ? decoded : null;
    final manifestPayload = _extractManifestText(
          responseMap?['manifest'] ??
              (responseMap?['resource'] is Map<String, dynamic>
                  ? (responseMap?['resource'] as Map<String, dynamic>)['manifest']
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
        diff: diffSource == null ? null : _extractDiffDocument(diffSource),
      );
    }

    String formattedJson;
    try {
      formattedJson = const JsonEncoder.withIndent('  ').convert(manifestDecoded);
    } catch (_) {
      formattedJson = manifestPayload;
    }

    final jsonLines = formattedJson.split('\n');

    if (manifestDecoded is! Map<String, dynamic>) {
      final diffSource = responseMap;
      return _ManifestDocumentBundle(
        yamlLines: jsonLines,
        yamlSections: const <_YamlSection>[],
        jsonLines: jsonLines,
        diff: diffSource == null ? null : _extractDiffDocument(diffSource),
      );
    }

    if (_hideManagedFields) {
      manifestDecoded = _stripManagedFields(manifestDecoded);
    }

    final yamlText = jsonToYaml(manifestDecoded);
    final yamlLines = _trimTrailingEmptyLine(yamlText.split('\n'));
    final sections = _buildSections(manifestDecoded, yamlLines);
    final diffSource = responseMap ?? manifestDecoded;

    return _ManifestDocumentBundle(
      yamlLines: yamlLines,
      yamlSections: sections,
      jsonLines: jsonLines,
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
    return _DiffDocument(_buildDiffLines(desired, live));
  }

  Map<String, dynamic> _stripManagedFields(Map<String, dynamic> obj) {
    final result = Map<String, dynamic>.of(obj);
    final metadata = result['metadata'];
    if (metadata is Map<String, dynamic> &&
        metadata.containsKey('managedFields')) {
      result['metadata'] =
          Map<String, dynamic>.of(metadata)..remove('managedFields');
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  Widget _buildScalarSectionLine(
    _ManifestDocumentBundle document,
    _YamlSection section,
    _ManifestViewData viewData,
  ) {
    final lineText = document.yamlLines[section.startLine];
    final valueText = _scalarValueForLine(lineText);
    return _buildYamlLine(
      keyId: 'yaml-${section.startLine}',
      lineNumber: section.startLine + 1,
      line: valueText,
      isMatch: viewData.matches.contains(section.startLine),
      isCurrentMatch:
          viewData.matches.isNotEmpty &&
          viewData.matches[_currentMatchIndex] == section.startLine,
    );
  }

  Widget _buildGapIndicator({
    required int hiddenLineCount,
    required int startLine,
    required int endLine,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        '... $hiddenLineCount lines hidden between $startLine and $endLine ...',
        style: theme.textTheme.labelSmall?.copyWith(
          fontFamily: 'monospace',
          color: colorScheme.onSurfaceVariant,
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
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.2,
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

  void _toggleJsonYamlMode() {
    _storeCurrentScrollOffsets();
    setState(() {
      if (_viewMode == _ManifestViewMode.diff) {
        _viewMode = _lastNonDiffMode;
      } else {
        _viewMode = _viewMode == _ManifestViewMode.json
            ? _ManifestViewMode.yaml
            : _ManifestViewMode.json;
        _lastNonDiffMode = _viewMode;
      }
    });
    _restoreScrollOffsets();
  }

  void _toggleDiffMode() {
    _storeCurrentScrollOffsets();
    setState(() {
      if (_viewMode == _ManifestViewMode.diff) {
        _viewMode = _lastNonDiffMode;
      } else {
        _lastNonDiffMode = _viewMode;
        _viewMode = _ManifestViewMode.diff;
      }
    });
    _restoreScrollOffsets();
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
    required this.diff,
  }) : sections = yamlSections;

  final List<String> yamlLines;
  final List<_YamlSection> sections;
  final List<String> jsonLines;
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

class _DiffDocument {
  const _DiffDocument(this.lines);

  final List<_DiffLine> lines;
}

enum _DiffKind { unchanged, added, removed, changed }

class _DiffLine {
  const _DiffLine({
    required this.prefix,
    required this.text,
    required this.kind,
  });

  final String prefix;
  final String text;
  final _DiffKind kind;
}

List<_DiffLine> _buildDiffLines(String desiredText, String liveText) {
  final desiredLines = _trimTrailingEmptyLine(desiredText.split('\n'));
  final liveLines = _trimTrailingEmptyLine(liveText.split('\n'));
  final maxLines = desiredLines.length > liveLines.length
      ? desiredLines.length
      : liveLines.length;
  final lines = <_DiffLine>[];

  for (var i = 0; i < maxLines; i++) {
    final desired = i < desiredLines.length ? desiredLines[i] : null;
    final live = i < liveLines.length ? liveLines[i] : null;

    if (desired == live && desired != null) {
      lines.add(
        _DiffLine(prefix: ' ', text: desired, kind: _DiffKind.unchanged),
      );
      continue;
    }
    if (desired == null && live != null) {
      lines.add(_DiffLine(prefix: '+', text: live, kind: _DiffKind.added));
      continue;
    }
    if (live == null && desired != null) {
      lines.add(_DiffLine(prefix: '-', text: desired, kind: _DiffKind.removed));
      continue;
    }
    if (desired != null) {
      lines.add(_DiffLine(prefix: '-', text: desired, kind: _DiffKind.removed));
    }
    if (live != null) {
      lines.add(_DiffLine(prefix: '+', text: live, kind: _DiffKind.added));
    }
  }

  return lines;
}

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
    if (lineCount <= 0) {
      return const SizedBox(width: 10);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 10,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final height = constraints.maxHeight;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.9 : 0.95,
              ),
              border: Border.all(color: colorScheme.outlineVariant),
              borderRadius: AppRadius.pill,
            ),
            child: Stack(
              children: <Widget>[
                for (final match in matches)
                  Positioned(
                    left: 1,
                    right: 1,
                    top: (match / lineCount) * (height - 6),
                    child: Container(
                      height: currentMatchLine == match ? 6 : 4,
                      decoration: BoxDecoration(
                        color: currentMatchLine == match
                            ? AppColors.amber
                            : AppColors.cobalt,
                        borderRadius: AppRadius.pill,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
