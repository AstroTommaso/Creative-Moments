import 'dart:ui';

enum BrushTool { pencil, brush, eraser }

class Stroke {
  Stroke({required this.tool, required this.color, required this.width, required this.points});
  final BrushTool tool;
  final int color; // ARGB
  final double width;
  final List<Offset> points;

  Map<String, dynamic> toJson() => {
    't': tool.name,
    'c': color,
    'w': double.parse(width.toStringAsFixed(1)),
    // flat [x0,y0,x1,y1,...] with one decimal to keep the JSON small
    'p': [
      for (final p in points) ...[double.parse(p.dx.toStringAsFixed(1)), double.parse(p.dy.toStringAsFixed(1))],
    ],
  };

  factory Stroke.fromJson(Map<String, dynamic> j) {
    final flat = (j['p'] as List).map((e) => (e as num).toDouble()).toList();
    return Stroke(
      tool: BrushTool.values.firstWhere((t) => t.name == j['t'], orElse: () => BrushTool.pencil),
      color: (j['c'] as num).toInt(),
      width: (j['w'] as num).toDouble(),
      points: [for (var i = 0; i + 1 < flat.length; i += 2) Offset(flat[i], flat[i + 1])],
    );
  }
}

/// Vector drawing, stored as JSON in creations.drawing_data.
class DrawingData {
  const DrawingData({required this.width, required this.height, required this.background, this.strokes = const []});
  final double width, height;
  final int background;
  final List<Stroke> strokes;

  bool get isEmpty => strokes.isEmpty;

  DrawingData copyWith({List<Stroke>? strokes, int? background}) =>
      DrawingData(width: width, height: height, background: background ?? this.background, strokes: strokes ?? this.strokes);

  Map<String, dynamic> toJson() => {
    'v': 1,
    'w': width,
    'h': height,
    'bg': background,
    'strokes': [for (final s in strokes) s.toJson()],
  };

  factory DrawingData.fromJson(Map<String, dynamic> j) => DrawingData(
    width: (j['w'] as num).toDouble(),
    height: (j['h'] as num).toDouble(),
    background: (j['bg'] as num).toInt(),
    strokes: [for (final s in (j['strokes'] as List? ?? const [])) Stroke.fromJson(Map<String, dynamic>.from(s as Map))],
  );
}
