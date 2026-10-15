import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/personal_task.dart';
import 'package:connect_ed_2/classes/week_workload.dart';
import 'package:flutter_test/flutter_test.dart';

Assessment _a(String title, DateTime day, {String course = 'Math'}) =>
    Assessment(title: title, className: course, date: day);

Map<DateTime, CalendarItem> _calendar(Map<DateTime, List<Assessment>> byDay) =>
    {
      for (final e in byDay.entries)
        e.key: CalendarItem(schedule: const [], assessments: e.value),
    };

List<int> _counts(List<DayLoad> week) => [for (final d in week) d.count];

void main() {
  final today = DateTime(2026, 3, 12);

  test('returns seven consecutive days starting today', () {
    final week = weekWorkload(
      calendar: null,
      tasks: const [],
      completed: const {},
      today: today,
    );
    expect(week.map((d) => d.day.day), [12, 13, 14, 15, 16, 17, 18]);
    expect(_counts(week), [0, 0, 0, 0, 0, 0, 0]);
  });

  test('counts feed assignments and dated personal tasks per day', () {
    final week = weekWorkload(
      calendar: _calendar({
        DateTime(2026, 3, 12): [_a('Quiz', DateTime(2026, 3, 12))],
        DateTime(2026, 3, 14): [
          _a('Essay', DateTime(2026, 3, 14)),
          _a('Lab', DateTime(2026, 3, 14), course: 'Chem'),
        ],
      }),
      tasks: [
        PersonalTask(
          id: '1',
          title: 'Pack',
          due: DateTime(2026, 3, 14, 18),
          hasTime: true,
        ),
        PersonalTask(id: '2', title: 'No date'),
      ],
      completed: const {},
      today: today,
    );
    expect(_counts(week), [1, 0, 3, 0, 0, 0, 0]);
  });

  test('excludes completed items and collapses duplicate feed entries', () {
    final essay = _a('Essay', DateTime(2026, 3, 14));
    final week = weekWorkload(
      calendar: _calendar({
        DateTime(2026, 3, 14): [essay, _a('Essay', DateTime(2026, 3, 14))],
        DateTime(2026, 3, 15): [_a('Read', DateTime(2026, 3, 15))],
      }),
      tasks: [PersonalTask(id: 't', title: 'Pack', due: DateTime(2026, 3, 15))],
      completed: {feedCompletionId(essay, DateTime(2026, 3, 14)), 'task|t'},
      today: today,
    );
    expect(_counts(week), [0, 0, 0, 1, 0, 0, 0]);
  });

  test('ignores overdue items and anything past the seventh day', () {
    final week = weekWorkload(
      calendar: _calendar({
        DateTime(2026, 3, 11): [_a('Late', DateTime(2026, 3, 11))],
        DateTime(2026, 3, 19): [_a('Far', DateTime(2026, 3, 19))],
        DateTime(2026, 3, 18): [_a('Edge', DateTime(2026, 3, 18))],
      }),
      tasks: const [],
      completed: const {},
      today: today,
    );
    expect(_counts(week), [0, 0, 0, 0, 0, 0, 1]);
  });

  test('crosses a month boundary and the spring-forward change', () {
    final start = DateTime(2026, 3, 8); // clocks go forward on 8 March 2026
    final week = weekWorkload(
      calendar: _calendar({
        DateTime(2026, 3, 9): [_a('After change', DateTime(2026, 3, 9))],
      }),
      tasks: const [],
      completed: const {},
      today: start,
    );
    expect(week.map((d) => d.day.day), [8, 9, 10, 11, 12, 13, 14]);
    expect(_counts(week), [0, 1, 0, 0, 0, 0, 0]);

    final endOfMonth = weekWorkload(
      calendar: null,
      tasks: const [],
      completed: const {},
      today: DateTime(2026, 3, 29),
    );
    expect(endOfMonth.last.day, DateTime(2026, 4, 4));
  });
}
