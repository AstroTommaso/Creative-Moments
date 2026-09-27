import 'package:creative_moments/core/constants/catalog.dart';
import 'package:creative_moments/data/models/moment.dart';
import 'package:creative_moments/shared/widgets/moment_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Moment _moment(String id, {List<String> insp = const []}) => Moment(
  id: id,
  userId: 'u',
  title: 'x',
  type: CreationType.idea,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  inspirations: [for (final i in insp) Inspiration(type: i, name: i)],
);

void main() {
  testWidgets('shows the creation type glyph plus up to two inspiration glyphs', (tester) async {
    final m = _moment('a', insp: ['moon', 'rain', 'ocean']);
    await tester.pumpWidget(MaterialApp(home: MomentCover(moment: m)));
    expect(find.text(CreationType.idea.emoji), findsOneWidget);
    expect(find.text(emojiFor(inspirationOptions, 'moon')), findsOneWidget);
    expect(find.text(emojiFor(inspirationOptions, 'rain')), findsOneWidget);
    // Only the first two inspirations are used.
    expect(find.text(emojiFor(inspirationOptions, 'ocean')), findsNothing);
  });

  testWidgets('composes the same way every time for the same moment', (tester) async {
    final m = _moment('same-id', insp: ['moon', 'rain']);
    await tester.pumpWidget(MaterialApp(home: MomentCover(moment: m)));
    final first = tester.getTopLeft(find.text(CreationType.idea.emoji));
    await tester.pumpWidget(Container());
    await tester.pumpWidget(MaterialApp(home: MomentCover(moment: m)));
    final second = tester.getTopLeft(find.text(CreationType.idea.emoji));
    expect(first, second);
  });

  testWidgets('never throws for a moment with no inspirations at all', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MomentCover(moment: _moment('bare'))));
    expect(tester.takeException(), isNull);
    expect(find.text(CreationType.idea.emoji), findsOneWidget);
  });
}
