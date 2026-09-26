import 'package:flutter/material.dart';

/// Spacing, radius, motion tokens shared by the whole app.
abstract final class Sp {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, huge = 48;
}

abstract final class Rd {
  static const double sm = 10, md = 16, lg = 24, xl = 32;
  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get pill => BorderRadius.circular(999);
}

abstract final class Mo {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 640);
  static const ambient = Duration(milliseconds: 1400);
  static const Curve soft = Curves.easeOutCubic;
  static const Curve gentle = Cubic(0.22, 0.61, 0.36, 1.0);
  static const Curve settle = Curves.easeInOutCubicEmphasized;
}

/// App palette exposed as a ThemeExtension so screens can adapt to light/dark.
@immutable
class CmColors extends ThemeExtension<CmColors> {
  const CmColors({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.muted,
    required this.accent,
    required this.accent2,
    required this.border,
    required this.danger,
    required this.isDark,
  });

  final Color bg, surface, surfaceHigh, text, muted, accent, accent2, border, danger;
  final bool isDark;

  static const dark = CmColors(
    bg: Color(0xFF0B0C1A),
    surface: Color(0xFF15172B),
    surfaceHigh: Color(0xFF1E2140),
    text: Color(0xFFF3EFE8),
    muted: Color(0xFFA6A3B8),
    accent: Color(0xFFE9C98F),
    accent2: Color(0xFF9D8CFF),
    border: Color(0x1FFFFFFF),
    danger: Color(0xFFFF8A8A),
    isDark: true,
  );

  static const light = CmColors(
    bg: Color(0xFFF6F1E9),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEFE8DC),
    text: Color(0xFF1B1A2E),
    muted: Color(0xFF6B6880),
    accent: Color(0xFFA9711F),
    accent2: Color(0xFF6A58E0),
    border: Color(0x1F1B1A2E),
    danger: Color(0xFFC0392B),
    isDark: false,
  );

  @override
  CmColors copyWith() => this;

  @override
  CmColors lerp(ThemeExtension<CmColors>? other, double t) {
    if (other is! CmColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension CmContext on BuildContext {
  CmColors get cm => Theme.of(this).extension<CmColors>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}
