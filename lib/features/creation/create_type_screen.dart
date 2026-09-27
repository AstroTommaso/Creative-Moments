import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/catalog.dart';
import '../../core/services/l10n_ext.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/ui.dart';
import 'draft.dart';

class CreateTypeScreen extends ConsumerWidget {
  const CreateTypeScreen({super.key});

  void _start(BuildContext context, WidgetRef ref, CreationType t) {
    ref.read(draftProvider.notifier).start(t);
    // Swap the picker for the editor so closing the editor returns to where you were.
    final router = GoRouter.of(context);
    router.pop();
    router.push('/create/edit');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.cm;
    final types = CreationType.selectable;
    return AtmoScaffold(
      intensity: 0.45,
      appBar: AppBar(
        leading: IconButton(tooltip: context.l10n.createCloseTooltip, icon: const Icon(Icons.close_rounded), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
          children: [
            Semantics(
              header: true,
              child: Text(context.l10n.createTitle, style: AppType.display(46, color: c.text, height: 1)),
            ),
            const SizedBox(height: Sp.sm),
            Text(context.l10n.createSubtitle, style: context.tt.bodyMedium?.copyWith(color: c.muted)),
            const SizedBox(height: Sp.xl),
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - Sp.md) / 2;
                Widget tile(CreationType t, double width) => SizedBox(
                  width: width,
                  height: 108,
                  child: Glass(
                    semanticLabel: t.label(context.l10n),
                    onTap: () => _start(context, ref, t),
                    padding: const EdgeInsets.all(Sp.lg),
                    child: Row(
                      children: [
                        Text(t.emoji, style: const TextStyle(fontSize: 30)),
                        const SizedBox(width: Sp.md),
                        Expanded(
                          child: Text(
                            t.label(context.l10n),
                            style: AppType.display(24, weight: FontWeight.w700, color: c.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                return Wrap(
                  spacing: Sp.md,
                  runSpacing: Sp.md,
                  children: [for (final t in types.where((t) => t != CreationType.freeform)) tile(t, w), tile(CreationType.freeform, box.maxWidth)],
                );
              },
            ),
            const SizedBox(height: Sp.lg),
            Center(
              child: GhostButton(label: context.l10n.createUnsureLabel, icon: Icons.auto_awesome_outlined, onPressed: () => _start(context, ref, CreationType.freeform)),
            ),
          ],
        ),
      ),
    );
  }
}
