// The Schedule tab shows each class block as a filled row: title on the left,
// time on the right, and the room on its own line beneath the title.
//
// The feed supplies no LOCATION field, so the parser takes the room from the
// summary's trailing parenthetical; these tests pin the rendering, including
// the narrow-screen and short-block cases, because that row is only 70% of the
// viewport wide and only ~24px tall at its smallest.
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/frontend/calendar/calendar.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// Seeds the cache the way a successful fetch does; CalendarPage reads
/// `prefs['calendar_data']` directly and decodes it.
void _seed(List<ScheduleItem> schedule) {
  final Map<DateTime, CalendarItem> data = {
    _today(): CalendarItem(schedule: schedule, assessments: const []),
  };
  calendarManager.storeData(data);
}

ScheduleItem _block(
  String title,
  String? location, {
  int startHour = 9,
  int startMinute = 30,
  int endHour = 10,
  int endMinute = 45,
}) => ScheduleItem(
  title: title,
  startTime: TimeOfDay(hour: startHour, minute: startMinute),
  endTime: TimeOfDay(hour: endHour, minute: endMinute),
  location: location,
);

/// A phone-sized viewport, where the schedule block is only ~350 of the 500
/// logical pixels wide.
///
/// Not narrower on purpose: flutter_test renders every glyph a full em wide, so
/// the 36pt month title in CECalendarAppBar measures far wider than it does with
/// a real font and overflows its Row below ~440px. That is a test-font artifact,
/// not a layout that breaks on device, so this test does not pin it.
Future<void> _pumpCalendar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(500, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: CalendarPage()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    calendarManager.lastRecorded = null;
  });

  testWidgets('shows the room under the class title', (tester) async {
    _seed([_block('AP Physics 1', 'A-1')]);

    await _pumpCalendar(tester);

    expect(find.text('AP Physics 1'), findsOneWidget);
    expect(find.text('A-1'), findsOneWidget);
  });

  testWidgets('a full campus room name sits on its own line', (tester) async {
    // The shape the app should eventually show for every class block, once the
    // school's code-to-building list is filled in.
    _seed([
      _block('AP English Language & Composition', 'Memorial Classroom Building MB104'),
    ]);

    await _pumpCalendar(tester);

    expect(
      find.text('Memorial Classroom Building MB104'),
      findsOneWidget,
    );
    expect(find.text('AP English Language & Composition'), findsOneWidget);
    // Long room and long title on 350px: both ellipsise rather than overflow.
    expect(tester.takeException(), isNull);
  });

  testWidgets('a known campus venue is expanded to its building name', (
    tester,
  ) async {
    // No lookup key has to be spelled exactly: the feed pads "Lunch " with a
    // trailing space, and codes arrive in mixed case.
    _seed([_block('Chapel Speech', 'Chapel Speech S1')]);

    await _pumpCalendar(tester);

    expect(find.text('Chapel Speech'), findsOneWidget);
    expect(find.text('John Bell Chapel'), findsOneWidget);
  });

  testWidgets('a room that only repeats the title is not shown twice', (
    tester,
  ) async {
    // "Lunch - SS (Lunch )" is the most common block in the real feed, and
    // printing "Lunch" over "Lunch" would be noise.
    _seed([_block('Lunch', 'Lunch')]);

    await _pumpCalendar(tester);

    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('a block with no room shows no room line', (tester) async {
    _seed([_block('Advisory', null)]);

    await _pumpCalendar(tester);

    expect(find.text('Advisory'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a block too short for a second line drops the room', (
    tester,
  ) async {
    // 20 minutes lands on the 24px floor, where a second line of text would
    // overflow the block. The room is still reachable by opening the event.
    _seed([
      _block('Advisory', 'Guidance S1', startHour: 10, startMinute: 5, endHour: 10, endMinute: 25),
    ]);

    await _pumpCalendar(tester);

    expect(find.text('Advisory'), findsOneWidget);
    expect(find.text('Guidance S1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
