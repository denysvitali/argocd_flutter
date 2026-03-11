import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

const EdgeInsets kPagePadding = EdgeInsets.fromLTRB(14, 10, 14, 16);

/// Converts a decoded JSON value to a YAML-formatted string.
String jsonToYaml(dynamic value, {int indent = 0}) {
  return _yamlLinesForValue(value, indent: indent).join('\n');
}

List<String> _yamlLinesForValue(dynamic value, {required int indent}) {
  if (value is Map) {
    return _yamlLinesForMap(
      value.map(
        (dynamic key, dynamic nestedValue) =>
            MapEntry(key.toString(), nestedValue),
      ),
      indent: indent,
    );
  }
  if (value is List) {
    return _yamlLinesForList(value, indent: indent);
  }
  return <String>[_yamlScalarAsLine(value, indent: indent)];
}

List<String> _yamlLinesForMap(
  Map<String, dynamic> value, {
  required int indent,
}) {
  final prefix = ' ' * indent;
  if (value.isEmpty) {
    return <String>['$prefix{}'];
  }

  final lines = <String>[];
  for (final entry in value.entries) {
    if (entry.value is Map && (entry.value as Map).isEmpty) {
      lines.add('$prefix${entry.key}: {}');
      continue;
    }

    if (entry.value is List && (entry.value as List).isEmpty) {
      lines.add('$prefix${entry.key}: []');
      continue;
    }

    final scalarLine = _yamlScalarLineOrNull(entry.value);
    if (scalarLine != null) {
      lines.add('$prefix${entry.key}: $scalarLine');
      continue;
    }

    final blockHeader = _yamlBlockHeaderOrNull(entry.value);
    if (blockHeader != null) {
      lines.add('$prefix${entry.key}: $blockHeader');
      lines.addAll(
        _yamlMultilineStringLines(entry.value as String, indent + 2),
      );
      continue;
    }

    lines.add('$prefix${entry.key}:');
    lines.addAll(_yamlLinesForValue(entry.value, indent: indent + 2));
  }
  return lines;
}

List<String> _yamlLinesForList(List<dynamic> value, {required int indent}) {
  final prefix = ' ' * indent;
  if (value.isEmpty) {
    return <String>['$prefix[]'];
  }

  final lines = <String>[];
  for (final item in value) {
    if (item is List && item.isEmpty) {
      lines.add('$prefix- []');
      continue;
    }

    final scalarLine = _yamlScalarLineOrNull(item);
    if (scalarLine != null) {
      lines.add('$prefix- $scalarLine');
      continue;
    }

    if (item is String && item.contains('\n')) {
      lines.add('$prefix- |');
      lines.addAll(_yamlMultilineStringLines(item, indent + 2));
      continue;
    }

    if (item is Map<String, dynamic>) {
      if (item.isEmpty) {
        lines.add('$prefix- {}');
        continue;
      }

      final entries = item.entries.toList(growable: false);
      final firstEntry = entries.first;
      final firstScalarLine = _yamlScalarLineOrNull(firstEntry.value);
      if (firstScalarLine != null) {
        lines.add('$prefix- ${firstEntry.key}: $firstScalarLine');
      } else if (firstEntry.value is String &&
          (firstEntry.value as String).contains('\n')) {
        lines.add('$prefix- ${firstEntry.key}: |');
        lines.addAll(
          _yamlMultilineStringLines(firstEntry.value as String, indent + 4),
        );
      } else {
        lines.add('$prefix- ${firstEntry.key}:');
        lines.addAll(_yamlLinesForValue(firstEntry.value, indent: indent + 4));
      }

      for (var i = 1; i < entries.length; i++) {
        final entry = entries[i];
        final entryScalarLine = _yamlScalarLineOrNull(entry.value);
        if (entryScalarLine != null) {
          lines.add('$prefix  ${entry.key}: $entryScalarLine');
          continue;
        }
        if (entry.value is String && (entry.value as String).contains('\n')) {
          lines.add('$prefix  ${entry.key}: |');
          lines.addAll(
            _yamlMultilineStringLines(entry.value as String, indent + 4),
          );
          continue;
        }
        lines.add('$prefix  ${entry.key}:');
        lines.addAll(_yamlLinesForValue(entry.value, indent: indent + 4));
      }
      continue;
    }

    lines.add('$prefix-');
    lines.addAll(_yamlLinesForValue(item, indent: indent + 2));
  }

  return lines;
}

String _yamlScalarAsLine(dynamic value, {required int indent}) {
  final scalarLine = _yamlScalarLineOrNull(value);
  if (scalarLine != null) {
    return '${' ' * indent}$scalarLine';
  }
  final blockHeader = _yamlBlockHeaderOrNull(value);
  if (blockHeader != null) {
    return '${' ' * indent}$blockHeader';
  }
  return '${' ' * indent}${value.toString()}';
}

String? _yamlScalarLineOrNull(dynamic value) {
  if (value is Map || value is List) {
    return null;
  }
  if (value == null) {
    return 'null';
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  if (value is num) {
    return value.toString();
  }
  final str = value.toString();
  if (str.contains('\n')) {
    return null;
  }
  if (_needsQuoting(str)) {
    return "'${str.replaceAll("'", "''")}'";
  }
  return str;
}

String? _yamlBlockHeaderOrNull(dynamic value) {
  if (value is String && value.contains('\n')) {
    return '|';
  }
  return null;
}

List<String> _yamlMultilineStringLines(String value, int indent) {
  final prefix = ' ' * indent;
  return <String>[for (final line in value.split('\n')) '$prefix$line'];
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
enum YamlTokenType {
  key,
  stringValue,
  numberValue,
  boolNullValue,
  listDash,
  comment,
}

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

  // Full-line comment.
  if (trimmedLeft.startsWith('#')) {
    tokens.add(YamlToken(line, YamlTokenType.comment));
    return tokens;
  }

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
///
/// Colours are chosen for readability on a light background (the primary use
/// case) and are applied at ~92 % opacity by the caller in dark mode.
Color yamlTokenColor(YamlTokenType? type) {
  return switch (type) {
    YamlTokenType.key => const Color(0xFF0D47A1),
    YamlTokenType.stringValue => const Color(0xFF1B5E20),
    YamlTokenType.numberValue => const Color(0xFFBF360C),
    YamlTokenType.boolNullValue => const Color(0xFF6A1B9A),
    YamlTokenType.listDash => const Color(0xFF0D47A1),
    YamlTokenType.comment => const Color(0xFF78909C),
    null => const Color(0xFF37474F),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.20 : 0.10,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
          ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.grey,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(child: Icon(icon, size: 14)),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// A small pill showing a label-value pair, used for at-a-glance metadata.
class DetailPill extends StatelessWidget {
  const DetailPill({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label: $value'),
    );
  }
}

/// A vertical label + value pair used for displaying detail fields.
class LabeledText extends StatelessWidget {
  const LabeledText({
    super.key,
    required this.label,
    required this.value,
    this.maxLines,
  });

  final String label;
  final String value;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: maxLines,
            overflow: maxLines != null ? TextOverflow.ellipsis : null,
          ),
        ],
      ),
    );
  }
}

/// A status indicator with a colored dot and label/value text.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A colored icon container used for resource type indicators and action cards.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 48,
    this.iconSize = 24,
    this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
