import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Base URL of the dev-only CORS proxy, for example
/// `http://127.0.0.1:8124/?url=`.
///
/// Supplied at build time with `--dart-define=FEED_PROXY=...`. It is empty in
/// normal builds, which makes every function here behave exactly as before.
const String feedProxyBase = String.fromEnvironment('FEED_PROXY');

/// The URL the app should actually GET in order to read [url].
///
/// School iCalendar feeds (Blackbaud / myschoolapp) are served without an
/// `Access-Control-Allow-Origin` header. Native builds don't care - there is no
/// same-origin policy outside the browser - but a *web* build gets nothing back
/// at all, however correct the URL is: the browser discards the response before
/// Dart ever sees it and reports a bare "Failed to fetch".
///
/// So on web, when a proxy has been configured, the real feed URL is handed to
/// the proxy as an encoded query parameter and the proxy adds the missing
/// header. The stored link stays the *real* school URL either way.
String resolveFeedUrl(
  String url, {
  bool isWeb = kIsWeb,
  String proxyBase = feedProxyBase,
}) {
  final trimmed = url.trim();
  if (isWeb && proxyBase.isNotEmpty) {
    return '$proxyBase${Uri.encodeComponent(trimmed)}';
  }
  return trimmed;
}

/// GETs [url], transparently routed through the dev proxy on web when one is
/// configured.
Future<http.Response> fetchFeed(String url) =>
    http.get(Uri.parse(resolveFeedUrl(url)));
