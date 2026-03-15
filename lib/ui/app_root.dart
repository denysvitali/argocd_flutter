import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/features/applications/application_detail_screen.dart';
import 'package:argocd_flutter/features/applications/applications_screen.dart';
import 'package:argocd_flutter/features/auth/sign_in_screen.dart';
import 'package:argocd_flutter/features/dashboard/dashboard_screen.dart';
import 'package:argocd_flutter/features/drift/drift_radar_screen.dart';
import 'package:argocd_flutter/features/projects/project_detail_screen.dart';
import 'package:argocd_flutter/features/projects/projects_screen.dart';
import 'package:argocd_flutter/features/settings/settings_screen.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

const _displayFontFamily = 'SpaceGrotesk';
const _bodyFontFamily = 'DMSans';

ThemeData buildLightAppTheme() {
  final lightBaseTextTheme = ThemeData.light().textTheme.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
    fontFamily: _displayFontFamily,
  );

  return ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppColors.cobalt,
      secondary: AppColors.teal,
      surface: AppColors.white,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.ink,
    ),
    textTheme: lightBaseTextTheme.copyWith(
      bodyMedium: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.ink,
        fontSize: 16,
      ),
      bodyLarge: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.ink,
        fontSize: 18,
      ),
    ),
    dividerColor: AppColors.border,
    appBarTheme: const AppBarTheme(toolbarHeight: 48),
    navigationBarTheme: NavigationBarThemeData(
      height: 56,
      labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontFamily: _bodyFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final color = states.contains(WidgetState.selected)
            ? AppColors.white
            : AppColors.grey;
        return IconThemeData(size: 24, color: color);
      }),
    ),
  );
}

ThemeData buildDarkAppTheme() {
  final darkBaseTextTheme = ThemeData.dark().textTheme.apply(
    bodyColor: AppColors.border,
    displayColor: AppColors.border,
    fontFamily: _displayFontFamily,
  );

  return ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cobalt,
      secondary: AppColors.teal,
      surface: AppColors.darkSurface,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.border,
    ),
    textTheme: darkBaseTextTheme.copyWith(
      bodyMedium: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.border,
        fontSize: 16,
      ),
      bodyLarge: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.border,
        fontSize: 18,
      ),
    ),
    dividerColor: AppColors.darkBorder,
    appBarTheme: const AppBarTheme(toolbarHeight: 48),
    navigationBarTheme: NavigationBarThemeData(
      height: 56,
      indicatorColor: AppColors.cobalt,
      labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontFamily: _bodyFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final color = states.contains(WidgetState.selected)
            ? AppColors.white
            : AppColors.grey;
        return IconThemeData(size: 24, color: color);
      }),
    ),
  );
}

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
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = buildLightAppTheme();
    final darkTheme = buildDarkAppTheme();

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.controller,
        widget.themeController,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ArgoCD Flutter',
          theme: baseTheme,
          darkTheme: darkTheme,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache tab pages once so they are not rebuilt on every setState.
    if (!_pagesInitialized) {
      _pages = <Widget>[
        DashboardScreen(
          controller: widget.controller,
          onOpenApplication: _openApplication,
        ),
        DriftRadarScreen(
          controller: widget.controller,
          onOpenApplication: _openApplication,
        ),
        ApplicationsScreen(
          controller: widget.controller,
          onOpenApplication: _openApplication,
        ),
        ProjectsScreen(
          controller: widget.controller,
          onOpenProject: (projectName) {
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
          },
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
    final compactNav = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      body: _IndexedStackWithTickerMode(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          indicatorColor: AppColors.cobalt,
          animationDuration: const Duration(milliseconds: 400),
          labelBehavior: compactNav
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (value) {
            setState(() {
              _index = value;
            });
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'Dashboard',
              tooltip: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.track_changes_outlined),
              selectedIcon: Icon(Icons.track_changes),
              label: 'Drift',
              tooltip: 'Drift Radar',
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_queue_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'ArgoCD Flutter',
                style: TextStyle(
                  fontFamily: _displayFontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colorScheme.primary,
                ),
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
