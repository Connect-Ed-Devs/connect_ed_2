import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';

class CalendarItem {
  final List<ScheduleItem> schedule;
  final List<Assessment> assessments;

  const CalendarItem({required this.schedule, required this.assessments});
}
