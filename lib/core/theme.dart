import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0E1A3C);
  static const surface = Color(0xFF12234D);
  static const surface2 = Color(0xFF1B2D60);
  static const border = Color(0xFF2E4169);
  static const text = Color(0xFFF7F9FF);
  static const muted = Color(0xFFC9D6EC);
  static const gold = Color(0xFFFFA435);
  static const green = Color(0xFF3B82F6);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF60A5FA);
  static const purple = Color(0xFFA78BFA);
}

class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.green,
      secondary: AppColors.gold,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.red,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        selectedIconTheme: IconThemeData(color: AppColors.gold),
        unselectedIconTheme: IconThemeData(color: AppColors.muted),
        selectedLabelTextStyle: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(color: AppColors.muted),
        indicatorColor: Color(0x33FFA435),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.green, width: 1.5)),
        labelStyle: const TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green,
          side: const BorderSide(color: Color(0x663B82F6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.green),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.surface2),
        dataRowColor: const WidgetStatePropertyAll(AppColors.surface),
        headingTextStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12),
        dataTextStyle: const TextStyle(color: AppColors.text, fontSize: 13),
        dividerThickness: 1,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
