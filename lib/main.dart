import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/health_monitor.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';

import 'sentry_init_native.dart'
    if (dart.library.js_interop) 'sentry_init_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSentryForPlatform(_runApp);
}

Future<void> _runApp() async {
  final themeController = ThemeController();

  // Create controller first, then wire HealthMonitor's refresh callback.
  late final AppController controller;
  final healthMonitor = HealthMonitor(
    onRefreshRequested: () => controller.refreshApplications(showSpinner: false),
  );

  controller = AppController(
    storage: SecureSessionStorage(),
    api: NetworkArgoCdApi(),
    certificateProvider: CertificateProvider(),
    healthMonitor: healthMonitor,
  );

  runApp(
    ArgoCdApp(
      controller: controller,
      themeController: themeController,
    ),
  );
}
