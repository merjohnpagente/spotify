import 'package:flutter/material.dart';

class SpotifyColors {
  static const Color primaryBackground = Color(0xFF121212);
  static const Color secondaryBackground = Color(0xFF1E1E1E);
  static const Color cardBackground = Color(0xFF282828);
  static const Color primaryAccent = Color(0xFF1DB954);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color dividerColor = Colors.white10;
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SpotifyColors.primaryBackground,
    primaryColor: SpotifyColors.primaryAccent,
    dividerColor: SpotifyColors.dividerColor,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: SpotifyColors.textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: SpotifyColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: SpotifyColors.textPrimary,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: SpotifyColors.textSecondary,
        fontSize: 14,
      ),
    ),
  );
}