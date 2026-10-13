import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/room_directory.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:intl/intl.dart';

/// Identifiers the native widgets are registered under. Part of the same wire
/// contract as the keys in [WidgetSnapshot.toMap]: they must match the
/// `android:name` in `AndroidManifest.xml`, the `kind` in
/// `ConnectEdWidget.swift`, and the app group enabled on both iOS targets.
const String widgetAndroidProvider =
    'com.example.connect_ed_2.ConnectEdWidgetProvider';
const String widgetIOSWidgetKind = 'ConnectEdWidget';
const String widgetAppGroupId = 'group.com.example.connectEd';

/// The handful of values the lock-screen and home-screen widgets show.
///
/// This is the wire format shared by three places that cannot import each other:
/// [WidgetBridge] publishes it, `android/.../ConnectEdWidgetProvider.kt` reads it
/// out of `HomeWidgetPreferences`, and `ios/ConnectEdWidget/ConnectEdWidget.swift`
/// reads it out of the `group.com.example.connectEd` app group. Changing a key
/// here without changing both native readers breaks the widget silently, which
/// is why [WidgetSnapshot.toMap] is pinned by a test.
///
/// Deliberately a plain value object built by a pure function: no widgets, no
/// plugin, nothing that needs a platform, so the "what will the widget say"
/// logic is unit-testable on any runner.
class WidgetSnapshot {
  /// False until the app has published anything at all - a fresh install, or a
  /// widget added before the app was ever opened. Readers show their own
  /// "open the app" state rather than inventing a class or a zero.
  final bool hasData;

  /// The next class, or a readable "nothing on" sentence. Never empty while
  /// [hasData] is true, so no reader has to invent a fallback.
  final String nextTitle;

  /// e.g. `1:30 PM – 2:45 PM`. Empty when there is no class.
  final String nextTime;

  /// Expanded through [roomDisplayName] so the widgets get the campus name once
  /// the school's code-to-building list is filled in. Empty when the feed
  /// carries no room, which the readers hide rather than render blank.
  final String nextRoom;

  /// Assessments due today.
  final int dueToday;

  /// The next thing due, when nothing is due today.
  final String dueNextTitle;

  /// `Today`, `Tomorrow` or `Mon 20 Oct`, matching the Assignments tab.
  final String dueNextWhen;

  const WidgetSnapshot({
    required this.hasData,
    required this.nextTitle,
    required this.nextTime,
    required this.nextRoom,
    required this.dueToday,
    required this.dueNextTitle,
    required this.dueNextWhen,
  });

  /// A snapshot for "we have never fetched anything".
  static const WidgetSnapshot empty = WidgetSnapshot(
    hasData: false,
    nextTitle: '',
    nextTime: '',
    nextRoom: '',
    dueToday: 0,
    dueNextTitle: '',
    dueNextWhen: '',
  );

  /// The exact keys the native readers use. Keep in step with
  /// `ConnectEdWidgetProvider.kt` and `ConnectEdWidget.swift`.
  Map<String, Object?> toMap() => {
    'has_data': hasData,
    'next_title': nextTitle,
    'next_time': nextTime,
    'next_room': nextRoom,
    'due_today': dueToday,
    'due_next_title': dueNextTitle,
    'due_next_when': dueNextWhen,
  };

  /// Builds the snapshot from the calendar cache.
  ///
  /// [now] is injectable because every branch reads the clock; without it the
  /// tests would only pass at the right time of day.
  static WidgetSnapshot build({
    required Map<DateTime, CalendarItem>? calendar,
    DateTime? now,
  }) {
    if (calendar == null || calendar.isEmpty) return empty;

    final at = now ?? DateTime.now();
    final today = DateTime(at.year, at.month, at.day);

    final upcoming = _nextClass(calendar, at, today);
    final due = _nextAssessment(calendar, today);

    return WidgetSnapshot(
      // We hold real cached data even if the next few days are empty, and the
      // readers should say "nothing on" rather than showing their install state.
      hasData: true,
      nextTitle: upcoming?.title.trim().isNotEmpty == true
          ? upcoming!.title.trim()
          : 'No classes coming up',
      nextTime: upcoming == null ? '' : _timeRange(upcoming),
      nextRoom: upcoming == null ? '' : roomDisplayName(upcoming.location),
      dueToday: calendar[today]?.assessments.length ?? 0,
      dueNextTitle: due?.assessment.title.trim() ?? '',
      dueNextWhen: due == null ? '' : _whenLabel(due.date, today),
    );
  }

  /// The next class, looking up to a week ahead.
  ///
  /// A class already under way does not count, matching the Home tab's "Up
  /// Next" card: it shows the *following* class rather than one halfway
  /// through. Days with no schedule are skipped, which is what makes a Monday
  /// widget useful on a Friday.
  static ScheduleItem? _nextClass(
    Map<DateTime, CalendarItem> calendar,
    DateTime at,
    DateTime today,
  ) {
    final nowMinutes = at.hour * 60 + at.minute;

    for (var offset = 0; offset < 7; offset++) {
      final day = today.add(Duration(days: offset));
      final schedule = calendar[day]?.schedule ?? const <ScheduleItem>[];
      if (schedule.isEmpty) continue;

      final sorted = [...schedule]
        ..sort(
          (a, b) =>
              (a.startTime.hour * 60 + a.startTime.minute).compareTo(
                b.startTime.hour * 60 + b.startTime.minute,
              ),
        );

      for (final item in sorted) {
        final start = item.startTime.hour * 60 + item.startTime.minute;
        if (offset > 0 || start > nowMinutes) return item;
      }
    }
    return null;
  }

  /// The next assessment due today or later, and the day it falls on.
  static _DueAssessment? _nextAssessment(
    Map<DateTime, CalendarItem> calendar,
    DateTime today,
  ) {
    // Bounded so a sparse cache cannot walk forever looking for work that is
    // not there; a term's worth of assignments is far inside this.
    for (var offset = 0; offset < 90; offset++) {
      final day = today.add(Duration(days: offset));
      final assessments = calendar[day]?.assessments ?? const <Assessment>[];
      if (assessments.isEmpty) continue;
      return _DueAssessment(assessments.first, day);
    }
    return null;
  }

  static String _timeRange(ScheduleItem item) {
    final format = DateFormat('h:mm a');
    final start = format.format(
      DateTime(2000, 1, 1, item.startTime.hour, item.startTime.minute),
    );
    final end = format.format(
      DateTime(2000, 1, 1, item.endTime.hour, item.endTime.minute),
    );
    return '$start – $end';
  }

  /// Same wording as the Assignments tab, so the two never disagree.
  static String _whenLabel(DateTime date, DateTime today) {
    final days = DateTime(date.year, date.month, date.day)
        .difference(today)
        .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return DateFormat('EEE d MMM').format(date);
  }
}

class _DueAssessment {
  final Assessment assessment;
  final DateTime date;
  const _DueAssessment(this.assessment, this.date);
}
