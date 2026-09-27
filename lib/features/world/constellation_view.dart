import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/catalog.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/moment.dart';
import '../../shared/widgets/ui.dart';
import 'constellation_layout.dart';

class ConstellationView extends StatefulWidget {
  const ConstellationView({super.key, required this.moments, required this.reduceMotion});
  final List<Moment> moments;
  final bool reduceMotion;
  @override
  State<ConstellationView> createState() => _ConstellationViewState();
}

class _ConstellationViewState extends State<ConstellationView> with SingleTickerProviderStateMixin {
  late Constellation _layout = layoutConstellation(widget.moments);
  final _tc = TransformationController();
  late final AnimationController _twinkle = AnimationController(vsync: this, duration: const Duration(seconds: 8));
  int? _selected;
  Size? _fittedFor;
  Constellation? _fittedLayout;
  String? _filter; // "mood:calm" | "insp:moon" | "type:drawing"

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _twinkle.repeat();
  }

  @override
  void didUpdateWidget(covariant ConstellationView old) {
    super.didUpdateWidget(old);
    if (old.moments.length != widget.moments.length || old.moments.firstOrNull?.id != widget.moments.firstOrNull?.id) {
      _layout = layoutConstellation(widget.moments);
      _selected = null;
    }
    if (widget.reduceMotion) {
      _twinkle.stop();
    } else if (!_twinkle.isAnimating) {
      _twinkle.repeat();
    }
  }

  @override
  void dispose() {
    _twinkle.dispose();
    _tc.dispose();
    super.dispose();
  }

  /// Centre and scale the graph so everything is on screen at first sight.
  void _fit(Size viewport) {
    if (_fittedFor == viewport && identical(_fittedLayout, _layout)) return;
    _fittedFor = viewport;
    _fittedLayout = _layout;
    if (_layout.nodes.isEmpty) return;
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final n in _layout.nodes) {
      minX = math.min(minX, n.pos.dx);
      minY = math.min(minY, n.pos.dy);
      maxX = math.max(maxX, n.pos.dx);
      maxY = math.max(maxY, n.pos.dy);
    }
    final w = math.max(maxX - minX, 1) + 160, h = math.max(maxY - minY, 1) + 200;
    final scale = math.min(viewport.width / w, viewport.height / h).clamp(0.4, 1.6);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    _tc.value = Matrix4.identity()
      ..translateByDouble(viewport.width / 2 - cx * scale, viewport.height / 2 - cy * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  bool _matches(Moment m) {
    final f = _filter;
    if (f == null) return true;
    final v = f.substring(f.indexOf(':') + 1);
    return switch (f.split(':').first) {
      'mood' => m.mood == v,
      'insp' => m.inspirationTypes.contains(v),
      'type' => m.type.name == v,
      _ => true,
    };
  }

  void _tap(Offset viewport) {
    final scene = _tc.toScene(viewport);
    var best = -1;
    var bestD = 34.0;
    for (var i = 0; i < _layout.nodes.length; i++) {
      final d = (_layout.nodes[i].pos - scene).distance;
      if (d < bestD && _matches(_layout.nodes[i].moment)) {
        bestD = d;
        best = i;
      }
    }
    setState(() => _selected = best < 0 ? null : best);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final l10n = context.l10n;
    final moods = <String>{
      for (final m in widget.moments)
        if (m.mood != null) m.mood!,
    };
    final insps = <String>{for (final m in widget.moments) ...m.inspirationTypes};
    final types = <String>{for (final m in widget.moments) m.type.name};
    final chips = <(String, String)>[
      for (final v in insps) ('insp:$v', '${emojiFor(inspirationOptions, v)} ${labelFor(l10n, inspirationOptions, v)}'),
      for (final v in moods) ('mood:$v', labelFor(l10n, moodOptions, v)),
      for (final v in types) ('type:$v', CreationType.parse(v).label(l10n)),
    ];
    final sel = _selected == null ? null : _layout.nodes[_selected!].moment;
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
            children: [
              for (final (key, label) in chips)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.sm),
                  child: OptionTile(emoji: '', label: label, selected: _filter == key, onTap: () => setState(() => _filter = _filter == key ? null : key)),
                ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              _fit(Size(box.maxWidth, box.maxHeight));
              return Stack(
                children: [
                  ClipRect(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _tap(d.localPosition),
                      child: InteractiveViewer(
                        transformationController: _tc,
                        constrained: false,
                        minScale: 0.4,
                        maxScale: 4,
                        boundaryMargin: const EdgeInsets.all(400),
                        child: SizedBox(
                          width: _layout.size.width,
                          height: _layout.size.height,
                          child: Semantics(
                            label: l10n.constellationSemanticsLabel(_layout.nodes.length),
                            child: CustomPaint(painter: _ConstellationPainter(_layout, _matches, _selected, _twinkle)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: Sp.lg,
                    right: Sp.lg,
                    bottom: 132,
                    child: AnimatedSwitcher(
                      duration: Mo.base,
                      transitionBuilder: (w, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(a),
                          child: w,
                        ),
                      ),
                      child: sel == null
                          ? Center(
                              key: const ValueKey('hint'),
                              child: Text(
                                widget.moments.length < 2 ? l10n.constellationHintSingle : l10n.constellationHintMulti,
                                style: context.tt.bodySmall,
                              ),
                            )
                          : Glass(
                              key: ValueKey(sel.id),
                              onTap: () => context.push('/moment/${sel.id}'),
                              semanticLabel: l10n.constellationOpenLabel(sel.displayTitle(l10n)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: moodColor(sel.mood),
                                      boxShadow: [BoxShadow(color: moodColor(sel.mood), blurRadius: 10)],
                                    ),
                                  ),
                                  const SizedBox(width: Sp.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sel.displayTitle(l10n),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppType.display(22, weight: FontWeight.w700, color: c.text),
                                        ),
                                        Text(
                                          '${sel.type.emoji} ${DateFormat('MMM d', Localizations.localeOf(context).toString()).format(sel.createdAt)}  ${sel.inspirations.take(3).map((e) => e.emoji).join(' ')}',
                                          style: context.tt.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_rounded, color: c.muted),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter(this.layout, this.matches, this.selected, Animation<double> t) : _t = t, super(repaint: t);
  final Constellation layout;
  final bool Function(Moment) matches;
  final int? selected;
  final Animation<double> _t;

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = layout.nodes;
    final active = [for (final n in nodes) matches(n.moment)];
    for (final e in layout.edges) {
      final both = active[e.a] && active[e.b];
      final a = nodes[e.a], b = nodes[e.b];
      final ca = moodColor(a.moment.mood), cb = moodColor(b.moment.mood);
      canvas.drawLine(
        a.pos,
        b.pos,
        Paint()
          ..strokeWidth = 1.2 + math.min(e.weight, 5) * 0.35
          ..shader = LinearGradient(
            colors: [
              ca.withValues(alpha: both ? 0.75 : 0.06),
              cb.withValues(alpha: both ? 0.75 : 0.06),
            ],
          ).createShader(Rect.fromPoints(a.pos, b.pos).inflate(1)),
      );
    }
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final col = moodColor(n.moment.mood);
      final tw = 0.8 + 0.2 * math.sin(2 * math.pi * (_t.value * 2) + i);
      final a = active[i] ? 1.0 : 0.15;
      final r = (7 + math.min(n.moment.inspirations.length, 4) * 1.6) * (i == selected ? 1.4 : 1);
      canvas.drawCircle(
        n.pos,
        r * 3.4,
        Paint()
          ..shader = RadialGradient(
            colors: [
              col.withValues(alpha: 0.5 * a * tw),
              col.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: n.pos, radius: r * 3.4)),
      );
      canvas.drawCircle(n.pos, r, Paint()..color = Color.lerp(Colors.white, col, 0.35)!.withValues(alpha: a));
      if (i == selected) {
        canvas.drawCircle(
          n.pos,
          r + 7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) => old.selected != selected || old.layout != layout;
}
