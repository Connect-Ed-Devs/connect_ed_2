import 'package:connect_ed_2/classes/personal_task.dart';
import 'package:connect_ed_2/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('PersonalTask json', () {
    test('round-trips a task with a date and a time', () {
      final task = PersonalTask(
        id: '1700000000000000',
        title: 'Study for chemistry quiz',
        due: DateTime(2026, 3, 14, 15, 30),
        hasTime: true,
      );

      final back = PersonalTask.fromJson(task.toJson());

      expect(back.id, task.id);
      expect(back.title, 'Study for chemistry quiz');
      expect(back.due, DateTime(2026, 3, 14, 15, 30));
      expect(back.hasTime, isTrue);
    });

    test('round-trips a date-only task and drops the time of day', () {
      final task = PersonalTask(
        id: 'a',
        title: 'Bring trip form',
        due: DateTime(2026, 3, 14, 9, 45),
        hasTime: false,
      );

      final back = PersonalTask.fromJson(task.toJson());

      expect(back.due, DateTime(2026, 3, 14));
      expect(back.hasTime, isFalse);
    });

    test('round-trips a task with no due date', () {
      final back = PersonalTask.fromJson(
        PersonalTask(id: 'b', title: 'Tidy locker').toJson(),
      );

      expect(back.due, isNull);
      expect(back.hasTime, isFalse);
    });
  });

  group('saved list', () {
    test('loads nothing when nothing was saved', () {
      expect(loadPersonalTasks(), isEmpty);
    });

    test('saves and loads the list in order', () async {
      await savePersonalTasks([
        PersonalTask(id: '1', title: 'First', due: DateTime(2026, 3, 14)),
        PersonalTask(id: '2', title: 'Second'),
      ]);

      final loaded = loadPersonalTasks();

      expect(loaded.map((t) => t.title), ['First', 'Second']);
      expect(loaded.first.due, DateTime(2026, 3, 14));
      expect(prefs.getString(personalTasksKey), isNotNull);
    });

    test('a corrupt value loads as empty instead of throwing', () async {
      await prefs.setString(personalTasksKey, '{not json');

      expect(loadPersonalTasks(), isEmpty);
    });

    test('one malformed item is skipped and the rest are kept', () async {
      await prefs.setString(
        personalTasksKey,
        '[{"id":"1","title":"Good","due":null,"hasTime":false},'
        '{"id":"2","due":"not a date"},'
        '{"id":"3","title":"Also good","due":null,"hasTime":false}]',
      );

      expect(loadPersonalTasks().map((t) => t.title), ['Good', 'Also good']);
    });
  });

  group('completion', () {
    test('isPersonalTaskDone reads the shared completed list', () async {
      final task = PersonalTask(id: '9', title: 'Tidy locker');
      expect(isPersonalTaskDone(task), isFalse);

      await prefs.setStringList(completedKey, [task.completionId]);

      expect(isPersonalTaskDone(task), isTrue);
    });
  });
}
