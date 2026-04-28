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
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

const _displayFontFamily = 'SpaceGrotesk';
const _bodyFontFamily = 'DMSans';

ThemeData buildLightAppTheme() {
  final lightBaseTextTheme = ThemeData.light().textTheme.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
    fontFamily: _displayFontFamily,
  );

  final scheme = const ColorScheme.light(
    primary: AppColors.teal,
    secondary: AppColors.orange,
    tertiary: AppColors.indigo,
    surface: AppColors.white,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.gray1,
    surfaceContainer: AppColors.gray2,
    surfaceContainerHigh: Color(0xFFE7EEF2),
    surfaceContainerHighest: Color(0xFFDDE7EC),
    onPrimary: AppColors.white,
    onSecondary: AppColors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.gray6,
    outline: Color(0xFFD7E0E6),
    outlineVariant: Color(0xFFE2E9ED),
    error: AppColors.error,
    shadow: Color(0xFF1E2933),
  );

  return ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: scheme,
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
    dividerColor: AppColors.gray4,
    appBarTheme: AppBarTheme(
      toolbarHeight: 56,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.inkDark,
      titleTextStyle: lightBaseTextTheme.titleLarge?.copyWith(
        color: AppColors.inkDark,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: const BorderSide(color: Color(0xFFD7E0E6)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: AppColors.teal.withValues(alpha: 0.14),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
      labelStyle: const TextStyle(fontFamily: _bodyFontFamily),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.inkDark,
      foregroundColor: AppColors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      backgroundColor: AppColors.headerDark,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.teal.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: _bodyFontFamily,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.white : AppColors.gray5,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? AppColors.orange : AppColors.gray5,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.headerDark,
      indicatorColor: AppColors.teal.withValues(alpha: 0.16),
      selectedIconTheme: const IconThemeData(color: AppColors.orange, size: 24),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.gray5,
        size: 22,
      ),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.gray5,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

ThemeData buildDarkAppTheme() {
  final darkBaseTextTheme = ThemeData.dark().textTheme.apply(
    bodyColor: AppColors.gray3,
    displayColor: AppColors.gray3,
    fontFamily: _displayFontFamily,
  );

  final scheme = const ColorScheme.dark(
    primary: AppColors.teal,
    secondary: AppColors.orange,
    tertiary: AppColors.azure,
    surface: AppColors.darkSurface,
    surfaceContainerLowest: Color(0xFF11161B),
    surfaceContainerLow: AppColors.darkSurface,
    surfaceContainer: AppColors.darkSurfaceElevated,
    surfaceContainerHigh: Color(0xFF26303A),
    surfaceContainerHighest: Color(0xFF303B46),
    onPrimary: AppColors.white,
    onSecondary: AppColors.white,
    onSurface: AppColors.gray3,
    onSurfaceVariant: AppColors.gray5,
    outline: AppColors.darkBorder,
    outlineVariant: Color(0xFF26323B),
    error: AppColors.error,
    shadow: AppColors.darkBackground,
  );

  return ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: scheme,
    textTheme: darkBaseTextTheme.copyWith(
      bodyMedium: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.gray3,
        fontSize: 16,
      ),
      bodyLarge: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.gray3,
        fontSize: 18,
      ),
    ),
    dividerColor: AppColors.darkBorder,
    appBarTheme: AppBarTheme(
      toolbarHeight: 56,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.gray2,
      titleTextStyle: darkBaseTextTheme.titleLarge?.copyWith(
        color: AppColors.gray2,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.md,
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainer,
      selectedColor: AppColors.teal.withValues(alpha: 0.2),
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
      labelStyle: const TextStyle(fontFamily: _bodyFontFamily),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.teal,
      foregroundColor: AppColors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceElevated,
      border: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      backgroundColor: AppColors.headerDark,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.teal.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: _bodyFontFamily,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.white : AppColors.gray5,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: selected ? AppColors.orange : AppColors.gray5,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.headerDark,
      indicatorColor: AppColors.teal.withValues(alpha: 0.18),
      selectedIconTheme: const IconThemeData(color: AppColors.orange, size: 24),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.gray5,
        size: 22,
      ),
      selectedLabelTextStyle: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(
        fontFamily: _bodyFontFamily,
        color: AppColors.gray5,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
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
    widget.controller.healthMonitor?.initialize();
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
        content: Text('${event.summary}$suffix'),
        backgroundColor: AppColors.degraded,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          textColor: AppColors.white,
          onPressed: () => _openApplication(event.applicationName),
        ),
        duration: const Duration(seconds: 5),
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
    final compactNav = width < 600;
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
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
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
        icon: const Icon(Icons.search),
        label: Text(railNav || !compactNav ? 'Quick search' : 'Search'),
      ),
      bottomNavigationBar: railNav
          ? null
          : NavigationBar(
              selectedIndex: _index,
              animationDuration: const Duration(milliseconds: 400),
              labelBehavior: compactNav
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (value) {
                setState(() {
                  _index = value;
                });
              },
              destinations: navDestinations,
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

    return SizedBox(
      width: 92,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.all,
        minWidth: 92,
        minExtendedWidth: 92,
        leading: Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 18),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.headerChipBackground(theme, alpha: 0.14),
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.headerDivider(theme)),
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: AppColors.orange,
              size: 24,
            ),
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

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.outline(theme)),
                boxShadow: AppElevation.subtle(
                  AppColors.surfaceShadow(theme, alpha: 0.10),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: AppRadius.md,
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      size: 30,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Argo CD',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFamily: _displayFontFamily,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Preparing workspace',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedText(theme),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 3),
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
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResults(context);

  Widget _buildResults(BuildContext context) {
    final theme = Theme.of(context);
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
        child: EmptyStateCard(
          icon: Icons.search_off_rounded,
          title: 'No results',
          subtitle: 'No applications or projects match this search.',
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
                leading: CircleAvatar(
                  backgroundColor: AppColors.teal.withValues(alpha: 0.12),
                  foregroundColor: AppColors.teal,
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText(theme),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
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
                leading: CircleAvatar(
                  backgroundColor: AppColors.orange.withValues(alpha: 0.12),
                  foregroundColor: AppColors.orange,
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedText(theme),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.mutedText(Theme.of(context)),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
