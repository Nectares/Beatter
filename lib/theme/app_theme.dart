import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_shadows.dart';
export 'app_typography.dart';

/// Central theme assembly. Prefer [AppColors]/[AppSpacing]/[AppRadius]/
/// [AppShadows]/[AppTypography] directly in new code — the members below
/// that mirror the old flat `AppTheme.xxx` constants are kept only so
/// existing call sites keep compiling/rendering identically while each
/// screen migrates to the new tokens one at a time.
class AppTheme {
  // --- Deprecated flat aliases (kept at their ORIGINAL values on purpose;
  // do not repoint these at the new AppColors roles — that would repaint
  // every remaining call site uncontrolled instead of migrating them
  // deliberately screen by screen). ---
  @Deprecated('Use AppColors.backgroundStart')
  static const Color backgroundStart = AppColors.backgroundStart;
  @Deprecated('Use AppColors.backgroundEnd')
  static const Color backgroundEnd = AppColors.backgroundEnd;
  @Deprecated('Use AppColors.primary')
  static const Color primaryPurple = Color(0xFFFF7A00);
  @Deprecated('This was always identical to primaryPurple. Migrate each call '
      'site explicitly to AppColors.primary or AppColors.secondary per its '
      'actual semantic intent — do not blind-replace.')
  static const Color secondaryCyan = Color(0xFFFF7A00);
  @Deprecated('Use AppColors.tertiary')
  static const Color accentPink = Color(0xFFFFC266);
  @Deprecated('Use AppColors.surface')
  static const Color cardBackground = AppColors.surface;
  @Deprecated('Use AppColors.surfaceBorder')
  static const Color cardBorder = AppColors.surfaceBorder;
  @Deprecated('Use AppColors.textPrimary')
  static const Color textPrimary = AppColors.textPrimary;
  @Deprecated('Use AppColors.textSecondary')
  static const Color textSecondary = AppColors.textSecondary;
  @Deprecated('Use AppColors.textMuted')
  static const Color textMuted = AppColors.textMuted;

  // Background Gradient Decoration
  static BoxDecoration get backgroundGradient => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
        ),
      );

  // Glassmorphic card decoration — the app's one consistent "surface" look.
  static BoxDecoration glassCardDecoration({double borderRadius = AppRadius.lg}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.surfaceBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      );

  // System status bar / navigation bar styling, matching the light Beatter chrome.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: AppColors.surfaceBorder,
  );

  static ThemeData get lightTheme {
    final textTheme = AppTypography.textTheme;

    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: AppColors.backgroundStart,
      primaryColor: AppColors.primary,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        surface: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: Color(0x33FF7A00),
        selectionHandleColor: AppColors.primary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.inactiveTrack,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.withValues(alpha: 0.12),
        valueIndicatorColor: AppColors.primary,
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.inactiveTrack,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: textTheme.headlineMedium,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.tertiaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return const IconThemeData(color: AppColors.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold);
          }
          return textTheme.labelMedium?.copyWith(color: AppColors.textSecondary);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.titleMedium,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.titleMedium,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.textPrimary,
          highlightColor: AppColors.primary.withValues(alpha: 0.08),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primaryContainer.withValues(alpha: 0.28),
        disabledColor: AppColors.surfaceBorder.withValues(alpha: 0.3),
        labelStyle: textTheme.titleMedium,
        secondaryLabelStyle: textTheme.titleMedium?.copyWith(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.surfaceBorder,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: textTheme.titleMedium,
        unselectedLabelStyle: textTheme.titleMedium,
        dividerColor: AppColors.surfaceBorder,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        contentTextStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceBorder,
        thickness: 1,
        space: AppSpacing.md,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary.withValues(alpha: 0.4);
          return AppColors.surfaceBorder;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
        ),
        textStyle: textTheme.bodyMedium,
      ),
    );
  }
}
