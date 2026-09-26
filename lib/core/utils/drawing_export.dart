import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../data/models/drawing.dart';
import '../../shared/widgets/drawing_view.dart';

/// Rasterises a vector drawing to PNG for storage (previews, export).
Future<Uint8List> renderDrawingPng(DrawingData data, {double maxWidth = 1200}) async {
  final scale = maxWidth / data.width;
  final size = Size(data.width * scale, data.height * scale);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  DrawingPainter(data).paint(canvas, size);
  final image = await recorder.endRecording().toImage(size.width.round(), size.height.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
