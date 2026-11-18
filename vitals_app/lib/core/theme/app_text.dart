import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

/// Manrope text styles used across VitalWatch.
abstract final class AppText {
  static TextStyle get screenTitle => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.2,
      );

  static TextStyle get sectionTitle => GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.25,
      );

  static TextStyle get cardTitle => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.3,
      );

  static TextStyle get body => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
        height: 1.45,
      );

  static TextStyle get bodyMuted => body.copyWith(color: AppColors.muted);

  static TextStyle get caption => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
        height: 1.35,
      );

  static TextStyle get bigNumber => GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.1,
      );

  static TextStyle get label => GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.3,
      );
}
