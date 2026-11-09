import 'package:flutter/material.dart';

/// ArgoCD-matched color palette.
///
/// Colors are sourced directly from the ArgoCD web UI
/// (`argo-ui/src/styles/config.scss`, `argo-ui/v2/styles/colors.scss`,
/// and `colors.ts`).
/// App color palette.
///
/// The palette follows Apple's Human Interface Guidelines: neutral grouped
/// backgrounds, white (light) / near-black (dark) content surfaces, a single
/// brand tint (Argo teal) and the system status hues for health/sync state.
/// Status colors are mid-tone so they read on both light and dark surfaces;
/// when a status color is used for *text* in light mode route it through
/// [AppColors.statusForeground] to keep WCAG contrast.
abstract final class AppColors {
  // ── Core neutrals ──────────────────────────────────────────────────────

  static const Color white = Color(0xFFFFFFFF);

  /// Light-mode grouped background (iOS systemGroupedBackground).
  static const Color canvas = Color(0xFFF2F2F7);

  /// Light-mode content surface (iOS secondarySystemGroupedBackground).
  static const Color canvasInset = Color(0xFFFFFFFF);

  /// Primary label (light mode).
  static const Color ink = Color(0xFF1C1C1E);

  /// Darkest label.
  static const Color inkDark = Color(0xFF000000);

  // ── Gray scale (iOS system grays, light appearance) ────────────────────

  static const Color gray1 = Color(0xFFF9F9FB);
  static const Color gray2 = Color(0xFFF2F2F7);
  static const Color gray3 = Color(0xFFE5E5EA);
  static const Color gray4 = Color(0xFFD1D1D6);
  static const Color gray5 = Color(0xFFAEAEB2);
  static const Color gray6 = Color(0xFF8E8E93);
  static const Color gray7 = Color(0xFF636366);
  static const Color gray8 = Color(0xFF3A3A3C);

  // ── Brand / accent ─────────────────────────────────────────────────────

  /// Brand tint (Argo teal, deepened for 4.5:1 contrast on white).
  static const Color teal = Color(0xFF00809A);

  /// Brand tint for dark appearance (brighter for contrast on black).
  static const Color tealBright = Color(0xFF45C4DA);

  /// Deep teal for pressed states / emphasis.
  static const Color tealDark = Color(0xFF00596B);

  /// Very light tint wash.
  static const Color tealLight = Color(0xFFE3F3F6);

  /// Argo orange — used sparingly (logo, secondary accent).
  static const Color orange = Color(0xFFFF6B35);

  /// Indigo accent (iOS systemIndigo).
  static const Color indigo = Color(0xFF5856D6);

  /// Blue accent (iOS systemBlue).
  static const Color azure = Color(0xFF007AFF);

  // ── Status: Health ─────────────────────────────────────────────────────

  /// Healthy (iOS systemGreen).
  static const Color healthy = Color(0xFF30C05A);

  /// Degraded (iOS systemRed).
  static const Color degraded = Color(0xFFFF3B30);

  /// Progressing (iOS systemBlue).
  static const Color progressing = Color(0xFF0A84FF);

  /// Suspended (iOS systemPurple).
  static const Color suspended = Color(0xFFAF52DE);

  /// Missing (iOS systemOrange).
  static const Color missing = Color(0xFFFF9500);

  /// Unknown status (iOS systemGray).
  static const Color unknown = Color(0xFF8E8E93);

  // ── Status: Sync ───────────────────────────────────────────────────────

  /// Synced — same green as healthy.
  static const Color synced = healthy;

  /// OutOfSync (iOS systemOrange).
  static const Color outOfSync = Color(0xFFFF9500);

  // ── Semantic shortcuts ─────────────────────────────────────────────────

  /// Error / destructive actions.
  static const Color error = degraded;

  /// Warning.
  static const Color warning = missing;

  /// Success.
  static const Color success = healthy;

  // ── Sidebar / navigation dark surface ──────────────────────────────────

  static const Color sidebarDark = Color(0xFF1C1C1E);
  static const Color sidebarDarkAlt = Color(0xFF2C2C2E);
  static const Color sidebarRail = Color(0xFF000000);

  // ── Dark mode surfaces (iOS dark grouped palette) ──────────────────────

  static const Color darkBackground = Color(0xFF000000);
  static const Color darkCanvasInset = Color(0xFF0C0C0E);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceElevated = Color(0xFF2C2C2E);
  static const Color darkBorder = Color(0xFF38383A);
  static const Color darkSlidingPanel = Color(0xFF2C2C2E);

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
  static const Color blueLight = Color(0xFFE5F1FF);
  static const Color canvasSubtle = gray1;
  static const Color peach = Color(0xFFFFF1E9);

  // ── Header / dark-surface helpers ──────────────────────────────────────

  static const Color headerDark = Color(0xFF1C1C1E);
  static const Color headerDarkAlt = Color(0xFF2C2C2E);
  static const Color textOnDarkMuted = Color(0xFF98989F);
  static const Color textOnDarkGreen = Color(0xFFDCFCE7);

  // ── YAML syntax highlighting ───────────────────────────────────────────

  // Xcode "Default (Light)" inspired. Dark-mode equivalents live below and
  // are selected by [yamlTokenColorFor] in shared_widgets.dart.
  static const Color yamlKey = Color(0xFF0F68A0);
  static const Color yamlString = Color(0xFFC41A16);
  static const Color yamlNumber = Color(0xFF1C00CF);
  static const Color yamlComment = Color(0xFF707F8C);
  static const Color yamlPunctuation = Color(0xFF3A3A3C);

  static const Color yamlKeyDark = Color(0xFF6BC7F2);
  static const Color yamlStringDark = Color(0xFFFC6A5D);
  static const Color yamlNumberDark = Color(0xFFD0BF69);
  static const Color yamlCommentDark = Color(0xFF7F8C98);
  static const Color yamlPunctuationDark = Color(0xFFD1D1D6);

  // ── Theme-aware helpers ────────────────────────────────────────────────
  //
  // Most helpers route through the active [ColorScheme] so the Material 3
  // tonal palette (`surfaceContainer`, `outlineVariant`, etc.) stays in sync
  // with the seed-generated theme.

  static Color headerSurface(ThemeData theme) {
    return theme.colorScheme.surfaceContainer;
  }

  static Color headerSurfaceAlt(ThemeData theme) {
    return theme.colorScheme.surfaceContainerHigh;
  }

  static Color headerForeground(ThemeData theme) {
    return theme.colorScheme.onSurface;
  }

  static Color headerMutedForeground(ThemeData theme) {
    return theme.colorScheme.onSurfaceVariant;
  }

  static Color headerDivider(ThemeData theme) {
    return theme.colorScheme.outlineVariant;
  }

  static Color headerChipBackground(ThemeData theme, {double alpha = 0.15}) {
    return theme.colorScheme.primary.withValues(alpha: alpha);
  }

  static Color outline(ThemeData theme) {
    return theme.colorScheme.outlineVariant;
  }

  static Color mutedText(ThemeData theme) {
    return theme.colorScheme.onSurfaceVariant;
  }

  static Color inputFill(ThemeData theme) {
    return theme.colorScheme.surfaceContainerHighest;
  }

  static Color surfaceShadow(ThemeData theme, {double alpha = 0.08}) {
    final effectiveAlpha = theme.brightness == Brightness.dark
        ? alpha * 2
        : alpha;
    return theme.colorScheme.shadow.withValues(alpha: effectiveAlpha);
  }

  static Color skeleton(ThemeData theme, {double alpha = 0.08}) {
    final base = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface;
    return base.withValues(alpha: alpha);
  }

  /// Page / grouped background (behind cards).
  static Color groupedBackground(ThemeData theme) => theme.colorScheme.surface;

  /// Card / grouped-row surface.
  static Color cardSurface(ThemeData theme) =>
      theme.colorScheme.surfaceContainerLow;

  /// Hairline separator inside cards and lists.
  static Color separator(ThemeData theme) => theme.colorScheme.outlineVariant;

  /// Secondary label (captions, metadata).
  static Color secondaryLabel(ThemeData theme) =>
      theme.colorScheme.onSurfaceVariant;

  /// Tertiary label (placeholders, disabled glyphs, chevrons).
  static Color tertiaryLabel(ThemeData theme) =>
      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);

  /// Neutral fill for inline controls (search fields, segmented tracks,
  /// neutral capsules) — iOS tertiarySystemFill.
  static Color fill(ThemeData theme) => theme.brightness == Brightness.dark
      ? const Color(0x3D767680)
      : const Color(0x1F767680);

  /// Readable foreground for a status/accent [color] when used as text or a
  /// small glyph. In light mode vivid hues are deepened to keep contrast on
  /// white; in dark mode the vivid hue is used as-is.
  static Color statusForeground(ThemeData theme, Color color) {
    if (theme.brightness == Brightness.dark) {
      return color;
    }
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * 0.78).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0))
        .toColor();
  }

  /// Soft background wash for a status/accent [color] (capsules, icon wells).
  static Color statusTint(ThemeData theme, Color color) {
    return color.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.20 : 0.12,
    );
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
