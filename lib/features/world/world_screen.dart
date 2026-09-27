import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/moment.dart';
import '../../data/providers.dart';
import '../../shared/widgets/ui.dart';
import '../moments/moments_sheet.dart';
import 'constellation_view.dart';

class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});
  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  bool _explore = false;

  @override
  Widget build(BuildContext context) {
    final moments = ref.watch(momentsProvider);
    final reduce = ref.watch(prefsProvider).reduceMotion;
    final c = context.cm;
    final l10n = context.l10n;
    return AtmoScaffold(
      intensity: 0.5,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenTitle(
              l10n.worldTitle,
              subtitle: _explore ? l10n.worldSubtitleExplore : l10n.worldSubtitleConstellation,
              trailing: Container(
                decoration: BoxDecoration(
                  borderRadius: Rd.pill,
                  border: Border.all(color: c.border),
                  color: c.text.withValues(alpha: 0.05),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Seg(icon: Icons.blur_on_rounded, label: l10n.worldConstellationTab, on: !_explore, onTap: () => setState(() => _explore = false)),
                    _Seg(icon: Icons.explore_outlined, label: l10n.worldExploreTab, on: _explore, onTap: () => setState(() => _explore = true)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: moments.when(
                loading: () => const Padding(padding: EdgeInsets.all(Sp.xl), child: Skeleton(height: 400)),
                error: (e, _) => ErrorState(message: friendlyError(e), onRetry: () => ref.read(momentsProvider.notifier).refresh()),
                data: (list) => list.isEmpty
                    ? EmptyState(
                        title: l10n.worldEmptyTitle,
                        message: l10n.worldEmptyMessage,
                        emoji: '🌌',
                        actionLabel: l10n.createMomentCta,
                        onAction: () => context.push('/create'),
                      )
                    : (_explore ? ExploreView(moments: list) : ConstellationView(moments: list, reduceMotion: reduce)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Mo.base,
          width: 48,
          height: 44,
          decoration: BoxDecoration(borderRadius: Rd.pill, color: on ? c.accent.withValues(alpha: 0.2) : Colors.transparent),
          child: Icon(icon, size: 20, color: on ? c.accent : c.muted),
        ),
      ),
    );
  }
}

/// Counts of everything the user's moments have in common, as tappable orbs.
class ExploreView extends StatelessWidget {
  const ExploreView({super.key, required this.moments});
  final List<Moment> moments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Map<String, List<Moment>> group(Iterable<String> Function(Moment) keys) {
      final out = <String, List<Moment>>{};
      for (final m in moments) {
        for (final k in keys(m).toSet()) {
          if (k.trim().isNotEmpty) out.putIfAbsent(k, () => []).add(m);
        }
      }
      return out;
    }

    final sections = <(String, Map<String, List<Moment>>, String Function(String))>[
      (l10n.worldSectionInspirations, group((m) => m.inspirationTypes), (k) => '${emojiFor(inspirationOptions, k)} ${labelFor(l10n, inspirationOptions, k)}'),
      (l10n.worldSectionMoods, group((m) => [if (m.mood != null) m.mood!]), (k) => labelFor(l10n, moodOptions, k)),
      (l10n.worldSectionPlaces, group((m) => [if (m.hasLocation) m.locationName!]), (k) => '📍 $k'),
      (l10n.worldSectionMusic, group((m) => [if (m.hasMusic) (m.musicArtist ?? '').isNotEmpty ? m.musicArtist! : m.musicTitle!]), (k) => '🎧 $k'),
      (l10n.worldSectionWhatYouMake, group((m) => [m.type.name]), (k) => '${CreationType.parse(k).emoji} ${CreationType.parse(k).label(l10n)}'),
    ];
    final c = context.cm;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, 140),
      children: [
        for (final (title, groups, label) in sections)
          if (groups.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.md),
              child: Text(title.toUpperCase(), style: context.tt.labelMedium?.copyWith(letterSpacing: 1.6)),
            ),
            Wrap(
              spacing: Sp.sm,
              runSpacing: Sp.sm,
              children: [
                for (final e in (groups.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length))).take(24))
                  _Orb(
                    label: label(e.key),
                    count: e.value.length,
                    max: groups.values.map((v) => v.length).reduce((a, b) => a > b ? a : b),
                    color: title == l10n.worldSectionMoods ? moodColor(e.key) : c.accent2,
                    onTap: () => showMomentsSheet(context, title: label(e.key), subtitle: l10n.worldMomentsCount(e.value.length), moments: e.value),
                  ),
              ],
            ),
          ],
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.label, required this.count, required this.max, required this.color, required this.onTap});
  final String label;
  final int count, max;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final weight = max <= 1 ? 0.5 : (count - 1) / (max - 1);
    return Semantics(
      button: true,
      label: '$label, ${context.l10n.worldMomentsCount(count)}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(horizontal: 14 + weight * 10, vertical: 10 + weight * 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.28 + weight * 0.25),
                color.withValues(alpha: 0.08),
              ],
              radius: 1.2,
            ),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18 * (0.4 + weight)), blurRadius: 16)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.ui(13.5 + weight * 2.5, weight: FontWeight.w700, color: c.text),
                ),
              ),
              const SizedBox(width: Sp.sm),
              Text(
                '$count',
                style: AppType.ui(12, weight: FontWeight.w800, color: c.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
