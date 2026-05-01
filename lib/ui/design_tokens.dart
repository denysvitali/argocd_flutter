// Design tokens for spacing, border radius, opacity, elevation/shadows,
// and shared card decorations.
//
// Radii follow Material 3's expressive shape scale
// (extra-small=4 / small=8 / medium=12 / large=16 / extra-large=28).

import 'package:flutter/painting.dart';

abstract final class AppSpacing {
  static const double xs = 2;
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 24;
  static const double huge = 32;
  static const double giant = 40;
  static const double shellRail = 104;
}

abstract final class AppRadius {
  /// 4dp — pills, chips, micro-tags.
  static final BorderRadius xs = BorderRadius.circular(4);

  /// 8dp — small chip groups, status badges.
  static final BorderRadius sm = BorderRadius.circular(8);

  /// 12dp — M3 medium shape. Default for most surface tiles, list rows, badges.
  static final BorderRadius base = BorderRadius.circular(12);

  /// 16dp — M3 large shape. Used by stock M3 Card & SearchBar.
  static final BorderRadius md = BorderRadius.circular(16);

  /// 20dp — feature cards, hero panels.
  static final BorderRadius lg = BorderRadius.circular(20);

  /// 28dp — M3 extra-large. FABs, sheets, dialogs.
  static final BorderRadius xl = BorderRadius.circular(28);

  /// Fully rounded.
  static final BorderRadius pill = BorderRadius.circular(999);
}

abstract final class AppOpacity {
  static const double subtle = 0.06;
  static const double light = 0.08;
  static const double soft = 0.10;
  static const double medium = 0.12;
  static const double moderate = 0.14;
  static const double strong = 0.2;
  static const double bold = 0.3;
  static const double heavy = 0.4;
  static const double intense = 0.5;
  static const double dense = 0.6;
  static const double prominent = 0.7;
  static const double opaque = 0.8;
  static const double nearOpaque = 0.9;
}

abstract final class AppIconSize {
  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 32;
  static const double huge = 48;
}

/// Elevation / shadow tokens. M3 prefers tonal surface elevation over
/// drop shadows, but a few floating chrome elements still need depth.
abstract final class AppElevation {
  /// No elevation -- tonal surface only. Default for most cards.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Subtle two-layer shadow for slightly raised surfaces.
  static List<BoxShadow> subtle(Color shadowColor) => <BoxShadow>[
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.07),
      blurRadius: 18,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  /// Light single-layer shadow for hover or focus highlights.
  static List<BoxShadow> light(Color shadowColor, {double alpha = 0.08}) =>
      <BoxShadow>[
        BoxShadow(
          color: shadowColor.withValues(alpha: alpha),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  /// Strong shadow for floating shell chrome (rail, drawer, sheet edges).
  static List<BoxShadow> shell(Color shadowColor) => <BoxShadow>[
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.18),
      blurRadius: 34,
      offset: const Offset(0, 18),
    ),
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.10),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Shared card decoration factory for consistent styling across all screens.
///
/// All cards default to `AppRadius.base` (12dp). Surface-tonal cards pass
/// no border color; outlined variants pass an explicit color.
abstract final class AppCardDecoration {
  /// Standard surface card: tonal surface, optional thin outline, no shadow.
  static BoxDecoration card({
    required Color backgroundColor,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: AppRadius.base,
      border: borderColor == null ? null : Border.all(color: borderColor),
    );
  }

  /// Elevated surface card: tonal surface plus subtle two-layer shadow.
  static BoxDecoration elevated({
    required Color backgroundColor,
    required Color shadowColor,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: AppRadius.base,
      border: borderColor == null ? null : Border.all(color: borderColor),
      boxShadow: AppElevation.subtle(shadowColor),
    );
  }
}
