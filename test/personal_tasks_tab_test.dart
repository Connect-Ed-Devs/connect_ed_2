import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/personal_task.dart';
import 'package:connect_ed_2/frontend/assignments/assignments.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thursday 12 March 2026, the same pinned day as assignments_tab_test.dart.
final DateTime _now = DateTime(2026, 3, 12, 9, 0);

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pumpTab(WidgetTester tester) async {
  _useTallView(tester);
  await tester.pumpWidget(MaterialApp(home: AssignmentsPage(now: _now)));
  await _settle(tester);
}

/// Adds a task through the sheet. [pickDate] accepts the date picker's default,
/// which is the pinned today.
Future<void> _addTask(
  WidgetTester tester,
  String title, {
  bool pickDate = false,
}) async {
  await tester.tap(find.byTooltip('Add task'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), title);
  await tester.pump();
  if (pickDate) {
    await tester.tap(find.text('Set due date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    calendarManager.lastRecorded = null;
    calendarManager.storeData(<DateTime, CalendarItem>{
      DateTime(2026, 3, 20): CalendarItem(
        schedule: const [],
        assessments: [
          Assessment(
            title: 'Essay draft',
            className: 'English',
            date: DateTime(2026, 3, 20),
          ),
        ],
      ),
    });
  });

  testWidgets('a dated task lands in its due-date section and is saved', (
    tester,
  ) async {
    await _pumpTab(tester);

    await _addTask(tester, 'Study for chemistry quiz', pickDate: true);

    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Study for chemistry quiz'), findsOneWidget);
    expect(find.text('Personal task'), findsOneWidget);
    // The feed assignment is still there, in its own section.
    expect(find.text('Essay draft'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    final saved = loadPersonalTasks();
    expect(saved, hasLength(1));
    expect(saved.single.title, 'Study for chemistry quiz');
    expect(saved.single.due, DateTime(2026, 3, 12));
  });

  testWidgets('a task with no date goes under No due date', (tester) async {
    await _pumpTab(tester);

    await _addTask(tester, 'Tidy locker');

    expect(find.text('No due date'), findsOneWidget);
    expect(find.text('Tidy locker'), findsOneWidget);
    expect(loadPersonalTasks().single.due, isNull);
  });

  testWidgets('Save stays disabled until the task has a title', (tester) async {
    await _pumpTab(tester);

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();

    final save = find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Something');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('tapping a task completes it and the choice is remembered', (
    tester,
  ) async {
    await _pumpTab(tester);
    await _addTask(tester, 'Bring trip form', pickDate: true);
    final id = loadPersonalTasks().single.id;

    await tester.tap(find.text('Bring trip form'));
    await _settle(tester);

    expect(prefs.getStringList('assignments_completed'), contains('task|$id'));
    expect(find.text('Bring trip form'), findsNothing);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('a long press edits a task', (tester) async {
    await _pumpTab(tester);
    await _addTask(tester, 'Bring trip form', pickDate: true);

    await tester.longPress(find.text('Bring trip form'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Bring signed trip form');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bring signed trip form'), findsOneWidget);
    expect(find.text('Bring trip form'), findsNothing);
    final saved = loadPersonalTasks();
    expect(saved, hasLength(1));
    expect(saved.single.title, 'Bring signed trip form');
  });

  testWidgets('deleting a task removes it and its completed mark', (
    tester,
  ) async {
    await _pumpTab(tester);
    await _addTask(tester, 'Bring trip form', pickDate: true);
    final id = loadPersonalTasks().single.id;
    await prefs.setStringList('assignments_completed', ['task|$id']);

    await tester.longPress(find.text('Bring trip form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();

    expect(find.text('Bring trip form'), findsNothing);
    expect(loadPersonalTasks(), isEmpty);
    expect(prefs.getStringList('assignments_completed'), isEmpty);
  });

  testWidgets('feed assignments cannot be edited by long press', (
    tester,
  ) async {
    await _pumpTab(tester);

    await tester.longPress(find.text('Essay draft'));
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsNothing);
  });

  testWidgets('saved tasks are shown when the tab opens', (tester) async {
    await savePersonalTasks([
      PersonalTask(
        id: '1',
        title: 'Study for quiz',
        due: DateTime(2026, 3, 13),
      ),
    ]);

    await _pumpTab(tester);

    expect(find.text('Study for quiz'), findsOneWidget);
    expect(find.text('Tomorrow'), findsWidgets);
  });
}
