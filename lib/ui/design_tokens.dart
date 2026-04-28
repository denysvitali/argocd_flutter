// Design tokens for consistent spacing, border radius, opacity values,
// elevation/shadows, and shared card decorations across the application.
//
// All values are compile-time constants and can be used in `const` contexts.

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
}

abstract final class AppRadius {
  static final BorderRadius xs = BorderRadius.circular(2);
  static final BorderRadius sm = BorderRadius.circular(4);
  static final BorderRadius base = BorderRadius.circular(6);
  static final BorderRadius md = BorderRadius.circular(8);
  static final BorderRadius lg = BorderRadius.circular(12);
  static final BorderRadius pill = BorderRadius.circular(100);
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

/// Consistent elevation/shadow tokens for cards and surfaces.
///
/// Use [AppCardDecoration.card] for standard surface cards (border only).
/// Use [AppCardDecoration.elevated] for cards that need depth (border + shadow).
abstract final class AppElevation {
  /// No elevation -- border only, no shadows. Used for standard section cards.
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Subtle elevation for cards that need gentle depth perception.
  /// Multi-layer shadow for crisp, modern surface separation.
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

  /// Light elevation for attention items or interactive cards.
  static List<BoxShadow> light(Color shadowColor, {double alpha = 0.08}) =>
      <BoxShadow>[
        BoxShadow(
          color: shadowColor.withValues(alpha: alpha),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Shared card decoration factory for consistent styling across all screens.
///
/// All cards use `borderRadius: AppRadius.base` (6px) and a standard border.
/// Elevated variants add subtle two-layer shadows for depth.
abstract final class AppCardDecoration {
  /// Standard surface card: solid background, border, no shadow.
  /// Used for SectionCard, SummaryTile, EmptyStateCard, and most content cards.
  static BoxDecoration card({
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: AppRadius.base,
      border: Border.all(color: borderColor),
    );
  }

  /// Elevated surface card: border plus subtle two-layer shadow.
  /// Used for the sign-in form card and other cards that need depth.
  static BoxDecoration elevated({
    required Color backgroundColor,
    required Color borderColor,
    required Color shadowColor,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: AppRadius.base,
      border: Border.all(color: borderColor),
      boxShadow: AppElevation.subtle(shadowColor),
    );
  }
}
