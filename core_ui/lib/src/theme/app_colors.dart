import 'package:flutter/material.dart';

/// Core UI color constants matching the Connect-Ed app theme
class AppColors {
  // Primary colors
  static const Color primaryLight = Color.fromARGB(255, 0, 66, 112);
  static const Color primaryDark = Color.fromARGB(255, 160, 207, 235);

  // Secondary colors
  static const Color secondaryLight = Color.fromARGB(255, 160, 207, 235);
  static const Color secondaryDark = Color.fromARGB(255, 0, 66, 112);

  // Tertiary colors
  static const Color tertiaryLight = Color.fromARGB(255, 231, 231, 231);
  static const Color tertiaryDark = Color.fromARGB(255, 48, 48, 48);

  // Surface colors
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color.fromARGB(255, 16, 16, 16);

  // On colors
  static const Color onPrimaryLight = Colors.white;
  static const Color onPrimaryDark = Colors.black;
  static const Color onSecondaryLight = Colors.black;
  static const Color onSecondaryDark = Colors.white;
  static const Color onSurfaceLight = Colors.black;
  static const Color onSurfaceDark = Colors.white;

  // Error colors
  static const Color errorLight = Color.fromARGB(255, 160, 31, 31);
  static const Color errorDark = Color.fromARGB(255, 241, 114, 114);

  // Gradient colors
  static const List<Color> primaryGradient = [
    Color.fromARGB(255, 0, 66, 112),
    Color.fromARGB(255, 160, 207, 235),
  ];

  // Utility colors
  static const Color transparent = Colors.transparent;
  static const Color divider = Color.fromARGB(255, 224, 224, 224);

  /// Get color scheme for light theme
  static ColorScheme get lightScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: primaryLight,
        onPrimary: onPrimaryLight,
        secondary: secondaryLight,
        onSecondary: onSecondaryLight,
        tertiary: tertiaryLight,
        error: errorLight,
        onError: onSecondaryLight,
        surface: surfaceLight,
        onSurface: onSurfaceLight,
      );

  /// Get color scheme for dark theme
  static ColorScheme get darkScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryDark,
        onPrimary: onPrimaryDark,
        secondary: secondaryDark,
        onSecondary: onSecondaryDark,
        tertiary: tertiaryDark,
        error: errorDark,
        onError: onPrimaryDark,
        surface: surfaceDark,
        onSurface: onSurfaceDark,
      );
}
