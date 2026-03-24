import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/app_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildLightAppTheme', () {
    test('returns a valid ThemeData', () {
      final theme = buildLightAppTheme();
      expect(theme, isA<ThemeData>());
    });

    test('has Material 3 enabled', () {
      final theme = buildLightAppTheme();
      expect(theme.useMaterial3, isTrue);
    });

    test('has correct scaffold background color', () {
      final theme = buildLightAppTheme();
      expect(theme.scaffoldBackgroundColor, equals(AppColors.canvas));
    });

    test('uses the correct primary color (AppColors.cobalt)', () {
      final theme = buildLightAppTheme();
      expect(theme.colorScheme.primary, equals(AppColors.cobalt));
    });

    test('has light brightness', () {
      final theme = buildLightAppTheme();
      expect(theme.brightness, equals(Brightness.light));
    });
  });

  group('buildDarkAppTheme', () {
    test('returns a valid ThemeData', () {
      final theme = buildDarkAppTheme();
      expect(theme, isA<ThemeData>());
    });

    test('has Material 3 enabled', () {
      final theme = buildDarkAppTheme();
      expect(theme.useMaterial3, isTrue);
    });

    test('has correct scaffold background color', () {
      final theme = buildDarkAppTheme();
      expect(theme.scaffoldBackgroundColor, equals(AppColors.darkBackground));
    });

    test('uses the correct primary color (AppColors.cobalt)', () {
      final theme = buildDarkAppTheme();
      expect(theme.colorScheme.primary, equals(AppColors.cobalt));
    });

    test('has dark brightness', () {
      final theme = buildDarkAppTheme();
      expect(theme.brightness, equals(Brightness.dark));
    });
  });
}
