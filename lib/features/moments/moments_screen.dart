import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/errors/app_error.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/moment.dart';
import '../../data/providers.dart';
import '../../shared/widgets/moment_card.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/ui.dart';
import '../calendar/calendar_view.dart';

class MomentsScreen extends ConsumerStatefulWidget {
  const MomentsScreen({super.key});
  @override
  ConsumerState<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends ConsumerState<MomentsScreen> {
  bool _calendar = false;

  @override
  Widget build(BuildContext context) {
    final moments = ref.watch(momentsProvider);
    final c = context.cm;
    return AtmoScaffold(
      intensity: 0.28,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenTitle(
              'Moments',
              subtitle: moments.value == null ? null : '${moments.value!.length} kept',
              trailing: Container(
                decoration: BoxDecoration(
                  borderRadius: Rd.pill,
                  border: Border.all(color: c.border),
                  color: c.text.withValues(alpha: 0.05),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Seg(icon: Icons.view_agenda_outlined, label: 'Timeline', on: !_calendar, onTap: () => setState(() => _calendar = false)),
                    _Seg(icon: Icons.calendar_month_outlined, label: 'Calendar', on: _calendar, onTap: () => setState(() => _calendar = true)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: moments.when(
                loading: () => ListView(
                  padding: const EdgeInsets.all(Sp.xl),
                  children: const [
                    Skeleton(height: 260),
                    SizedBox(height: Sp.lg),
                    Skeleton(height: 260),
                    SizedBox(height: Sp.lg),
                    Skeleton(height: 260),
                  ],
                ),
                error: (e, _) => ErrorState(message: friendlyError(e), onRetry: () => ref.read(momentsProvider.notifier).refresh()),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      title: 'Your story starts here.',
                      message: 'Create something worth remembering.',
                      actionLabel: 'Create a Moment',
                      onAction: () => context.push('/create'),
                    );
                  }
                  return AnimatedSwitcher(
                    duration: Mo.base,
                    child: _calendar ? CalendarView(key: const ValueKey('cal'), moments: list) : _Timeline(key: const ValueKey('tl'), moments: list),
                  );
                },
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

class _Timeline extends ConsumerWidget {
  const _Timeline({super.key, required this.moments});
  final List<Moment> moments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // group by month
    final groups = <String, List<Moment>>{};
    for (final m in moments) {
      groups.putIfAbsent(DateFormat('MMMM y').format(m.createdAt), () => []).add(m);
    }
    final c = context.cm;
    return RefreshIndicator(
      color: c.accent,
      onRefresh: () => ref.read(momentsProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, 140),
        children: [
          for (final e in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: Sp.lg, bottom: Sp.md),
              child: Text(e.key.toUpperCase(), style: context.tt.labelMedium?.copyWith(letterSpacing: 1.6)),
            ),
            for (var i = 0; i < e.value.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.lg),
                child: FadeSlide(
                  index: i.clamp(0, 4),
                  child: MomentCard(moment: e.value[i], height: i == 0 ? 300 : 240),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
