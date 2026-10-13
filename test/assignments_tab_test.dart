import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/frontend/assignments/assignments.dart';
import 'package:connect_ed_2/frontend/setup/nav_bar.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A pinned "today" (Thursday 12 March 2026). Urgency grouping, the countdown
/// labels and which month the tab opens on all read the clock, so fixtures and
/// expectations are built from this instead of the wall clock. Without it the
/// end-of-month runs would silently move items into a different month - and
/// out of the month the tab is actually showing.
final DateTime _now = DateTime(2026, 3, 12, 9, 0);

/// A day in the month the tab opens on.
DateTime _due(int day) => DateTime(2026, 3, day);

/// A day in the following month, used to prove the month picker filters.
DateTime _nextMonth(int day) => DateTime(2026, 4, day);

/// The real date, for the app-shell test that cannot inject a clock.
DateTime _realToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Assessment _assessment(String title, String className, DateTime date) =>
    Assessment(title: title, className: className, date: date);

CalendarItem _item(List<Assessment> assessments) =>
    CalendarItem(schedule: const [], assessments: assessments);

/// Seeds the exact SharedPreferences cache a successful network fetch produces.
void _seed(Map<DateTime, CalendarItem> data) => calendarManager.storeData(data);

/// Mounts the tab with the clock pinned and lets its (cache-backed) load settle.
Future<void> _pumpTab(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: AssignmentsPage(now: _now)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _selectMonth(WidgetTester tester, DateTime month) async {
  await tester.tap(find.byType(DropdownButton<DateTime>));
  await tester.pumpAndSettle();
  // The selected value is also rendered in the closed button, so target the
  // last match - the one inside the open menu.
  await tester.tap(find.text(DateFormat('MMM yyyy').format(month)).last);
  await tester.pumpAndSettle();
}

/// The completed dropdown sits below the outstanding work, so a tall surface
/// keeps it built in the lazy list.
void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() async {
    // AssignmentsPage reads the global `prefs`, which main() normally assigns.
    // Tests never call main(), so seed it here.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // calendarManager is a process-wide singleton; drop any timestamp left
    // behind by a previous test so cache freshness is deterministic.
    calendarManager.lastRecorded = null;
  });

  group('structure', () {
    testWidgets('renders the Assignments header', (tester) async {
      await _pumpTab(tester);

      expect(find.text('Assignments'), findsOneWidget);
    });

    testWidgets('is constructible as a distinct tab page', (tester) async {
      expect(() => const AssignmentsPage(), returnsNormally);
    });

    testWidgets('nav bar reports index 2 for the assignments icon', (
      tester,
    ) async {
      int? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CENavBar(
              selectedIndex: 0,
              onIndexChanged: (index) => tapped = index,
            ),
          ),
        ),
      );

      // The icon sits inside a scaled Transform, so its own box is not the
      // hit target; the enclosing nav item is. The assertion below is what
      // proves the tap landed on the assignments item.
      await tester.tap(
        find.byIcon(Icons.assignment_outlined),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tapped, 2);
    });
  });

  group('required assignment detail', () {
    testWidgets('shows the assignment name, its class and when it is due', (
      tester,
    ) async {
      _seed({
        _due(15): _item([_assessment('Essay draft', 'English', _due(15))]),
      });

      await _pumpTab(tester);

      expect(find.text('Essay draft'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      // One date label per row: relative while that reads naturally, the date
      // beyond it. It replaced a "Due ..." line beside a countdown pill.
      expect(
        find.text(DateFormat('EEE d MMM').format(_due(15))),
        findsOneWidget,
      );
    });

    testWidgets('rows sit on the canvas, separated by a divider', (
      tester,
    ) async {
      _seed({
        _due(14): _item([
          _assessment('Lab report', 'Chemistry', _due(14)),
          _assessment('Problem set', 'Math', _due(14)),
        ]),
      });

      await _pumpTab(tester);

      // A list, not a stack of containers: one hairline between the two rows,
      // indented to the text column.
      expect(find.byType(Divider), findsOneWidget);
      // Regression guard for the removed row chrome - a rounded surface per
      // item plus the coloured accent spine down its left edge, which is the
      // most reliable "generated, not designed" tell there is (DESIGN.md 2.1).
      expect(
        find.byWidgetPredicate(
          (w) => w is Material && w.borderRadius != null,
        ),
        findsNothing,
        reason: 'assignment rows should sit on the canvas, not in rounded cards',
      );
    });

    testWidgets('falls back to a placeholder when an assignment has no name', (
      tester,
    ) async {
      _seed({
        _due(13): _item([_assessment('   ', 'Math', _due(13))]),
      });

      await _pumpTab(tester);

      expect(find.text('Untitled assignment'), findsOneWidget);
      expect(find.text('Math'), findsOneWidget);
    });

    testWidgets('labels an assignment with no class as Unclassified', (
      tester,
    ) async {
      _seed({
        _due(13): _item([_assessment('Read chapter 4', '', _due(13))]),
      });

      await _pumpTab(tester);

      expect(find.text('Unclassified'), findsOneWidget);
    });

    testWidgets('shows every assignment exactly once', (tester) async {
      _seed({
        _due(14): _item([
          _assessment('Lab report', 'Chemistry', _due(14)),
          _assessment('Lab report', 'Chemistry', _due(14)),
          _assessment('Problem set', 'Math', _due(14)),
        ]),
      });

      await _pumpTab(tester);

      // Same class + title + day is one assignment, not two.
      expect(find.text('Lab report'), findsOneWidget);
      expect(find.text('Problem set'), findsOneWidget);
    });
  });

  group('urgency buckets', () {
    testWidgets('groups assignments by how soon they are due', (tester) async {
      _useTallView(tester);

      _seed({
        _due(10): _item([_assessment('Late thing', 'History', _due(10))]),
        _due(12): _item([_assessment('Today thing', 'Math', _due(12))]),
        _due(13): _item([_assessment('Tomorrow thing', 'Biology', _due(13))]),
        _due(16): _item([_assessment('Week thing', 'French', _due(16))]),
        _due(25): _item([_assessment('Later thing', 'Physics', _due(25))]),
      });

      await _pumpTab(tester);

      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      // 'Tomorrow' is also the countdown chip label for the next day.
      expect(find.text('Tomorrow'), findsWidgets);

      expect(find.text('Late thing'), findsOneWidget);
      expect(find.text('Today thing'), findsOneWidget);
      expect(find.text('Later thing'), findsOneWidget);
    });
  });

  group('month picking', () {
    testWidgets('opens on the current month and hides the others', (
      tester,
    ) async {
      _seed({
        _due(20): _item([_assessment('March thing', 'Math', _due(20))]),
        _nextMonth(6): _item([_assessment('April thing', 'Physics', _nextMonth(6))]),
      });

      await _pumpTab(tester);

      expect(find.text('March thing'), findsOneWidget);
      // A year-long feed would otherwise open on hundreds of rows.
      expect(find.text('April thing'), findsNothing);
      // Both months are still offered.
      expect(find.text('Mar 2026'), findsOneWidget);
    });

    testWidgets("another month's work can be selected", (tester) async {
      _seed({
        _due(20): _item([_assessment('March thing', 'Math', _due(20))]),
        _nextMonth(6): _item([_assessment('April thing', 'Physics', _nextMonth(6))]),
      });

      await _pumpTab(tester);
      await _selectMonth(tester, DateTime(2026, 4));

      expect(find.text('April thing'), findsOneWidget);
      expect(find.text('March thing'), findsNothing);
      expect(find.text('Apr 2026'), findsOneWidget);
    });

    testWidgets('says so when the open month is empty', (tester) async {
      // Everything is in April, so March - the month the tab opens on - has
      // nothing. That must read as "nothing this month", not as "no data".
      _seed({
        _nextMonth(6): _item([_assessment('April thing', 'Physics', _nextMonth(6))]),
      });

      await _pumpTab(tester);

      expect(find.text('Nothing due in March 2026'), findsOneWidget);
      expect(find.text('No assignments yet'), findsNothing);
    });
  });

  group('completing work', () {
    testWidgets('marks an assignment done on tap and persists it', (
      tester,
    ) async {
      _seed({
        _due(14): _item([_assessment('Essay draft', 'English', _due(14))]),
      });

      await _pumpTab(tester);
      expect(find.text('Essay draft'), findsOneWidget);

      await tester.tap(find.text('Essay draft'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final id = 'English|Essay draft|${DateFormat('yyyy-MM-dd').format(_due(14))}';
      expect(prefs.getStringList('assignments_completed'), contains(id));
      // Completed work drops out of the outstanding list, but the dropdown
      // keeps it reachable.
      expect(find.text('Essay draft'), findsNothing);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Show'), findsOneWidget);
    });

    testWidgets('the Completed dropdown reveals what was finished', (
      tester,
    ) async {
      _useTallView(tester);

      _seed({
        _due(14): _item([
          _assessment('Essay draft', 'English', _due(14)),
          _assessment('Problem set', 'Math', _due(14)),
        ]),
      });

      await _pumpTab(tester);
      await tester.tap(find.text('Essay draft'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Essay draft'), findsNothing);

      await tester.tap(find.text('Completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Essay draft'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
    });

    testWidgets('a completed assignment can be un-completed from the dropdown', (
      tester,
    ) async {
      _useTallView(tester);

      _seed({
        _due(14): _item([_assessment('Essay draft', 'English', _due(14))]),
      });

      await _pumpTab(tester);
      await tester.tap(find.text('Essay draft'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.text('Essay draft'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(prefs.getStringList('assignments_completed'), isEmpty);
      expect(find.text('1 to do'), findsOneWidget);
    });

    testWidgets('restores previously completed assignments from storage', (
      tester,
    ) async {
      await prefs.setStringList('assignments_completed', [
        'English|Essay draft|${DateFormat('yyyy-MM-dd').format(_due(14))}',
      ]);
      _seed({
        _due(14): _item([_assessment('Essay draft', 'English', _due(14))]),
      });

      await _pumpTab(tester);

      expect(find.text('Essay draft'), findsNothing);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('All caught up'), findsOneWidget);
    });

    testWidgets('keeps the outstanding count in step with the taps', (
      tester,
    ) async {
      _seed({
        _due(14): _item([
          _assessment('Essay draft', 'English', _due(14)),
          _assessment('Problem set', 'Math', _due(14)),
        ]),
      });

      await _pumpTab(tester);
      expect(find.text('2 to do'), findsOneWidget);

      await tester.tap(find.text('Problem set'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('1 to do'), findsOneWidget);

      await tester.tap(find.text('Essay draft'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('All caught up'), findsOneWidget);
    });
  });

  group('empty and error states', () {
    testWidgets('shows the empty state when the feed has no assessments', (
      tester,
    ) async {
      // A day that only carries classes, no assessments.
      _seed({_due(12): const CalendarItem(schedule: [], assessments: [])});

      await _pumpTab(tester);

      expect(find.text('No assignments yet'), findsOneWidget);
    });

    testWidgets('shows the error state when loading fails', (tester) async {
      // No cache and no reachable feed: the fetch must surface an error
      // instead of a blank screen.
      await _pumpTab(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Could not load assignments'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('never renders a blank screen in an unknown state', (
      tester,
    ) async {
      await _pumpTab(tester);
      await tester.pump(const Duration(seconds: 1));

      final empty = find.text('No assignments yet');
      final emptyMonth = find.textContaining('Nothing due in');
      final error = find.text('Could not load assignments');
      final loading = find.byType(CircularProgressIndicator);
      final header = find.text('Assignments');

      expect(
        empty.evaluate().isNotEmpty ||
            emptyMonth.evaluate().isNotEmpty ||
            error.evaluate().isNotEmpty ||
            loading.evaluate().isNotEmpty,
        isTrue,
        reason: 'AssignmentsPage rendered none of its known states',
      );
      expect(header, findsOneWidget);
    });
  });

  group('reachable from the app shell', () {
    testWidgets('tapping the assignments tab in the home shell opens it', (
      tester,
    ) async {
      await prefs.setString('setup', 'complete');
      // This path mounts the real MyApp, which builds AssignmentsPage without a
      // pinned clock, so the fixture has to be due today to be sure it lands in
      // the month the tab opens on.
      final today = _realToday();
      _seed({
        today: _item([_assessment('Essay draft', 'English', today)]),
      });

      await tester.pumpWidget(const MyApp());
      // Let the home tab's async loads finish while it is still mounted.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Scoped to the nav bar so the home tab's own assignment icons can't
      // be tapped by mistake.
      await tester.tap(
        find.descendant(
          of: find.byType(CENavBar),
          matching: find.byIcon(Icons.assignment_outlined),
        ),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Assignments'), findsOneWidget);
      expect(find.text('Essay draft'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });
  });
}
