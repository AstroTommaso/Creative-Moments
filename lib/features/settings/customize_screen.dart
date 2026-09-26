import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/catalog.dart';
import '../../core/errors/app_error.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/preferences.dart';
import '../../data/providers.dart';
import '../../shared/widgets/ui.dart';
import '../home/environment/environment_scene.dart';

/// Live customization: the environment behind the panel changes as you tap.
class CustomizeScreen extends ConsumerWidget {
  const CustomizeScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, UserPreferences Function(UserPreferences) f) async {
    try {
      await ref.read(preferencesProvider.notifier).edit(f);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(prefsProvider);
    final c = context.cm;

    Widget group(String title, List<Option> opts, bool Function(String) selected, void Function(String) onTap) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.sm),
          child: Text(title.toUpperCase(), style: context.tt.labelMedium?.copyWith(letterSpacing: 1.4)),
        ),
        Wrap(
          spacing: Sp.sm,
          runSpacing: Sp.sm,
          children: [for (final o in opts) OptionTile(emoji: o.emoji, label: o.label, selected: selected(o.id), onTap: () => onTap(o.id))],
        ),
      ],
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const EnvironmentScene(),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(Sp.sm),
                child: Glass(
                  radius: 999,
                  padding: EdgeInsets.zero,
                  child: IconButton(
                    tooltip: 'Done',
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ),
          ),
          // Pull the panel down to see the whole environment.
          DraggableScrollableSheet(
            initialChildSize: 0.44,
            minChildSize: 0.12,
            maxChildSize: 0.8,
            snap: true,
            builder: (context, scroll) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Rd.xl)),
              child: ColoredBox(
                color: c.bg.withValues(alpha: 0.88),
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.md, Sp.xl, Sp.xxl),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(borderRadius: Rd.pill, color: c.muted.withValues(alpha: 0.5)),
                      ),
                    ),
                    const SizedBox(height: Sp.lg),
                    Text('Customize', style: AppType.display(34, color: c.text)),
                    Text('Tap to change your world. Pull this panel down to see all of it.', style: context.tt.bodySmall),
                    group('Environment', environmentOptions, (id) => p.environments.contains(id), (id) {
                      _edit(context, ref, (q) {
                        final list = [...q.environments];
                        list.contains(id) ? list.remove(id) : list.add(id);
                        return q.copyWith(environments: list, environment: list.isEmpty ? 'moon' : list.first);
                      });
                    }),
                    if (p.environments.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: Sp.sm),
                        child: Text('${labelFor(environmentOptions, p.environments.first)} leads; the rest blend in.', style: context.tt.bodySmall),
                      ),
                    group('Time', timeOptions, (id) => p.timeStyle == id, (id) => _edit(context, ref, (q) => q.copyWith(timeStyle: id))),
                    group('Atmosphere', atmosphereOptions, (id) => p.atmosphere == id, (id) => _edit(context, ref, (q) => q.copyWith(atmosphere: id))),
                    group('Visual density', densityOptions, (id) => p.visualDensity == id, (id) => _edit(context, ref, (q) => q.copyWith(visualDensity: id))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
