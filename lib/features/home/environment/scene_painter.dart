import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/animations/sky.dart';
import '../../../core/services/weather_service.dart';
import 'scene_model.dart';

const _tau = math.pi * 2;

class SceneStar {
  SceneStar(this.x, this.y, this.r, this.phase, this.cycles, this.depth);
  final double x, y, r, phase, depth;
  final int cycles;
}

class SceneDrift {
  SceneDrift(this.x, this.y, this.s, this.cycles, this.phase, this.depth);
  final double x, y, s, phase, depth;
  final int cycles;
}

/// Paints the whole living environment. Everything is deterministic in
/// (model.t, presence) so loops are seamless and there are no per-frame
/// allocations of particle state.
class ScenePainter extends CustomPainter {
  ScenePainter(this.m) : super(repaint: m) {
    final r = math.Random(11);
    stars = List.generate(
      170,
      (_) => SceneStar(r.nextDouble(), r.nextDouble() * 0.5, 0.5 + r.nextDouble() * 1.4, r.nextDouble() * _tau, 1 + r.nextInt(4), 0.2 + r.nextDouble() * 0.8),
    );
    drops = List.generate(140, (_) => SceneDrift(r.nextDouble(), r.nextDouble(), 0.6 + r.nextDouble() * 0.8, 3 + r.nextInt(3), r.nextDouble(), r.nextDouble()));
    flakes = List.generate(
      120,
      (_) => SceneDrift(r.nextDouble(), r.nextDouble(), 0.5 + r.nextDouble(), 1 + r.nextInt(2), r.nextDouble() * _tau, r.nextDouble()),
    );
    embers = List.generate(
      60,
      (_) => SceneDrift(r.nextDouble(), r.nextDouble(), 0.5 + r.nextDouble(), 1 + r.nextInt(3), r.nextDouble() * _tau, r.nextDouble()),
    );
    leaves = List.generate(
      28,
      (_) => SceneDrift(r.nextDouble(), r.nextDouble(), 0.6 + r.nextDouble() * 0.8, 1 + r.nextInt(2), r.nextDouble() * _tau, r.nextDouble()),
    );
    motes = List.generate(50, (_) => SceneDrift(r.nextDouble(), r.nextDouble(), 0.4 + r.nextDouble(), 1 + r.nextInt(3), r.nextDouble() * _tau, r.nextDouble()));
    clouds = List.generate(
      7,
      (_) => SceneDrift(r.nextDouble(), 0.05 + r.nextDouble() * 0.4, 0.6 + r.nextDouble() * 0.9, 1, r.nextDouble() * _tau, r.nextDouble()),
    );
    buildings = List.generate(34, (_) => r.nextDouble());
    windows = List.generate(400, (_) => r.nextDouble());
  }

  final SceneModel m;
  late final List<SceneStar> stars;
  late final List<SceneDrift> drops, flakes, embers, leaves, motes, clouds;
  late final List<double> buildings, windows;

  double _p(String k) => m.presence[k] ?? 0;
  double _loop(double cycles, [double phase = 0]) => ((m.t / 60) * cycles + phase) % 1.0;
  double _sin(double cycles, [double phase = 0]) => math.sin(_tau * ((m.t / 60) * cycles) + phase);
  double _plx(double depth) => -m.parallax * depth * 0.06;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w == 0 || h == 0) return;
    final (pal, night) = SkyPalette.at(m.hour);
    final tint = atmosphereTint(m.atmosphere);
    final tintAmt = m.atmosphere == 'dark' ? 0.55 : 0.2;

    // sky
    final top = Color.lerp(pal.top, tint, tintAmt)!;
    final mid = Color.lerp(pal.mid, tint, tintAmt * 0.8)!;
    final bot = Color.lerp(pal.bottom, tint, tintAmt * 0.6)!;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, mid, bot],
          stops: const [0, .58, 1],
        ).createShader(Offset.zero & size),
    );

    final q = m.quality * m.density;
    _stars(canvas, size, night, q);
    _sun(canvas, size, night);
    _moon(canvas, size, night);
    _aurora(canvas, size, night);
    _clouds(canvas, size, night, q);
    _mountains(canvas, size, night, bot);
    _city(canvas, size, night);
    _desert(canvas, size, night);
    _ocean(canvas, size, night);
    _flowers(canvas, size, night);
    _nature(canvas, size, night, q);
    _rain(canvas, size, q);
    _snow(canvas, size, q);
    _autumn(canvas, size, q);
    _fire(canvas, size, q);
    _abstract(canvas, size);
    _atmosphere(canvas, size, night);
  }

  // ── sky bodies ────────────────────────────────────────────────────────
  void _stars(Canvas c, Size s, double night, double q) {
    final base = 0.28 + 0.55 * (_p('stars') + _p('moon') * 0.6).clamp(0.0, 1.0) + m.starBoost * 0.3;
    final vis = night * base;
    if (vis < 0.02) return;
    final n = (stars.length * (0.35 + 0.65 * q.clamp(0.0, 1.4) / 1.4) * (1 + m.starBoost * 0.5)).round().clamp(0, stars.length);
    final p = Paint();
    final weatherHaze = m.weather == Weather.cloudy || m.weather == Weather.rain ? 0.35 : 1.0;
    for (var i = 0; i < n; i++) {
      final st = stars[i];
      final tw = 0.55 + 0.45 * math.sin(_tau * (m.t / 60) * st.cycles + st.phase);
      final a = (vis * tw * (0.4 + st.depth * 0.6) * weatherHaze).clamp(0.0, 1.0);
      p.color = Colors.white.withValues(alpha: a);
      final x = st.x * s.width + _plx(st.depth);
      final y = st.y * s.height;
      c.drawCircle(Offset(x, y), st.r * (0.7 + st.depth * 0.5), p);
      if (st.r > 1.5 && a > 0.5) {
        p
          ..color = Colors.white.withValues(alpha: a * 0.25)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        c.drawLine(Offset(x - st.r * 3, y), Offset(x + st.r * 3, y), p);
        c.drawLine(Offset(x, y - st.r * 3), Offset(x, y + st.r * 3), p);
        p.style = PaintingStyle.fill;
      }
    }
  }

  Offset _moonPos(Size s) => Offset(s.width * 0.72 + _sin(1) * 6 + _plx(0.4), s.height * 0.17 + _sin(2, 1) * 3);

  void _moon(Canvas c, Size s, double night) {
    final a = _p('moon') * math.max(night, 0.3);
    if (a < 0.01) return;
    final pos = _moonPos(s);
    final r = math.min(s.width, s.height) * 0.085 * (0.85 + 0.15 * _p('moon'));
    c.drawCircle(
      pos,
      r * 4.2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3D0).withValues(alpha: 0.30 * a),
            const Color(0xFFFFF3D0).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: pos, radius: r * 4.2)),
    );
    c.drawCircle(
      pos,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 1.1,
          colors: [
            const Color(0xFFFFFBEA).withValues(alpha: a),
            const Color(0xFFE8DFC2).withValues(alpha: a),
            const Color(0xFFCFC4A4).withValues(alpha: a),
          ],
          stops: const [0, .6, 1],
        ).createShader(Rect.fromCircle(center: pos, radius: r)),
    );
    final cp = Paint()..color = const Color(0xFF9A8F72).withValues(alpha: 0.18 * a);
    for (final d in const [(-.35, .1, .22), (.25, -.3, .15), (.3, .3, .18), (-.1, -.4, .1), (0.05, .5, .09)]) {
      c.drawCircle(pos + Offset(d.$1 * r, d.$2 * r), d.$3 * r, cp);
    }
  }

  void _sun(Canvas c, Size s, double night) {
    final a = _p('sunset') * (1 - night * 0.85);
    if (a < 0.01) return;
    final pos = Offset(s.width * 0.5 + _plx(0.3), s.height * (0.62 - 0.03 * _sin(1)));
    final r = s.width * 0.14;
    c.drawCircle(
      pos,
      r * 3.4,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB067).withValues(alpha: 0.55 * a),
            const Color(0xFFFF6E6E).withValues(alpha: 0.12 * a),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: pos, radius: r * 3.4)),
    );
    c.drawCircle(
      pos,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF0C8).withValues(alpha: a),
            const Color(0xFFFFB067).withValues(alpha: a),
          ],
        ).createShader(Rect.fromCircle(center: pos, radius: r)),
    );
  }

  void _aurora(Canvas c, Size s, double night) {
    final a = _p('abstract') * 0.7;
    if (a < 0.02) return;
    for (var k = 0; k < 3; k++) {
      final path = Path();
      final baseY = s.height * (0.2 + k * 0.1);
      for (var i = 0; i <= 24; i++) {
        final x = s.width * i / 24;
        final y = baseY + math.sin(i * 0.5 + _tau * (m.t / 60) * (k + 1)) * s.height * 0.05 + _plx(0.3);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      final col = [const Color(0xFF7EF3C8), const Color(0xFF9D8CFF), const Color(0xFFFF9BD2)][k];
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.height * 0.07
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.height * 0.05)
          ..color = col.withValues(alpha: 0.22 * a),
      );
    }
  }

  void _clouds(Canvas c, Size s, double night, double q) {
    var a = math.max(_p('clouds'), _p('rain') * 0.9);
    if (m.weather == Weather.cloudy || m.weather == Weather.rain) a = math.max(a, 0.9);
    if (a < 0.02) return;
    final tone = Color.lerp(const Color(0xFFF4F1FF), const Color(0xFF5A5F86), night * 0.85)!;
    final n = (clouds.length * (0.5 + 0.5 * q.clamp(0.0, 1.2))).round().clamp(2, clouds.length);
    final p = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.05);
    for (var i = 0; i < n; i++) {
      final cl = clouds[i];
      final x = ((cl.x + m.t / 60 * 0.4 * cl.s) % 1.5 - 0.25) * s.width + _plx(cl.depth);
      final y = cl.y * s.height;
      final sc = s.width * (0.16 + cl.s * 0.1);
      p.color = tone.withValues(alpha: (0.10 + 0.2 * cl.depth) * a);
      for (final d in const [(0.0, 0.0, 1.0), (-0.7, 0.2, 0.7), (0.8, 0.15, 0.75), (0.1, -0.3, 0.7)]) {
        c.drawOval(Rect.fromCenter(center: Offset(x + d.$1 * sc, y + d.$2 * sc * 0.5), width: sc * 1.6 * d.$3, height: sc * 0.7 * d.$3), p);
      }
    }
  }

  // ── land / water ──────────────────────────────────────────────────────
  Path _ridge(Size s, double base, double amp, double f1, double f2, double phase, double dx) {
    final p = Path()..moveTo(0, s.height);
    for (var i = 0; i <= 40; i++) {
      final x = s.width * i / 40;
      final n = math.sin(i * f1 + phase) * 0.55 + math.sin(i * f2 + phase * 1.7) * 0.3 + math.sin(i * f1 * 2.3 + phase * .3) * 0.15;
      p.lineTo(x + dx, s.height * base - n.abs() * amp * s.height);
    }
    p.lineTo(s.width, s.height);
    return p..close();
  }

  void _mountains(Canvas c, Size s, double night, Color haze) {
    final a = _p('mountains');
    if (a < 0.01) return;
    for (var l = 0; l < 3; l++) {
      final depth = l / 2;
      final col = Color.lerp(Color.lerp(haze, const Color(0xFF1B2140), 0.35 + depth * 0.45)!, Colors.black, night * 0.2 * (1 + depth))!;
      final path = _ridge(s, 0.66 + l * 0.07, 0.24 - l * 0.05, 0.35 + l * 0.1, 0.9, 1.3 + l * 2.1, _plx(0.2 + depth * 0.5));
      c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              col.withValues(alpha: a),
              Color.lerp(col, Colors.black, 0.3)!.withValues(alpha: a),
            ],
          ).createShader(Offset.zero & s),
      );
    }
    // snow caps mist
    c.drawRect(
      Rect.fromLTWH(0, s.height * 0.7, s.width, s.height * 0.3),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10 * a),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, s.height * 0.7, s.width, s.height * 0.3)),
    );
  }

  void _city(Canvas c, Size s, double night) {
    final a = _p('city');
    if (a < 0.01) return;
    for (var layer = 0; layer < 2; layer++) {
      final far = layer == 0;
      final bodyCol = Color.lerp(far ? const Color(0xFF232048) : const Color(0xFF0E0D22), const Color(0xFF000000), night * 0.25)!;
      final dx = _plx(far ? 0.3 : 0.8);
      var x = -10.0;
      var bi = far ? 0 : 17;
      while (x < s.width + 20) {
        final bw = s.width * (0.05 + buildings[bi % buildings.length] * 0.06);
        final bh = s.height * ((far ? 0.14 : 0.10) + buildings[(bi * 7 + 3) % buildings.length] * (far ? 0.16 : 0.2));
        final top = s.height * (far ? 0.82 : 0.9) - bh;
        c.drawRect(Rect.fromLTWH(x + dx, top, bw, s.height - top), Paint()..color = bodyCol.withValues(alpha: a));
        // lit windows
        final lit = Paint();
        final cols = (bw / 9).floor(), rows = (bh / 12).floor();
        for (var r = 0; r < rows; r++) {
          for (var cc = 0; cc < cols; cc++) {
            final wv = windows[(bi * 31 + r * 7 + cc * 13) % windows.length];
            if (wv > (far ? 0.72 : 0.6)) {
              final flick = 0.75 + 0.25 * math.sin(_tau * (m.t / 60) * (1 + (bi + r) % 3) + wv * 20);
              lit.color = const Color(0xFFFFD98A).withValues(alpha: (far ? 0.45 : 0.85) * a * flick * (0.4 + 0.6 * night));
              c.drawRect(Rect.fromLTWH(x + dx + 4 + cc * 9, top + 6 + r * 12, 4, 5), lit);
            }
          }
        }
        x += bw + s.width * 0.004;
        bi++;
      }
    }
    // haze
    final r = Rect.fromLTWH(0, s.height * 0.62, s.width, s.height * 0.38);
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFB79BFF).withValues(alpha: 0.16 * a),
          ],
        ).createShader(r),
    );
  }

  void _desert(Canvas c, Size s, double night) {
    final a = _p('desert');
    if (a < 0.01) return;
    for (var l = 0; l < 3; l++) {
      final base = Color.lerp(const Color(0xFFE9B36D), const Color(0xFF6B3E2A), l / 2 * 0.7 + night * 0.35)!;
      final path = Path()..moveTo(0, s.height);
      final y0 = s.height * (0.7 + l * 0.08);
      for (var i = 0; i <= 30; i++) {
        final x = s.width * i / 30;
        path.lineTo(x, y0 - (math.sin(i * 0.28 + l * 2.3) * 0.5 + 0.5) * s.height * (0.09 - l * 0.02));
      }
      path.lineTo(s.width, s.height);
      path.close();
      c.save();
      c.translate(_plx(0.3 + l * 0.3), 0);
      c.drawPath(path, Paint()..color = base.withValues(alpha: a));
      c.restore();
    }
    // wind-blown sand
    final p = Paint();
    for (var i = 0; i < (motes.length * 0.8 * m.quality).round(); i++) {
      final d = motes[i];
      final x = ((d.x + _loop(d.cycles.toDouble())) % 1.0) * s.width;
      final y = s.height * (0.72 + d.y * 0.25) + math.sin(_tau * _loop(2, d.phase)) * 4;
      p.color = const Color(0xFFFFE2A8).withValues(alpha: 0.35 * a * d.depth);
      c.drawCircle(Offset(x, y), 0.8 + d.s, p);
    }
  }

  void _ocean(Canvas c, Size s, double night) {
    final a = _p('ocean');
    if (a < 0.01) return;
    final horizon = s.height * 0.66;
    final rect = Rect.fromLTWH(0, horizon, s.width, s.height - horizon);
    final deep = Color.lerp(const Color(0xFF2A6C8C), const Color(0xFF0B1A3A), 0.4 + night * 0.5)!;
    final shallow = Color.lerp(const Color(0xFF6EC1CF), const Color(0xFF203A70), 0.3 + night * 0.6)!;
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            shallow.withValues(alpha: a),
            deep.withValues(alpha: a),
          ],
        ).createShader(rect),
    );
    // moon / sun reflection
    final mp = _moonPos(s);
    final refl = Paint();
    for (var i = 0; i < 26; i++) {
      final y = horizon + 6 + i * (s.height - horizon) / 26;
      final wob = math.sin(_tau * _loop(2, i * 0.4)) * (6 + i * 0.9);
      final wdt = (14 + i * 3.4) * (0.6 + 0.4 * math.sin(_tau * _loop(3, i * 0.9)).abs());
      refl.color = const Color(0xFFFFF3D0).withValues(alpha: (0.34 - i * 0.011).clamp(0.0, 1.0) * a * math.max(night, 0.2) * _p('moon').clamp(0.3, 1.0));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(mp.dx + wob, y), width: wdt, height: 2.2), const Radius.circular(2)), refl);
    }
    // wave lines
    for (var l = 0; l < 4; l++) {
      final path = Path();
      final y0 = horizon + (s.height - horizon) * (0.12 + l * 0.22);
      for (var i = 0; i <= 30; i++) {
        final x = s.width * i / 30;
        final y = y0 + math.sin(i * 0.55 + _tau * _loop(l + 1, l * 1.1)) * (3 + l * 3);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + l * 0.4
          ..color = Colors.white.withValues(alpha: (0.10 + l * 0.02) * a),
      );
    }
    // horizon glow
    c.drawRect(
      Rect.fromLTWH(0, horizon - 2, s.width, 4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12 * a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  // ── flora ─────────────────────────────────────────────────────────────
  void _flowers(Canvas c, Size s, double night) {
    final a = _p('flowers');
    if (a < 0.02) return;
    const petalCols = [Color(0xFFF7B6CF), Color(0xFFFFE3EC), Color(0xFFC9B6FF), Color(0xFFFFD9A8), Color(0xFFFFFFFF)];
    for (var i = 0; i < 11; i++) {
      final seed = math.Random(i * 97 + 3);
      final x = s.width * (0.04 + i / 11 * 0.94 + seed.nextDouble() * 0.03) + _plx(0.4 + seed.nextDouble() * 0.5);
      final grow = Curves.easeOutCubic.transform(a.clamp(0.0, 1.0));
      final hh = s.height * (0.10 + seed.nextDouble() * 0.16) * grow;
      final sway = _sin(1 + i % 2, i * 0.7) * 8 * grow;
      final base = Offset(x, s.height + 4);
      final headPt = Offset(x + sway, s.height - hh);
      final stem = Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(x - sway * 0.3, s.height - hh * 0.5, headPt.dx, headPt.dy);
      c.drawPath(
        stem,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(const Color(0xFF3F8F5A), const Color(0xFF1B3A34), night * 0.6)!.withValues(alpha: a),
      );
      // leaf
      _leaf(c, Offset(x + sway * 0.4, s.height - hh * 0.4), 14 * grow, -0.7 + sway * 0.03, const Color(0xFF4FA36B).withValues(alpha: a * 0.9));
      final col = petalCols[i % petalCols.length];
      final petalR = (10 + seed.nextDouble() * 8) * grow;
      final pp = Paint()..color = Color.lerp(col, const Color(0xFF8A7FB8), night * 0.35)!.withValues(alpha: 0.85 * a);
      for (var k = 0; k < 7; k++) {
        final ang = k / 7 * _tau + _sin(1, i.toDouble()) * 0.05;
        c.save();
        c.translate(headPt.dx, headPt.dy);
        c.rotate(ang);
        c.drawOval(Rect.fromCenter(center: Offset(0, -petalR * 0.75), width: petalR * 0.85, height: petalR * 1.4), pp);
        c.restore();
      }
      c.drawCircle(headPt, petalR * 0.35, Paint()..color = const Color(0xFFFFD27A).withValues(alpha: a));
    }
  }

  void _leaf(Canvas c, Offset at, double len, double rot, Color col) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(rot);
    final p = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.6, -len * 0.35, len * 1.6, 0)
      ..quadraticBezierTo(len * 0.6, len * 0.35, 0, 0);
    c.drawPath(p, Paint()..color = col);
    c.drawLine(
      Offset.zero,
      Offset(len * 1.4, 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..strokeWidth = 0.8,
    );
    c.restore();
  }

  void _nature(Canvas c, Size s, double night, double q) {
    final a = _p('nature');
    if (a < 0.02) return;
    final green = Color.lerp(const Color(0xFF4FA36B), const Color(0xFF14382E), night * 0.55)!;
    // fronds from both bottom corners
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i < 9; i++) {
        final ax = side == 0 ? -6.0 : s.width + 6;
        final dir = side == 0 ? 1.0 : -1.0;
        final ay = s.height - i * s.height * 0.045;
        final rot = (side == 0 ? -0.9 : math.pi + 0.9) + _sin(1, i * 0.6 + side) * 0.06;
        _leaf(c, Offset(ax, ay), s.width * (0.16 - i * 0.008), rot, green.withValues(alpha: a * (0.9 - i * 0.05)));
        _leaf(c, Offset(ax + dir * 8, ay + 10), s.width * (0.12 - i * 0.006), rot + (side == 0 ? 0.5 : -0.5), green.withValues(alpha: a * 0.6));
      }
    }
    // fireflies / pollen
    final p = Paint();
    for (var i = 0; i < (motes.length * q.clamp(0.3, 1.0)).round(); i++) {
      final d = motes[i];
      final x = (d.x + _sin(1, d.phase) * 0.05) * s.width;
      final y = (0.35 + d.y * 0.6 - _loop(1, d.phase / _tau) * 0.02) * s.height;
      final tw = 0.5 + 0.5 * math.sin(_tau * _loop(d.cycles.toDouble() + 1, d.phase));
      p.color = const Color(0xFFEFFFA8).withValues(alpha: a * 0.5 * tw * (0.4 + 0.6 * night));
      c.drawCircle(Offset(x, y), 1.2 + d.s, p);
    }
  }

  // ── weather-like particles ────────────────────────────────────────────
  void _rain(Canvas c, Size s, double q) {
    var a = _p('rain');
    if (m.weather == Weather.rain) a = math.max(a, 0.9);
    if (a < 0.02) return;
    final n = (drops.length * q.clamp(0.25, 1.3) * a).round().clamp(0, drops.length);
    final p = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final d = drops[i];
      final y = (d.y + _loop(d.cycles * 3.0)) % 1.0;
      final x = ((d.x + y * 0.1) % 1.0) * s.width + _plx(d.depth * 0.5);
      final len = 10 + d.s * 16;
      final yy = y * (s.height + 40) - 20;
      p.color = const Color(0xFFCFE0FF).withValues(alpha: (0.10 + 0.32 * d.depth) * a);
      c.drawLine(Offset(x, yy), Offset(x - len * 0.16, yy + len), p);
    }
    // mist along the ground
    final r = Rect.fromLTWH(0, s.height * 0.72, s.width, s.height * 0.28);
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF9DB4E6).withValues(alpha: 0.16 * a),
          ],
        ).createShader(r),
    );
  }

  void _snow(Canvas c, Size s, double q) {
    var a = _p('winter');
    if (m.weather == Weather.snow) a = math.max(a, 0.9);
    if (a < 0.02) return;
    final n = (flakes.length * q.clamp(0.3, 1.2) * a).round().clamp(0, flakes.length);
    final p = Paint();
    for (var i = 0; i < n; i++) {
      final d = flakes[i];
      final y = (d.y + _loop(d.cycles.toDouble())) % 1.0;
      final x = (d.x + math.sin(_tau * _loop(2, d.phase / _tau)) * 0.03) * s.width + _plx(d.depth * 0.5);
      p.color = Colors.white.withValues(alpha: (0.35 + 0.5 * d.depth) * a);
      c.drawCircle(Offset(x, y * s.height), 0.9 + d.s * 1.6 * d.depth, p);
    }
    final r = Rect.fromLTWH(0, s.height * 0.86, s.width, s.height * 0.14);
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFEAF2FF).withValues(alpha: 0.35 * a),
          ],
        ).createShader(r),
    );
  }

  void _autumn(Canvas c, Size s, double q) {
    final a = _p('autumn');
    if (a < 0.02) return;
    const cols = [Color(0xFFE8873A), Color(0xFFC4452B), Color(0xFFF2B84B), Color(0xFF9C4A2B)];
    final n = (leaves.length * q.clamp(0.3, 1.2) * a).round().clamp(0, leaves.length);
    for (var i = 0; i < n; i++) {
      final d = leaves[i];
      final y = (d.y + _loop(d.cycles.toDouble())) % 1.0;
      final x = (d.x + math.sin(_tau * _loop(2, d.phase / _tau)) * 0.08) * s.width + _plx(d.depth * 0.6);
      _leaf(c, Offset(x, y * s.height), 7 + d.s * 6, _tau * _loop(3, d.phase / _tau) + d.phase, cols[i % cols.length].withValues(alpha: 0.85 * a));
    }
    final r = Rect.fromLTWH(0, s.height * 0.8, s.width, s.height * 0.2);
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF7A3A1E).withValues(alpha: 0.35 * a),
          ],
        ).createShader(r),
    );
  }

  void _fire(Canvas c, Size s, double q) {
    final a = _p('fire');
    if (a < 0.02) return;
    final glow = Rect.fromLTWH(0, s.height * 0.6, s.width, s.height * 0.4);
    final flick = 0.85 + 0.15 * _sin(6);
    c.drawRect(
      glow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFFF7A2E).withValues(alpha: 0.38 * a * flick),
          ],
        ).createShader(glow),
    );
    final p = Paint();
    final n = (embers.length * q.clamp(0.3, 1.2) * a).round().clamp(0, embers.length);
    for (var i = 0; i < n; i++) {
      final d = embers[i];
      final y = (d.y + _loop(d.cycles.toDouble())) % 1.0;
      final x = (d.x + math.sin(_tau * _loop(2, d.phase / _tau)) * 0.04) * s.width;
      final life = 1 - y;
      p.color = Color.lerp(const Color(0xFFFFD27A), const Color(0xFFFF4A2E), y)!.withValues(alpha: life * 0.85 * a);
      c.drawCircle(Offset(x, s.height * (0.35 + 0.65 * (1 - y))), 0.8 + d.s * 1.6 * life, p);
    }
  }

  void _abstract(Canvas c, Size s) {
    final a = _p('abstract');
    if (a < 0.02) return;
    const cols = [Color(0xFF9D8CFF), Color(0xFFFF9BD2), Color(0xFF7EF3C8), Color(0xFFFFD27A), Color(0xFF78B8FF)];
    for (var i = 0; i < 5; i++) {
      final cx = s.width * (0.5 + 0.38 * math.sin(_tau * _loop(1, i * 0.21) + i * 1.3)) + _plx(0.3 + i * 0.1);
      final cy = s.height * (0.5 + 0.34 * math.cos(_tau * _loop(2, i * 0.13) + i * 2.1));
      final r = s.width * (0.22 + 0.05 * i);
      c.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = cols[i].withValues(alpha: 0.20 * a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55),
      );
    }
  }

  // ── overall atmosphere ────────────────────────────────────────────────
  void _atmosphere(Canvas c, Size s, double night) {
    final full = Offset.zero & s;
    switch (m.atmosphere) {
      case 'warm':
        c.drawRect(full, Paint()..color = const Color(0xFFFFA24A).withValues(alpha: 0.07));
      case 'romantic':
        c.drawRect(full, Paint()..color = const Color(0xFFFF6FA0).withValues(alpha: 0.06));
      case 'dark':
        c.drawRect(full, Paint()..color = Colors.black.withValues(alpha: 0.22));
      case 'natural':
        c.drawRect(full, Paint()..color = const Color(0xFF3FBF7A).withValues(alpha: 0.05));
      case 'dreamy' || 'mystical':
        final col = m.atmosphere == 'dreamy' ? const Color(0xFFD9B8FF) : const Color(0xFF7EF3C8);
        final p = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.04);
        for (var i = 0; i < (10 * m.quality).round().clamp(3, 10); i++) {
          final d = motes[i];
          final x = (d.x + _sin(1, d.phase) * 0.04) * s.width;
          final y = ((d.y - _loop(1, d.phase / _tau) * 0.15) % 1.0) * s.height;
          p.color = col.withValues(alpha: 0.10 + 0.07 * math.sin(_tau * _loop(2, d.phase)).abs());
          c.drawCircle(Offset(x, y), 6 + d.s * 10, p);
        }
    }
    if (m.weather == Weather.fog) {
      c.drawRect(
        full,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.30)],
          ).createShader(full),
      );
    }
    // vignette keeps text legible and adds depth
    c.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.0,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.38)],
          stops: const [0.55, 1],
        ).createShader(full),
    );
  }

  @override
  bool shouldRepaint(covariant ScenePainter old) => old.m != m;
}
