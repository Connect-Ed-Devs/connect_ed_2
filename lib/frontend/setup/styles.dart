import 'package:flutter/material.dart';

ColorScheme lightScheme = const ColorScheme(
  brightness: Brightness.light,
  primary: Color.fromARGB(255, 0, 66, 112),
  onPrimary: Colors.white,
  secondary: Color.fromARGB(255, 160, 207, 235),
  tertiary: Color.fromARGB(255, 231, 231, 231),

  onSecondary: Colors.black,
  error: Color.fromARGB(255, 241, 114, 114),
  onError: Colors.black,
  surface: Colors.white,
  onSurface: Colors.black,
);

ColorScheme darkScheme = const ColorScheme(
  brightness: Brightness.dark,
  primary: Color.fromARGB(255, 160, 207, 235),
  onPrimary: Colors.black,
  secondary: Color.fromARGB(255, 0, 66, 112),
  tertiary: Color.fromARGB(255, 48, 48, 48),
  onSecondary: Colors.white,
  error: Color.fromARGB(255, 160, 31, 31),
  onError: Colors.white,
  surface: Color.fromARGB(255, 16, 16, 16),
  onSurface: Colors.white,
);
