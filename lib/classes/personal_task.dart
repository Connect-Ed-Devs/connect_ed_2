import 'dart:convert';

import 'package:connect_ed_2/logger.dart';
import 'package:connect_ed_2/main.dart';

/// SharedPreferences key holding every personal task as one JSON list.
const personalTasksKey = 'personal_tasks';

/// SharedPreferences key of the string list of completed ids shared by feed
/// assignments and personal tasks.
const completedKey = 'assignments_completed';

/// A task the student added themselves, as opposed to one from a school feed.
///
/// [due] is null for a task with no date. When [hasTime] is false only the
/// calendar day of [due] is meaningful and the time of day is dropped.
class PersonalTask {
  PersonalTask({
    required this.id,
    required this.title,
    DateTime? due,
    this.hasTime = false,
  }) : due =
           due == null || hasTime
               ? due
               : DateTime(due.year, due.month, due.day);

  final String id;
  final String title;
  final DateTime? due;
  final bool hasTime;

  /// The key that marks this task done in the Assignments tab's
  /// `assignments_completed` set. Prefixed so it can never collide with a feed
  /// assignment's `class|title|day` id.
  String get completionId => 'task|$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'due': due?.toIso8601String(),
    'hasTime': hasTime,
  };

  factory PersonalTask.fromJson(Map<String, dynamic> json) {
    final due = json['due'] as String?;
    return PersonalTask(
      id: json['id'] as String,
      title: json['title'] as String,
      due: due == null ? null : DateTime.parse(due),
      hasTime: json['hasTime'] as bool? ?? false,
    );
  }
}

/// Every saved personal task, in the order they were saved.
///
/// Items are decoded one at a time: a malformed item is logged and skipped so
/// the rest survive, and an unreadable list is logged and read as empty.
List<PersonalTask> loadPersonalTasks() {
  final raw = prefs.getString(personalTasksKey);
  if (raw == null) return [];
  final List<dynamic> list;
  try {
    list = jsonDecode(raw) as List<dynamic>;
  } catch (error) {
    logger.e('Could not read saved personal tasks: $error');
    return [];
  }
  final tasks = <PersonalTask>[];
  for (final item in list) {
    try {
      tasks.add(PersonalTask.fromJson(item as Map<String, dynamic>));
    } catch (error) {
      logger.e('Skipped an unreadable personal task: $error');
    }
  }
  return tasks;
}

/// Whether [task] is ticked off in the Assignments tab.
bool isPersonalTaskDone(PersonalTask task) =>
    (prefs.getStringList(completedKey) ?? const <String>[]).contains(
      task.completionId,
    );

Future<void> savePersonalTasks(List<PersonalTask> tasks) async {
  await prefs.setString(
    personalTasksKey,
    jsonEncode([for (final task in tasks) task.toJson()]),
  );
}
