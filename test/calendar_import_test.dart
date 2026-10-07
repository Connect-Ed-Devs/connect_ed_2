// Exercises the real iCalendar import path (CalendarManager.fetchData) against
// feeds served over loopback HTTP, so parsing behaviour is pinned down rather
// than assumed.
//
// These are plain `test()` cases: widget tests run inside a fake-async zone
// where real socket I/O never completes, which is why the widget-binding HTTP
// mock is irrelevant here.
import 'dart:io';

import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _feed(List<String> events, {String eol = '\r\n'}) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Blackbaud//School//EN',
    ...events,
    'END:VCALENDAR',
    '',
  ];
  return lines.join(eol);
}

/// An all-day assignment the way Blackbaud exports it, using a VALUE=DATE
/// parameter rather than a bare date.
List<String> get _allDayEventParam => [
  'BEGIN:VEVENT',
  'UID:all-day-param@school',
  'SUMMARY:English: Essay draft',
  'DTSTART;VALUE=DATE:20261015',
  'DTEND;VALUE=DATE:20261016',
  'END:VEVENT',
];

/// The same event with bare DATE values (no parameters).
List<String> get _allDayEventBare => [
  'BEGIN:VEVENT',
  'UID:all-day-bare@school',
  'SUMMARY:English: Essay draft',
  'DTSTART:20261015',
  'DTEND:20261016',
  'END:VEVENT',
];

/// A timed class block.
List<String> get _timedEvent => [
  'BEGIN:VEVENT',
  'UID:timed@school',
  'SUMMARY:Math - D1',
  'DTSTART:20261015T093000',
  'DTEND:20261015T104500',
  'LOCATION:Room 204',
  'END:VEVENT',
];

/// An all-day event with no DTEND, which is legal iCalendar for a single day.
List<String> get _allDayNoDtend => [
  'BEGIN:VEVENT',
  'UID:no-dtend@school',
  'SUMMARY:History: Read chapter 4',
  'DTSTART;VALUE=DATE:20261018',
  'END:VEVENT',
];

/// An all-day assignment with no DTEND, which is legal iCalendar.
List<String> _event(String uid, String summary, String date) => [
  'BEGIN:VEVENT',
  'UID:$uid@school',
  'SUMMARY:$summary',
  'DTSTART;VALUE=DATE:$date',
  'END:VEVENT',
];

Future<HttpServer> _serve(
  String body, {
  String contentType = 'text/calendar; charset=utf-8',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    request.response
      ..statusCode = 200
      ..headers.set(HttpHeaders.contentTypeHeader, contentType)
      ..write(body);
    request.response.close();
  });
  return server;
}

Future<void> _pointAt(HttpServer server) async {
  await prefs.setString('link', 'http://127.0.0.1:${server.port}/feed.ics');
}

/// `calendarManager` is declared as the `CacheManager` base type, so its
/// `fetchData()` is `Future<dynamic>`; cast once here to keep the assertions
/// type-checked.
Future<Map<DateTime, CalendarItem>> _import() async =>
    await calendarManager.fetchData() as Map<DateTime, CalendarItem>;

void main() {
  setUp(() async {
    // Plain tests: no test binding, so real sockets are allowed.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    calendarManager.clearCache();
  });

  test('imports an all-day assignment (DTSTART;VALUE=DATE) over CRLF', () async {
    final server = await _serve(_feed([..._allDayEventParam]));
    addTearDown(() => server.close(force: true));
    await _pointAt(server);

    final data = await _import();

    final assessments = data.values.expand((item) => item.assessments).toList();
    // ignore: avoid_print
    print('CRLF+VALUE=DATE -> days=${data.length} assessments=${assessments
        .map((a) => '${a.title}|${a.className}|${a.date}')
        .toList()}');
    expect(assessments, isNotEmpty, reason: 'all-day assignment was skipped');
  });

  test('imports an all-day assignment with bare DATE values', () async {
    final server = await _serve(_feed([..._allDayEventBare]));
    addTearDown(() => server.close(force: true));
    await _pointAt(server);

    final data = await _import();

    final assessments = data.values.expand((item) => item.assessments).toList();
    // ignore: avoid_print
    print('CRLF+bare DATE -> days=${data.length} assessments=${assessments
        .map((a) => '${a.title}|${a.className}|${a.date}')
        .toList()}');
    expect(assessments, isNotEmpty, reason: 'all-day assignment was skipped');
  });

  test('imports a timed class block into the schedule', () async {
    final server = await _serve(_feed([..._timedEvent]));
    addTearDown(() => server.close(force: true));
    await _pointAt(server);

    final data = await _import();

    final schedule = data.values.expand((item) => item.schedule).toList();
    // ignore: avoid_print
    print('CRLF+timed -> days=${data.length} schedule=${schedule
        .map((s) => '${s.title}|${s.startTime}|${s.endTime}')
        .toList()}');
    expect(schedule, isNotEmpty, reason: 'timed class was skipped');
  });

  test('an all-day event without DTEND is not dropped', () async {
    final server = await _serve(_feed([..._allDayNoDtend]));
    addTearDown(() => server.close(force: true));
    await _pointAt(server);

    final data = await _import();

    final assessments = data.values.expand((item) => item.assessments).toList();
    // ignore: avoid_print
    print('no DTEND -> days=${data.length} assessments=$assessments');
    expect(
      assessments,
      isNotEmpty,
      reason: 'DTEND is optional in iCalendar; a single-day event has no DTEND',
    );
  });

  test('imports the same feed with LF line endings', () async {
    final server = await _serve(_feed([..._allDayEventParam], eol: '\n'));
    addTearDown(() => server.close(force: true));
    await _pointAt(server);

    final data = await _import();

    final assessments = data.values.expand((item) => item.assessments).toList();
    // ignore: avoid_print
    print('LF -> days=${data.length} assessments=${assessments
        .map((a) => '${a.title}|${a.className}|${a.date}')
        .toList()}');
    expect(assessments, isNotEmpty);
  });

  test('preserves non-ASCII titles when the server omits a charset', () async {
    final server = await _serve(
      _feed([
        'BEGIN:VEVENT',
        'UID:unicode@school',
        'SUMMARY:Français: Révision écrite',
        'DTSTART:20261015',
        'DTEND:20261016',
        'END:VEVENT',
      ]),
      // No charset parameter: http defaults to latin1 when decoding .body.
      contentType: 'text/calendar',
    );
    addTearDown(() => server.close(force: true));
    await _pointAt(server);

    final data = await _import();

    final titles = data.values
        .expand((item) => item.assessments)
        .map((a) => a.title)
        .toList();
    // ignore: avoid_print
    print('no-charset titles=$titles');
    expect(titles.join(), contains('Révision'));
  });

  test('extracts clean class names from real summary shapes', () async {
    final server = await _serve(
      _feed([
        ..._event('a', 'English: Essay draft', '20261015'),
        ..._event('b', 'AP Calculus: Trig quiz', '20261016'),
        ..._event('c', 'Math - D1: Problem set', '20261017'),
      ]),
    );
    addTearDown(() => server.close(force: true));
    await _pointAt(server);

    final data = await _import();
    final classNameByTitle = {
      for (final a in data.values.expand((item) => item.assessments))
        a.title: a.className,
    };
    // ignore: avoid_print
    print('classNames=$classNameByTitle');

    expect(classNameByTitle['Essay draft'], 'English');
    // An AP summary with no dash used to return an empty class name.
    expect(classNameByTitle['Trig quiz'], 'AP Calculus');
    expect(classNameByTitle['Problem set'], 'Math');
  });

  group('HTML references left in the feed text', () {
    test('a numeric character reference is decoded into a real letter', () async {
      // Straight off the Appleby feed, where "Unité" arrives as "Unit&#233;".
      final server = await _serve(
        _feed([
          ..._event(
            'enc1',
            'Extended French, Grade 12 - AP French Language and Culture - 01: '
                'Production Orale Unit&#233; 1',
            '20261015',
          ),
        ]),
      );
      addTearDown(() => server.close(force: true));
      await _pointAt(server);

      final data = await _import();

      final assessments = data.values
          .expand((item) => item.assessments)
          .toList();
      // ignore: avoid_print
      print('entities -> ${assessments.map((a) => a.title).toList()}');
      expect(assessments.single.title, 'Production Orale Unité 1');
    });

    test('the exporter padding space is normalised away', () async {
      final server = await _serve(
        _feed([
          ..._event(
            'enc2',
            'Chemistry, Grade 11 - 03: Titration Lab&#160; [O/P]',
            '20261016',
          ),
          ..._event(
            'enc3',
            'Mathematics: Graphs &amp; tables',
            '20261017',
          ),
        ]),
      );
      addTearDown(() => server.close(force: true));
      await _pointAt(server);

      final data = await _import();

      final byTitle = {
        for (final a in data.values.expand((item) => item.assessments))
          a.title: a.className,
      };
      // ignore: avoid_print
      print('padding/named -> $byTitle');

      // &#160; sat between the title and " [O/P]" and must not leave a gap.
      expect(byTitle.containsKey('Titration Lab [O/P]'), isTrue);
      expect(byTitle['Titration Lab [O/P]'], 'Chemistry');
      expect(byTitle.containsKey('Graphs & tables'), isTrue);
    });
  });

  group('room from the summary parenthetical', () {
    test('a trailing parenthetical becomes the location', () async {
      // The feed has no LOCATION property; "(A-1)" is the only room data in it.
      final server = await _serve(
        _feed([
          'BEGIN:VEVENT',
          'UID:room1@school',
          'SUMMARY:Physics, Grade 11 - AP Physics 1 - 02 (A-1)',
          'DTSTART:20261015T093000',
          'DTEND:20261015T104500',
          'END:VEVENT',
        ]),
      );
      addTearDown(() => server.close(force: true));
      await _pointAt(server);

      final data = await _import();
      final schedule = data.values.expand((item) => item.schedule).toList();
      // ignore: avoid_print
      print('room -> ${schedule.map((s) => '${s.title}|${s.location}')}');

      expect(schedule.single.location, 'A-1');
      // The room must not survive in the course name.
      expect(schedule.single.title, 'AP Physics 1');
    });

    test('an explicit LOCATION field still wins over the parenthetical', () async {
      final server = await _serve(
        _feed([
          'BEGIN:VEVENT',
          'UID:room2@school',
          'SUMMARY:Chemistry, Grade 11 - 03 (D-2)',
          'DTSTART:20261015T093000',
          'DTEND:20261015T104500',
          'LOCATION:Science Wing Lab',
          'END:VEVENT',
        ]),
      );
      addTearDown(() => server.close(force: true));
      await _pointAt(server);

      final data = await _import();
      final schedule = data.values.expand((item) => item.schedule).toList();

      expect(schedule.single.location, 'Science Wing Lab');
      expect(schedule.single.title, 'Chemistry');
    });

    test('a block with no room anywhere leaves the location empty', () async {
      final server = await _serve(
        _feed([
          'BEGIN:VEVENT',
          'UID:room3@school',
          'SUMMARY:Math - D1',
          'DTSTART:20261015T093000',
          'DTEND:20261015T104500',
          'END:VEVENT',
        ]),
      );
      addTearDown(() => server.close(force: true));
      await _pointAt(server);

      final data = await _import();
      final schedule = data.values.expand((item) => item.schedule).toList();

      expect(schedule.single.location, isNull);
      expect(schedule.single.title, 'Math');
    });
  });

  group('all-day events that are not work', () {
    test('a day-rotation or survey marker is not an assignment', () async {
      // Taken from a real Appleby (Podium) export, where these outnumber the
      // genuine assignments roughly three to one.
      final server = await _serve(
        _feed([
          ..._event('d1', 'Day 1 (AC)', '20261015'),
          ..._event('d2', 'Day 2 (AC)', '20261016'),
          ..._event('s1', 'Compass Survey (AC)', '20261017'),
          ..._event('s2', 'DEIB Day (AC)', '20261018'),
          ..._event('s3', 'Walkathon (AC)', '20261019'),
        ]),
      );
      addTearDown(() => server.close(force: true));
      await _pointAt(server);

      final data = await _import();

      final titles = data.values
          .expand((item) => item.assessments)
          .map((a) => a.title)
          .toList();
      // ignore: avoid_print
      print('markers only -> assessments=$titles');
      expect(
        titles,
        isEmpty,
        reason:
            'the day rotation and school surveys are all-day events but not '
            'work, and must not reach the assignments view',
      );
    });

    test('the real assignments beside those markers still import', () async {
      final server = await _serve(
        _feed([
          ..._event('d1', 'Day 1 (AC)', '20261015'),
          ..._event(
            'a1',
            'Advanced Functions, Grade 12 - 03: Unit 1 Test (product)',
            '20261015',
          ),
          ..._event('s1', 'DEIB Day (AC)', '20261016'),
          ..._event(
            'a2',
            'Chemistry, Grade 11 - 03: Unit 4: Gases Quiz [P]',
            '20261016',
          ),
        ]),
      );
      addTearDown(() => server.close(force: true));
      await _pointAt(server);

      final data = await _import();

      final classNameByTitle = {
        for (final a in data.values.expand((item) => item.assessments))
          a.title: a.className,
      };
      // ignore: avoid_print
      print('mixed feed -> $classNameByTitle');

      expect(classNameByTitle, hasLength(2));
      expect(classNameByTitle['Unit 1 Test (product)'], 'Advanced Functions');
      // Pinned as-is: the title is everything after the *final* ": ", so the
      // "Unit 4:" prefix is dropped. Splitting on the first ": " instead would
      // fix this one and break every course whose own name has a colon.
      expect(classNameByTitle['Gases Quiz [P]'], 'Chemistry');
    });
  });

  test('a feed without a calendar link fails loudly', () async {
    await prefs.remove('link');

    await expectLater(
      calendarManager.fetchData(),
      throwsA(isA<Exception>()),
      reason:
          'with no link configured the failure should be a clear Exception, '
          'not an ArgumentError from deep inside dart:io',
    );
  });
}
