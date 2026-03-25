import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:flutter/material.dart';

const EdgeInsets kPagePadding = EdgeInsets.fromLTRB(12, 8, 12, 12);

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

/// Cache for tokenised YAML lines so that repeated calls with the same input
/// (e.g. during widget rebuilds) skip re-tokenisation.
final Map<String, List<YamlToken>> _yamlLineCache = <String, List<YamlToken>>{};

/// Clears the YAML token cache. Visible for testing.
void clearYamlTokenCache() => _yamlLineCache.clear();

/// Tokenises a single line of YAML for syntax highlighting.
List<YamlToken> tokenizeYamlLine(String line) {
  final cached = _yamlLineCache[line];
  if (cached != null) {
    return cached;
  }

  final tokens = <YamlToken>[];
  final trimmedLeft = line.trimLeft();

  // Full-line comment.
  if (trimmedLeft.startsWith('#')) {
    tokens.add(YamlToken(line, YamlTokenType.comment));
    _yamlLineCache[line] = tokens;
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
    _yamlLineCache[line] = tokens;
    return tokens;
  }

  tokens.addAll(_tokenizeKeyValue(line));
  _yamlLineCache[line] = tokens;
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
    YamlTokenType.key => AppColors.yamlKey, // clear blue
    YamlTokenType.stringValue => AppColors.yamlString, // green
    YamlTokenType.numberValue => AppColors.yamlNumber, // deep orange
    YamlTokenType.boolNullValue => AppColors.yamlNumber, // deep orange
    YamlTokenType.listDash => AppColors.yamlKey, // match keys
    YamlTokenType.comment => AppColors.yamlComment, // muted grey
    null => AppColors.yamlPunctuation, // dark blue-grey for punctuation
  };
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.22 : 0.12,
          ),
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: color.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.6 : 0.45,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns an ArgoCD-style icon for a health status string.
///
/// Icons match the ArgoCD web UI FontAwesome mappings:
/// healthy=heart, degraded=heart-broken, progressing=circle-notch,
/// suspended=pause-circle, missing=warning (ghost equivalent).
IconData healthStatusIcon(String status) {
  return switch (status.toLowerCase()) {
    'healthy' => Icons.favorite,
    'progressing' => Icons.autorenew,
    'degraded' => Icons.heart_broken,
    'suspended' => Icons.pause_circle_filled,
    'missing' => Icons.warning_amber_rounded,
    _ => Icons.help_outline,
  };
}

/// Returns an ArgoCD-style icon for a sync status string.
///
/// Icons match the ArgoCD web UI: synced=check-circle,
/// outofsync=arrow-circle-up.
IconData syncStatusIcon(String status) {
  return switch (status.toLowerCase()) {
    'synced' => Icons.check_circle,
    'outofsync' => Icons.arrow_circle_up,
    _ => Icons.help_outline,
  };
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: theme.dividerColor),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 8),
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
    this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData? icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$title. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.base,
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 32, color: AppColors.grey),
              const SizedBox(height: 8),
            ],
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

    return Semantics(
      label: '$value $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.md,
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
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(child: Icon(icon, size: 14)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single segment in a [StatusSegmentBar].
class StatusSegment {
  const StatusSegment({required this.color, required this.count});

  final Color color;
  final int count;
}

/// ArgoCD-style proportional colored bar showing status distribution.
///
/// Each segment's width is proportional to its [StatusSegment.count].
/// Segments with count == 0 are skipped. Adjacent segments are separated
/// by a thin white line.
class StatusSegmentBar extends StatelessWidget {
  const StatusSegmentBar({
    super.key,
    required this.segments,
    this.height = 8,
  });

  final List<StatusSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final nonZero =
        segments.where((s) => s.count > 0).toList(growable: false);
    final total = segments.fold<int>(0, (sum, s) => sum + s.count);

    if (total == 0 || nonZero.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Container(color: AppColors.gray4),
        ),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < nonZero.length; i++) {
      if (i > 0) {
        children.add(SizedBox(width: 1.5, child: ColoredBox(color: AppColors.white)));
      }
      children.add(
        Expanded(
          flex: nonZero[i].count,
          child: ColoredBox(color: nonZero[i].color),
        ),
      );
    }

    final percentages = nonZero
        .map((s) => '${s.count} (${(s.count / total * 100).round()}%)')
        .join(', ');

    return Semantics(
      label: 'Status bar: $percentages',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(height: height, child: Row(children: children)),
      ),
    );
  }
}
