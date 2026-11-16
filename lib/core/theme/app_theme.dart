import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Material 3 theme configuration for Vienna POI Explorer.
abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppPalette.accent,
      brightness: Brightness.light,
      primary: AppPalette.accent,
      onPrimary: Colors.white,
      secondary: AppPalette.ink,
      onSecondary: Colors.white,
      surface: AppPalette.surface,
      onSurface: AppPalette.ink,
      surfaceContainerLowest: AppPalette.canvas,
      surfaceContainerLow: AppPalette.surface,
      surfaceContainer: AppPalette.surfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppPalette.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppPalette.ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppPalette.divider, width: 0.8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        indicatorColor: AppPalette.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppPalette.accent : AppPalette.ink,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? AppPalette.accent : AppPalette.ink,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surface,
        selectedColor: AppPalette.accent,
        labelStyle: const TextStyle(
          color: AppPalette.ink,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: AppPalette.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppPalette.divider,
        thickness: 0.8,
        space: 1,
      ),
    );
  }
}

