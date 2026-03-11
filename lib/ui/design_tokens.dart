/// Design tokens for consistent spacing, border radius, and opacity values
/// across the application.
///
/// All values are compile-time constants and can be used in `const` contexts.

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
}

abstract final class AppRadius {
  static final BorderRadius xs = BorderRadius.circular(3);
  static final BorderRadius sm = BorderRadius.circular(4);
  static final BorderRadius md = BorderRadius.circular(8);
  static final BorderRadius lg = BorderRadius.circular(12);
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
