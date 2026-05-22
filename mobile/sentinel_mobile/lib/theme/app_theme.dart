// lib/theme/app_theme.dart — TDS Sentinel
// Tema visual centralizado. Colores, tipografía y estilos TDS Innovate.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // TDS Brand
  static const Color navyDark      = Color(0xFF0B1F3B);
  static const Color coreGreen     = Color(0xFF00C853);
  static const Color white         = Color(0xFFFFFFFF);
  static const Color black         = Color(0xFF000000);
  static const Color textMain      = Color(0xFF0B2A4A);
  static const Color textSecondary = Color(0xFF3F556F);

  // UI functional
  static const Color surface       = Color(0xFFF5F7FA);
  static const Color cardBg        = Color(0xFFFFFFFF);
  static const Color divider       = Color(0xFFE0E7EF);
  static const Color inputBg       = Color(0xFFF0F4F8);

  // Risk levels
  static const Color riskLow      = Color(0xFF00C853);
  static const Color riskMedium   = Color(0xFFFFB300);
  static const Color riskHigh     = Color(0xFFE53935);
  static const Color riskCritical = Color(0xFF7B1FA2);

  static const Color riskLowBg      = Color(0xFFE8F5E9);
  static const Color riskMediumBg   = Color(0xFFFFF8E1);
  static const Color riskHighBg     = Color(0xFFFFEBEE);
  static const Color riskCriticalBg = Color(0xFFF3E5F5);
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navyDark,
        primary: AppColors.navyDark,
        secondary: AppColors.coreGreen,
        surface: AppColors.surface,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.montserratTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.montserrat(
          fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textMain),
        displayMedium: GoogleFonts.montserrat(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textMain),
        titleLarge: GoogleFonts.montserrat(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textMain),
        titleMedium: GoogleFonts.montserrat(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textMain),
        bodyLarge: GoogleFonts.montserrat(
          fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textMain),
        bodyMedium: GoogleFonts.montserrat(
          fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        labelLarge: GoogleFonts.montserrat(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navyDark,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navyDark,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyDark,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AppColors.navyDark, width: 1.5),
          textStyle: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navyDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.riskHigh),
        ),
        labelStyle: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.divider),
        ),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1),
      scaffoldBackgroundColor: AppColors.surface,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: GoogleFonts.montserrat(fontSize: 13),
      ),
    );
  }

  // Helpers de color por risk level
  static Color riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':      return AppColors.riskLow;
      case 'MEDIUM':   return AppColors.riskMedium;
      case 'HIGH':     return AppColors.riskHigh;
      case 'CRITICAL': return AppColors.riskCritical;
      default:         return AppColors.textSecondary;
    }
  }

  static Color riskBgColor(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':      return AppColors.riskLowBg;
      case 'MEDIUM':   return AppColors.riskMediumBg;
      case 'HIGH':     return AppColors.riskHighBg;
      case 'CRITICAL': return AppColors.riskCriticalBg;
      default:         return AppColors.surface;
    }
  }

  static String riskLabel(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':      return 'Riesgo Bajo';
      case 'MEDIUM':   return 'Riesgo Medio';
      case 'HIGH':     return 'Riesgo Alto';
      case 'CRITICAL': return 'Riesgo Crítico';
      default:         return level;
    }
  }
}
