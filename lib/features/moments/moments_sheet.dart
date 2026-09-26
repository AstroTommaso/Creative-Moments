import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/moment.dart';
import '../../shared/widgets/moment_card.dart';

/// Bottom sheet listing moments (used by calendar days and My World filters).
Future<void> showMomentsSheet(BuildContext context, {required String title, String? subtitle, required List<Moment> moments}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: moments.length == 1 ? 0.5 : 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xxl),
        children: [
          Semantics(header: true, child: Text(title, style: ctx.tt.headlineMedium)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.xs),
              child: Text(subtitle, style: ctx.tt.bodySmall),
            ),
          const SizedBox(height: Sp.lg),
          for (final m in moments)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.lg),
              child: GestureDetector(
                // close the sheet first so back from detail lands on the list
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/moment/${m.id}');
                },
                child: AbsorbPointer(child: MomentCard(moment: m, height: 220)),
              ),
            ),
        ],
      ),
    ),
  );
}
