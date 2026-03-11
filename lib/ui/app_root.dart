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
      surface: Colors.white,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
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
      labelTextStyle: const MaterialStatePropertyAll<TextStyle>(
        TextStyle(
          fontFamily: _bodyFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: MaterialStateProperty.resolveWith<IconThemeData>((states) {
        final color = states.contains(MaterialState.selected)
            ? Colors.white
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
      onPrimary: Colors.white,
      onSecondary: Colors.white,
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
    navigationBarTheme: const NavigationBarThemeData(
      height: 56,
      labelTextStyle: MaterialStatePropertyAll<TextStyle>(
        TextStyle(
          fontFamily: _bodyFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
