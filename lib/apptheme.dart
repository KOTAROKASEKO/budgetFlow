import 'package:flutter/material.dart';

class AppTheme {
  // --- Primary Dark Palette ---
  static const Color baseBackground = Color(0xFF16161A); // Near Black
  static const Color cardBackground = Color(0xFF1E1E24); // Dark Grey for cards
  static const Color primaryText = Color(0xFFEAEAEB);    // Soft White
  static const Color secondaryText = Color(0xFF8A8A90);  // Cool Grey
  static const Color shiokuriBlue = Color(0xFF3B82F6); // Primary Accent (Electric Blue)

  // --- Chart Accent Palette ---
  static const List<Color> chartColors = [
    shiokuriBlue,
    Color(0xFF14B8A6), // Vibrant Teal
    Color(0xFFF97316), // Warm Orange
    Color(0xFF8B5CF6), // Cool Purple
    Color(0xFF84CC16), // Lime Green
    Color(0xFFEC4899), // Rose Pink
    Color(0xFFFACC15), // Bright Yellow
    Color(0xFF22D3EE), // Cyan
  ];

  // --- Typography (using system default for simplicity, recommend 'Inter' or 'Manrope') ---
  // For a truly custom look, add font files to your project and define TextStyles here.
  // Example: static const TextStyle heading1 = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 24, color: primaryText);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: baseBackground,
    primaryColor: shiokuriBlue,
    colorScheme: const ColorScheme.dark(
      primary: shiokuriBlue,
      secondary: shiokuriBlue, // Can be another accent
      surface: cardBackground, // Used by Cards, Dialogs
      background: baseBackground,
      error: Colors.redAccent,
      onPrimary: primaryText,
      onSecondary: primaryText,
      onSurface: primaryText,
      onBackground: primaryText,
      onError: primaryText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: baseBackground,
      elevation: 0,
      titleTextStyle: TextStyle(
          color: primaryText, fontSize: 20, fontWeight: FontWeight.w600),
      iconTheme: IconThemeData(color: primaryText),
    ),
    cardTheme: CardTheme(
      color: cardBackground,
      elevation: 2, // Subtle shadow
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold, color: primaryText, letterSpacing: 0.5), // For Total Amount
      headlineMedium: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: primaryText), // Main titles
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500, color: primaryText), // Card titles
      bodyLarge: TextStyle(fontSize: 14, color: primaryText),
      bodyMedium: TextStyle(fontSize: 12, color: secondaryText), // Secondary info
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, color: shiokuriBlue), // Buttons
    ),
    iconTheme: const IconThemeData(color: primaryText, size: 24),
    dividerColor: secondaryText.withOpacity(0.3),
    tabBarTheme: TabBarTheme(
      labelColor: shiokuriBlue,
      unselectedLabelColor: secondaryText,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: shiokuriBlue, width: 2.0),
      ),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    // Add other theme properties as needed
  );

  
}