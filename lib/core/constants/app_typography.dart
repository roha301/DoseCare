import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Serene Clinical Typography System
/// Headings & Metrics: Plus Jakarta Sans
/// Body & Labels: Inter
class AppTypography {
  // Display Large (36px, 700)
  static TextStyle displayLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 44 / 36,
        letterSpacing: -0.7,
        color: color,
      );

  // Headline Large (28px, 700)
  static TextStyle headlineLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        letterSpacing: -0.3,
        color: color,
      );

  // Headline Medium (22px, 600)
  static TextStyle headlineMd({Color color = AppColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 28 / 22,
        letterSpacing: -0.2,
        color: color,
      );

  // Headline Small (18px, 600)
  static TextStyle headlineSm({Color color = AppColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: color,
      );

  // Title Large (20px, 600)
  static TextStyle titleLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 26 / 20,
        color: color,
      );

  // Title Medium (16px, 600)
  static TextStyle titleMd({Color color = AppColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 22 / 16,
        color: color,
      );

  // Title Small (14px, 600)
  static TextStyle titleSm({Color color = AppColors.onSurface}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        color: color,
      );

  // Body Large (16px, 500)
  static TextStyle bodyLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        color: color,
      );

  // Body Medium (14px, 400)
  static TextStyle bodyMd({Color color = AppColors.onSurface}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: color,
      );

  // Body Small (12px, 400)
  static TextStyle bodySm({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: color,
      );

  // Label Large (15px, 600)
  static TextStyle labelLg({Color color = AppColors.onSurface}) =>
      GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 20 / 15,
        color: color,
      );

  // Label Medium (13px, 600)
  static TextStyle labelMd({Color color = AppColors.onSurface}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 18 / 13,
        color: color,
      );

  // Label Small (11px, 600)
  static TextStyle labelSm({Color color = AppColors.onSurfaceVariant}) =>
      GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 14 / 11,
        letterSpacing: 0.4,
        color: color,
      );
}
