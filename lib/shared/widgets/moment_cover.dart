import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/moment.dart';

/// A small, unique-looking mark composed from a moment's own creation type
/// and inspirations — stands in wherever there's no drawing, photo or text
/// excerpt to show, so an empty moment still looks like its own thing
/// instead of a blank. Deterministic: the same moment always composes the
/// same way, never a different look on every rebuild.
class MomentCover extends StatelessWidget {
  const MomentCover({super.key, required this.moment});
  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final glyphs = [moment.type.emoji, ...moment.inspirations.take(2).map((i) => i.emoji)];
    final seed = moment.id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff);
    final r = math.Random(seed);
    return Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < glyphs.length; i++)
          Transform.translate(
            offset: Offset((r.nextDouble() - 0.5) * 52, (r.nextDouble() - 0.5) * 52),
            child: Opacity(
              opacity: i == 0 ? 1 : 0.5,
              child: Text(glyphs[i], style: TextStyle(fontSize: i == 0 ? 44 : 26 + r.nextDouble() * 10)),
            ),
          ),
      ],
    );
  }
}
