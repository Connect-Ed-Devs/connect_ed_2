import 'package:connect_ed_2/classes/week_workload.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One row of the next seven days: weekday letter, date and how much is due.
///
/// The busiest day's count is in `primary`; days with nothing due show a muted
/// dash and cannot be tapped. Today is marked by heavier text, the selected day
/// by an underlined date.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.week,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final List<DayLoad> week;
  final DateTime today;

  /// The day the list is filtered to, or null when it shows everything.
  final DateTime? selected;

  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busiest = week.fold<int>(0, (m, d) => d.count > m ? d.count : m);

    return Padding(
      key: const ValueKey('week-strip'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          for (final load in week)
            Expanded(
              child: _buildDay(theme, load, isBusiest: load.count == busiest),
            ),
        ],
      ),
    );
  }

  Widget _buildDay(ThemeData theme, DayLoad load, {required bool isBusiest}) {
    final day = load.day;
    final isToday = day == today;
    final isSelected = day == selected;
    final empty = load.count == 0;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final weight = isToday ? FontWeight.w700 : FontWeight.w400;
    final heaviest = isBusiest && !empty;

    return Semantics(
      label:
          '${DateFormat('EEEE d MMMM').format(day)}, '
          '${empty ? 'nothing due' : '${load.count} due'}',
      button: !empty,
      excludeSemantics: true,
      child: InkWell(
        onTap: empty ? null : () => onSelect(day),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                DateFormat('EEEEE').format(day),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: weight,
                  color: muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: weight,
                  decoration: isSelected ? TextDecoration.underline : null,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                empty ? '–' : '${load.count}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: heaviest ? FontWeight.w700 : weight,
                  color:
                      heaviest
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(
                            alpha: empty ? 0.38 : 1,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
