import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/argocd_api.dart';
import 'package:argocd_flutter/core/services/certificate_provider.dart';
import 'package:argocd_flutter/core/services/session_storage.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ArgoCdApp(
      controller: AppController(
        storage: SecureSessionStorage(),
        api: NetworkArgoCdApi(),
        certificateProvider: CertificateProvider(),
      ),
    ),
  );
}
