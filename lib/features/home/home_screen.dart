import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/moment.dart';
import '../../data/providers.dart';
import '../../shared/widgets/moment_card.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/ui.dart';
import 'environment/environment_scene.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _parallax = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _parallax.value = _scroll.hasClients ? _scroll.offset : 0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _parallax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A new moment was just kept: bring the sky back into view so its star can appear.
    ref.listen(lastCreatedProvider, (p, n) {
      if (n != null && _scroll.hasClients && _scroll.offset > 0) {
        _scroll.animateTo(0, duration: Mo.slow, curve: Mo.soft);
      }
    });
    final moments = ref.watch(momentsProvider);
    final profile = ref.watch(profileProvider).value;
    final size = MediaQuery.of(context).size;
    final hour = DateTime.now().hour;
    final name = (profile?.displayName ?? '').trim().split(' ').first;
    final skyH = size.height * 0.42;
    const white = Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: context.cm.bg),
          EnvironmentScene(parallax: _parallax),
          // legibility scrim for the lower half
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1],
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                ),
              ),
            ),
          ),
          RefreshIndicator(
            color: context.cm.accent,
            edgeOffset: 80,
            onRefresh: () => ref.read(momentsProvider.notifier).refresh(),
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: skyH)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                    child: FadeSlide(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              greetingForHour(context.l10n, hour, name: name),
                              style: AppType.display(52, color: white, height: 1.0, weight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(height: Sp.md),
                          Text(
                            promptForHour(context.l10n, hour),
                            style: AppType.display(26, color: white.withValues(alpha: 0.9), style: FontStyle.italic, height: 1.15),
                          ),
                          const SizedBox(height: Sp.xl),
                          PrimaryButton(label: context.l10n.createMomentCta, icon: Icons.add_rounded, expand: false, onPressed: () => context.push('/create')),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xxl + Sp.lg, Sp.xl, Sp.md),
                    child: Text(
                      context.l10n.homeRecentMomentsHeader,
                      style: AppType.ui(13, weight: FontWeight.w800, color: white.withValues(alpha: 0.75), letterSpacing: 1.2),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: moments.when(
                    loading: () => SizedBox(
                      height: 300,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                        children: const [
                          Skeleton(height: 300, width: 230),
                          SizedBox(width: Sp.md),
                          Skeleton(height: 300, width: 230),
                        ],
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                      child: Glass(
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_rounded, color: Colors.white70),
                            const SizedBox(width: Sp.md),
                            Expanded(
                              child: Text(friendlyError(e), style: AppType.ui(14, color: white)),
                            ),
                            TextButton(onPressed: () => ref.read(momentsProvider.notifier).refresh(), child: Text(context.l10n.tryAgain)),
                          ],
                        ),
                      ),
                    ),
                    data: (list) {
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                          child: Glass(
                            padding: const EdgeInsets.all(Sp.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.homeEmptyStateTitle, style: AppType.display(32, color: white, height: 1.05)),
                                const SizedBox(height: Sp.sm),
                                Text(context.l10n.homeEmptyStateSubtitle, style: AppType.ui(15, color: white.withValues(alpha: 0.8))),
                                const SizedBox(height: Sp.lg),
                                GhostButton(label: context.l10n.createMomentCta, icon: Icons.add_rounded, color: white, onPressed: () => context.push('/create')),
                              ],
                            ),
                          ),
                        );
                      }
                      final recent = list.take(8).toList();
                      return SizedBox(
                        height: 310,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                          itemCount: recent.length,
                          separatorBuilder: (_, _) => const SizedBox(width: Sp.md),
                          itemBuilder: (_, i) => FadeSlide(
                            index: i.clamp(0, 4),
                            child: MomentCard(moment: recent[i], width: 232, height: 300, compact: true),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 150)),
              ],
            ),
          ),
          // moments as stars, above the scroll view so they can be tapped
          // (Align loosens the Stack's tight constraints so the sky keeps its own height)
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: skyH,
                child: _StarField(moments: moments.value ?? const [], scroll: _parallax),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(Sp.md),
                child: Glass(
                  radius: 999,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.sm),
                  semanticLabel: context.l10n.homeCustomizeSemanticLabel,
                  onTap: () => context.push('/customize'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: Sp.sm),
                      Text(
                        context.l10n.homeCustomizeLabel,
                        style: AppType.ui(13, weight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _hash(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h = ((h ^ u) * 0x01000193) & 0x7fffffff;
  }
  return h;
}

/// Each recent moment is a small star in the sky; tapping opens it.
class _StarField extends ConsumerStatefulWidget {
  const _StarField({required this.moments, required this.scroll});
  final List<Moment> moments;
  final ValueListenable<double> scroll;
  @override
  ConsumerState<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends ConsumerState<_StarField> with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final AnimationController _born = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  Timer? _clear;

  @override
  void initState() {
    super.initState();
    _loop.repeat();
    final last = ref.read(lastCreatedProvider);
    if (last != null) _celebrate();
  }

  void _celebrate() {
    _born.forward(from: 0);
    _clear?.cancel();
    _clear = Timer(const Duration(seconds: 10), () => mounted ? ref.read(lastCreatedProvider.notifier).set(null) : null);
  }

  @override
  void dispose() {
    _clear?.cancel();
    _loop.dispose();
    _born.dispose();
    super.dispose();
  }

  Offset _pos(Moment m, Size s) {
    final r = math.Random(_hash(m.id));
    var x = 0.08 + r.nextDouble() * 0.84;
    final y = 0.1 + r.nextDouble() * 0.72;
    if (x > 0.58 && y < 0.42) x = x - 0.4; // keep clear of the moon
    return Offset(x * s.width, y * s.height);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lastCreatedProvider, (p, n) {
      if (n != null && n != p) _celebrate();
    });
    final reduce = ref.watch(prefsProvider).reduceMotion || MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _loop.stop();
      _born.value = 1;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
    final newest = ref.watch(lastCreatedProvider);
    final stars = widget.moments.take(28).toList();
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return AnimatedBuilder(
          animation: Listenable.merge([widget.scroll, _loop, _born]),
          builder: (_, _) {
            final fade = (1 - widget.scroll.value / 220).clamp(0.0, 1.0);
            return Opacity(
              opacity: fade,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _StarsPainter(stars.map((m) => (m, _pos(m, size))).toList(), _loop.value, _born.value, newest)),
                    ),
                  ),
                  if (fade > 0.3)
                    for (final m in stars)
                      Positioned(
                        left: _pos(m, size).dx - 24,
                        top: _pos(m, size).dy - 24,
                        width: 48,
                        height: 48,
                        child: Semantics(
                          button: true,
                          label: context.l10n.homeOpenMomentSemanticLabel(m.displayTitle),
                          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => context.push('/moment/${m.id}')),
                        ),
                      ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.stars, this.t, this.born, this.newest);
  final List<(Moment, Offset)> stars;
  final double t, born;
  final String? newest;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (m, p) in stars) {
      final isNew = m.id == newest;
      final base = 2.2 + math.min(m.inspirations.length, 4) * 0.5;
      final tw = 0.75 + 0.25 * math.sin(2 * math.pi * (t * 2) + _hash(m.id) % 7);
      final scale = isNew ? Curves.easeOutBack.transform(born.clamp(0.0, 1.0)) : 1.0;
      final col = Color.lerp(Colors.white, moodColor(m.mood), 0.45)!;
      final r = base * scale;
      canvas.drawCircle(
        p,
        r * 4,
        Paint()
          ..shader = RadialGradient(
            colors: [
              col.withValues(alpha: 0.42 * tw * scale),
              col.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: r * 4)),
      );
      canvas.drawCircle(p, r, Paint()..color = Colors.white.withValues(alpha: 0.95 * scale));
      // four-point sparkle
      final len = r * 3.2 * tw;
      final line = Paint()
        ..color = col.withValues(alpha: 0.55 * scale)
        ..strokeWidth = 1;
      canvas.drawLine(p - Offset(len, 0), p + Offset(len, 0), line);
      canvas.drawLine(p - Offset(0, len), p + Offset(0, len), line);
      if (isNew) {
        final ring = (t * 3) % 1.0;
        canvas.drawCircle(
          p,
          r * 4 + ring * 26,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: (1 - ring) * 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => true;
}
