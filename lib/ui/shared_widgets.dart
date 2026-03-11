import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

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
    final entries = value.entries.toList(growable: false);
    for (final entry in entries) {
      buffer.write('$prefix${entry.key}:');
      if (entry.value is Map<String, dynamic> || entry.value is List) {
        final isEmpty = (entry.value is Map && (entry.value as Map).isEmpty) ||
            (entry.value is List && (entry.value as List).isEmpty);
        if (isEmpty) {
          buffer.write(' ');
        }
        _writeYamlValue(buffer, entry.value, indent: indent + 2);
      } else if (entry.value is String) {
        final stringValue = entry.value as String;
        if (stringValue.contains('\n')) {
          _writeYamlScalar(buffer, stringValue, indent: indent + 2);
        } else {
          buffer.write(' ');
          _writeYamlScalar(buffer, stringValue, indent: indent + 2);
          buffer.writeln();
        }
      } else {
        buffer.write(' ');
        _writeYamlScalar(buffer, entry.value, indent: indent + 2);
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
        final entries = item.entries.toList(growable: false);
        buffer.write('$prefix- ${entries.first.key}:');
        if (entries.first.value is Map<String, dynamic> ||
            entries.first.value is List) {
          _writeYamlValue(
            buffer,
            entries.first.value,
            indent: indent + 4,
          );
        } else if (entries.first.value is String) {
          final stringValue = entries.first.value as String;
          if (stringValue.contains('\n')) {
            _writeYamlScalar(buffer, stringValue, indent: indent + 4);
          } else {
            buffer.write(' ');
            _writeYamlScalar(buffer, stringValue, indent: indent + 4);
            buffer.writeln();
          }
        } else {
          buffer.write(' ');
          _writeYamlScalar(buffer, entries.first.value, indent: indent + 4);
          buffer.writeln();
        }
        for (var i = 1; i < entries.length; i++) {
          buffer.write('$prefix  ${entries[i].key}:');
          if (entries[i].value is Map<String, dynamic> ||
              entries[i].value is List) {
            _writeYamlValue(
              buffer,
              entries[i].value,
              indent: indent + 4,
            );
          } else if (entries[i].value is String) {
            final stringValue = entries[i].value as String;
            if (stringValue.contains('\n')) {
              _writeYamlScalar(buffer, stringValue, indent: indent + 4);
            } else {
              buffer.write(' ');
              _writeYamlScalar(buffer, stringValue, indent: indent + 4);
              buffer.writeln();
            }
          } else {
            buffer.write(' ');
            _writeYamlScalar(buffer, entries[i].value, indent: indent + 4);
            buffer.writeln();
          }
        }
      } else if (item is List) {
        buffer.write('$prefix-');
        _writeYamlValue(buffer, item, indent: indent + 2);
      } else if (item is String && item.contains('\n')) {
        buffer.write('$prefix-');
        _writeYamlScalar(buffer, item, indent: indent + 2);
      } else {
        buffer.write('$prefix- ');
        _writeYamlScalar(buffer, item, indent: indent + 2);
        buffer.writeln();
      }
    }
  } else {
    _writeYamlScalar(buffer, value, indent: indent);
    buffer.writeln();
  }
}

void _writeYamlScalar(StringBuffer buffer, dynamic value, {required int indent}) {
  if (value == null) {
    buffer.write('null');
  } else if (value is bool) {
    buffer.write(value ? 'true' : 'false');
  } else if (value is num) {
    buffer.write(value);
  } else {
    final str = value.toString();
    if (str.contains('\n')) {
      final lines = str.split('\n');
      buffer.writeln(' |');
      for (final line in lines) {
        buffer.writeln('${' ' * indent}$line');
      }
    } else if (_needsQuoting(str)) {
      buffer.write("'${str.replaceAll("'", "''")}'");
    } else {
      buffer.write(str);
    }
  }
}

bool needsYamlQuoting(String str) => _needsQuoting(str);

bool _needsQuoting(String str) {
  if (str.isEmpty) return true;
  if (str.contains('\n') || str.contains(':') || str.contains('#')) return true;
  if (str.startsWith(' ') || str.endsWith(' ')) return true;
  if (str.startsWith('{') || str.startsWith('[')) return true;
  if (str.startsWith('"') || str.startsWith("'")) return true;
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
  final trimmedLeft = line.trimLeft();

  if (trimmedLeft.startsWith('- ') || trimmedLeft == '-') {
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
  final colonIndex = _findKeySeparator(text);
  if (colonIndex != null) {
    final beforeColon = text.substring(0, colonIndex);
    tokens.add(YamlToken(beforeColon, YamlTokenType.key));
    tokens.add(const YamlToken(':', YamlTokenType.key));
    final afterColon = text.substring(colonIndex + 1);
    if (afterColon.isNotEmpty) {
      tokens.addAll(_tokenizeValue(afterColon));
    }
    return tokens;
  }

  tokens.addAll(_tokenizeValue(text));
  return tokens;
}

int? _findKeySeparator(String text) {
  var inSingleQuotes = false;
  var inDoubleQuotes = false;

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == "'" && !inDoubleQuotes) {
      inSingleQuotes = !inSingleQuotes;
      continue;
    }
    if (char == '"' && !inSingleQuotes) {
      inDoubleQuotes = !inDoubleQuotes;
      continue;
    }
    if (char != ':' || inSingleQuotes || inDoubleQuotes) {
      continue;
    }
    final nextChar = i + 1 < text.length ? text[i + 1] : '';
    if (nextChar.isNotEmpty && nextChar != ' ') {
      continue;
    }
    final beforeColon = text.substring(0, i);
    final trimmed = beforeColon.trimLeft();
    if (trimmed.isEmpty ||
        trimmed.startsWith("'") ||
        trimmed.startsWith('"') ||
        trimmed.contains('{') ||
        trimmed.contains('[')) {
      continue;
    }
    return i;
  }
  return null;
}

List<YamlToken> _tokenizeValue(String text) {
  if (text.trim().isEmpty) {
    return <YamlToken>[YamlToken(text, null)];
  }

  final trimmed = text.trim();
  final leadingSpace = text.substring(0, text.length - text.trimLeft().length);

  if (trimmed == 'null' || trimmed == 'true' || trimmed == 'false') {
    return <YamlToken>[
      if (leadingSpace.isNotEmpty) YamlToken(leadingSpace, null),
      YamlToken(trimmed, YamlTokenType.boolNullValue),
    ];
  }
  if (num.tryParse(trimmed) != null) {
    return <YamlToken>[
      if (leadingSpace.isNotEmpty) YamlToken(leadingSpace, null),
      YamlToken(trimmed, YamlTokenType.numberValue),
    ];
  }
  if (trimmed == '{}' || trimmed == '[]' || trimmed == '|') {
    return <YamlToken>[
      if (leadingSpace.isNotEmpty) YamlToken(leadingSpace, null),
      YamlToken(trimmed, YamlTokenType.stringValue),
    ];
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

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.24 : 0.12,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(subtitle),
        ],
      ),
    );
  }
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final int value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '$value',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class FactBadge extends StatelessWidget {
  const FactBadge({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(child: Icon(icon, size: 18)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
