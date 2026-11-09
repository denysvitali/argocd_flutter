import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:flutter/material.dart';

const EdgeInsets kPagePadding = EdgeInsets.fromLTRB(16, 8, 16, 24);

/// iOS-style large-title page header.
///
/// Renders a bold large title with an optional one-line secondary label,
/// trailing toolbar actions aligned to the title baseline area, and an
/// optional [bottom] widget (search field, filters, ...).
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 0, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineLarge,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
            if (bottom != null) ...<Widget>[
              const SizedBox(height: 14),
              bottom!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Content section title in the App Store / Health style ("Needs Attention").
/// Sits *outside* a card, directly above it.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 10),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// iOS inset-grouped list: a rounded card whose [children] are separated by
/// inset hairlines, with an optional small caps [header] and muted [footer].
class GroupedList extends StatelessWidget {
  const GroupedList({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.dividerIndent = 16,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  /// Leading inset of separators. Use 60 when rows carry an [IconWell].
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 0.5,
            indent: dividerIndent,
            color: scheme.outlineVariant,
          ),
        );
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
            child: Semantics(
              header: true,
              child: Text(
                header!.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        Material(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.md,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// A single row inside a [GroupedList]: leading glyph, title (+ optional
/// subtitle), a muted trailing [value] and a disclosure chevron when tappable.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron,
    this.destructive = false,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Defaults to `onTap != null && trailing == null`.
  final bool? showChevron;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chevron = showChevron ?? (onTap != null && trailing == null);

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final label = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: destructive ? scheme.error : scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              );
              return Row(
                children: <Widget>[
                  if (leading != null) ...<Widget>[
                    leading!,
                    const SizedBox(width: 14),
                  ],
                  // With a value, the label keeps its natural width (capped
                  // at 60%) and the value takes the remaining space, so short
                  // labels don't force long values to truncate at 50%.
                  if (value == null)
                    Expanded(child: label)
                  else ...<Widget>[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.6,
                      ),
                      child: label,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 12),
                    trailing!,
                  ],
                  if (chevron) ...<Widget>[
                    const SizedBox(width: 6),
                    const DisclosureChevron(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The muted ">" disclosure indicator used on tappable rows.
class DisclosureChevron extends StatelessWidget {
  const DisclosureChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: AppColors.tertiaryLabel(Theme.of(context)),
      ),
    );
  }
}

/// iOS Settings-style icon: a white glyph on a solid rounded square.
class IconWell extends StatelessWidget {
  const IconWell({
    super.key,
    required this.icon,
    required this.color,
    this.size = 30,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        child: Icon(icon, size: size * 0.6, color: Colors.white),
      ),
    );
  }
}

/// Small solid status dot.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

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

/// Returns the theme-appropriate color for a YAML token type (Xcode-style
/// palettes for light and dark appearance).
Color yamlTokenColorFor(YamlTokenType? type, Brightness brightness) {
  if (brightness == Brightness.light) {
    return yamlTokenColor(type);
  }
  return switch (type) {
    YamlTokenType.key => AppColors.yamlKeyDark,
    YamlTokenType.stringValue => AppColors.yamlStringDark,
    YamlTokenType.numberValue => AppColors.yamlNumberDark,
    YamlTokenType.boolNullValue => AppColors.yamlNumberDark,
    YamlTokenType.listDash => AppColors.yamlKeyDark,
    YamlTokenType.comment => AppColors.yamlCommentDark,
    null => AppColors.yamlPunctuationDark,
  };
}

/// Returns the light-appearance color for a given YAML token type.
/// Prefer [yamlTokenColorFor] in widgets so dark mode stays legible.
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

/// Compact tinted capsule for a health / sync status.
///
/// The text and glyph use [AppColors.statusForeground] so vivid status hues
/// stay legible on light surfaces.
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
    final foreground = AppColors.statusForeground(theme, color);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: EdgeInsets.fromLTRB(icon != null ? 6 : 8, 3, 8, 3),
        decoration: BoxDecoration(
          color: AppColors.statusTint(theme, color),
          borderRadius: AppRadius.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 12, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns an icon for a health status string (rounded glyph family).
IconData healthStatusIcon(String status) {
  return switch (status.toLowerCase()) {
    'healthy' => Icons.favorite_rounded,
    'progressing' => Icons.autorenew_rounded,
    'degraded' => Icons.heart_broken_rounded,
    'suspended' => Icons.pause_circle_filled_rounded,
    'missing' => Icons.warning_amber_rounded,
    _ => Icons.help_outline_rounded,
  };
}

/// Returns an icon for a sync status string.
IconData syncStatusIcon(String status) {
  return switch (status.toLowerCase()) {
    'synced' => Icons.check_circle_rounded,
    'outofsync' => Icons.arrow_circle_up_rounded,
    _ => Icons.help_outline_rounded,
  };
}

/// Rounded content card (iOS inset-grouped surface) with an optional
/// headline [title].
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    required this.child,
  });

  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Content-unavailable view: a large muted glyph, a headline and a short
/// explanation, centered (iOS `ContentUnavailableView`).
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: '$title. $subtitle',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 40, color: AppColors.tertiaryLabel(theme)),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Big-number metric tile: a large display numeral over a muted caption.
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
    final scheme = theme.colorScheme;

    return Semantics(
      label: '$value $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.base,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$value',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: valueColor ?? scheme.onSurface,
                fontFeatures: AppFonts.tabularFigures,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline metadata: a small muted glyph followed by a label. No chrome —
/// lay several out in a `Wrap` with ~12pt spacing.
class FactBadge extends StatelessWidget {
  const FactBadge({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(icon, size: 14, color: AppColors.tertiaryLabel(theme)),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A single segment in a [StatusSegmentBar].
class StatusSegment {
  const StatusSegment({required this.color, required this.count});

  final Color color;
  final int count;
}

/// Proportional capsule bar showing a status distribution.
///
/// Each segment's width is proportional to its [StatusSegment.count].
/// Segments with count == 0 are skipped; adjacent segments are separated by
/// a 2pt transparent gap so the bar reads correctly on any surface.
class StatusSegmentBar extends StatelessWidget {
  const StatusSegmentBar({super.key, required this.segments, this.height = 6});

  final List<StatusSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final nonZero = segments.where((s) => s.count > 0).toList(growable: false);
    final total = segments.fold<int>(0, (sum, s) => sum + s.count);

    if (total == 0 || nonZero.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: ColoredBox(color: AppColors.fill(Theme.of(context))),
        ),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < nonZero.length; i++) {
      if (i > 0) {
        children.add(
          const SizedBox(
            width: 2,
            child: ColoredBox(color: Colors.transparent),
          ),
        );
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
        child: SizedBox(
          height: height,
          // Stretch is required: childless ColoredBoxes otherwise collapse to
          // zero height under the Row's loose cross-axis constraints.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
