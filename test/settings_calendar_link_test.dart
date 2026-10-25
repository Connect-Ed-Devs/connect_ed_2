import 'package:connect_ed_2/frontend/settings/settings.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/url_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A link that the checker accepted.
const _accepted = LinkCheckResult(
  LinkCheckStatus.valid,
  'Calendar feed verified.',
);

/// A link the checker rejected for a specific, user-visible reason.
LinkCheckResult _rejected(String message) =>
    LinkCheckResult(LinkCheckStatus.notCalendar, message);

/// Mounts Settings with a stubbed link checker so the save path can be
/// exercised without real network access.
Future<void> _pumpSettings(
  WidgetTester tester, {
  required Future<LinkCheckResult> Function(String url) checker,
}) async {
  await tester.pumpWidget(
    MaterialApp(home: SettingsPage(linkChecker: checker)),
  );
  await tester.pump();
}

Future<void> _typeAndSave(WidgetTester tester, String url) async {
  await tester.enterText(find.byType(TextFormField), url);
  await tester.pump();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('Save stays disabled until a link is entered', (tester) async {
    await _pumpSettings(tester, checker: (url) async => _accepted);

    expect(find.text('Calendar Link (iCal URL)'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextFormField), 'https://x/y.ics');
    await tester.pump();

    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('a verified link is saved under the key the calendar fetcher '
      'reads', (tester) async {
    await _pumpSettings(tester, checker: (url) async => _accepted);

    const url = 'https://example.com/feed.ics';
    await _typeAndSave(tester, url);

    // CalendarManager.fetchData reads prefs.getString('link'). Saving to
    // 'calendar_link' instead would silently leave the app on the old feed.
    expect(prefs.getString('link'), url);
    expect(prefs.getString('calendar_link'), isNull);
    expect(find.textContaining('verified and saved'), findsOneWidget);
  });

  testWidgets('a webcal link is stored as https', (tester) async {
    await _pumpSettings(tester, checker: (url) async => _accepted);

    await _typeAndSave(tester, 'webcal://example.com/feed.ics');

    expect(prefs.getString('link'), 'https://example.com/feed.ics');
  });

  testWidgets('surrounding whitespace from a paste is stripped before saving', (
    tester,
  ) async {
    await _pumpSettings(tester, checker: (url) async => _accepted);

    // Portals hand the link out as text, so a trailing newline or space is
    // easy to paste in and used to make a correct URL look broken.
    await _typeAndSave(tester, '  https://example.com/feed.ics\n');

    expect(prefs.getString('link'), 'https://example.com/feed.ics');
  });

  testWidgets('a rejected link reports the specific reason and saves nothing', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      checker: (url) async => _rejected('The calendar server answered HTTP 403.'),
    );

    await _typeAndSave(tester, 'https://example.com/not-a-feed');

    expect(prefs.getString('link'), isNull);
    expect(prefs.getString('calendar_link'), isNull);
    // The old build showed a generic "Invalid calendar link" for every
    // failure, which is why a correct URL was impossible to diagnose.
    expect(
      find.textContaining('The calendar server answered HTTP 403'),
      findsOneWidget,
    );
  });

  testWidgets('a checker failure is surfaced instead of being swallowed', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      checker: (url) async => throw const FormatException('boom'),
    );

    await _typeAndSave(tester, 'https://example.com/feed.ics');

    expect(prefs.getString('link'), isNull);
    expect(find.textContaining('An error occurred'), findsOneWidget);
  });
}
