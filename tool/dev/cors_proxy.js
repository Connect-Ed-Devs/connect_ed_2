// Dev-only CORS shim for school iCalendar feeds.
//
// Why this exists
// ---------------
// A school feed (Blackbaud / myschoolapp) is served without an
// `Access-Control-Allow-Origin` header. That is fine for the iOS/Android app -
// there is no same-origin policy outside a browser - but a Flutter *web* build
// gets nothing back: the browser discards the response and Dart only sees a
// bare "Failed to fetch", however correct the URL is.
//
// This fetches the feed server-side and re-serves it with permissive CORS
// headers, so the web preview can exercise a real feed.
//
//   node tool/dev/cors_proxy.js [port]        # default 8124
//
// Then build the app with the matching proxy base:
//
//   flutter run -d web-server --web-port=8099 -t lib/dev/app_preview.dart \
//     --dart-define=FEED_PROXY=http://127.0.0.1:8124/?url=
//
// `tool/dev/run_web_preview.sh` does both. The app still stores your real
// school URL; only the web build rewrites it, and only while FEED_PROXY is set.

const http = require('http');
const https = require('https');
const { URL } = require('url');

const PORT = Number(process.argv[2] || 8124);

// Some portals serve a different page (or refuse) for unknown clients.
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

function allow(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
}

const server = http.createServer((req, res) => {
  allow(res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const target = new URL(req.url, `http://127.0.0.1:${PORT}`).searchParams.get(
    'url',
  );
  if (!target) {
    res.writeHead(400, { 'Content-Type': 'text/plain' });
    res.end('missing ?url=<encoded feed url>');
    return;
  }

  let targetUrl;
  try {
    targetUrl = new URL(target);
  } catch {
    res.writeHead(400, { 'Content-Type': 'text/plain' });
    res.end('url is not a valid absolute URL');
    return;
  }
  if (targetUrl.protocol !== 'https:' && targetUrl.protocol !== 'http:') {
    res.writeHead(400, { 'Content-Type': 'text/plain' });
    res.end(`unsupported scheme ${targetUrl.protocol}`);
    return;
  }

  const client = targetUrl.protocol === 'https:' ? https : http;
  const upstream = client.get(
    targetUrl,
    { headers: { 'User-Agent': UA, Accept: '*/*' } },
    (up) => {
      res.writeHead(up.statusCode || 502, {
        'Content-Type':
          up.headers['content-type'] || 'text/calendar; charset=utf-8',
      });
      up.pipe(res);
    },
  );

  upstream.on('error', (e) => {
    if (res.headersSent) {
      res.end();
      return;
    }
    res.writeHead(502, { 'Content-Type': 'text/plain' });
    res.end(`proxy could not reach the feed: ${e.message}`);
  });
  upstream.setTimeout(30000, () => upstream.destroy(new Error('upstream timeout')));
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`CORS proxy listening on http://127.0.0.1:${PORT}/?url=<encoded>`);
});
