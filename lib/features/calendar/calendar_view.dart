import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/catalog.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/models/moment.dart';
import '../moments/moments_sheet.dart';

/// Month grid: each day shows its moments as small glowing marks; tap a day
/// to open what was made.
class CalendarView extends StatefulWidget {
  const CalendarView({super.key, required this.moments});
  final List<Moment> moments;
  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Map<int, List<Moment>> _byDay() {
    final out = <int, List<Moment>>{};
    for (final m in widget.moments) {
      if (m.createdAt.year == _month.year && m.createdAt.month == _month.month) {
        out.putIfAbsent(m.createdAt.day, () => []).add(m);
      }
    }
    return out;
  }

  void _shift(int d) => setState(() => _month = DateTime(_month.year, _month.month + d));

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final byDay = _byDay();
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final lead = (first.weekday + 6) % 7; // Monday first
    final now = DateTime.now();
    final total = byDay.values.fold<int>(0, (a, b) => a + b.length);
    final canNext = _month.isBefore(DateTime(now.year, now.month));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, 140),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(tooltip: 'Previous month', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM y').format(_month),
                      style: AppType.display(28, weight: FontWeight.w700, color: c.text),
                    ),
                    Text(total == 0 ? 'Nothing this month' : '$total moment${total == 1 ? '' : 's'}', style: context.tt.bodySmall),
                  ],
                ),
              ),
              IconButton(tooltip: 'Next month', onPressed: canNext ? () => _shift(1) : null, icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(child: Text(d, style: context.tt.labelSmall)),
                ),
            ],
          ),
          const SizedBox(height: Sp.sm),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.78,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var day = 1; day <= days; day++)
                _DayCell(
                  day: day,
                  moments: byDay[day] ?? const [],
                  isToday: now.year == _month.year && now.month == _month.month && now.day == day,
                  onTap: (byDay[day] ?? const []).isEmpty
                      ? null
                      : () => showMomentsSheet(
                          context,
                          title: DateFormat('EEEE, MMMM d').format(DateTime(_month.year, _month.month, day)),
                          subtitle: '${byDay[day]!.length} moment${byDay[day]!.length == 1 ? '' : 's'}',
                          moments: byDay[day]!,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.moments, required this.isToday, required this.onTap});
  final int day;
  final List<Moment> moments;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cm;
    final has = moments.isNotEmpty;
    final col = has ? moodColor(moments.first.mood) : c.muted;
    return Semantics(
      button: has,
      label: has ? '$day, ${moments.length} moment${moments.length == 1 ? '' : 's'}' : '$day',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Mo.base,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rd.sm + 2),
            color: has ? col.withValues(alpha: 0.16) : c.text.withValues(alpha: 0.03),
            border: Border.all(color: isToday ? c.accent : (has ? col.withValues(alpha: 0.4) : Colors.transparent), width: isToday ? 1.6 : 1),
            boxShadow: has ? [BoxShadow(color: col.withValues(alpha: 0.18), blurRadius: 12)] : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: AppType.ui(14, weight: has || isToday ? FontWeight.w800 : FontWeight.w500, color: has || isToday ? c.text : c.muted),
              ),
              const SizedBox(height: 2),
              if (has)
                FittedBox(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final m in moments.take(3)) Text(m.type.emoji, style: const TextStyle(fontSize: 11)),
                      if (moments.length > 3)
                        Text(
                          '+${moments.length - 3}',
                          style: AppType.ui(10, weight: FontWeight.w800, color: c.text),
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
