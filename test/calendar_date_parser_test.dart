import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseICalendarDate', () {
    test('parses a bare iCalendar DATE (YYYYMMDD)', () {
      // This is how Blackbaud exports assignments (all-day events).
      // DateTime.parse throws on this format, which is the bug this
      // function exists to fix.
      expect(parseICalendarDate('20250315'), DateTime(2025, 3, 15));
    });

    test('parses a UTC DATE-TIME', () {
      final result = parseICalendarDate('20250315T093000Z');
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.year, 2025);
      expect(result.month, 3);
      expect(result.day, 15);
      expect(result.hour, 9);
      expect(result.minute, 30);
    });

    test('parses a floating (local) DATE-TIME', () {
      final result = parseICalendarDate('20250315T093000');
      expect(result, isNotNull);
      expect(result!.isUtc, isFalse);
      expect(result.hour, 9);
      expect(result.minute, 30);
    });

    test('parses an already-normalised ISO value', () {
      expect(parseICalendarDate('2025-03-15'), DateTime(2025, 3, 15));
      expect(
        parseICalendarDate('2025-03-15T09:30:00Z'),
        DateTime.utc(2025, 3, 15, 9, 30),
      );
    });

    test('returns null instead of throwing on junk input', () {
      // Must never throw -- an unparseable event used to take down the
      // entire calendar fetch.
      expect(parseICalendarDate(''), isNull);
      expect(parseICalendarDate('   '), isNull);
      expect(parseICalendarDate('garbage'), isNull);
      expect(parseICalendarDate('2025031'), isNull); // too short
      expect(parseICalendarDate('2025031A'), isNull); // non-numeric
    });

    test('trims surrounding whitespace', () {
      expect(parseICalendarDate('  20250315  '), DateTime(2025, 3, 15));
    });

    test('handles leap day and month boundaries', () {
      expect(parseICalendarDate('20240229'), DateTime(2024, 2, 29));
      expect(parseICalendarDate('20251231'), DateTime(2025, 12, 31));
      expect(parseICalendarDate('20250101'), DateTime(2025));
    });
  });
}
