import 'dart:ui' show ImageFilter;

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/health_event.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/features/applications/application_detail_screen.dart';
import 'package:argocd_flutter/features/applications/applications_screen.dart';
import 'package:argocd_flutter/features/auth/sign_in_screen.dart';
import 'package:argocd_flutter/features/dashboard/dashboard_screen.dart';
import 'package:argocd_flutter/features/projects/project_detail_screen.dart';
import 'package:argocd_flutter/features/projects/projects_screen.dart';
import 'package:argocd_flutter/features/settings/settings_screen.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/argo_logo.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

const _textFont = AppFonts.text;
const _displayFont = AppFonts.display;

/// Neutral, Apple-style color scheme. Surfaces are untinted grays; the brand
/// teal only appears as the interactive tint.
ColorScheme _buildColorScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
  );
  if (isDark) {
    return base.copyWith(
      primary: AppColors.tealBright,
      onPrimary: const Color(0xFF00222A),
      primaryContainer: const Color(0xFF0F3A44),
      onPrimaryContainer: const Color(0xFFB8ECF5),
      secondary: AppColors.orange,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF2C2C2E),
      onSecondaryContainer: const Color(0xFFF5F5F7),
      tertiary: const Color(0xFF5E5CE6),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF26254D),
      onTertiaryContainer: const Color(0xFFD7D6FF),
      error: const Color(0xFFFF453A),
      onError: Colors.white,
      errorContainer: const Color(0xFF3B1513),
      onErrorContainer: const Color(0xFFFFB4AE),
      surface: AppColors.darkBackground,
      onSurface: const Color(0xFFF5F5F7),
      onSurfaceVariant: const Color(0xFF98989F),
      surfaceDim: AppColors.darkBackground,
      surfaceBright: const Color(0xFF2C2C2E),
      surfaceContainerLowest: const Color(0xFF0C0C0E),
      surfaceContainerLow: AppColors.darkSurface,
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHigh: AppColors.darkSurfaceElevated,
      surfaceContainerHighest: const Color(0xFF3A3A3C),
      outline: const Color(0xFF545458),
      outlineVariant: AppColors.darkBorder,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFF2F2F7),
      onInverseSurface: const Color(0xFF1C1C1E),
      inversePrimary: AppColors.teal,
      surfaceTint: Colors.transparent,
    );
  }
  return base.copyWith(
    primary: AppColors.teal,
    onPrimary: Colors.white,
    primaryContainer: AppColors.tealLight,
    onPrimaryContainer: AppColors.tealDark,
    secondary: AppColors.orange,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE9E9EE),
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.indigo,
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFE8E8FB),
    onTertiaryContainer: const Color(0xFF2B2A86),
    error: const Color(0xFFE5342A),
    onError: Colors.white,
    errorContainer: const Color(0xFFFFE9E7),
    onErrorContainer: const Color(0xFF8C1A13),
    surface: AppColors.canvas,
    onSurface: AppColors.ink,
    onSurfaceVariant: const Color(0xFF6C6C72),
    surfaceDim: const Color(0xFFE5E5EA),
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: const Color(0xFFF7F7FA),
    surfaceContainerHigh: const Color(0xFFEFEFF4),
    surfaceContainerHighest: const Color(0xFFE5E5EA),
    outline: AppColors.gray4,
    outlineVariant: const Color(0xFFE3E3E8),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFF1C1C1E),
    onInverseSurface: const Color(0xFFF5F5F7),
    inversePrimary: AppColors.tealBright,
    surfaceTint: Colors.transparent,
  );
}

/// Type ramp modelled on Apple's HIG text styles (Large Title, Title 1-3,
/// Headline, Body, Callout, Subheadline, Footnote, Caption), set in Inter.
TextTheme _buildTextTheme(ColorScheme scheme) {
  TextStyle display(
    double size,
    FontWeight weight,
    double tracking, [
    double height = 1.15,
  ]) {
    return TextStyle(
      fontFamily: _displayFont,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: height,
      color: scheme.onSurface,
    );
  }

  TextStyle text(
    double size,
    FontWeight weight,
    double tracking, [
    double height = 1.35,
  ]) {
    return TextStyle(
      fontFamily: _textFont,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      height: height,
      color: scheme.onSurface,
    );
  }

  return TextTheme(
    displayLarge: display(52, FontWeight.w700, -1.4, 1.08),
    displayMedium: display(42, FontWeight.w700, -1.1, 1.1),
    displaySmall: display(34, FontWeight.w700, -0.8, 1.12),
    // Large Title
    headlineLarge: display(32, FontWeight.w700, -0.7),
    // Title 1
    headlineMedium: display(27, FontWeight.w700, -0.5),
    // Title 2
    headlineSmall: display(22, FontWeight.w700, -0.35, 1.2),
    // Title 3
    titleLarge: text(19, FontWeight.w600, -0.3, 1.25),
    // Headline
    titleMedium: text(16, FontWeight.w600, -0.2, 1.3),
    // Subheadline (emphasized)
    titleSmall: text(14, FontWeight.w600, -0.1, 1.3),
    // Body
    bodyLarge: text(16, FontWeight.w400, -0.2, 1.4),
    // Callout / Subheadline
    bodyMedium: text(14, FontWeight.w400, -0.1, 1.4),
    // Footnote
    bodySmall: text(12.5, FontWeight.w400, 0, 1.35),
    // Buttons
    labelLarge: text(15, FontWeight.w600, -0.15, 1.2),
    // Caption 1
    labelMedium: text(12.5, FontWeight.w500, 0, 1.25),
    // Caption 2
    labelSmall: text(11, FontWeight.w500, 0.05, 1.2),
  );
}

/// Build the app [ThemeData]: Material 3 widgets dressed in an Apple-style
/// visual language (neutral grouped surfaces, single tint, hairlines, no
/// tonal elevation).
ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = _buildColorScheme(brightness);
  final textTheme = _buildTextTheme(scheme);
  final fill = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE9E9EE);
  final cardColor = scheme.surfaceContainerLow;
  final barColor = isDark ? const Color(0xFF121214) : const Color(0xFFF9F9FB);
  final inactiveTab = isDark
      ? const Color(0xFF8E8E93)
      : const Color(0xFF8E8E93);
  const hairline = 0.5;

  RoundedRectangleBorder rounded(BorderRadius radius) =>
      RoundedRectangleBorder(borderRadius: radius);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: _textFont,
    splashFactory: InkSparkle.splashFactory,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    cardColor: cardColor,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    dividerColor: scheme.outlineVariant,
    visualDensity: VisualDensity.standard,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
    // iOS-style back chevron on every platform.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) =>
          const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: hairline,
    ),
    appBarTheme: AppBarTheme(
      toolbarHeight: 52,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.scrolledUnder)) {
          return barColor;
        }
        return scheme.surface;
      }),
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      iconTheme: IconThemeData(color: scheme.primary, size: 22),
      actionsIconTheme: IconThemeData(color: scheme.primary, size: 22),
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: rounded(AppRadius.md),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        iconSize: 22,
        shape: const CircleBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: fill,
      selectedColor: scheme.onSurface,
      disabledColor: fill,
      secondarySelectedColor: scheme.onSurface,
      checkmarkColor: scheme.surface,
      showCheckmark: false,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      // A plain TextStyle (not WidgetStateTextStyle) so RawChip can merge it
      // with its defaults; the color itself resolves per state.
      labelStyle: TextStyle(
        fontFamily: _textFont,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.surfaceContainerLowest
              : scheme.onSurface,
        ),
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: _textFont,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: scheme.surfaceContainerLowest,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      focusElevation: 3,
      hoverElevation: 3,
      highlightElevation: 2,
      shape: const StadiumBorder(),
      extendedTextStyle: textTheme.labelLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: textTheme.bodyLarge?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      labelStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide(color: scheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: rounded(AppRadius.base),
        elevation: 0,
        textStyle: textTheme.labelLarge,
      ),
    ),
    // Apple-style "tinted" button: tint wash, no outline.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: scheme.primary,
        backgroundColor: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
        side: BorderSide.none,
        shape: rounded(AppRadius.base),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: rounded(AppRadius.base),
        textStyle: textTheme.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: cardColor,
        foregroundColor: scheme.primary,
        minimumSize: const Size(64, 46),
        shape: rounded(AppRadius.base),
        textStyle: textTheme.labelLarge,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: scheme.onSurface,
        selectedBackgroundColor: cardColor,
        selectedForegroundColor: scheme.onSurface,
        side: BorderSide.none,
        shape: rounded(AppRadius.sm),
        textStyle: textTheme.labelMedium?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      minVerticalPadding: 10,
      horizontalTitleGap: 14,
      iconColor: scheme.onSurfaceVariant,
      tileColor: Colors.transparent,
      shape: rounded(AppRadius.base),
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontSize: 13,
      ),
      leadingAndTrailingTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: rounded(AppRadius.md),
      backgroundColor: scheme.inverseSurface,
      actionTextColor: isDark ? AppColors.teal : AppColors.tealBright,
      closeIconColor: scheme.onInverseSurface.withValues(alpha: 0.7),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w500,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: rounded(AppRadius.lg),
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      dragHandleSize: const Size(36, 5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      modalBarrierColor: Colors.black.withValues(alpha: 0.35),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: rounded(AppRadius.base),
      textStyle: textTheme.bodyLarge,
      labelTextStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.bodyLarge),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(
          isDark ? AppColors.darkSurfaceElevated : Colors.white,
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(rounded(AppRadius.base)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface.withValues(alpha: 0.92),
        borderRadius: AppRadius.sm,
      ),
      textStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
    ),
    // Segmented-control style tabs: a raised "thumb" on a neutral track.
    // Call sites that want the full control wrap the TabBar in a container
    // painted with [AppColors.fill].
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      dividerHeight: 0,
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      indicator: BoxDecoration(
        color: isDark ? const Color(0xFF636366) : Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: isDark
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 1,
                  offset: const Offset(0, 0.5),
                ),
              ],
      ),
      labelStyle: textTheme.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: textTheme.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll<double>(0),
      constraints: const BoxConstraints(minHeight: 40),
      backgroundColor: WidgetStatePropertyAll<Color>(fill),
      surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      shape: WidgetStatePropertyAll<OutlinedBorder>(rounded(AppRadius.base)),
      side: const WidgetStatePropertyAll<BorderSide>(BorderSide.none),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      hintStyle: WidgetStatePropertyAll<TextStyle?>(
        textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.bodyLarge),
    ),
    searchViewTheme: SearchViewThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      headerHintStyle: textTheme.bodyLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      headerTextStyle: textTheme.bodyLarge,
      shape: rounded(AppRadius.lg),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 62,
      backgroundColor: barColor,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      labelPadding: const EdgeInsets.only(top: 2),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: _textFont,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05,
          color: selected ? scheme.primary : inactiveTab,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 25,
          color: selected ? scheme.primary : inactiveTab,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: barColor,
      indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
      indicatorShape: rounded(AppRadius.base),
      selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
      unselectedIconTheme: IconThemeData(color: inactiveTab, size: 24),
      selectedLabelTextStyle: TextStyle(
        fontFamily: _textFont,
        color: scheme.primary,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: _textFont,
        color: inactiveTab,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      circularTrackColor: Colors.transparent,
      linearTrackColor: scheme.outlineVariant,
      linearMinHeight: 3,
      borderRadius: AppRadius.pill,
      strokeCap: StrokeCap.round,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: isDark
          ? const Color(0xFF3A3A3C)
          : const Color(0xFFE3E3E8),
      thumbColor: Colors.white,
      overlayColor: Colors.transparent,
      trackHeight: 4,
      activeTickMarkColor: Colors.transparent,
      inactiveTickMarkColor: Colors.transparent,
      valueIndicatorColor: scheme.inverseSurface,
      valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      thumbShape: const RoundSliderThumbShape(
        enabledThumbRadius: 12,
        elevation: 2,
        pressedElevation: 3,
      ),
    ),
    // iOS-style switch: green track when on, white thumb, no outline.
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.healthy;
        }
        return isDark ? const Color(0xFF39393D) : const Color(0xFFE3E3E8);
      }),
      trackOutlineColor: const WidgetStatePropertyAll<Color>(
        Colors.transparent,
      ),
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
      thumbIcon: const WidgetStatePropertyAll<Icon?>(
        Icon(Icons.circle, color: Colors.transparent),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: scheme.outline, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return Colors.transparent;
      }),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return scheme.outline;
      }),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: scheme.onSurfaceVariant,
      collapsedIconColor: scheme.onSurfaceVariant,
    ),
  );
}

ThemeData buildLightAppTheme() => _buildAppTheme(Brightness.light);

ThemeData buildDarkAppTheme() => _buildAppTheme(Brightness.dark);

class ArgoCdApp extends StatefulWidget {
  const ArgoCdApp({
    super.key,
    required this.controller,
    required this.themeController,
  });

  final AppController controller;
  final ThemeController themeController;

  @override
  State<ArgoCdApp> createState() => _ArgoCdAppState();
}

class _ArgoCdAppState extends State<ArgoCdApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
    widget.themeController.initialize();
    widget.controller.healthMonitor?.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller,
        widget.themeController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ArgoCD Flutter',
          theme: buildLightAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: widget.themeController.themeMode,
          home: switch (widget.controller.stage) {
            AppStage.booting => const _BootstrapScreen(),
            AppStage.unauthenticated => SignInScreen(
              controller: widget.controller,
            ),
            AppStage.authenticated => HomeShell(
              controller: widget.controller,
              themeController: widget.themeController,
            ),
          },
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
    required this.themeController,
  });

  final AppController controller;
  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _pagesInitialized = false;
  late final List<Widget> _pages;

  void _openApplication(String applicationName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return ApplicationDetailScreen(
            controller: widget.controller,
            applicationName: applicationName,
          );
        },
      ),
    );
  }

  void _openProject(String projectName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return ProjectDetailScreen(
            controller: widget.controller,
            projectName: projectName,
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller.healthMonitor?.onNewEvents = _onNewHealthEvents;
  }

  void _onNewHealthEvents(List<HealthEvent> events) {
    if (!mounted) {
      return;
    }
    final event = events.first;
    final remaining = events.length - 1;
    final suffix = remaining > 0 ? ' (+$remaining more)' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            const StatusDot(color: AppColors.degraded),
            const SizedBox(width: 10),
            Expanded(child: Text('${event.summary}$suffix')),
          ],
        ),
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _openApplication(event.applicationName),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pagesInitialized) {
      _pages = <Widget>[
        DashboardScreen(
          controller: widget.controller,
          onOpenApplication: _openApplication,
          onShowSearch: _showQuickSearch,
        ),
        ApplicationsScreen(
          controller: widget.controller,
          onOpenApplication: _openApplication,
        ),
        ProjectsScreen(
          controller: widget.controller,
          onOpenProject: _openProject,
        ),
        SettingsScreen(
          controller: widget.controller,
          themeController: widget.themeController,
        ),
      ];
      _pagesInitialized = true;
    }
  }

  void _selectTab(int value) {
    if (value == _index) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _index = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sidebarNav = width >= 900;
    final pages = <Widget>[
      for (var i = 0; i < _pages.length; i++)
        _ShellPage(
          title: _shellDestinations[i].label,
          maxContentWidth: _shellDestinations[i].maxContentWidth,
          child: _pages[i],
        ),
    ];

    return Scaffold(
      body: sidebarNav
          ? Row(
              children: <Widget>[
                _ShellSidebar(
                  selectedIndex: _index,
                  onDestinationSelected: _selectTab,
                  onSearch: _showQuickSearch,
                  session: widget.controller.session,
                ),
                Expanded(
                  child: _IndexedStackWithTickerMode(
                    index: _index,
                    children: pages,
                  ),
                ),
              ],
            )
          : _IndexedStackWithTickerMode(index: _index, children: pages),
      bottomNavigationBar: sidebarNav
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                destinations: <NavigationDestination>[
                  for (final destination in _shellDestinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label,
                      tooltip: destination.label,
                    ),
                ],
                onDestinationSelected: _selectTab,
              ),
            ),
    );
  }

  Future<void> _showQuickSearch() async {
    await showSearch<void>(
      context: context,
      delegate: _ShellSearchDelegate(
        controller: widget.controller,
        onOpenApplication: _openApplication,
        onOpenProject: _openProject,
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.maxContentWidth,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Readable-width cap for the page on large screens.
  final double maxContentWidth;
}

const List<_ShellDestination> _shellDestinations = <_ShellDestination>[
  _ShellDestination(
    label: 'Dashboard',
    icon: Icons.analytics_outlined,
    selectedIcon: Icons.analytics,
    maxContentWidth: 1180,
  ),
  _ShellDestination(
    label: 'Applications',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    maxContentWidth: 980,
  ),
  _ShellDestination(
    label: 'Projects',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
    maxContentWidth: 980,
  ),
  _ShellDestination(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    maxContentWidth: 720,
  ),
];

/// Wraps a root tab page with two iOS behaviours:
///
/// * a readable-width cap on large screens, and
/// * a compact, translucent navigation bar that fades in with the page title
///   once the large title has scrolled away (tap it to scroll to top).
class _ShellPage extends StatefulWidget {
  const _ShellPage({
    required this.title,
    required this.maxContentWidth,
    required this.child,
  });

  final String title;
  final double maxContentWidth;
  final Widget child;

  @override
  State<_ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<_ShellPage> {
  static const double _collapseStart = 36;
  static const double _collapseEnd = 56;

  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  ScrollPosition? _position;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final context = notification.context;
    if (context != null) {
      _position = Scrollable.maybeOf(context)?.position;
    }
    final offset = notification.metrics.pixels;
    _progress.value =
        ((offset - _collapseStart) / (_collapseEnd - _collapseStart)).clamp(
          0.0,
          1.0,
        );
    return false;
  }

  void _scrollToTop() {
    final position = _position;
    if (position == null || !position.hasPixels) {
      return;
    }
    position.animateTo(
      0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxContentWidth),
                child: widget.child,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (context, progress, _) {
                if (progress == 0) {
                  return const SizedBox.shrink();
                }
                return _CompactTitleBar(
                  title: widget.title,
                  progress: progress,
                  onTap: _scrollToTop,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactTitleBar extends StatelessWidget {
  const _CompactTitleBar({
    required this.title,
    required this.progress,
    required this.onTap,
  });

  final String title;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final barColor = theme.brightness == Brightness.dark
        ? const Color(0xFF121214)
        : const Color(0xFFF9F9FB);

    return Opacity(
      opacity: progress,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: topInset + 44,
              padding: EdgeInsets.only(top: topInset),
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.82),
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
                ),
              ),
              alignment: Alignment.center,
              child: Semantics(
                header: true,
                button: true,
                hint: 'Scroll to top',
                child: Text(title, style: theme.appBarTheme.titleTextStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// iPadOS-style sidebar used on wide layouts: brand header, search field,
/// tinted selection and the signed-in account at the bottom.
class _ShellSidebar extends StatelessWidget {
  const _ShellSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSearch,
    required this.session,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSearch;
  final AppSession? session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final host = session == null
        ? null
        : (Uri.tryParse(session!.serverUrl)?.host.isNotEmpty ?? false)
        ? Uri.parse(session!.serverUrl).host
        : session!.serverUrl;

    return Container(
      width: AppSpacing.shellSidebar,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: <Widget>[
                    const ArgoLogo(size: 30),
                    const SizedBox(width: 10),
                    Text('Argo CD', style: theme.textTheme.titleLarge),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                button: true,
                label: 'Search',
                child: Material(
                  color: AppColors.fill(theme),
                  borderRadius: AppRadius.sm,
                  child: InkWell(
                    onTap: onSearch,
                    borderRadius: AppRadius.sm,
                    child: SizedBox(
                      height: 36,
                      child: Row(
                        children: <Widget>[
                          const SizedBox(width: 9),
                          Icon(
                            Icons.search_rounded,
                            size: 19,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          ExcludeSemantics(
                            child: Text(
                              'Search',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _shellDestinations.length; i++)
                _SidebarItem(
                  destination: _shellDestinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onDestinationSelected(i),
                ),
              const Spacer(),
              if (session != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.gray6,
                        foregroundColor: Colors.white,
                        child: Text(
                          session!.username.isEmpty
                              ? '?'
                              : session!.username[0].toUpperCase(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              session!.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (host != null)
                              Text(
                                host,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: AppRadius.sm,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.sm,
            child: SizedBox(
              height: 40,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 10),
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 21,
                    color: selected ? scheme.onPrimary : scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    destination.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ArgoLogo(size: 80),
              const SizedBox(height: 20),
              Text('Argo CD', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Preparing workspace',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [IndexedStack] wrapper that automatically disables [TickerMode] for
/// offscreen children so that repeating animations and periodic timers don't
/// prevent [WidgetTester.pumpAndSettle] from settling in tests, while still
/// preserving widget state across tab switches.
class _IndexedStackWithTickerMode extends StatelessWidget {
  const _IndexedStackWithTickerMode({
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      children: <Widget>[
        for (int i = 0; i < children.length; i++)
          TickerMode(
            key: ValueKey<int>(i),
            enabled: i == index,
            child: children[i],
          ),
      ],
    );
  }
}

class _ShellSearchDelegate extends SearchDelegate<void> {
  _ShellSearchDelegate({
    required this.controller,
    required this.onOpenApplication,
    required this.onOpenProject,
  });

  final AppController controller;
  final ValueChanged<String> onOpenApplication;
  final ValueChanged<String> onOpenProject;

  @override
  String get searchFieldLabel => 'Search applications or projects';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: scheme.surface,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear',
          onPressed: () => query = '',
          icon: const Icon(Icons.close_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final normalizedQuery = query.trim().toLowerCase();
    final matchingApplications = controller.applications
        .where((app) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return app.name.toLowerCase().contains(normalizedQuery) ||
              app.project.toLowerCase().contains(normalizedQuery) ||
              app.namespace.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
    final matchingProjects = controller.projects
        .where((project) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return project.name.toLowerCase().contains(normalizedQuery) ||
              project.description.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    if (matchingApplications.isEmpty && matchingProjects.isEmpty) {
      return Center(
        child: Padding(
          padding: kPagePadding,
          child: const EmptyStateCard(
            icon: Icons.search_off_rounded,
            title: 'No results',
            subtitle: 'No applications or projects match this search.',
          ),
        ),
      );
    }

    return ListView(
      padding: kPagePadding.copyWith(top: 20),
      children: <Widget>[
        if (matchingApplications.isNotEmpty)
          GroupedList(
            header: 'Applications',
            dividerIndent: 60,
            children: <Widget>[
              for (final ArgoApplication application in matchingApplications)
                GroupedRow(
                  leading: IconWell(
                    icon: Icons.dashboard_rounded,
                    color: AppColors.healthColor(application.healthStatus),
                  ),
                  title: application.name,
                  subtitle: '${application.project} / ${application.namespace}',
                  onTap: () {
                    close(context, null);
                    onOpenApplication(application.name);
                  },
                ),
            ],
          ),
        if (matchingApplications.isNotEmpty && matchingProjects.isNotEmpty)
          const SizedBox(height: 28),
        if (matchingProjects.isNotEmpty)
          GroupedList(
            header: 'Projects',
            dividerIndent: 60,
            children: <Widget>[
              for (final ArgoProject project in matchingProjects)
                GroupedRow(
                  leading: IconWell(
                    icon: Icons.folder_rounded,
                    color: scheme.tertiary,
                  ),
                  title: project.name,
                  subtitle: project.description.isEmpty
                      ? '${project.destinations.length} destinations'
                      : project.description,
                  onTap: () {
                    close(context, null);
                    onOpenProject(project.name);
                  },
                ),
            ],
          ),
      ],
    );
  }
}
