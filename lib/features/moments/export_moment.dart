import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/constants/catalog.dart';
import '../../data/models/moment.dart';
import '../../l10n/app_localizations.dart';

/// A short, human-readable summary of a moment — shared between the plain
/// text export and the PDF's body.
String momentExportText(Moment m, AppLocalizations l10n, String locale) {
  final answered = m.prompts.where((p) => (p.answer ?? '').trim().isNotEmpty);
  final lines = <String>[
    if (m.title.trim().isNotEmpty) m.title.trim(),
    DateFormat('MMMM d, y · HH:mm', locale).format(m.createdAt),
    '${m.type.emoji} ${m.type.label(l10n)}',
    if (m.mood != null) labelFor(l10n, moodOptions, m.mood),
    if (m.hasLocation) '📍 ${m.locationName}',
    if (m.hasMusic) '🎧 ${m.musicTitle}${(m.musicArtist ?? '').isNotEmpty ? ' — ${m.musicArtist}' : ''}',
    if (m.inspirations.isNotEmpty) '${l10n.momentDetailInspiredBy}: ${m.inspirations.map((e) => e.name).join(' · ')}',
    if (m.text.trim().isNotEmpty) ...['', m.text.trim()],
    for (final p in answered) ...['', p.question, '“${p.answer!.trim()}”'],
  ];
  return lines.join('\n');
}

Future<void> exportMomentAsText(Moment m, AppLocalizations l10n, String locale) => SharePlus.instance.share(
  ShareParams(text: momentExportText(m, l10n, locale), subject: m.title.trim().isEmpty ? null : m.title.trim()),
);

/// Captures whatever is inside the (already mounted) [boundaryKey] — the
/// moment's own artwork — as a shareable PNG.
Future<void> exportMomentAsImage(GlobalKey boundaryKey) async {
  final boundary = boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/creative-moment.png');
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}

Future<void> exportMomentAsPdf(Moment m, AppLocalizations l10n, String locale) async {
  final answered = m.prompts.where((p) => (p.answer ?? '').trim().isNotEmpty);
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (m.title.trim().isNotEmpty) pw.Text(m.title.trim(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(DateFormat('MMMM d, y · HH:mm', locale).format(m.createdAt), style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),
            if (m.text.trim().isNotEmpty) pw.Text(m.text.trim(), style: const pw.TextStyle(fontSize: 13)),
            for (final p in answered) ...[
              pw.SizedBox(height: 16),
              pw.Text(p.question, style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
              pw.SizedBox(height: 4),
              pw.Text('“${p.answer!.trim()}”', style: const pw.TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    ),
  );
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/creative-moment.pdf');
  await file.writeAsBytes(await doc.save());
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
}
