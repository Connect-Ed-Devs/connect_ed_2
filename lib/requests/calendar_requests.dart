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
    super.cacheKey = 'calendar_data',
    super.smallThreshold = const Duration(minutes: 30),
    super.largeThreshold = const Duration(days: 2),
  });

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
      encodedMap[dateKey] = {
        'schedule': scheduleList,
        'assessments': assessmentList,
      };
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
            startTime: TimeOfDay(
              hour: scheduleData['startTimeHour'],
              minute: scheduleData['startTimeMinute'],
            ),
            endTime: TimeOfDay(
              hour: scheduleData['endTimeHour'],
              minute: scheduleData['endTimeMinute'],
            ),
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
      calendarData[date] = CalendarItem(
        schedule: schedule,
        assessments: assessments,
      );
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
    if (response.statusCode != 200)
      throw Exception('Failed to load calendar data');

    final iCalendar = ICalendar.fromLines(response.body.split('\n'));
    var items = iCalendar.toJson()['data'];

    Map<DateTime, CalendarItem> calendarData = {};

    for (final item in items) {
      if (item['dtstart'] != null && item['dtend'] != null) {
        if (item['dtstart']['dt'].length > 9) {
          final DateTime? startDate = parseICalendarDate(
            item['dtstart']['dt'],
          );
          final DateTime? endDate = parseICalendarDate(item['dtend']['dt']);
          if (startDate == null || endDate == null) continue;
          DateTime date = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          String courseName = getCourseName(item['summary']);

          // Extract location from iCalendar data if available
          String? location = item['location'] as String?;
          String? instructor;

          // If location is still null, try alternative field names
          location ??= item['venue'] as String?;
          location ??= item['details'] as String?;

          // Extract instructor information if available
          instructor = item['organizer'] as String?;
          instructor ??= item['attendee'] as String?;

          // Sometimes location and instructor info might be in the description
          if (item['description'] != null) {
            String description = item['description'] as String;

            // Look for location patterns in description if not found yet
            if (location == null) {
              if (description.contains('Location:')) {
                var locationMatch = RegExp(
                  r'Location:\s*(.+?)(?:\n|$)',
                ).firstMatch(description);
                if (locationMatch != null) {
                  location = locationMatch.group(1)?.trim();
                }
              } else if (description.contains('Room:')) {
                var roomMatch = RegExp(
                  r'Room:\s*(.+?)(?:\n|$)',
                ).firstMatch(description);
                if (roomMatch != null) {
                  location = roomMatch.group(1)?.trim();
                }
              }
            }

            // Look for instructor patterns in description if not found yet
            if (instructor == null) {
              if (description.contains('Instructor:')) {
                var instructorMatch = RegExp(
                  r'Instructor:\s*(.+?)(?:\n|$)',
                ).firstMatch(description);
                if (instructorMatch != null) {
                  instructor = instructorMatch.group(1)?.trim();
                }
              } else if (description.contains('Teacher:')) {
                var teacherMatch = RegExp(
                  r'Teacher:\s*(.+?)(?:\n|$)',
                ).firstMatch(description);
                if (teacherMatch != null) {
                  instructor = teacherMatch.group(1)?.trim();
                }
              }
            }
          }

          ScheduleItem scheduleItem = ScheduleItem(
            title: courseName,
            startTime: TimeOfDay.fromDateTime(startDate),
            endTime: TimeOfDay.fromDateTime(endDate),
            location: location,
            instructor: instructor,
          );

          if (calendarData[date] == null) {
            calendarData[date] = CalendarItem(
              schedule: [scheduleItem],
              assessments: [],
            );
          } else {
            calendarData[date]!.schedule.add(scheduleItem);
          }
        } else if (item['dtstart']['dt'].length >= 8) {
          final DateTime? startDate = parseICalendarDate(
            item['dtstart']['dt'],
          );
          if (startDate == null) continue;

          // Normalise to midnight. Schedule entries are keyed by a
          // date-only DateTime, so assessments must use the same key shape
          // or `_calendarData[selectedDay]` never finds them.
          final DateTime dueDay = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );

          var descriptionList = item['summary'].split(': ');
          String assignmentName =
              descriptionList[descriptionList.length - 1] ?? '';
          String className = getCourseName(
            item['summary'].substring(
              0,
              item['summary'].length - assignmentName.length,
            ),
          );

          Assessment assessment = Assessment(
            title: assignmentName,
            className: className,
            date: dueDay,
          );

          if (calendarData[dueDay] == null) {
            calendarData[dueDay] = CalendarItem(
              schedule: [],
              assessments: [assessment],
            );
          } else {
            calendarData[dueDay]!.assessments.add(assessment);
          }
        }
      }
    }
    super.storeData(calendarData);
    return calendarData;
  }
}

/// Parses a raw iCalendar DATE or DATE-TIME value into a [DateTime].
///
/// `icalendar_parser` hands back the raw ICS string, which can legally be any
/// of these:
///
/// * `20250315`          - DATE (all-day). This is how Blackbaud exports
///   assignments, so it is the common case.
/// * `20250315T093000Z`  - DATE-TIME in UTC
/// * `20250315T093000`   - DATE-TIME, floating/local
/// * `2025-03-15...`     - already normalised
///
/// `DateTime.parse` only accepts the last form. The first three used to throw
/// a FormatException, and because there was no try/catch that exception took
/// down the *entire* calendar fetch - not just the one event.
///
/// Returns null if the value cannot be understood, so callers can skip the
/// event instead of crashing.
DateTime? parseICalendarDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  // Already has separators - DateTime.parse can handle it.
  if (value.contains('-')) return DateTime.tryParse(value);

  // Basic format: YYYYMMDD with an optional THHMMSS and trailing Z.
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
  ).firstMatch(value);
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);

  // DATE (all-day) - no time component, so build a local midnight.
  if (match.group(4) == null) return DateTime(year, month, day);

  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final isUtc = match.group(7) == 'Z';

  return isUtc
      ? DateTime.utc(year, month, day, hour, minute, second)
      : DateTime(year, month, day, hour, minute, second);
}

String getCourseName(String name) {
  try {
    bool isAP = false;
    for (int i = 0; i < name.length - 1; i++) {
      if (name.substring(i, i + 2) == 'AP') {
        isAP = true;
      }
    }

    List<String> courseNames = name.split('-');
    if (isAP) {
      return courseNames[1].substring(1, courseNames[1].length);
    } else {
      return courseNames[0].substring(0, courseNames[0].length).split(',')[0];
    }
  } catch (e) {
    return '';
  }
}
