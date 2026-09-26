import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../widgets/ui.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.md),
          child: Glass(
            radius: 32,
            blur: 24,
            opacity: context.cm.isDark ? 0.14 : 0.7,
            padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.sm),
            child: Row(
              children: [
                _Tab(icon: Icons.blur_circular_rounded, label: 'Home', on: shell.currentIndex == 0, onTap: () => _go(0)),
                _Tab(icon: Icons.auto_stories_outlined, label: 'Moments', on: shell.currentIndex == 1, onTap: () => _go(1)),
                const _CreateButton(),
                _Tab(icon: Icons.public_rounded, label: 'World', on: shell.currentIndex == 2, onTap: () => _go(2)),
                _Tab(icon: Icons.person_outline_rounded, label: 'Me', on: shell.currentIndex == 3, onTap: () => _go(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    // Home sits on top of the sky, where the glass is dark whatever the theme
    final col = on ? c.accent : c.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        child: InkResponse(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: on ? 1.12 : 1,
                  duration: Mo.base,
                  curve: Mo.soft,
                  child: Icon(icon, size: 24, color: col),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppType.ui(10.5, weight: on ? FontWeight.w800 : FontWeight.w600, color: col),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton();
  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    return Semantics(
      button: true,
      label: 'Create a Moment',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push('/create');
        },
        child: Container(
          width: 58,
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: Sp.sm),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent, Color.lerp(c.accent, c.accent2, 0.45)!]),
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 22, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.add_rounded, size: 30, color: Color(0xFF1A1408)),
        ),
      ),
    );
  }
}
