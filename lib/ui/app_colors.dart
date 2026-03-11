import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color canvas = Color(0xFFF4F7FB);
  static const Color ink = Color(0xFF0E1726);
  static const Color cobalt = Color(0xFF1F6FEB);
  static const Color teal = Color(0xFF14B8A6);
  static const Color coral = Color(0xFFFF6B57);
  static const Color amber = Color(0xFFFFC857);
  static const Color grey = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE2EAF3);

  static const Color darkSurface = Color(0xFF1A2332);
  static const Color darkBorder = Color(0xFF2A3A4E);

  static const Color textOnDarkMuted = Color(0xFFD8E5FF);
  static const Color textOnDarkGreen = Color(0xFFDCFCE7);
  static const Color cobaltLight = Color(0xFFEAF2FF);
  static const Color canvasSubtle = Color(0xFFF5F9FF);
  static const Color peach = Color(0xFFFFF2E8);
  static const Color blueLight = Color(0xFFE8F0FF);

  static const Color gradientAppStart = Color(0xFF0E1726);
  static const Color gradientAppMid = Color(0xFF183153);
  static const Color gradientProjectStart = Color(0xFF10233D);
  static const Color gradientProjectMid = Color(0xFF14532D);

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
      _ => coral,
    };
  }
}
