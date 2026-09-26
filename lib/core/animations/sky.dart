import 'dart:ui';

/// Time-of-day sky: colours are interpolated continuously between keyframes so
/// the environment shifts gradually instead of switching.
class SkyPalette {
  const SkyPalette(this.top, this.mid, this.bottom);
  final Color top, mid, bottom;

  static SkyPalette lerp(SkyPalette a, SkyPalette b, double t) =>
      SkyPalette(Color.lerp(a.top, b.top, t)!, Color.lerp(a.mid, b.mid, t)!, Color.lerp(a.bottom, b.bottom, t)!);

  static const dawn = SkyPalette(Color(0xFF3B3A6B), Color(0xFFB5789A), Color(0xFFF2B98B));
  static const day = SkyPalette(Color(0xFF2C5A8C), Color(0xFF5C93BF), Color(0xFFA9CFE0));
  static const sunset = SkyPalette(Color(0xFF3A2E5F), Color(0xFFC2586A), Color(0xFFF59A5B));
  static const night = SkyPalette(Color(0xFF05060F), Color(0xFF10143A), Color(0xFF262056));

  // hour keyframes (0–6 are shifted by +24 so night wraps past midnight);
  // third value is "nightness": how visible stars and moon should be.
  static const _keys = <(double, SkyPalette, double)>[
    (6.0, dawn, 0.25),
    (12.5, day, 0.0),
    (18.5, sunset, 0.3),
    (21.5, night, 1.0),
    (28.0, night, 1.0),
    (30.0, dawn, 0.25),
  ];

  static (SkyPalette, double) at(double hour) {
    var h = hour % 24;
    if (h < 6) h += 24;
    for (var i = 0; i < _keys.length - 1; i++) {
      final a = _keys[i], b = _keys[i + 1];
      if (h >= a.$1 && h <= b.$1) {
        final x = (h - a.$1) / (b.$1 - a.$1);
        final t = x * x * (3 - 2 * x);
        return (SkyPalette.lerp(a.$2, b.$2, t), a.$3 + (b.$3 - a.$3) * t);
      }
    }
    return (night, 1.0);
  }

  static double nightness(double hour) => at(hour).$2;

  /// Fixed hour used when the user pins a time of day.
  static double? hourFor(String style) => switch (style) {
    'dawn' => 6.4,
    'day' => 12.5,
    'sunset' => 18.6,
    'night' => 23.0,
    _ => null,
  };
}

Color atmosphereTint(String a) => switch (a) {
  'dreamy' => const Color(0xFF8B6BD9),
  'calm' => const Color(0xFF3F8FA8),
  'mystical' => const Color(0xFF4B2E83),
  'warm' => const Color(0xFFD98B3F),
  'dark' => const Color(0xFF000000),
  'romantic' => const Color(0xFFD9577F),
  'natural' => const Color(0xFF3F8F5A),
  'energetic' => const Color(0xFFE8623A),
  _ => const Color(0xFF8B6BD9),
};
