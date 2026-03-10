import 'dart:convert';

import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Converts a decoded JSON value to a YAML-formatted string.
String jsonToYaml(dynamic value, {int indent = 0}) {
  final buffer = StringBuffer();
  _writeYamlValue(buffer, value, indent: indent, isTopLevel: true);
  return buffer.toString();
}

void _writeYamlValue(
  StringBuffer buffer,
  dynamic value, {
  required int indent,
  bool isTopLevel = false,
}) {
  final prefix = ' ' * indent;

  if (value is Map<String, dynamic>) {
    if (value.isEmpty) {
      buffer.writeln('{}');
      return;
    }
    if (!isTopLevel) {
      buffer.writeln();
    }
    final entries = value.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('$prefix${entry.key}:');
      if (entry.value is Map<String, dynamic> || entry.value is List) {
        final isEmpty = (entry.value is Map && (entry.value as Map).isEmpty) ||
            (entry.value is List && (entry.value as List).isEmpty);
        if (isEmpty) {
          buffer.write(' ');
        }
        _writeYamlValue(buffer, entry.value, indent: indent + 2);
      } else {
        buffer.write(' ');
        _writeYamlScalar(buffer, entry.value);
        buffer.writeln();
      }
    }
  } else if (value is List) {
    if (value.isEmpty) {
      buffer.writeln('[]');
      return;
    }
    buffer.writeln();
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        if (item.isEmpty) {
          buffer.writeln('$prefix- {}');
          continue;
        }
        final entries = item.entries.toList();
        // First entry goes on the same line as the dash
        buffer.write('$prefix- ${entries.first.key}:');
        if (entries.first.value is Map<String, dynamic> ||
            entries.first.value is List) {
          _writeYamlValue(
            buffer,
            entries.first.value,
            indent: indent + 4,
          );
        } else {
          buffer.write(' ');
          _writeYamlScalar(buffer, entries.first.value);
          buffer.writeln();
        }
        // Remaining entries indented under the dash
        for (var i = 1; i < entries.length; i++) {
          buffer.write('$prefix  ${entries[i].key}:');
          if (entries[i].value is Map<String, dynamic> ||
              entries[i].value is List) {
            _writeYamlValue(
              buffer,
              entries[i].value,
              indent: indent + 4,
            );
          } else {
            buffer.write(' ');
            _writeYamlScalar(buffer, entries[i].value);
            buffer.writeln();
          }
        }
      } else if (item is List) {
        buffer.write('$prefix-');
        _writeYamlValue(buffer, item, indent: indent + 2);
      } else {
        buffer.write('$prefix- ');
        _writeYamlScalar(buffer, item);
        buffer.writeln();
      }
    }
  } else {
    _writeYamlScalar(buffer, value);
    buffer.writeln();
  }
}

void _writeYamlScalar(StringBuffer buffer, dynamic value) {
  if (value == null) {
    buffer.write('null');
  } else if (value is bool) {
    buffer.write(value ? 'true' : 'false');
  } else if (value is num) {
    buffer.write(value);
  } else {
    final str = value.toString();
    if (_needsQuoting(str)) {
      buffer.write("'${str.replaceAll("'", "''")}'");
    } else {
      buffer.write(str);
    }
  }
}

bool _needsQuoting(String str) {
  if (str.isEmpty) return true;
  if (str.contains('\n') || str.contains(':') || str.contains('#')) return true;
  if (str.startsWith(' ') || str.endsWith(' ')) return true;
  if (str.startsWith('{') || str.startsWith('[')) return true;
  if (str.startsWith('"') || str.startsWith("'")) return true;
  // Quote values that look like booleans, null, or numbers
  final lower = str.toLowerCase();
  if (lower == 'true' || lower == 'false' || lower == 'null') return true;
  if (num.tryParse(str) != null) return true;
  return false;
}

/// Identifies the type of a YAML token for syntax highlighting.
enum YamlTokenType { key, stringValue, numberValue, boolNullValue, listDash }

/// A single syntax-highlighted span in a YAML line.
class YamlToken {
  const YamlToken(this.text, this.type);

  final String text;
  final YamlTokenType? type;
}

/// Tokenises a single line of YAML for syntax highlighting.
List<YamlToken> tokenizeYamlLine(String line) {
  final tokens = <YamlToken>[];

  if (line.trimLeft().startsWith('- ') || line.trimLeft() == '-') {
    final dashIndex = line.indexOf('-');
    if (dashIndex > 0) {
      tokens.add(YamlToken(line.substring(0, dashIndex), null));
    }
    tokens.add(const YamlToken('-', YamlTokenType.listDash));
    final rest = line.substring(dashIndex + 1);
    if (rest.isNotEmpty) {
      tokens.addAll(_tokenizeKeyValue(rest));
    }
    return tokens;
  }

  tokens.addAll(_tokenizeKeyValue(line));
  return tokens;
}

List<YamlToken> _tokenizeKeyValue(String text) {
  final tokens = <YamlToken>[];
  // Look for a key: value pattern
  final colonIndex = text.indexOf(':');
  if (colonIndex > 0) {
    final beforeColon = text.substring(0, colonIndex);
    // Only treat as key if the part before colon is a simple identifier
    // (possibly with leading whitespace)
    if (beforeColon.trimLeft().isNotEmpty &&
        !beforeColon.trimLeft().startsWith("'") &&
        !beforeColon.trimLeft().startsWith('"')) {
      tokens.add(YamlToken(beforeColon, YamlTokenType.key));
      tokens.add(const YamlToken(':', YamlTokenType.key));
      final afterColon = text.substring(colonIndex + 1);
      if (afterColon.isNotEmpty) {
        tokens.addAll(_tokenizeValue(afterColon));
      }
      return tokens;
    }
  }
  // No key found, treat as a value
  tokens.addAll(_tokenizeValue(text));
  return tokens;
}

List<YamlToken> _tokenizeValue(String text) {
  if (text.trim().isEmpty) {
    return <YamlToken>[YamlToken(text, null)];
  }

  final trimmed = text.trim();
  final leadingSpace = text.substring(0, text.length - text.trimLeft().length);

  if (trimmed == 'null') {
    return <YamlToken>[
      if (leadingSpace.isNotEmpty) YamlToken(leadingSpace, null),
      const YamlToken('null', YamlTokenType.boolNullValue),
    ];
  }
  if (trimmed == 'true' || trimmed == 'false') {
    return <YamlToken>[
      if (leadingSpace.isNotEmpty) YamlToken(leadingSpace, null),
      YamlToken(trimmed, YamlTokenType.numberValue),
    ];
  }
  if (num.tryParse(trimmed) != null) {
    return <YamlToken>[
      if (leadingSpace.isNotEmpty) YamlToken(leadingSpace, null),
      YamlToken(trimmed, YamlTokenType.numberValue),
    ];
  }
  if (trimmed == '{}' || trimmed == '[]') {
    return <YamlToken>[YamlToken(text, null)];
  }

  return <YamlToken>[
    if (leadingSpace.isNotEmpty) YamlToken(leadingSpace, null),
    YamlToken(trimmed, YamlTokenType.stringValue),
  ];
}

/// Returns the color for a given YAML token type.
Color yamlTokenColor(YamlTokenType? type) {
  return switch (type) {
    YamlTokenType.key => AppColors.cobalt,
    YamlTokenType.stringValue => AppColors.teal,
    YamlTokenType.numberValue => AppColors.amber,
    YamlTokenType.boolNullValue => AppColors.grey,
    YamlTokenType.listDash => AppColors.coral,
    null => AppColors.border,
  };
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
  late Future<String> _future;
  bool _showRawJson = false;
  bool _showSearch = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _expandedSections = <String, bool>{};

  @override
  void initState() {
    super.initState();
    _future = _loadManifest();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
            icon: const Icon(Icons.search),
          ),
          FutureBuilder<String>(
            future: _future,
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              return IconButton(
                tooltip: _showRawJson ? 'Show YAML' : 'Show JSON',
                onPressed: snapshot.hasData
                    ? () {
                        setState(() {
                          _showRawJson = !_showRawJson;
                        });
                      }
                    : null,
                icon: Icon(
                  _showRawJson ? Icons.data_object : Icons.code,
                ),
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
          if (_showSearch)
            Container(
              color: AppColors.darkSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  });
                },
              ),
            ),
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

                if (_showRawJson) {
                  return _buildRawJsonView(manifest);
                }

                return _buildYamlView(manifest);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawJsonView(String manifest) {
    String formatted;
    try {
      final decoded = jsonDecode(manifest);
      formatted = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      formatted = manifest;
    }

    final lines = formatted.split('\n');
    final filteredIndices = _getFilteredLineIndices(lines);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.ink,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildLineNumbers(lines.length, filteredIndices),
              const SizedBox(width: 12),
              SelectableText(
                filteredIndices != null
                    ? filteredIndices
                        .map((int i) => lines[i])
                        .join('\n')
                    : formatted,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.border,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYamlView(String manifest) {
    Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(manifest);
      if (decoded is Map<String, dynamic>) {
        parsed = decoded;
      } else {
        // Not a JSON object, show as raw
        return _buildRawJsonView(manifest);
      }
    } catch (_) {
      return _buildRawJsonView(manifest);
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.ink,
      child: ListView.builder(
        padding: const EdgeInsets.all(0),
        itemCount: parsed.keys.length,
        itemBuilder: (BuildContext context, int index) {
          final key = parsed.keys.elementAt(index);
          final value = parsed[key];
          return _buildCollapsibleSection(key, value);
        },
      ),
    );
  }

  Widget _buildCollapsibleSection(String key, dynamic value) {
    final isExpandable = value is Map<String, dynamic> || value is List;
    final isExpanded = _expandedSections[key] ?? true;

    if (!isExpandable) {
      // Simple key-value — render as a single highlighted line
      final yamlLine = '$key: ${_scalarToYaml(value)}';
      if (_searchQuery.isNotEmpty &&
          !yamlLine.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return const SizedBox.shrink();
      }
      final lineNumber = 1; // Standalone line
      return Container(
        color: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 40,
              child: Text(
                '$lineNumber',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppColors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildHighlightedLine(yamlLine),
            ),
          ],
        ),
      );
    }

    final yamlContent = jsonToYaml(<String, dynamic>{key: value});
    final yamlLines = yamlContent.split('\n');
    // Remove trailing empty line from yaml output
    if (yamlLines.isNotEmpty && yamlLines.last.isEmpty) {
      yamlLines.removeLast();
    }

    final filteredIndices = _searchQuery.isNotEmpty
        ? <int>[
            for (var i = 0; i < yamlLines.length; i++)
              if (yamlLines[i]
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
                i,
          ]
        : null;

    if (_searchQuery.isNotEmpty &&
        filteredIndices != null &&
        filteredIndices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>(key),
        initiallyExpanded: isExpanded,
        onExpansionChanged: (bool expanded) {
          setState(() {
            _expandedSections[key] = expanded;
          });
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: EdgeInsets.zero,
        collapsedIconColor: AppColors.grey,
        iconColor: AppColors.cobalt,
        title: Text(
          key,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: AppColors.cobalt,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var i = 0; i < yamlLines.length; i++)
                    if (filteredIndices == null || filteredIndices.contains(i))
                      _buildNumberedLine(i + 1, yamlLines[i]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedLine(int lineNumber, String line) {
    final isHighlighted = _searchQuery.isNotEmpty &&
        line.toLowerCase().contains(_searchQuery.toLowerCase());

    return Container(
      color: isHighlighted
          ? AppColors.cobalt.withValues(alpha: 0.15)
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Text(
              '$lineNumber',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.grey,
                height: 1.5,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          _buildHighlightedLine(line),
        ],
      ),
    );
  }

  Widget _buildHighlightedLine(String line) {
    final tokens = tokenizeYamlLine(line);
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          for (final token in tokens)
            TextSpan(
              text: token.text,
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

  Widget _buildLineNumbers(int totalLines, List<int>? filteredIndices) {
    final indices = filteredIndices ?? List<int>.generate(totalLines, (int i) => i);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final i in indices)
          SizedBox(
            width: 40,
            height: 19.5, // matches line height of 13 * 1.5
            child: Text(
              '${i + 1}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: AppColors.grey,
                height: 1.5,
              ),
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );
  }

  List<int>? _getFilteredLineIndices(List<String> lines) {
    if (_searchQuery.isEmpty) return null;
    final query = _searchQuery.toLowerCase();
    return <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i].toLowerCase().contains(query)) i,
    ];
  }

  String _scalarToYaml(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return '$value';
    final str = value.toString();
    if (_needsQuoting(str)) {
      return "'${str.replaceAll("'", "''")}'";
    }
    return str;
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
    });
  }

  Future<void> _copyManifest(String manifest) async {
    var textToCopy = manifest;
    if (_showRawJson) {
      try {
        final decoded = jsonDecode(manifest);
        textToCopy = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        // Keep original manifest
      }
    } else {
      try {
        final decoded = jsonDecode(manifest);
        if (decoded is Map<String, dynamic>) {
          textToCopy = jsonToYaml(decoded);
        }
      } catch (_) {
        // Keep original manifest
      }
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
