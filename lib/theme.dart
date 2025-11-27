import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFFF9FAFB);
  static const panel = Color(0xFFFFFFFF);
  static const accent = Color(0xFF9AD0EC);
  static const accent600 = Color(0xFF7FC3E6);
  static const text = Color(0xFF2D2D2D);
  static const muted = Color(0xFF6B7280);
}

ThemeData buildAppTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.text),
    primaryColor: AppColors.accent,
    colorScheme: base.colorScheme.copyWith(primary: AppColors.accent),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.panel,
      elevation: 0,
      iconTheme: const IconThemeData(color: Color(0xFF2D2D2D)),
    ),
    cardTheme: base.cardTheme.copyWith(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      elevation: 4,
      color: AppColors.panel,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),
  );
}
