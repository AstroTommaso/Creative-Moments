import 'package:flutter/material.dart';

import '../../core/services/l10n_ext.dart';
import '../../data/models/drawing.dart';

/// Smooth path through points (quadratic through midpoints).
Path strokePath(List<Offset> pts) {
  final p = Path();
  if (pts.isEmpty) return p;
  if (pts.length == 1) {
    return p..addOval(Rect.fromCircle(center: pts.first, radius: 0.1));
  }
  p.moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
    p.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  p.lineTo(pts.last.dx, pts.last.dy);
  return p;
}

void paintStroke(Canvas canvas, Stroke s, int background) {
  final color = s.tool == BrushTool.eraser ? Color(background) : Color(s.color);
  final paint = Paint()
    ..color = s.tool == BrushTool.brush ? color.withValues(alpha: color.a * 0.82) : color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = s.width
    ..isAntiAlias = true;
  if (s.tool == BrushTool.brush) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.width * 0.08);
  if (s.points.length == 1) {
    canvas.drawCircle(s.points.first, s.width / 2, paint..style = PaintingStyle.fill);
  } else {
    canvas.drawPath(strokePath(s.points), paint);
  }
}

class DrawingPainter extends CustomPainter {
  DrawingPainter(this.data, {this.live, super.repaint});
  final DrawingData data;
  final Stroke? live;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / data.width;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = Color(data.background));
    canvas.scale(scale);
    for (final s in data.strokes) {
      paintStroke(canvas, s, data.background);
    }
    if (live != null) paintStroke(canvas, live!, data.background);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter old) => old.data != data || old.live != live;
}

/// Read-only render of a stored drawing, scaled to the available width.
class DrawingView extends StatelessWidget {
  const DrawingView({super.key, required this.data, this.radius = 0});
  final DrawingData data;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: context.l10n.uiDrawingLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: data.width / data.height,
          child: RepaintBoundary(child: CustomPaint(painter: DrawingPainter(data))),
        ),
      ),
    );
  }
}
