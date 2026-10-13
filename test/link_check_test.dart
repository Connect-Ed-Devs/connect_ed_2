// Pins down *why* a calendar link is accepted or rejected.
//
// Before this the validator returned a bare bool, so a typo, an expired token,
// an HTTP 403 and a browser CORS refusal were indistinguishable - every one of
// them surfaced as "Invalid Calendar Link". These plain `test()` cases use real
// loopback sockets, which is why they cannot be widget tests.
import 'dart:io';

import 'package:connect_ed_2/requests/url_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

String _feed() => [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//Blackbaud//School//EN',
  'BEGIN:VEVENT',
  'UID:essay@school',
  'SUMMARY:English: Essay draft',
  'DTSTART;VALUE=DATE:20261015',
  'END:VEVENT',
  'END:VCALENDAR',
  '',
].join('\r\n');

Future<HttpServer> _serve({
  int status = 200,
  String? body,
  String contentType = 'text/calendar; charset=utf-8',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    request.response
      ..statusCode = status
      ..headers.set(HttpHeaders.contentTypeHeader, contentType)
      ..write(body ?? _feed());
    request.response.close();
  });
  return server;
}

/// A fetcher that behaves like a browser refusing a cross-origin request.
Future<http.Response> _blockedLikeABrowser(String url) async =>
    throw http.ClientException('Failed to fetch', Uri.parse(url));

void main() {
  test('an empty link is reported as empty, not as invalid', () async {
    final result = await checkLinkDetailed('   ');

    expect(result.ok, isFalse);
    expect(result.status, LinkCheckStatus.empty);
  });

  test('free text is reported as malformed', () async {
    final result = await checkLinkDetailed('my school calendar');

    expect(result.status, LinkCheckStatus.malformed);
  });

  test('a scheme with no host is reported as malformed', () async {
    final result = await checkLinkDetailed('https://');

    expect(result.status, LinkCheckStatus.malformed);
  });

  test('a real iCalendar feed validates', () async {
    final server = await _serve();
    addTearDown(() => server.close(force: true));

    final result = await checkLinkDetailed(
      'http://127.0.0.1:${server.port}/feed.ics',
    );

    expect(result.status, LinkCheckStatus.valid);
    expect(result.ok, isTrue);
  });

  test('a link pasted with trailing whitespace still validates', () async {
    final server = await _serve();
    addTearDown(() => server.close(force: true));

    final result = await checkLinkDetailed(
      '  http://127.0.0.1:${server.port}/feed.ics \n',
    );

    expect(result.status, LinkCheckStatus.valid);
  });

  test('a webcal link is requested as https, not rejected for its scheme', () async {
    String? requested;

    // Portals hand the feed out as webcal://, which no HTTP client understands.
    // Captured through an injected fetcher because the rewrite switches to TLS
    // and the loopback server below is plain HTTP.
    final result = await checkLinkDetailed(
      'webcal://example.com/feed.ics',
      fetcher: (url) async {
        requested = url;
        return http.Response(
          _feed(),
          200,
          headers: {'content-type': 'text/calendar; charset=utf-8'},
        );
      },
    );

    expect(requested, 'https://example.com/feed.ics');
    expect(result.status, LinkCheckStatus.valid);
  });

  test('a non-200 answer names the status code', () async {
    final server = await _serve(status: 403, body: 'Forbidden');
    addTearDown(() => server.close(force: true));

    final result = await checkLinkDetailed(
      'http://127.0.0.1:${server.port}/feed.ics',
    );

    expect(result.status, LinkCheckStatus.httpError);
    expect(result.message, contains('403'));
  });

  test('a 200 that is not a feed is reported as not a calendar', () async {
    final server = await _serve(
      body: '<html><body>Sign in to your school portal</body></html>',
      contentType: 'text/html; charset=utf-8',
    );
    addTearDown(() => server.close(force: true));

    final result = await checkLinkDetailed(
      'http://127.0.0.1:${server.port}/login',
    );

    expect(result.status, LinkCheckStatus.notCalendar);
  });

  test('on web a refused request is blamed on the browser, not the link', () async {
    final result = await checkLinkDetailed(
      'https://appleby.myschoolapp.com/podium/feed/iCal.aspx?z=7',
      fetcher: _blockedLikeABrowser,
      isWeb: true,
    );

    expect(result.status, LinkCheckStatus.blocked);
    expect(result.message.toLowerCase(), contains('browser'));
    expect(result.message, contains('CORS'));
  });

  test('on native the same refusal is reported as a connection problem', () async {
    final result = await checkLinkDetailed(
      'https://appleby.myschoolapp.com/podium/feed/iCal.aspx?z=7',
      fetcher: _blockedLikeABrowser,
      isWeb: false,
    );

    expect(result.status, LinkCheckStatus.blocked);
    expect(result.message.toLowerCase(), isNot(contains('browser')));
    expect(result.message.toLowerCase(), contains('connection'));
  });
}
