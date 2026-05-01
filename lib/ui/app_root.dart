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
import 'package:flutter/material.dart';

const _displayFontFamily = 'SpaceGrotesk';
const _bodyFontFamily = 'DMSans';

/// Build a Material 3 / Material You [ThemeData] derived from the ArgoCD
/// brand seed colour. All surface tones, container roles and on-colours come
/// from [ColorScheme.fromSeed], with hand-picked secondary/tertiary roles
/// that lock the brand palette in place.
ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
    primary: AppColors.teal,
    secondary: AppColors.orange,
    tertiary: AppColors.indigo,
    error: AppColors.error,
  );

  final baseTextTheme = (isDark ? ThemeData.dark() : ThemeData.light())
      .textTheme
      .apply(fontFamily: _displayFontFamily);

  final textTheme = baseTextTheme.copyWith(
    displayLarge: baseTextTheme.displayLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    displayMedium: baseTextTheme.displayMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
    ),
    headlineLarge: baseTextTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    ),
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.2,
    ),
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    bodyLarge: const TextStyle(
      fontFamily: _bodyFontFamily,
      fontSize: 16,
      height: 1.4,
    ),
    bodyMedium: const TextStyle(
      fontFamily: _bodyFontFamily,
      fontSize: 14.5,
      height: 1.4,
    ),
    bodySmall: const TextStyle(
      fontFamily: _bodyFontFamily,
      fontSize: 12.5,
      height: 1.35,
    ),
    labelLarge: const TextStyle(
      fontFamily: _bodyFontFamily,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
    labelMedium: const TextStyle(
      fontFamily: _bodyFontFamily,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
    labelSmall: const TextStyle(
      fontFamily: _bodyFontFamily,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    splashFactory: InkSparkle.splashFactory,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    dividerColor: scheme.outlineVariant,
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    appBarTheme: AppBarTheme(
      toolbarHeight: 60,
      elevation: 0,
      scrolledUnderElevation: 2,
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      foregroundColor: scheme.onSurface,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      margin: EdgeInsets.zero,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.secondaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
      labelStyle: TextStyle(
        fontFamily: _bodyFontFamily,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 3,
      focusElevation: 6,
      hoverElevation: 6,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.base,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(56, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        textStyle: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        textStyle: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.base),
        textStyle: const TextStyle(
          fontFamily: _bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.base),
      titleTextStyle: textTheme.titleSmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.base),
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: _bodyFontFamily,
        color: scheme.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      modalBarrierColor: scheme.scrim.withValues(alpha: 0.5),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: scheme.primary, width: 3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
      labelStyle: const TextStyle(
        fontFamily: _bodyFontFamily,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        letterSpacing: 0.4,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: _bodyFontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        letterSpacing: 0.4,
      ),
    ),
    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll<double>(0),
      backgroundColor: WidgetStatePropertyAll<Color>(
        scheme.surfaceContainerHigh,
      ),
      surfaceTintColor: WidgetStatePropertyAll<Color>(scheme.surfaceTint),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppRadius.xl),
      ),
      side: WidgetStatePropertyAll<BorderSide>(
        BorderSide(color: scheme.outlineVariant),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 16),
      ),
      hintStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontFamily: _bodyFontFamily,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontFamily: _bodyFontFamily,
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    searchViewTheme: SearchViewThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: scheme.surfaceTint,
      headerHintStyle: TextStyle(
        fontFamily: _bodyFontFamily,
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
      headerTextStyle: TextStyle(
        fontFamily: _bodyFontFamily,
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 3,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: _bodyFontFamily,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(
        color: scheme.onSecondaryContainer,
        size: 24,
      ),
      unselectedIconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: 22,
      ),
      selectedLabelTextStyle: TextStyle(
        fontFamily: _bodyFontFamily,
        color: scheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: _bodyFontFamily,
        color: scheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      circularTrackColor: scheme.surfaceContainerHighest,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.onPrimary;
        }
        return scheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return scheme.surfaceContainerHighest;
      }),
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
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${event.summary}$suffix'),
        backgroundColor: scheme.errorContainer,
        showCloseIcon: true,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          textColor: scheme.onErrorContainer,
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final railNav = width >= 900;
    final navDestinations = const <NavigationDestination>[
      NavigationDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics),
        label: 'Dashboard',
        tooltip: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Applications',
        tooltip: 'Applications',
      ),
      NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder),
        label: 'Projects',
        tooltip: 'Projects',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
        tooltip: 'Settings',
      ),
    ];

    return Scaffold(
      body: railNav
          ? Row(
              children: <Widget>[
                _ShellRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() {
                      _index = value;
                    });
                  },
                ),
                Expanded(
                  child: _IndexedStackWithTickerMode(
                    index: _index,
                    children: _pages,
                  ),
                ),
              ],
            )
          : _IndexedStackWithTickerMode(index: _index, children: _pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickSearch,
        icon: const Icon(Icons.search_rounded),
        label: const Text('Search'),
      ),
      bottomNavigationBar: railNav
          ? null
          : NavigationBar(
              selectedIndex: _index,
              destinations: navDestinations,
              onDestinationSelected: (value) {
                setState(() {
                  _index = value;
                });
              },
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

class _ShellRail extends StatelessWidget {
  const _ShellRail({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        width: AppSpacing.shellRail,
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          labelType: NavigationRailLabelType.all,
          minWidth: AppSpacing.shellRail,
          minExtendedWidth: AppSpacing.shellRail,
          groupAlignment: -0.85,
          backgroundColor: scheme.surfaceContainer,
          leading: Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 26),
            child: Column(
              children: <Widget>[
                const ArgoLogo(size: 44),
                const SizedBox(height: 10),
                Text(
                  'Argo CD',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          trailing: const Expanded(child: SizedBox.shrink()),
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: Text('Dashboard'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: Text('Apps'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: Text('Projects'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: Text('Settings'),
            ),
          ],
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.surface,
              scheme.surfaceContainerLow,
              scheme.surface,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const ArgoLogo(size: 96),
                const SizedBox(height: 18),
                Text(
                  'Argo CD',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Preparing workspace',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
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
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: scheme.surfaceTint,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
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
      icon: const Icon(Icons.arrow_back_rounded),
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
      padding: kPagePadding,
      children: <Widget>[
        if (matchingApplications.isNotEmpty) ...<Widget>[
          _SearchSectionHeader(title: 'Applications'),
          ...matchingApplications.map(
            (ArgoApplication application) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.dashboard_outlined, size: 20),
                ),
                title: Text(
                  application.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${application.project} / ${application.namespace}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  close(context, null);
                  onOpenApplication(application.name);
                },
              ),
            ),
          ),
        ],
        if (matchingProjects.isNotEmpty) ...<Widget>[
          _SearchSectionHeader(title: 'Projects'),
          ...matchingProjects.map(
            (ArgoProject project) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
                leading: CircleAvatar(
                  backgroundColor: scheme.tertiaryContainer,
                  foregroundColor: scheme.onTertiaryContainer,
                  child: const Icon(Icons.folder_outlined, size: 20),
                ),
                title: Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  project.description.isEmpty
                      ? '${project.destinations.length} destinations'
                      : project.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  close(context, null);
                  onOpenProject(project.name);
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
