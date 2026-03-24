import 'package:flutter/material.dart';

/// ArgoCD-matched color palette.
///
/// Colors are sourced directly from the ArgoCD web UI
/// (`argo-ui/src/styles/config.scss`, `argo-ui/v2/styles/colors.scss`,
/// and `colors.ts`).
abstract final class AppColors {
  // ── Core neutrals ──────────────────────────────────────────────────────

  static const Color white = Color(0xFFFFFFFF);

  /// Light-mode canvas / scaffold background (ArgoCD gray-3).
  static const Color canvas = Color(0xFFDEE6EB);

  /// Primary dark text (ArgoCD gray-7).
  static const Color ink = Color(0xFF495763);

  /// Darkest text / label badge text (ArgoCD gray-8).
  static const Color inkDark = Color(0xFF363C4A);

  // ── Gray scale (ArgoCD official grays) ─────────────────────────────────

  static const Color gray1 = Color(0xFFF8FBFB);
  static const Color gray2 = Color(0xFFEFF3F5);
  static const Color gray3 = Color(0xFFDEE6EB);
  static const Color gray4 = Color(0xFFCCD6DD);
  static const Color gray5 = Color(0xFF8FA4B1);
  static const Color gray6 = Color(0xFF6D7F8B);
  static const Color gray7 = Color(0xFF495763);
  static const Color gray8 = Color(0xFF363C4A);

  // ── Brand / accent ─────────────────────────────────────────────────────

  /// ArgoCD primary interactive teal (teal-5).
  static const Color teal = Color(0xFF1FBDD0);

  /// Darker teal for headings / links (teal-7).
  static const Color tealDark = Color(0xFF006F8A);

  /// Light teal for backgrounds (teal-2).
  static const Color tealLight = Color(0xFFDFF6F9);

  /// Sidebar active icon / loading accent (ArgoCD orange).
  static const Color orange = Color(0xFFFE733F);

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

  static const Color darkBackground = Color(0xFF100F0F);
  static const Color darkSurface = Color(0xFF1E2735);
  static const Color darkBorder = Color(0xFF495763);
  static const Color darkSlidingPanel = Color(0xFF28292A);

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
  static const Color blueLight = tealLight;
  static const Color canvasSubtle = gray1;
  static const Color peach = Color(0xFFFFF1E9);

  // ── Header / dark-surface helpers ──────────────────────────────────────

  static const Color headerDark = sidebarDark;
  static const Color headerDarkAlt = Color(0xFF15221B);
  static const Color textOnDarkMuted = Color(0xFF818D94);
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
        ? darkSurface
        : sidebarDark;
  }

  static Color headerSurfaceAlt(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? headerDarkAlt
        : theme.colorScheme.surfaceContainerHighest;
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
    return theme.brightness == Brightness.dark ? darkBorder : gray4;
  }

  static Color mutedText(ThemeData theme) {
    return theme.brightness == Brightness.dark ? gray5 : gray6;
  }

  static Color inputFill(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? darkSurface
        : gray1;
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
