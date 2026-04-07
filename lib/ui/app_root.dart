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
      primary: AppColors.teal,
      secondary: AppColors.healthy,
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
    dividerColor: AppColors.gray4,
    appBarTheme: const AppBarTheme(toolbarHeight: 48),
    navigationBarTheme: NavigationBarThemeData(
      height: 60,
      backgroundColor: AppColors.sidebarDark,
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
  );
}

ThemeData buildDarkAppTheme() {
  final darkBaseTextTheme = ThemeData.dark().textTheme.apply(
    bodyColor: AppColors.gray3,
    displayColor: AppColors.gray3,
    fontFamily: _displayFontFamily,
  );

  return ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.teal,
      secondary: AppColors.healthy,
      surface: AppColors.darkSurface,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.gray3,
    ),
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
    appBarTheme: const AppBarTheme(toolbarHeight: 48),
    navigationBarTheme: NavigationBarThemeData(
      height: 60,
      backgroundColor: AppColors.sidebarDark,
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
    final compactNav = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      body: _IndexedStackWithTickerMode(index: _index, children: _pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickSearch,
        icon: const Icon(Icons.search),
        label: Text(compactNav ? 'Search' : 'Quick search'),
      ),
      bottomNavigationBar: NavigationBar(
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
        destinations: const <NavigationDestination>[
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
        ],
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
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_queue_rounded, size: 64, color: AppColors.teal),
              const SizedBox(height: 16),
              Text(
                'Argo CD',
                style: TextStyle(
                  fontFamily: _displayFontFamily,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.orange,
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
      return const Center(child: Text('No matching applications or projects.'));
    }

    return ListView(
      children: <Widget>[
        if (matchingApplications.isNotEmpty) ...<Widget>[
          _SearchSectionHeader(title: 'Applications'),
          ...matchingApplications.map(
            (ArgoApplication application) => ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: Text(application.name),
              subtitle: Text(
                '${application.project} • ${application.namespace}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                close(context, null);
                onOpenApplication(application.name);
              },
            ),
          ),
        ],
        if (matchingProjects.isNotEmpty) ...<Widget>[
          _SearchSectionHeader(title: 'Projects'),
          ...matchingProjects.map(
            (ArgoProject project) => ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(project.name),
              subtitle: Text(
                project.description.isEmpty
                    ? '${project.destinations.length} destinations'
                    : project.description,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                close(context, null);
                onOpenProject(project.name);
              },
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
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
