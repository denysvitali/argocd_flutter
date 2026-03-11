import 'dart:convert';

import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
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

  _ManifestViewMode _viewMode = _ManifestViewMode.yaml;
  _ManifestViewMode _lastNonDiffMode = _ManifestViewMode.yaml;
  bool _showSearch = false;
  bool _wrapLines = false;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.kind}: ${widget.resourceName}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Search',
            onPressed: _toggleSearch,
            icon: const Icon(Icons.search),
          ),
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
                      padding: const EdgeInsets.all(24),
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
                    color: AppColors.ink,
                    child: switch (_viewMode) {
                      _ManifestViewMode.json => _buildJsonView(viewData),
                      _ManifestViewMode.yaml => _buildYamlView(document, viewData),
                      _ManifestViewMode.diff => _buildDiffView(document, viewData),
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
    final matchCount = _activeMatchCount;
    final currentLabel = matchCount == 0 ? '0/0' : '${_currentMatchIndex + 1}/$matchCount';

    return Container(
      color: AppColors.darkSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search manifest...',
                hintStyle: const TextStyle(color: AppColors.grey),
                prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.grey),
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
                fillColor: AppColors.ink,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.cobalt),
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
          const SizedBox(width: 12),
          Text(
            currentLabel,
            style: const TextStyle(
              color: AppColors.border,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          IconButton(
            tooltip: 'Previous match',
            onPressed: matchCount == 0 ? null : _goToPreviousMatch,
            icon: const Icon(Icons.keyboard_arrow_up),
            color: AppColors.border,
          ),
          IconButton(
            tooltip: 'Next match',
            onPressed: matchCount == 0 ? null : _goToNextMatch,
            icon: const Icon(Icons.keyboard_arrow_down),
            color: AppColors.border,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    return _buildScrollableSurface(
      lineCount: document.yamlLines.length,
      matches: viewData.matches,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final section in document.sections)
            _buildSection(document, section, viewData),
        ],
      ),
    );
  }

  Widget _buildDiffView(
    _ManifestDocumentBundle document,
    _ManifestViewData viewData,
  ) {
    if (document.diff == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Desired/live diff is not available for this manifest response.',
            style: TextStyle(color: AppColors.border),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                currentMatchLine: matches.isEmpty ? null : matches[_currentMatchIndex],
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
  ) {
    final hasMatches =
        section.matchingLineIndices(document.yamlLines, viewData.query).isNotEmpty;
    if (viewData.query.isNotEmpty && !hasMatches) {
      return const SizedBox.shrink();
    }

    final userExpanded = _expandedSections[section.key] ?? true;
    final isExpanded = viewData.query.isNotEmpty ? true : userExpanded;
    final visibleLines = section.visibleLineIndices(
      yamlLines: document.yamlLines,
      query: viewData.query,
      contextRadius: _searchContextRadius,
    );

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.darkBorder),
        ),
      ),
      child: Column(
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    section.expandable
                        ? (isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right)
                        : Icons.drag_handle,
                    size: 18,
                    color: section.expandable
                        ? AppColors.cobalt
                        : AppColors.greyLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    section.key,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: AppColors.cobalt,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLineCountBadge(section.lineCount),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeInCubic,
            sizeCurve: Curves.easeInOutCubic,
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final globalIndex in visibleLines)
                    _buildYamlLine(
                      keyId: 'yaml-$globalIndex',
                      lineNumber: globalIndex + 1,
                      line: document.yamlLines[globalIndex],
                      isMatch: viewData.matches.contains(globalIndex),
                      isCurrentMatch:
                          viewData.matches.isNotEmpty &&
                          viewData.matches[_currentMatchIndex] == globalIndex,
                    ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLineCountBadge(int lineCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(
        '$lineCount ${lineCount == 1 ? 'line' : 'lines'}',
        style: const TextStyle(
          color: AppColors.border,
          fontSize: 12,
          fontFamily: 'monospace',
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
                fontSize: 13,
                color: yamlTokenColor(token.type),
                height: 1.5,
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
    return _buildLineFrame(
      keyId: keyId,
      lineNumber: lineNumber,
      isMatch: isMatch,
      isCurrentMatch: isCurrentMatch,
      child: Text(
        line,
        softWrap: _wrapLines,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.border,
          height: 1.5,
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
    final lineColor = switch (line.kind) {
      _DiffKind.added => AppColors.teal,
      _DiffKind.removed => AppColors.coral,
      _DiffKind.changed => AppColors.amber,
      _DiffKind.unchanged => AppColors.border,
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
          fontSize: 13,
          color: lineColor,
          height: 1.5,
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
    final key = _lineKeys.putIfAbsent(keyId, GlobalKey.new);

    return Container(
      key: key,
      color: isCurrentMatch
          ? AppColors.amber.withValues(alpha: 0.18)
          : isMatch
          ? AppColors.cobalt.withValues(alpha: 0.14)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisSize: _wrapLines ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 48,
            child: Text(
              '$lineNumber',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.grey,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_wrapLines) Expanded(child: child) else child,
        ],
      ),
    );
  }

  _ManifestDocumentBundle _buildDocumentBundle(String manifest) {
    dynamic decoded;
    try {
      decoded = jsonDecode(manifest);
    } catch (_) {
      return _ManifestDocumentBundle(
        yamlLines: manifest.split('\n'),
        yamlSections: const <_YamlSection>[],
        jsonLines: manifest.split('\n'),
        diff: null,
      );
    }

    String formattedJson;
    try {
      formattedJson = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      formattedJson = manifest;
    }

    final jsonLines = formattedJson.split('\n');

    if (decoded is! Map<String, dynamic>) {
      return _ManifestDocumentBundle(
        yamlLines: jsonLines,
        yamlSections: const <_YamlSection>[],
        jsonLines: jsonLines,
        diff: null,
      );
    }

    final yamlText = jsonToYaml(decoded);
    final yamlLines = _trimTrailingEmptyLine(yamlText.split('\n'));
    final sections = _buildSections(decoded);

    return _ManifestDocumentBundle(
      yamlLines: yamlLines,
      yamlSections: sections,
      jsonLines: jsonLines,
      diff: _extractDiffDocument(decoded),
    );
  }

  _DiffDocument? _extractDiffDocument(Map<String, dynamic> decoded) {
    final desired = _extractManifestText(decoded['desiredManifest'] ?? decoded['desired']);
    final live = _extractManifestText(decoded['liveManifest'] ?? decoded['live']);
    if (desired == null || live == null) {
      return null;
    }
    return _DiffDocument(_buildDiffLines(desired, live));
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

  List<_YamlSection> _buildSections(Map<String, dynamic> decoded) {
    final sections = <_YamlSection>[];
    var currentLine = 0;

    for (final entry in decoded.entries) {
      final yamlText = jsonToYaml(<String, dynamic>{entry.key: entry.value});
      final lines = _trimTrailingEmptyLine(yamlText.split('\n'));
      sections.add(
        _YamlSection(
          key: entry.key,
          startLine: currentLine,
          endLine: currentLine + lines.length - 1,
          expandable: entry.value is Map<String, dynamic> || entry.value is List,
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
        lines: document.diff?.lines.map((line) => line.text).toList(growable: false) ??
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
    _scheduleEnsureCurrentMatch();
  }

  void _toggleDiffMode() {
    setState(() {
      if (_viewMode == _ManifestViewMode.diff) {
        _viewMode = _lastNonDiffMode;
      } else {
        _lastNonDiffMode = _viewMode;
        _viewMode = _ManifestViewMode.diff;
      }
    });
    _scheduleEnsureCurrentMatch();
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
          textToCopy = decoded is Map<String, dynamic> ? jsonToYaml(decoded) : manifest;
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
  });

  final String key;
  final int startLine;
  final int endLine;
  final bool expandable;

  int get lineCount => endLine - startLine + 1;

  List<int> matchingLineIndices(List<String> yamlLines, String query) {
    if (query.isEmpty) {
      return const <int>[];
    }
    return <int>[
      for (var i = startLine; i <= endLine; i++)
        if (yamlLines[i].toLowerCase().contains(query)) i,
    ];
  }

  List<int> visibleLineIndices({
    required List<String> yamlLines,
    required String query,
    required int contextRadius,
  }) {
    if (query.isEmpty) {
      return <int>[for (var i = startLine; i <= endLine; i++) i];
    }

    final indices = <int>{};
    for (final match in matchingLineIndices(yamlLines, query)) {
      final first = match - contextRadius < startLine
          ? startLine
          : match - contextRadius;
      final last = match + contextRadius > endLine ? endLine : match + contextRadius;
      for (var i = first; i <= last; i++) {
        indices.add(i);
      }
    }

    final sorted = indices.toList()..sort();
    return sorted;
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
      lines.add(_DiffLine(prefix: ' ', text: desired, kind: _DiffKind.unchanged));
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

    return SizedBox(
      width: 10,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final height = constraints.maxHeight;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.darkSurface.withValues(alpha: 0.9),
              border: Border.all(color: AppColors.darkBorder),
              borderRadius: BorderRadius.circular(999),
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
                        borderRadius: BorderRadius.circular(999),
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
