import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/typography.dart';

export 'design/tokens.dart';
export 'design/typography.dart';

/// Builds the Lango theme from the design tokens.
///
/// Light-only by deliberate decision: the reference is light-only and its
/// pastel tints do not invert meaningfully — see REFERENCE_ANALYSIS.md §9 and
/// REDESIGN.md §30 ("do not simply invert colors"). Tokens are structured so a
/// dark theme can be added later without touching widget code.
///
/// Depth model: **flat**. The reference has no drop shadows, no elevation and
/// no card borders (measured — REFERENCE_ANALYSIS.md §5), so every component
/// theme here pins elevation to 0 and uses `BorderSide.none`. Surfaces are
/// separated by pastel fill, not by edges or shadows.
ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: LangoColors.primary,
    onPrimary: LangoColors.primaryForeground,
    primaryContainer: LangoPalette.tintPink,
    onPrimaryContainer: LangoColors.primaryDeep,
    secondary: LangoColors.accent,
    onSecondary: LangoColors.accentForeground,
    secondaryContainer: LangoPalette.tintSky,
    onSecondaryContainer: LangoColors.foreground,
    tertiary: LangoPalette.tintCyan,
    onTertiary: LangoColors.foreground,
    error: LangoColors.error,
    onError: LangoPalette.white,
    surface: LangoColors.surface,
    onSurface: LangoColors.foreground,
    onSurfaceVariant: LangoColors.foregroundMuted,
    outline: LangoColors.border,
    outlineVariant: LangoColors.borderSubtle,
  );

  final textTheme = const TextTheme(
    displayLarge: LangoType.display,
    displayMedium: LangoType.h1,
    headlineLarge: LangoType.h1,
    headlineMedium: LangoType.h2,
    headlineSmall: LangoType.h2,
    titleLarge: LangoType.h3,
    titleMedium: LangoType.label,
    titleSmall: LangoType.label,
    bodyLarge: LangoType.body,
    bodyMedium: LangoType.body,
    bodySmall: LangoType.bodyMuted,
    labelLarge: LangoType.label,
    labelMedium: LangoType.caption,
    labelSmall: LangoType.navLabel,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    fontFamily: LangoFonts.latin,
    fontFamilyFallback: LangoFonts.uiFallback,
    scaffoldBackgroundColor: LangoColors.background,
    canvasColor: LangoColors.background,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: LangoColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: LangoColors.foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: LangoType.h3,
    ),

    // Flat, borderless, tint-filled.
    cardTheme: const CardThemeData(
      elevation: 0,
      color: LangoColors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: LangoRadius.xlAll,
        side: BorderSide.none,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LangoColors.primary,
        foregroundColor: LangoColors.primaryForeground,
        // Measured: the reference CTA is 57pt tall with a 13pt radius —
        // a rounded rectangle, not a pill.
        minimumSize: const Size.fromHeight(57),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: LangoRadius.mdAll),
        textStyle: LangoType.label,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LangoColors.primary,
        minimumSize: const Size.fromHeight(57),
        side: const BorderSide(color: LangoColors.border),
        shape: const RoundedRectangleBorder(borderRadius: LangoRadius.mdAll),
        textStyle: LangoType.label,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LangoColors.primary,
        textStyle: LangoType.label,
        shape: const RoundedRectangleBorder(borderRadius: LangoRadius.smAll),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LangoColors.surfaceMuted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: LangoSpace.lg,
        vertical: LangoSpace.md,
      ),
      hintStyle: LangoType.bodyMuted,
      border: const OutlineInputBorder(
        borderRadius: LangoRadius.mdAll,
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: LangoRadius.mdAll,
        borderSide: BorderSide.none,
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: LangoRadius.mdAll,
        borderSide: BorderSide(color: LangoColors.primary, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: LangoRadius.mdAll,
        borderSide: BorderSide(color: LangoColors.error, width: 2),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: LangoRadius.mdAll,
        borderSide: BorderSide(color: LangoColors.error, width: 2),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: LangoColors.surfaceMuted,
      selectedColor: LangoPalette.tintPink,
      side: BorderSide.none,
      labelStyle: LangoType.caption.copyWith(
        color: LangoColors.foregroundSecondary,
      ),
      shape: const RoundedRectangleBorder(borderRadius: LangoRadius.pillAll),
      padding: const EdgeInsets.symmetric(
        horizontal: LangoSpace.sm,
        vertical: LangoSpace.xs,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: LangoColors.borderSubtle,
      thickness: 1,
      space: 1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: LangoColors.primary,
      linearTrackColor: LangoColors.surfaceMuted,
      circularTrackColor: LangoColors.surfaceMuted,
      linearMinHeight: 8,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LangoColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(LangoRadius.xl)),
      ),
    ),

    dialogTheme: const DialogThemeData(
      backgroundColor: LangoColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: LangoRadius.lgAll),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: LangoColors.foreground,
      contentTextStyle: LangoType.body.copyWith(color: LangoPalette.white),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: LangoRadius.mdAll),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LangoColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      // The reference's bar has no pill indicator behind the active icon.
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => LangoType.navLabel.copyWith(
          color: states.contains(WidgetState.selected)
              ? LangoColors.primary
              : LangoColors.foregroundMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? LangoColors.primary
              : LangoColors.foregroundMuted,
        ),
      ),
    ),
  );
}
