// The Home header renders "Up Next" inside a fixed-height (175px) flexible
// space. Real campus class names are long enough to wrap to a second line there,
// which pushed the content past the bottom of the header and tripped a
// RenderFlex overflow - the red banner shown over the blue card. The title is
// now single-line with an ellipsis.
//
// Note: Home only lists a class as "up next" when its start time is later today
// (see HomePage._getNextScheduleItem), so the fixture is built relative to the
// wall clock. In the last couple of minutes before midnight there is no room
// for a future class today and the assertion below would fail rather than pass
// vacuously - the title check is there precisely so a missing up-next item can
// never masquerade as a fixed layout.
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/frontend/home/home.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The exact title that overflowed the header, straight off Appleby's Podium
/// feed (it is folded across two lines in the raw iCalendar).
const _longTitle = 'AP English Language & Composition';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Process-wide singleton: drop any timestamp from an earlier test so cache
    // freshness is deterministic.
    calendarManager.lastRecorded = null;
  });

  testWidgets('a long class name does not overflow the Up Next header', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = now.add(const Duration(minutes: 2));

    // Annotated on purpose: storeData takes a Map<dynamic, dynamic>, so an
    // inline literal is inferred with that contextual type and then throws
    // inside CalendarManager.encodeData, which casts to the real key/value
    // types.
    final Map<DateTime, CalendarItem> seeded = {
      today: CalendarItem(
        schedule: [
          ScheduleItem(
            title: _longTitle,
            startTime: TimeOfDay.fromDateTime(start),
            endTime: TimeOfDay.fromDateTime(
              start.add(const Duration(minutes: 55)),
            ),
          ),
        ],
        assessments: const [],
      ),
    };
    calendarManager.storeData(seeded);

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Guard against a vacuous pass: the long title has to actually be on
    // screen. Exact match, because the collapsed header also shows it as
    // "Up Next: <title>".
    expect(find.text(_longTitle), findsOneWidget);
    // A RenderFlex overflow is reported through the exception channel.
    expect(tester.takeException(), isNull);
  });
}
