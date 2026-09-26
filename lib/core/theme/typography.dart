import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central place for type. Display/writing = Cormorant Garamond, UI = Manrope.
/// Tests flip [systemFonts] so no network font fetch is attempted.
abstract final class AppType {
  static bool systemFonts = false;

  static TextStyle display(double size, {FontWeight weight = FontWeight.w500, Color? color, double? height, FontStyle? style, double? letterSpacing}) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      fontStyle: style,
      letterSpacing: letterSpacing,
      fontFamily: 'serif',
    );
    if (systemFonts) return base;
    return GoogleFonts.cormorantGaramond(fontSize: size, fontWeight: weight, color: color, height: height, fontStyle: style, letterSpacing: letterSpacing);
  }

  static TextStyle ui(double size, {FontWeight weight = FontWeight.w500, Color? color, double? height, double? letterSpacing}) {
    final base = TextStyle(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing);
    if (systemFonts) return base;
    return GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing);
  }

  static TextTheme textTheme(Color text, Color muted) => TextTheme(
    displayLarge: display(48, weight: FontWeight.w500, color: text, height: 1.05),
    displayMedium: display(38, color: text, height: 1.1),
    headlineMedium: display(30, color: text, height: 1.15),
    headlineSmall: display(24, weight: FontWeight.w600, color: text, height: 1.2),
    titleLarge: ui(20, weight: FontWeight.w700, color: text),
    titleMedium: ui(16, weight: FontWeight.w700, color: text),
    titleSmall: ui(14, weight: FontWeight.w700, color: text),
    bodyLarge: ui(16, color: text, height: 1.5),
    bodyMedium: ui(14, color: text, height: 1.45),
    bodySmall: ui(12, color: muted, height: 1.4),
    labelLarge: ui(15, weight: FontWeight.w700, color: text),
    labelMedium: ui(12, weight: FontWeight.w600, color: muted, letterSpacing: 0.4),
    labelSmall: ui(11, weight: FontWeight.w600, color: muted, letterSpacing: 0.6),
  );
}
