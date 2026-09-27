import 'dart:ui' show Tristate;

import 'package:creative_moments/core/theme/app_theme.dart';
import 'package:creative_moments/core/theme/tokens.dart';
import 'package:creative_moments/data/models/drawing.dart';
import 'package:creative_moments/features/drawing/drawing_editor.dart';
import 'package:creative_moments/l10n/app_localizations.dart';
import 'package:creative_moments/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

Future<void> _pump(WidgetTester tester, void Function(DrawingData) onChanged, {int? initialBackground}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.build(CmColors.dark),
        home: Scaffold(
          body: DrawingCanvasEditor(
            initial: initialBackground == null ? null : DrawingData(width: 300, height: 300, background: initialBackground, strokes: const []),
            onChanged: onChanged,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every paper option is offered, and picking one updates the background', (tester) async {
    DrawingData? changed;
    await _pump(tester, (d) => changed = d);

    await tester.tap(find.bySemanticsLabel(_en.drawingPaperTooltip));
    await tester.pumpAndSettle();
    for (final p in paperColors) {
      expect(find.bySemanticsLabel(p.$1(_en)), findsOneWidget);
    }

    final target = paperColors.firstWhere((p) => p.$2 != paperColors.first.$2);
    await tester.tap(find.bySemanticsLabel(target.$1(_en)));
    await tester.pumpAndSettle();
    expect(changed?.background, target.$2);
  });

  testWidgets('the eraser tool can be selected like any other tool', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, (_) {});
    final eraser = tester.getSemantics(find.bySemanticsLabel(_en.drawingEraserLabel));
    expect(eraser.flagsCollection.isSelected, Tristate.isFalse);
    await tester.tap(find.bySemanticsLabel(_en.drawingEraserLabel));
    await tester.pumpAndSettle();
    final erasedAfter = tester.getSemantics(find.bySemanticsLabel(_en.drawingEraserLabel));
    expect(erasedAfter.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('a light paper keeps the toolbar readable (dark ink, not washed-out light-on-light)', (tester) async {
    await _pump(tester, (_) {}, initialBackground: 0xFFFFFFFF);
    final undo = tester.widget<Icon>(find.byIcon(Icons.undo_rounded));
    // Disabled (nothing to undo yet) but still resolved from the dark tone,
    // not the pale one the app's own theme would otherwise pick.
    expect(undo.color, isNotNull);
    expect(undo.color!.computeLuminance(), lessThan(0.5));
  });
}
