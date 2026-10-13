// The lock-screen widgets are the one part of this app that cannot be tested
// from Dart, because the readers are Kotlin and Swift. What *can* be pinned is
// the contract they read: the key names, and the rule for what each value says.
//
// A wrong key here does not throw anywhere - the widget just goes quiet - so
// these tests treat the payload as an interface, not as an implementation
// detail.
import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/classes/widget_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Thursday 12 March 2026, 9:00am. Every branch of the builder reads the clock,
/// so it is pinned rather than taken from the wall.
final DateTime _now = DateTime(2026, 3, 12, 9, 0);

DateTime _day(int d) => DateTime(2026, 3, d);

CalendarItem _calendarItem({
  List<ScheduleItem> schedule = const [],
  List<Assessment> assessments = const [],
}) => CalendarItem(schedule: schedule, assessments: assessments);

ScheduleItem _class(
  String title,
  int startHour,
  int startMinute, {
  int endHour = 10,
  int endMinute = 0,
  String? room,
}) => ScheduleItem(
  title: title,
  startTime: TimeOfDay(hour: startHour, minute: startMinute),
  endTime: TimeOfDay(hour: endHour, minute: endMinute),
  location: room,
);

Assessment _work(String title, String className, DateTime date) =>
    Assessment(title: title, className: className, date: date);

void main() {
  group('the wire contract', () {
    test('exposes exactly the keys the native readers look for', () {
      // These seven names appear verbatim in
      // android/.../ConnectEdWidgetProvider.kt and
      // ios/ConnectEdWidget/ConnectEdWidget.swift. Renaming one here without
      // renaming them there breaks the widget silently.
      expect(WidgetSnapshot.empty.toMap().keys.toSet(), {
        'has_data',
        'next_title',
        'next_time',
        'next_room',
        'due_today',
        'due_next_title',
        'due_next_when',
      });
    });

    test('types are what an untyped native store expects', () {
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(12): _calendarItem(
            schedule: [_class('Chemistry', 13, 30, endHour: 14, endMinute: 45)],
            assessments: [_work('Unit 1 Test', 'Chemistry', _day(12))],
          ),
        },
        now: _now,
      );

      final map = snapshot.toMap();
      expect(map['has_data'], isA<bool>());
      expect(map['due_today'], isA<int>());
      expect(map['next_title'], isA<String>());
    });

    test('a payload with data never carries an empty title', () {
      // The readers show their own "open the app" state only when has_data is
      // false, so they rely on this.
      final snapshot = WidgetSnapshot.build(
        calendar: {_day(12): _calendarItem()},
        now: _now,
      );

      expect(snapshot.hasData, isTrue);
      expect(snapshot.nextTitle, isNotEmpty);
    });
  });

  group('before the app has fetched anything', () {
    test('reports no data rather than inventing an empty class', () {
      for (final calendar in <Map<DateTime, CalendarItem>?>[null, {}]) {
        final snapshot = WidgetSnapshot.build(calendar: calendar, now: _now);

        expect(snapshot.hasData, isFalse);
        expect(snapshot.nextTitle, isEmpty);
        expect(snapshot.dueToday, 0);
        expect(snapshot.dueNextTitle, isEmpty);
      }
    });
  });

  group('the next class', () {
    test('is the next one starting after now, with its time and room', () {
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(12): _calendarItem(
            schedule: [
              _class('Math', 8, 0, room: 'C-1'),
              _class(
                'Introduction to Computer Science',
                10,
                5,
                endHour: 11,
                endMinute: 20,
                room: 'B-1',
              ),
            ],
          ),
        },
        now: _now,
      );

      expect(snapshot.nextTitle, 'Introduction to Computer Science');
      expect(snapshot.nextTime, '10:05 AM – 11:20 AM');
      expect(snapshot.nextRoom, 'B-1');
    });

    test('skips a class already under way, matching the Home card', () {
      // 8:45-10:00 with "now" at 9:00 is in progress. Home shows the class
      // after it, so the widget must not disagree with the app.
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(12): _calendarItem(
            schedule: [
              _class('Physics', 8, 45, endHour: 10, endMinute: 0, room: 'A-1'),
              _class('Chemistry', 10, 5, endHour: 11, endMinute: 0, room: 'D-2'),
            ],
          ),
        },
        now: _now,
      );

      expect(snapshot.nextTitle, 'Chemistry');
      expect(snapshot.nextRoom, 'D-2');
    });

    test('rolls forward to the next day that has classes', () {
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(12): _calendarItem(),
          _day(13): _calendarItem(
            schedule: [_class('Biology', 9, 5, room: 'A-2')],
          ),
        },
        now: _now,
      );

      expect(snapshot.nextTitle, 'Biology');
      expect(snapshot.nextRoom, 'A-2');
    });

    test('says so plainly when the week is empty', () {
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(12): _calendarItem(),
          _day(30): _calendarItem(
            schedule: [_class('Too far out', 9, 0)],
          ),
        },
        now: _now,
      );

      expect(snapshot.hasData, isTrue);
      expect(snapshot.nextTitle, 'No classes coming up');
      expect(snapshot.nextTime, isEmpty);
      expect(snapshot.nextRoom, isEmpty);
    });

    test('expands a room through the shared room directory', () {
      // The widgets inherit whatever the room directory knows, so filling in
      // the school's code-to-building list updates them too.
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(12): _calendarItem(
            schedule: [_class('Chapel Speech', 10, 5, room: 'Chapel Speech S1')],
          ),
        },
        now: _now,
      );

      expect(snapshot.nextRoom, 'John Bell Chapel');
    });
  });

  group('assessments', () {
    test('counts what is due today', () {
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(12): _calendarItem(
            assessments: [
              _work('Unit 1 Test', 'Chemistry', _day(12)),
              _work('Vocabulaire', 'French', _day(12)),
            ],
          ),
        },
        now: _now,
      );

      expect(snapshot.dueToday, 2);
    });

    test('names the next thing due when nothing is due today', () {
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(12): _calendarItem(),
          _day(13): _calendarItem(
            assessments: [_work('Population Dynamics', 'Geography', _day(13))],
          ),
        },
        now: _now,
      );

      expect(snapshot.dueToday, 0);
      expect(snapshot.dueNextTitle, 'Population Dynamics');
      expect(snapshot.dueNextWhen, 'Tomorrow');
    });

    test('dates anything further out, as the Assignments tab does', () {
      final snapshot = WidgetSnapshot.build(
        calendar: {
          _day(16): _calendarItem(
            assessments: [_work('Essay draft', 'English', _day(16))],
          ),
        },
        now: _now,
      );

      expect(snapshot.dueNextWhen, 'Mon 16 Mar');
    });
  });
}
