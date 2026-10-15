import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/personal_task.dart';

/// How many unfinished items fall due on [day].
class DayLoad {
  const DayLoad(this.day, this.count);

  /// Midnight of the calendar day.
  final DateTime day;
  final int count;
}

/// The seven days starting at [today] with the number of incomplete feed
/// assignments and dated personal tasks due on each.
///
/// Overdue items are not counted: they have no day in this week. Days are
/// built and matched by year, month and day, never by subtracting durations,
/// because a day is 23 or 25 hours long across a clock change.
List<DayLoad> weekWorkload({
  required Map<DateTime, CalendarItem>? calendar,
  required List<PersonalTask> tasks,
  required Set<String> completed,
  required DateTime today,
}) {
  final days = [
    for (var i = 0; i < 7; i++)
      DateTime(today.year, today.month, today.day + i),
  ];
  final counts = {for (final day in days) day: 0};

  void count(DateTime due) {
    final key = DateTime(due.year, due.month, due.day);
    final current = counts[key];
    if (current != null) counts[key] = current + 1;
  }

  final seen = <String>{};
  calendar?.forEach((day, item) {
    for (final assessment in item.assessments) {
      final id = feedCompletionId(assessment, day);
      if (!seen.add(id) || completed.contains(id)) continue;
      count(day);
    }
  });

  for (final task in tasks) {
    final due = task.due;
    if (due == null || completed.contains(task.completionId)) continue;
    count(due);
  }

  return [for (final day in days) DayLoad(day, counts[day]!)];
}
