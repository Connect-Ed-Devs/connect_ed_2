import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart';

import 'feed_fetch.dart';

/// Why a candidate calendar link was accepted or rejected.
enum LinkCheckStatus {
  valid,

  /// No link was entered at all.
  empty,

  /// The text is not a usable absolute URL.
  malformed,

  /// The request never produced a response. In a browser this is almost always
  /// CORS; on native it is a connection problem.
  blocked,

  /// The server answered, but not with success.
  httpError,

  /// The server answered 200 with something that is not an iCalendar feed.
  notCalendar,
}

/// The outcome of validating a calendar link, with a message suitable for
/// showing to the user.
///
/// This exists because the old `checkLink` returned a bare `bool`: a typo, a
/// 403, an expired token and a browser CORS refusal all collapsed into the same
/// useless "Invalid Calendar Link", leaving no way to tell them apart.
class LinkCheckResult {
  const LinkCheckResult(this.status, this.message);

  final LinkCheckStatus status;
  final String message;

  bool get ok => status == LinkCheckStatus.valid;

  @override
  String toString() => 'LinkCheckResult(${status.name}: $message)';
}

/// Validates [url] and says *why* it failed.
///
/// [fetcher] and [isWeb] are injectable so the failure classification can be
/// exercised without a browser.
Future<LinkCheckResult> checkLinkDetailed(
  String url, {
  Future<http.Response> Function(String url)? fetcher,
  bool isWeb = kIsWeb,
}) async {
  final candidate = makeHTTPS(url.trim());
  if (candidate.isEmpty) {
    return const LinkCheckResult(
      LinkCheckStatus.empty,
      'Enter your school calendar link first.',
    );
  }

  final Uri? parsed = Uri.tryParse(candidate);
  if (parsed == null || !parsed.isAbsolute || parsed.host.isEmpty) {
    return const LinkCheckResult(
      LinkCheckStatus.malformed,
      "That isn't a web address. It should start with https:// and end in .ics",
    );
  }

  final http.Response response;
  try {
    response = await (fetcher ?? fetchFeed)(candidate);
  } catch (_) {
    // At this level a CORS refusal and a dead network look identical, but only
    // the browser enforces a same-origin policy and a school feed never opts in
    // to it, so on web that is overwhelmingly the real cause - and naming it
    // stops a correct link from being blamed for the browser's decision.
    if (isWeb) {
      return const LinkCheckResult(
        LinkCheckStatus.blocked,
        "Your browser blocked this feed (CORS). School feeds can't be read straight from a web page - use the phone app, or launch with the dev proxy.",
      );
    }
    return const LinkCheckResult(
      LinkCheckStatus.blocked,
      "Couldn't reach the calendar feed. Check your connection and try again.",
    );
  }

  if (response.statusCode != 200) {
    return LinkCheckResult(
      LinkCheckStatus.httpError,
      'The calendar server answered HTTP ${response.statusCode}. The link may have expired - copy a fresh one from your school portal.',
    );
  }

  try {
    final iCalendar = ICalendar.fromLines(response.body.split(RegExp(r'\r?\n')));
    if (iCalendar.toJson()['data'] == null) {
      return const LinkCheckResult(
        LinkCheckStatus.notCalendar,
        "That address loaded, but it isn't an iCalendar feed. Make sure you copied the calendar link, not the portal page.",
      );
    }
  } catch (_) {
    return const LinkCheckResult(
      LinkCheckStatus.notCalendar,
      "That address loaded, but it couldn't be read as an iCalendar feed.",
    );
  }

  return const LinkCheckResult(
    LinkCheckStatus.valid,
    'Calendar feed verified.',
  );
}

/// Boolean convenience wrapper, kept for callers that only care about yes/no.
Future<bool> checkLink(String url) async => (await checkLinkDetailed(url)).ok;

/// Rewrites a `webcal://` link (what school portals hand out) to `https://`.
String makeHTTPS(String url) {
  final trimmed = url.trim();
  if (trimmed.toLowerCase().contains('webcal')) {
    return trimmed.replaceFirst(
      RegExp('webcal', caseSensitive: false),
      'https',
    );
  }
  return trimmed;
}
