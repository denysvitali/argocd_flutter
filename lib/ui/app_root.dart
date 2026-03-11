import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/features/applications/application_detail_screen.dart';
import 'package:argocd_flutter/features/applications/applications_screen.dart';
import 'package:argocd_flutter/features/auth/sign_in_screen.dart';
import 'package:argocd_flutter/features/dashboard/dashboard_screen.dart';
import 'package:argocd_flutter/features/projects/project_detail_screen.dart';
import 'package:argocd_flutter/features/projects/projects_screen.dart';
import 'package:argocd_flutter/features/settings/settings_screen.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

ThemeData buildLightAppTheme() {
  final lightBaseTextTheme = ThemeData.light().textTheme.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.canvas,
    colorScheme: const ColorScheme.light(
      primary: AppColors.cobalt,
      secondary: AppColors.teal,
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.ink,
    ),
    textTheme: lightBaseTextTheme.copyWith(
      bodySmall: const TextStyle(
        color: AppColors.ink,
        fontSize: 12,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.ink,
        fontSize: 14,
      ),
      bodyLarge: const TextStyle(
        color: AppColors.ink,
        fontSize: 16,
      ),
      labelSmall: const TextStyle(
        color: AppColors.ink,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: const TextStyle(
        color: AppColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: const TextStyle(
        color: AppColors.ink,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: const TextStyle(
        color: AppColors.ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: const TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: const TextStyle(
        color: AppColors.ink,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerColor: AppColors.border,
    appBarTheme: const AppBarTheme(toolbarHeight: 48),
    navigationBarTheme: NavigationBarThemeData(
      height: 56,
      labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final color = states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.grey;
        return IconThemeData(size: 20, color: color);
      }),
    ),
  );
}

ThemeData buildDarkAppTheme() {
  final darkBaseTextTheme = ThemeData.dark().textTheme.apply(
    bodyColor: AppColors.border,
    displayColor: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    splashFactory: InkRipple.splashFactory,
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cobalt,
      secondary: AppColors.teal,
      surface: AppColors.darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.border,
    ),
    textTheme: darkBaseTextTheme.copyWith(
      bodySmall: const TextStyle(
        color: AppColors.border,
        fontSize: 12,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.border,
        fontSize: 14,
      ),
      bodyLarge: const TextStyle(
        color: AppColors.border,
        fontSize: 16,
      ),
      labelSmall: const TextStyle(
        color: AppColors.border,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: const TextStyle(
        color: AppColors.border,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: const TextStyle(
        color: AppColors.border,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: const TextStyle(
        color: AppColors.border,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: const TextStyle(
        color: AppColors.border,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: const TextStyle(
        color: AppColors.border,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: const TextStyle(
        color: AppColors.border,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerColor: AppColors.darkBorder,
    appBarTheme: const AppBarTheme(toolbarHeight: 48),
    navigationBarTheme: NavigationBarThemeData(
      height: 56,
      labelTextStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final color = states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.greyLight;
        return IconThemeData(size: 20, color: color);
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
  Widget build(BuildContext context) {
    final compactNav = MediaQuery.sizeOf(context).width < 600;
    final pages = <Widget>[
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

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        indicatorColor: AppColors.cobalt,
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
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Applications',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
