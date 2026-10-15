import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/personal_task.dart';
import 'package:connect_ed_2/frontend/assignments/assignments.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thursday 12 March 2026.
final DateTime _now = DateTime(2026, 3, 12, 9, 0);

Assessment _a(String title, int day) =>
    Assessment(title: title, className: 'Math', date: DateTime(2026, 3, day));

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: AssignmentsPage(now: _now)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      personalTasksKey:
          '[{"id":"p","title":"Pack bag","due":"2026-03-14T00:00:00.000","hasTime":false}]',
      completedKey: ['Math|Done thing|2026-03-14'],
    });
    prefs = await SharedPreferences.getInstance();
    calendarManager.lastRecorded = null;
    calendarManager.storeData(<DateTime, CalendarItem>{
      DateTime(2026, 3, 12): CalendarItem(
        schedule: const [],
        assessments: [_a('Quiz', 12)],
      ),
      DateTime(2026, 3, 14): CalendarItem(
        schedule: const [],
        assessments: [_a('Essay', 14), _a('Lab', 14), _a('Done thing', 14)],
      ),
    });
  });

  testWidgets('shows a count per day with a dash for empty days', (
    tester,
  ) async {
    await _pump(tester);
    final strip = find.byKey(const ValueKey('week-strip'));
    expect(strip, findsOneWidget);
    expect(
      find.descendant(of: strip, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('3')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('–')),
      findsNWidgets(5),
    );
    expect(
      find.descendant(of: strip, matching: find.text('12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('18')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a day filters the list to it and tapping again clears', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Quiz'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('Saturday 14 March')));
    await tester.pump();
    expect(find.text('Essay'), findsOneWidget);
    expect(find.text('Pack bag'), findsOneWidget);
    expect(find.text('Quiz'), findsNothing);

    await tester.tap(find.bySemanticsLabel(RegExp('Saturday 14 March')));
    await tester.pump();
    expect(find.text('Quiz'), findsOneWidget);
  });
}
