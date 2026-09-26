import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/providers.dart';
import '../../features/home/environment/environment_scene.dart';

/// Frosted surface used over the environment.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.lg),
    this.radius = Rd.lg,
    this.blur = 18,
    this.opacity = 0.09,
    this.onTap,
    this.semanticLabel,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius, blur, opacity;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = context.cm.isDark;
    final base = dark ? Colors.white : Colors.black;
    Widget w = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: base.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: base.withValues(alpha: dark ? 0.14 : 0.08)),
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      w = Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: w),
      );
    }
    return w;
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final bool loading, expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: AnimatedOpacity(
        duration: Mo.fast,
        opacity: enabled || loading ? 1 : 0.45,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: Rd.pill,
            gradient: LinearGradient(colors: [c.accent, Color.lerp(c.accent, c.accent2, 0.35)!]),
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: Rd.pill,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onPressed!();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1408)))
                    else ...[
                      if (icon != null) ...[Icon(icon, size: 20, color: const Color(0xFF1A1408)), const SizedBox(width: Sp.sm)],
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.ui(16, weight: FontWeight.w800, color: const Color(0xFF1A1408)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed, this.icon, this.color});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.cm.text;
    return Semantics(
      button: true,
      label: label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: c,
          padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: Sp.sm)],
            Flexible(
              child: Text(
                label,
                style: AppType.ui(15, weight: FontWeight.w700, color: c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selectable emoji tile used for environments, inspirations, moods, types.
class OptionTile extends StatelessWidget {
  const OptionTile({super.key, required this.emoji, required this.label, required this.selected, required this.onTap, this.big = false});
  final String emoji, label;
  final bool selected, big;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: Mo.base,
          curve: Mo.soft,
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          padding: EdgeInsets.symmetric(horizontal: big ? Sp.lg : Sp.md, vertical: big ? Sp.lg : Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(big ? Rd.lg : 999.0),
            color: selected ? c.accent.withValues(alpha: 0.18) : (c.isDark ? Colors.black.withValues(alpha: 0.22) : c.text.withValues(alpha: 0.05)),
            border: Border.all(color: selected ? c.accent : c.border, width: selected ? 1.4 : 1),
            boxShadow: selected ? [BoxShadow(color: c.accent.withValues(alpha: 0.25), blurRadius: 18)] : null,
          ),
          child: big
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: selected ? 1.12 : 1,
                      duration: Mo.base,
                      curve: Mo.soft,
                      child: Text(emoji, style: const TextStyle(fontSize: 30)),
                    ),
                    const SizedBox(height: Sp.sm),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppType.ui(13, weight: FontWeight.w700, color: selected ? c.text : c.text.withValues(alpha: 0.8)),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji.isNotEmpty) ...[Text(emoji, style: const TextStyle(fontSize: 18)), const SizedBox(width: Sp.sm)],
                    Flexible(
                      child: Text(
                        label,
                        style: AppType.ui(14, weight: FontWeight.w700, color: selected ? c.text : c.text.withValues(alpha: 0.82)),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Screen with the user's environment behind it, dimmed by [intensity].
class AtmoScaffold extends StatelessWidget {
  const AtmoScaffold({super.key, required this.body, this.intensity = 0.2, this.appBar, this.bottom, this.resizeToAvoidBottomInset = true, this.quality = 0.4});
  final Widget body;
  final double intensity, quality;
  final PreferredSizeWidget? appBar;
  final Widget? bottom;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: context.cm.bg),
        if (intensity > 0) EnvironmentScene(intensity: intensity, quality: quality),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          body: body,
          bottomNavigationBar: bottom,
        ),
      ],
    );
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.lg, Sp.xl, Sp.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.tt.headlineMedium)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Sp.xs),
                    child: Text(subtitle!, style: context.tt.bodySmall),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Soft shimmer block for loading states.
class Skeleton extends ConsumerStatefulWidget {
  const Skeleton({super.key, this.height = 120, this.width, this.radius = Rd.lg});
  final double height, radius;
  final double? width;
  @override
  ConsumerState<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends ConsumerState<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final reduce = ref.watch(prefsProvider).reduceMotion;
    if (reduce) _c.stop();
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _c.value * 3, 0),
              end: Alignment(_c.value * 3, 0),
              colors: [c.text.withValues(alpha: 0.05), c.text.withValues(alpha: 0.12), c.text.withValues(alpha: 0.05)],
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.title = 'Something went wrong.', required this.message, required this.onRetry});
  final String title, message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌫️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: Sp.md),
            Text(title, style: context.tt.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: Sp.sm),
            Text(
              message,
              style: context.tt.bodyMedium?.copyWith(color: context.cm.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Sp.xl),
            PrimaryButton(label: 'Try Again', onPressed: onRetry, expand: false),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.actionLabel, this.onAction, this.emoji = '🌙'});
  final String title, message, emoji;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: Sp.lg),
            Text(
              title,
              style: AppType.display(32, color: context.cm.text, height: 1.1),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Sp.sm),
            Text(
              message,
              style: context.tt.bodyLarge?.copyWith(color: context.cm.muted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: Sp.xl),
              PrimaryButton(label: actionLabel!, onPressed: onAction, expand: false, icon: Icons.add_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

void showSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final c = context.cm;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: ctx.tt.headlineSmall),
      content: Text(message, style: ctx.tt.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            'Cancel',
            style: AppType.ui(15, weight: FontWeight.w700, color: c.muted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: AppType.ui(15, weight: FontWeight.w800, color: destructive ? c.danger : c.accent),
          ),
        ),
      ],
    ),
  );
  return r ?? false;
}
