import 'dart:async';

import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  appClock = () => DateTime.utc(2026, 4, 10, 10, 0, 0);
  await loadAppFonts();
  await testMain();
}
