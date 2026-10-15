import 'dart:convert';

import 'package:connect_ed_2/logger.dart';
import 'package:connect_ed_2/main.dart';

/// SharedPreferences key holding every personal task as one JSON list.
const personalTasksKey = 'personal_tasks';

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

  PersonalTask copyWith({
    String? title,
    DateTime? due,
    bool? hasTime,
    bool clearDue = false,
  }) {
    return PersonalTask(
      id: id,
      title: title ?? this.title,
      due: clearDue ? null : (due ?? this.due),
      hasTime: clearDue ? false : (hasTime ?? this.hasTime),
    );
  }

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
/// An unreadable value is logged and treated as no tasks, so one bad write
/// cannot stop the Assignments tab from opening.
List<PersonalTask> loadPersonalTasks() {
  final raw = prefs.getString(personalTasksKey);
  if (raw == null) return [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list)
        PersonalTask.fromJson(item as Map<String, dynamic>),
    ];
  } catch (error) {
    logger.e('Could not read saved personal tasks: $error');
    return [];
  }
}

Future<void> savePersonalTasks(List<PersonalTask> tasks) async {
  await prefs.setString(
    personalTasksKey,
    jsonEncode([for (final task in tasks) task.toJson()]),
  );
}
