import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/animations/sky.dart';
import '../../core/constants/catalog.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/moment.dart';
import 'drawing_view.dart';
import 'signed_image.dart';

/// Each moment keeps its own atmosphere: sky of the hour it was made in,
/// tinted by mood.
LinearGradient momentGradient(Moment m) {
  final pal = switch (m.timeOfDay) {
    'dawn' => SkyPalette.dawn,
    'day' => SkyPalette.day,
    'sunset' => SkyPalette.sunset,
    _ => SkyPalette.night,
  };
  final tint = m.mood != null ? moodColor(m.mood) : atmosphereTint(m.atmosphere ?? 'dreamy');
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color.lerp(pal.top, tint, 0.18)!, Color.lerp(pal.mid, tint, 0.3)!, Color.lerp(pal.bottom, tint, 0.35)!],
  );
}

/// The artwork area; shared between card and detail for the Hero transition.
class MomentArtwork extends StatelessWidget {
  const MomentArtwork({super.key, required this.moment, this.compact = false});
  final Moment moment;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final drawing = moment.drawing;
    final images = moment.images;
    Widget content;
    if (drawing != null && !drawing.isEmpty) {
      content = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: 300,
          height: 300 * drawing.height / drawing.width,
          child: CustomPaint(painter: DrawingPainter(drawing)),
        ),
      );
    } else if (images.isNotEmpty) {
      content = SizedBox.expand(child: SignedImage(path: images.first.storagePath, cacheWidth: 700));
    } else if (moment.excerpt.isNotEmpty) {
      content = Padding(
        padding: const EdgeInsets.all(Sp.lg),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            moment.excerpt,
            maxLines: compact ? 3 : 5,
            overflow: TextOverflow.fade,
            style: AppType.display(compact ? 17 : 20, style: FontStyle.italic, color: Colors.white.withValues(alpha: 0.92), height: 1.25),
          ),
        ),
      );
    } else {
      content = Center(child: Text(moment.type.emoji, style: const TextStyle(fontSize: 42)));
    }
    return Container(
      decoration: BoxDecoration(gradient: momentGradient(moment)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MomentCard extends StatelessWidget {
  const MomentCard({super.key, required this.moment, this.width, this.height = 250, this.compact = false});
  final Moment moment;
  final double? width;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final when = DateFormat(compact ? 'MMM d' : 'MMM d · HH:mm').format(moment.createdAt);
    final insp = moment.inspirations.take(3).map((e) => e.emoji).join(' ');
    return Semantics(
      button: true,
      label: '${moment.displayTitle}, ${moment.type.label}, $when',
      child: GestureDetector(
        onTap: () => context.push('/moment/${moment.id}'),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: Rd.card,
            color: c.surface,
            border: Border.all(color: c.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Hero(
                  tag: 'moment-art-${moment.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: SizedBox.expand(
                      child: MomentArtwork(moment: moment, compact: compact),
                    ),
                  ),
                ),
              ),
              Container(
                color: c.isDark ? const Color(0xFF12142A) : c.surface,
                padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moment.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.display(20, weight: FontWeight.w700, color: c.text),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('${moment.type.emoji}  $when', style: context.tt.bodySmall),
                        const Spacer(),
                        if (insp.isNotEmpty) Text(insp, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
