import 'package:intl/intl.dart';

class Assessment {
  String className;
  DateTime date;
  String title;
  String? description;

  Assessment({
    required this.className,
    required this.date,
    required this.title,
    this.description,
  });
}

/// The key that marks a feed assignment done in the `assignments_completed`
/// list, for [assessment] filed under [day] in the calendar map.
///
/// Keyed on class + title + day (not time) so it survives re-fetches and
/// stays stable when the same assignment appears on the same day. The
/// Assignments tab and the reminder scheduler must agree on it, or ticking an
/// assignment off would not stop its reminder.
String feedCompletionId(Assessment assessment, DateTime day) =>
    '${assessment.className}|${assessment.title}|'
    '${DateFormat('yyyy-MM-dd').format(day)}';
