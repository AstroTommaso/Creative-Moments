import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';

/// Gentle staggered entrance. Skips all motion when Reduce Motion is on.
class FadeSlide extends ConsumerWidget {
  const FadeSlide({super.key, required this.child, this.index = 0, this.dy = 18});
  final Widget child;
  final int index;
  final double dy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = ref.watch(prefsProvider).reduceMotion || MediaQuery.of(context).disableAnimations;
    if (reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 90),
      curve: Mo.gentle,
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: c),
      ),
      child: child,
    );
  }
}
