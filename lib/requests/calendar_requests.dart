import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';
import 'dart:convert';

CacheManager calendarManager = CalendarManager();

class CalendarManager extends CacheManager {
  CalendarManager({
    String cacheKey = 'calendar_data',
    Duration smallThreshold = const Duration(minutes: 30),
    Duration largeThreshold = const Duration(days: 2),
  }) : super(cacheKey: cacheKey, smallThreshold: smallThreshold, largeThreshold: largeThreshold);

  @override
  String encodeData(dynamic data) {
    // Create a Map with string keys (DateTime converted to ISO 8601 string)
    Map<String, dynamic> encodedMap = {};

    Map<DateTime, CalendarItem> calendarData = data;

    calendarData.forEach((date, item) {
      // Convert DateTime key to string
      String dateKey = date.toIso8601String();

      // Encode each ScheduleItem
      List<Map<String, dynamic>> scheduleList =
          item.schedule
              .map(
                (scheduleItem) => {
                  'title': scheduleItem.title,
                  'startTimeHour': scheduleItem.startTime.hour,
                  'startTimeMinute': scheduleItem.startTime.minute,
                  'endTimeHour': scheduleItem.endTime.hour,
                  'endTimeMinute': scheduleItem.endTime.minute,
                  'location': scheduleItem.location,
                  'instructor': scheduleItem.instructor,
                  // Color is not encoded as it's not essential and harder to serialize
                },
              )
              .toList();

      // Encode each Assessment
      List<Map<String, dynamic>> assessmentList =
          item.assessments
              .map(
                (assessment) => {
                  'title': assessment.title,
                  'className': assessment.className,
                  'date': assessment.date.toIso8601String(),
                },
              )
              .toList();

      // Store in map
      encodedMap[dateKey] = {'schedule': scheduleList, 'assessments': assessmentList};
    });

    return jsonEncode(encodedMap);
  }

  @override
  Map<DateTime, CalendarItem> decodeData(String data) {
    Map<DateTime, CalendarItem> calendarData = {};

    // Parse the JSON string
    Map<String, dynamic> decodedMap = jsonDecode(data);

    decodedMap.forEach((dateKey, value) {
      // Convert string key back to DateTime
      DateTime date = DateTime.parse(dateKey);

      // Rebuild schedule items
      List<ScheduleItem> schedule = [];
      for (var scheduleData in value['schedule']) {
        schedule.add(
          ScheduleItem(
            title: scheduleData['title'],
            startTime: TimeOfDay(hour: scheduleData['startTimeHour'], minute: scheduleData['startTimeMinute']),
            endTime: TimeOfDay(hour: scheduleData['endTimeHour'], minute: scheduleData['endTimeMinute']),
            location: scheduleData['location'],
            instructor: scheduleData['instructor'],
          ),
        );
      }

      // Rebuild assessment items
      List<Assessment> assessments = [];
      for (var assessmentData in value['assessments']) {
        assessments.add(
          Assessment(
            title: assessmentData['title'],
            className: assessmentData['className'],
            date: DateTime.parse(assessmentData['date']),
          ),
        );
      }

      // Create CalendarItem and add to map
      calendarData[date] = CalendarItem(schedule: schedule, assessments: assessments);
    });

    return calendarData;
  }

  @override
  Future<Map<DateTime, CalendarItem>> fetchData() async {
    // Simulate a fetch error for testing
    // throw Exception('Simulated network error: Unable to connect to calendar service');

    // Original code commented out for testing

    String calendarLink = prefs.getString('link') ?? '';

    final response = await http.get(Uri.parse(calendarLink));
    if (response.statusCode != 200) throw Exception('Failed to load calendar data');

    final iCalendar = ICalendar.fromLines(response.body.split("\n"));
    var items = iCalendar.toJson()["data"];

    Map<DateTime, CalendarItem> calendarData = {};

    for (final item in items) {
      if (item["dtstart"] != null && item["dtend"] != null) {
        if (item["dtstart"]["dt"].length > 9) {
          DateTime startDate = DateTime.parse(item["dtstart"]["dt"]);
          DateTime endDate = DateTime.parse(item["dtend"]["dt"]);
          DateTime date = DateTime(startDate.year, startDate.month, startDate.day);
          String courseName = getCourseName(item["summary"]);

          ScheduleItem scheduleItem = ScheduleItem(
            title: courseName,
            startTime: TimeOfDay.fromDateTime(startDate),
            endTime: TimeOfDay.fromDateTime(endDate),
          );

          if (calendarData[date] == null) {
            calendarData[date] = CalendarItem(schedule: [scheduleItem], assessments: []);
          } else {
            calendarData[date]!.schedule.add(scheduleItem);
          }
        } else if (item["dtstart"]["dt"].length == 8) {
          DateTime startDate = DateTime.parse(item["dtstart"]["dt"]);
          var descriptionList = item["summary"].split(": ");
          String assignmentName = descriptionList[descriptionList.length - 1] ?? '';
          String _className = getCourseName(
            item["summary"].substring(0, item["summary"].length - assignmentName.length),
          );

          Assessment assessment = Assessment(title: assignmentName, className: _className, date: startDate);

          if (calendarData[startDate] == null) {
            calendarData[startDate] = CalendarItem(schedule: [], assessments: [assessment]);
          } else {
            calendarData[startDate]!.assessments.add(assessment);
          }
        }
      }
    }
    super.storeData(calendarData);
    return calendarData;
  }
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
