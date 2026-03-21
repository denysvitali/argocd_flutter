import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF4F6F9);
  static const Color ink = Color(0xFF1B2430);
  static const Color cobalt = Color(0xFF2F6BFF);
  static const Color teal = Color(0xFF1F9D55);
  static const Color coral = Color(0xFFE34850);
  static const Color amber = Color(0xFFF0B429);
  static const Color grey = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFF9AA5B1);
  static const Color border = Color(0xFFE1E6ED);

  static const Color darkSurface = Color(0xFF1E2735);
  static const Color darkBorder = Color(0xFF2B394D);

  static const Color textOnDarkMuted = Color(0xFFD8E5FF);
  static const Color textOnDarkGreen = Color(0xFFDCFCE7);
  static const Color cobaltLight = Color(0xFFE9F0FF);
  static const Color canvasSubtle = Color(0xFFF7F9FC);
  static const Color peach = Color(0xFFFFF1E9);
  static const Color blueLight = Color(0xFFE9F1FF);

  static const Color headerDark = Color(0xFF1A2230);
  static const Color headerDarkAlt = Color(0xFF15221B);

  static const Color yamlKey = Color(0xFF1565C0);
  static const Color yamlString = Color(0xFF2E7D32);
  static const Color yamlNumber = Color(0xFFE65100);
  static const Color yamlComment = Color(0xFF9E9E9E);
  static const Color yamlPunctuation = Color(0xFF37474F);

  static Color headerSurface(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? headerDark
        : theme.colorScheme.surface;
  }

  static Color headerSurfaceAlt(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? headerDarkAlt
        : theme.colorScheme.surfaceContainerHighest;
  }

  static Color headerForeground(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface;
  }

  static Color headerMutedForeground(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? textOnDarkMuted
        : theme.colorScheme.onSurface.withValues(alpha: 0.65);
  }

  static Color headerDivider(ThemeData theme) {
    final alpha = theme.brightness == Brightness.dark ? 0.12 : 0.18;
    return headerForeground(theme).withValues(alpha: alpha);
  }

  static Color headerChipBackground(ThemeData theme, {double alpha = 0.1}) {
    return headerForeground(theme).withValues(alpha: alpha);
  }

  static Color outline(ThemeData theme) {
    return theme.brightness == Brightness.dark ? darkBorder : border;
  }

  static Color mutedText(ThemeData theme) {
    return theme.colorScheme.onSurfaceVariant;
  }

  static Color inputFill(ThemeData theme) {
    return theme.colorScheme.surface;
  }

  static Color surfaceShadow(ThemeData theme, {double alpha = 0.08}) {
    final effectiveAlpha = theme.brightness == Brightness.dark
        ? alpha * 2
        : alpha;
    return theme.colorScheme.shadow.withValues(alpha: effectiveAlpha);
  }

  static Color skeleton(ThemeData theme, {double alpha = 0.08}) {
    final base = theme.brightness == Brightness.dark ? border : ink;
    return base.withValues(alpha: alpha);
  }

  static Color healthColor(String status) {
    return switch (status.toLowerCase()) {
      'healthy' => teal,
      'progressing' => amber,
      'degraded' => coral,
      'missing' => greyLight,
      _ => grey,
    };
  }

  static Color syncColor(String status) {
    return switch (status.toLowerCase()) {
      'synced' => cobalt,
      _ => amber,
    };
  }
}
