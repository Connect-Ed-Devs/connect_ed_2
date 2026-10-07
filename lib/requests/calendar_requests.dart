import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:connect_ed_2/requests/feed_fetch.dart';
import 'package:connect_ed_2/requests/url_check.dart' as link_check;
import 'package:flutter/material.dart';
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

    // Normalise here as well as on save: a `webcal://` link would otherwise
    // reach dart:io as an unsupported scheme and fail with a confusing error.
    final String calendarLink = link_check.makeHTTPS(
      (prefs.getString('link') ?? '').trim(),
    );
    if (calendarLink.isEmpty) {
      throw Exception(
        'No calendar link configured. Add your school iCal URL in Settings.',
      );
    }

    // Goes through feed_fetch so a web build can use the dev CORS proxy;
    // native builds talk to the school directly.
    final response = await fetchFeed(calendarLink);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load calendar data (HTTP ${response.statusCode})',
      );
    }

    // Split tolerantly: real exports are CRLF, and leaving the \r on the end of
    // every line corrupts the last field of each one.
    final iCalendar = ICalendar.fromLines(response.body.split(RegExp(r'\r?\n')));
    var items = iCalendar.toJson()['data'];

    Map<DateTime, CalendarItem> calendarData = {};

    for (final item in items) {
      // Only DTSTART is mandatory. DTEND is optional in iCalendar and
      // single-day all-day events routinely omit it, so requiring both here
      // used to silently drop every assignment in feeds exported that way.
      if (item['dtstart'] != null) {
        final String startRaw = item['dtstart']['dt'] as String;
        final String? endRaw =
            item['dtend'] == null ? null : item['dtend']['dt'] as String;
        final String summary = decodeIcalText(
          (item['summary'] as String?) ?? '',
        );

        if (startRaw.length > 9) {
          final DateTime? startDate = parseICalendarDate(startRaw);
          if (startDate == null) continue;
          // No end supplied: assume a one-hour block so the class still
          // appears rather than vanishing from the schedule.
          final DateTime endDate =
              parseICalendarDate(endRaw ?? '') ??
              startDate.add(const Duration(hours: 1));
          DateTime date = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );
          // Podium exports no LOCATION property at all: the room is the
          // trailing parenthetical ("... - 01 (A-2)"). Take it off before the
          // course name is derived so it cannot leak into the title. Checked
          // against all 969 timed events of a real export - stripping it
          // changes no course name, while `location` was previously always
          // null.
          // Named `roomSuffix`, not `roomMatch`: the description branch below
          // already has a `roomMatch`, and shadowing it here would make the two
          // easy to confuse.
          final roomSuffix = RegExp(
            r'\s*\(([^()]*)\)\s*$',
          ).firstMatch(summary);
          final String room = (roomSuffix?.group(1) ?? '').trim();
          String courseName = getCourseName(
            roomSuffix == null
                ? summary
                : summary.substring(0, roomSuffix.start),
          );

          // Extract location from iCalendar data if available
          String? location = item['location'] as String?;
          String? instructor;

          // If location is still null, try alternative field names
          location ??= item['venue'] as String?;
          location ??= item['details'] as String?;

          // None of the above fire for this feed - there is no LOCATION field
          // and no description - so fall back to the room from the summary.
          if ((location == null || location.trim().isEmpty) &&
              room.isNotEmpty) {
            location = room;
          }

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
        } else if (startRaw.length >= 8) {
          final DateTime? startDate = parseICalendarDate(startRaw);
          if (startDate == null) continue;

          // Normalise to midnight. Schedule entries are keyed by a
          // date-only DateTime, so assessments must use the same key shape
          // or `_calendarData[selectedDay]` never finds them.
          final DateTime dueDay = DateTime(
            startDate.year,
            startDate.month,
            startDate.day,
          );

          // An all-day event is not automatically a piece of work. The same
          // Podium export carries the day rotation ("Day 1 (AC)"), school days
          // ("DEIB Day (AC)") and surveys ("Compass Survey (AC)") as all-day
          // events too. Counting those as assessments put 156 entries nobody
          // can complete on the Assignments tab of a real Appleby feed, against
          // 47 genuine ones. Real work always carries the "<course>: <task>"
          // shape, so that is what separates the two.
          if (!summary.contains(': ')) continue;

          final List<String> descriptionList = summary.split(': ');
          // Everything after the final ": " is the assignment itself; the
          // remainder is the course, which getCourseName trims up. Taking the
          // last segment is deliberate: course names carry their own colon
          // ("Canadian and World Issues: A Geographic Analysis, Grade 12 - ..."),
          // so splitting on the first one would cut the course in half.
          final String assignmentName = descriptionList.last.trim();
          // Rebuild the course from the same split rather than by subtracting
          // lengths: trimming the task name would otherwise leave its trailing
          // space on the end of the course.
          final String className = getCourseName(
            descriptionList.sublist(0, descriptionList.length - 1).join(': '),
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

/// Decodes the HTML character references this feed's exporter leaves in text.
///
/// Podium writes `&#233;` for "é" and `&#160;` for a padding non-breaking
/// space, so a real title arrived on screen as "Production Orale Unit&#233; 1"
/// and "Titration Lab&#160; [O/P]". Numeric references cover all of Unicode, so
/// they are decoded by code point; the handful of named entities that appear in
/// practice are mapped explicitly. Returns [value] untouched when it holds no
/// `&`, which is the common case.
String decodeIcalText(String value) {
  if (!value.contains('&')) return value;

  var out = value.replaceAllMapped(
    RegExp(r'&#(x?)([0-9a-fA-F]+);'),
    (match) {
      final isHex = match.group(1)!.isNotEmpty;
      final code = int.tryParse(match.group(2)!, radix: isHex ? 16 : 10);
      if (code == null || code < 0) return match.group(0)!;
      return String.fromCharCode(code);
    },
  );

  const named = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
  };
  named.forEach((entity, replacement) {
    out = out.replaceAll(entity, replacement);
  });

  // A non-breaking space is just padding in this feed, and it usually sits
  // right next to an ordinary space ("Titration Lab&#160; [O/P]"). Make it a
  // normal space and collapse the doubled-up result so titles read cleanly and
  // trim like ordinary text.
  return out.replaceAll('\u00a0', ' ').replaceAll(RegExp(r' {2,}'), ' ');
}

/// Best-effort extraction of a course name from an iCalendar SUMMARY.
///
/// Feed summaries look like `"English: Essay draft"` or
/// `"Math - D1: Problem set"`. The returned name is stripped of the trailing
/// `": "`, any teacher/section suffix after a `-`, and a trailing `", ..."`.
///
/// This never throws and never returns bare punctuation: an AP course with no
/// dash in its summary (for example `"AP Calculus: Quiz"`) used to index past
/// the end of the split, get swallowed by the catch, and surface as an empty
/// class name - which the UI then showed as "Unclassified".
String getCourseName(String name) {
  try {
    bool isAP = false;
    for (int i = 0; i < name.length - 1; i++) {
      if (name.substring(i, i + 2) == 'AP') {
        isAP = true;
      }
    }

    List<String> courseNames = name.split('-');
    // Keep the existing preference for the post-dash part of AP summaries,
    // but fall back to the whole string when there is no dash to split on.
    final String chosen =
        isAP && courseNames.length > 1 ? courseNames[1] : courseNames[0];

    var cleaned = chosen;
    final colon = cleaned.lastIndexOf(':');
    if (colon != -1) cleaned = cleaned.substring(0, colon);
    cleaned = cleaned.split(',').first;
    return cleaned.trim();
  } catch (e) {
    return '';
  }
}
