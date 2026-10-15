# 02: Personal tasks

## Decision

A student can add their own tasks from the plus button in the Assignments app
bar. Tasks live in one SharedPreferences string, `personal_tasks`, a JSON list
of `{id, title, due, hasTime}`. `due` is an ISO-8601 string or null; with
`hasTime` false only the calendar day is kept.

Public API for later tasks (reminders, week strip), in
`lib/classes/personal_task.dart`:

- `const personalTasksKey = 'personal_tasks'`
- `class PersonalTask` with `toJson` / `fromJson` / `copyWith` and
  `completionId` (`task|<id>`)
- `List<PersonalTask> loadPersonalTasks()` reads the saved list; unreadable
  data is logged and returns an empty list
- `Future<void> savePersonalTasks(List<PersonalTask>)`

Completion reuses the existing `assignments_completed` string list. A task's
entry is `task|<id>`, which cannot collide with a feed id (`class|title|day`).
Readers that need "is it done" read that list for `task.completionId`.

In the tab, a task is a row built by the same `_buildRow` as a feed item, bucketed
by the same day rules, and told apart only by the secondary line "Personal
task". Tasks with no date go in a final "No due date" section and show in every
month. Tap completes; long press opens the edit sheet, which has Save and
Delete task. The sheet is `lib/frontend/assignments/personal_task_sheet.dart`
because `assignments.dart` was already over the size limit in ANTISLOP 1.7.

## Judgment calls

- Long press to edit is not discoverable. Alternatives (a trailing menu or a
  swipe action) add a second control to the row primitive, which DESIGN.md
  says to avoid. Revisit if students do not find it.
- Day counts now compare calendar days. A task due 15:30 yesterday must read
  "1 day ago", but `DateTime.difference(midnight).inDays` truncates that to 0.
- When the feed fails to load but the student has tasks, the tasks show and the
  error state is skipped. The failure is therefore not shown on that screen;
  Settings still shows a failing school link.
- Task ids are `DateTime.now().microsecondsSinceEpoch`; two tasks cannot be
  created in the same microsecond from one sheet.
- Rejected: a separate Tasks tab (the brief asks for the Assignments tab), a
  database package (a short list in SharedPreferences matches how the rest of
  the app persists), a floating action button (it sits under the floating nav
  bar).

## Not verified

- Not run on a device or emulator, and not screenshotted with real data; the
  sheet's look is checked only through widget tests.
- Time-of-day entry through the time picker has a model test but no widget test.
- No external sources: this uses only Flutter's `showModalBottomSheet`,
  `showDatePicker` and `showTimePicker`, whose behaviour was exercised by the
  tests.
