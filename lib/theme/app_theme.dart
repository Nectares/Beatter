import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors inspired by the logo
  static const Color backgroundStart = Color(0xFFFFF8F1); // #FFF8F1
  static const Color backgroundEnd = Color(0xFFFFF0E0); // Warm peachy orange gradient end
  
  static const Color primaryPurple = Color(0xFFFF7A00); // Beatter Orange (#FF7A00)
  static const Color secondaryCyan = Color(0xFFFF7A00); // Beatter Orange (#FF7A00)
  static const Color accentPink = Color(0xFFFFC266); // Accent (#FFC266)
  
  static const Color cardBackground = Color(0xFAFFFFFF); // Pure white with high opacity for clean light cards
  static const Color cardBorder = Color(0xFFFCD5B5); // Soft orange-tinted border for cards
  static const Color textPrimary = Color(0xFF2D2D2D); // Text Primary (#2D2D2D)
  static const Color textSecondary = Color(0xFF666666); // Text Secondary (#666666)
  static const Color textMuted = Color(0xFF999999); // Text Muted (#999999)

  // Background Gradient Decoration
  static BoxDecoration get backgroundGradient => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundStart, backgroundEnd],
        ),
      );

  // Glassmorphic Card Decoration adapted for light theme
  static BoxDecoration glassCardDecoration({double borderRadius = 16.0}) => BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A00).withOpacity(0.06), // Very soft warm orange shadow
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      );

  // Theme Data definition (configured as light theme, aliased to darkTheme for backwards compatibility)
  static ThemeData get darkTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: backgroundStart,
      primaryColor: primaryPurple,
      colorScheme: const ColorScheme.light(
        primary: primaryPurple,
        primaryContainer: Color(0xFFFFA347),
        secondary: accentPink,
        surface: Colors.white,
        background: backgroundStart,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: primaryPurple,
        selectionColor: Color(0x33FF7A00),
        selectionHandleColor: primaryPurple,
      ),
      // Slider Theme Configuration
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryPurple,
        inactiveTrackColor: const Color(0xFFFFEAD6),
        thumbColor: primaryPurple,
        overlayColor: primaryPurple.withOpacity(0.12),
        valueIndicatorColor: primaryPurple,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
      ),
      // Progress Indicator Theme Configuration
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryPurple,
        linearTrackColor: Color(0xFFFFEAD6),
      ),
      // AppBar Theme Configuration
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      // Bottom Navigation Bar Theme Configuration
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryPurple,
        unselectedItemColor: textSecondary,
      ),
      // Navigation Bar Theme Configuration
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFFEAD6),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: primaryPurple);
          }
          return const IconThemeData(color: textSecondary);
        }),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: primaryPurple, fontWeight: FontWeight.bold);
          }
          return const TextStyle(color: textSecondary);
        }),
      ),
      // Input Decoration Theme Configuration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cardBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      ),
      // Elevated Button Theme Configuration
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      // Filled Button Theme Configuration
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
