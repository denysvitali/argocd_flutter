import 'package:flutter/material.dart';

/// ArgoCD-matched color palette.
///
/// Colors are sourced directly from the ArgoCD web UI
/// (`argo-ui/src/styles/config.scss`, `argo-ui/v2/styles/colors.scss`,
/// and `colors.ts`).
abstract final class AppColors {
  // ── Core neutrals ──────────────────────────────────────────────────────

  static const Color white = Color(0xFFFFFFFF);

  /// Light-mode canvas / scaffold background.
  static const Color canvas = Color(0xFFF3F6F8);

  /// Primary dark text (ArgoCD gray-7).
  static const Color ink = Color(0xFF495763);

  /// Darkest text / label badge text (ArgoCD gray-8).
  static const Color inkDark = Color(0xFF363C4A);

  // ── Gray scale (ArgoCD official grays) ─────────────────────────────────

  static const Color gray1 = Color(0xFFFAFCFD);
  static const Color gray2 = Color(0xFFF0F4F6);
  static const Color gray3 = Color(0xFFDEE6EB);
  static const Color gray4 = Color(0xFFCCD6DD);
  static const Color gray5 = Color(0xFF8FA4B1);
  static const Color gray6 = Color(0xFF6D7F8B);
  static const Color gray7 = Color(0xFF495763);
  static const Color gray8 = Color(0xFF363C4A);

  // ── Brand / accent ─────────────────────────────────────────────────────

  /// ArgoCD primary interactive teal (teal-5).
  static const Color teal = Color(0xFF00A7B7);

  /// Darker teal for headings / links (teal-7).
  static const Color tealDark = Color(0xFF006F8A);

  /// Light teal for backgrounds (teal-2).
  static const Color tealLight = Color(0xFFDFF6F9);

  /// Sidebar active icon / loading accent (ArgoCD orange).
  static const Color orange = Color(0xFFFF6B35);

  /// Secondary operational accent for focused controls and active rails.
  static const Color indigo = Color(0xFF3655D4);

  /// Cool accent for informational badges and charts.
  static const Color azure = Color(0xFF0B84FF);

  // ── Status: Health ─────────────────────────────────────────────────────

  /// Healthy (ArgoCD green).
  static const Color healthy = Color(0xFF18BE94);

  /// Degraded (ArgoCD salmon-pink).
  static const Color degraded = Color(0xFFE96D76);

  /// Progressing (ArgoCD sky-blue).
  static const Color progressing = Color(0xFF0DADEA);

  /// Suspended (ArgoCD purple).
  static const Color suspended = Color(0xFF766F94);

  /// Missing (ArgoCD amber/yellow).
  static const Color missing = Color(0xFFF4C030);

  /// Unknown status (ArgoCD gray-4).
  static const Color unknown = Color(0xFFCCD6DD);

  // ── Status: Sync ───────────────────────────────────────────────────────

  /// Synced — same green as healthy in ArgoCD.
  static const Color synced = Color(0xFF18BE94);

  /// OutOfSync (ArgoCD amber).
  static const Color outOfSync = Color(0xFFF4C030);

  // ── Semantic shortcuts ─────────────────────────────────────────────────

  /// Error / destructive actions (same as degraded).
  static const Color error = degraded;

  /// Warning (same as missing / outOfSync).
  static const Color warning = missing;

  /// Success (same as healthy / synced).
  static const Color success = healthy;

  // ── Sidebar / navigation dark surface ──────────────────────────────────

  /// ArgoCD sidebar background.
  static const Color sidebarDark = Color(0xFF0F2733);

  // ── Dark mode surfaces ─────────────────────────────────────────────────

  static const Color darkBackground = Color(0xFF0F1317);
  static const Color darkSurface = Color(0xFF171D23);
  static const Color darkSurfaceElevated = Color(0xFF202831);
  static const Color darkBorder = Color(0xFF33414D);
  static const Color darkSlidingPanel = Color(0xFF232B33);

  // ── Legacy aliases (keep in sync with the rest of the codebase) ────────

  /// Alias: cobalt was the old primary accent; now points to teal.
  static const Color cobalt = teal;

  /// Alias: coral was the old error color; now points to degraded.
  static const Color coral = degraded;

  /// Alias: amber was the old warning; now points to outOfSync.
  static const Color amber = outOfSync;

  /// Alias: grey was the old muted text; now points to gray-6.
  static const Color grey = gray6;

  /// Alias: greyLight was the old lighter gray; now points to gray-5.
  static const Color greyLight = gray5;

  /// Alias: border was the old light-mode border; now points to gray-4.
  static const Color border = gray4;

  static const Color cobaltLight = tealLight;
  static const Color blueLight = Color(0xFFEAF3FF);
  static const Color canvasSubtle = gray1;
  static const Color peach = Color(0xFFFFF1E9);

  // ── Header / dark-surface helpers ──────────────────────────────────────

  static const Color headerDark = Color(0xFF111A20);
  static const Color headerDarkAlt = Color(0xFF203135);
  static const Color textOnDarkMuted = Color(0xFF9AA8B2);
  static const Color textOnDarkGreen = Color(0xFFDCFCE7);

  // ── YAML syntax highlighting ───────────────────────────────────────────

  static const Color yamlKey = Color(0xFF1565C0);
  static const Color yamlString = Color(0xFF2E7D32);
  static const Color yamlNumber = Color(0xFFE65100);
  static const Color yamlComment = Color(0xFF9E9E9E);
  static const Color yamlPunctuation = Color(0xFF37474F);

  // ── Theme-aware helpers ────────────────────────────────────────────────

  static Color headerSurface(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? darkSurfaceElevated
        : headerDark;
  }

  static Color headerSurfaceAlt(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? headerDarkAlt
        : const Color(0xFFEAF3F4);
  }

  static Color headerForeground(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : white;
  }

  static Color headerMutedForeground(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? textOnDarkMuted
        : textOnDarkMuted;
  }

  static Color headerDivider(ThemeData theme) {
    final alpha = theme.brightness == Brightness.dark ? 0.12 : 0.18;
    return headerForeground(theme).withValues(alpha: alpha);
  }

  static Color headerChipBackground(ThemeData theme, {double alpha = 0.15}) {
    return headerForeground(theme).withValues(alpha: alpha);
  }

  static Color outline(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? darkBorder
        : const Color(0xFFD7E0E6);
  }

  static Color mutedText(ThemeData theme) {
    return theme.brightness == Brightness.dark ? gray5 : gray6;
  }

  static Color inputFill(ThemeData theme) {
    return theme.brightness == Brightness.dark ? darkSurfaceElevated : white;
  }

  static Color surfaceShadow(ThemeData theme, {double alpha = 0.08}) {
    final effectiveAlpha = theme.brightness == Brightness.dark
        ? alpha * 2
        : alpha;
    return theme.colorScheme.shadow.withValues(alpha: effectiveAlpha);
  }

  static Color skeleton(ThemeData theme, {double alpha = 0.08}) {
    final base = theme.brightness == Brightness.dark ? gray4 : ink;
    return base.withValues(alpha: alpha);
  }

  /// Map health status string to the matching ArgoCD status color.
  static Color healthColor(String status) {
    return switch (status.toLowerCase()) {
      'healthy' => healthy,
      'progressing' => progressing,
      'degraded' => degraded,
      'suspended' => suspended,
      'missing' => missing,
      _ => unknown,
    };
  }

  /// Map sync status string to the matching ArgoCD status color.
  static Color syncColor(String status) {
    return switch (status.toLowerCase()) {
      'synced' => synced,
      _ => outOfSync,
    };
  }
}
