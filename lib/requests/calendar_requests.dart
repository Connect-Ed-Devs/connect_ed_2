import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';

CacheManager CalendarManager = CacheManager(
  cacheKey: 'schedule',
  smallThreshold: const Duration(minutes: 10),
  largeThreshold: const Duration(days: 2),
);

Future<Map<DateTime, CalendarItem>> getCalendarData() async {
  String calendarLink = prefs.getString('calendar_link') ?? '';

  final response = await http.get(Uri.parse(calendarLink));
  if (response.statusCode != 200) throw Exception('Failed to load calendar data');

  final iCalendar = ICalendar.fromLines(response.body.split("\n"));
  var items = iCalendar.toJson()["data"];

  Map<DateTime, CalendarItem> calendarData = {};

  for (final item in items) {
    var rawDate = item["dtstart"];
    if (rawDate != null) {
      if (rawDate["dt"].length > 9) {
        DateTime startDate = DateTime.parse(rawDate["dt"]);
        DateTime endDate = DateTime.parse(item["dtend"]["dt"]);
        String courseName = getCourseName(item["summary"]);

        ScheduleItem scheduleItem = ScheduleItem(
          title: courseName,
          startTime: TimeOfDay.fromDateTime(startDate),
          endTime: TimeOfDay.fromDateTime(endDate),
        );

        if (calendarData[startDate] == null) {
          calendarData[startDate] = CalendarItem(schedule: [scheduleItem], assessments: []);
        } else {
          calendarData[startDate]!.schedule.add(scheduleItem);
        }
      } else if (rawDate["dt"].length == 8) {
        DateTime startDate = DateTime.parse(rawDate["dt"]);
        var descriptionList = item["summary"].split(": ");
        String assignmentName = descriptionList[descriptionList.length - 1] ?? '';
        String _className = getCourseName(item["summary"].substring(0, item["summary"].length - assignmentName.length));

        Assessment assessment = Assessment(title: assignmentName, className: _className, date: startDate);

        if (calendarData[startDate] == null) {
          calendarData[startDate] = CalendarItem(schedule: [], assessments: [assessment]);
        } else {
          calendarData[startDate]!.assessments.add(assessment);
        }
      }
    }
  }
  print(calendarData);
  return calendarData;
}

String getCourseName(String name) {
  try {
    bool isAP = false;
    for (int i = 0; i < name.length - 1; i++) {
      if (name.substring(i, i + 2) == "AP") {
        isAP = true;
      }
    }

    List<String> courseNames = name.split("-");
    if (isAP) {
      return courseNames[1].substring(1, courseNames[1].length);
    } else {
      return courseNames[0].substring(0, courseNames[0].length).split(",")[0];
    }
  } catch (e) {
    return "";
  }
}
