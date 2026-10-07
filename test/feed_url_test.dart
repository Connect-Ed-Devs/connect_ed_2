// Covers the web-only rewrite of feed URLs.
//
// School iCal feeds are served without an Access-Control-Allow-Origin header,
// so a browser refuses to hand the response to Dart. On web with a proxy
// configured the real feed URL is handed to the proxy instead; everywhere else
// the school is called directly.
import 'package:connect_ed_2/requests/feed_fetch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const school =
      'https://appleby.myschoolapp.com/podium/feed/iCal.aspx?z=7&uid=42';
  const proxy = 'http://127.0.0.1:8124/?url=';

  test('with no proxy configured the URL is used untouched', () {
    // This is the release path: FEED_PROXY is empty unless it was passed with
    // --dart-define, so production behaviour is unchanged.
    expect(resolveFeedUrl(school), school);
  });

  test('surrounding whitespace from a paste is stripped', () {
    expect(resolveFeedUrl('  $school\n'), school);
  });

  test('on web with a proxy the URL is wrapped as an encoded parameter', () {
    final resolved = resolveFeedUrl(school, isWeb: true, proxyBase: proxy);

    // The proxy's own `?url=` must be the only unencoded query marker.
    expect(resolved, '$proxy${Uri.encodeComponent(school)}');
    expect(resolved, startsWith(proxy));
    expect(resolved, isNot(contains('appleby.myschoolapp.com/podium')));
  });

  test('native builds never use the proxy, even when one is configured', () {
    expect(resolveFeedUrl(school, isWeb: false, proxyBase: proxy), school);
  });
}
