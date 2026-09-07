import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const navy950 = Color(0xFF0A1220);
  static const navy900 = Color(0xFF0E1B32);
  static const navy800 = Color(0xFF152845);
  static const navy700 = Color(0xFF1D3357);

  static const blue600 = Color(0xFF2B5FE8);
  static const blue500 = Color(0xFF3E76F5);
  static const blue400 = Color(0xFF6E97FF);

  static const gold400 = Color(0xFFF2B33D);
  static const gold500 = Color(0xFFE19E1D);

  static const paper = Color(0xFFF4F6FB);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0A1220);

  static const slate600 = Color(0xFF5B688A);
  static const slate400 = Color(0xFF93A0C1);
  static const slate200 = Color(0xFFD7DEEC);

  static const success = Color(0xFF2FBF7A);
  static const danger = Color(0xFFE5484D);



  static const blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue500, blue600],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold400, gold500],
  );

  static const navyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy900, navy950],
  );

  static const headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [blue600, blue500, Color(0xFF4C8BFF)],
  );
}

class AppRadius {
  AppRadius._();
  static const lg = 22.0;
  static const md = 14.0;
  static const sm = 10.0;
}

class AppTextStyles {
  AppTextStyles._();

  // 'Sora' → display font, 'Inter' → body font, 'IBM Plex Mono' → mono font
  static TextStyle display({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.ink,
  }) =>
      GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color);

  static TextStyle body({
    double size = 14.5,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
  }) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
  }) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.paper,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue600,
      primary: AppColors.blue600,
      secondary: AppColors.gold500,
    ),
    textTheme: GoogleFonts.interTextTheme(),
  );
}
