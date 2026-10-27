'use strict';

// Lambda@Edge viewer-request handler: serves OG/Twitter link-preview HTML to social
// crawler bots, and passes every real-user request through untouched.
// Node.js 20, CommonJS, no external dependencies (built-in https only).

const https = require('https');

// Known link-preview / crawler bots (case-insensitive).
const BOT_RE = /(facebookexternalhit|Facebot|Twitterbot|Slackbot|Slack-ImgProxy|WhatsApp|LinkedInBot|Discordbot|TelegramBot|Pinterest|redditbot|Applebot|SkypeUriPreview|vkShare|W3C_Validator|Googlebot|bingbot|embedly|Iframely|nuzzel|Google-InspectionTool)/i;

const STATIC_ASSET_EXACT = new Set(['/favicon.ico', '/sw.js']);
const STATIC_ASSET_PREFIX = '/assets/';

function shouldRewriteToIndex(uri) {
  if (STATIC_ASSET_EXACT.has(uri)) return false;
  if (uri.indexOf(STATIC_ASSET_PREFIX) === 0) return false;
  return true;
}

const API_HOST = 'api.example.com';
const API_PATH = '/api/v1/tenant/link-preview';
const FETCH_TIMEOUT_MS = 2000;

function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function fetchPreview(host) {
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        host: API_HOST,
        path: API_PATH,
        method: 'GET',
        headers: { 'x-forwarded-host': host, accept: 'application/json' },
        timeout: FETCH_TIMEOUT_MS,
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, body: data }));
      }
    );
    req.on('timeout', () => req.destroy(new Error('link-preview timeout')));
    req.on('error', reject);
    req.end();
  });
}

function htmlResponse(html) {
  return {
    status: '200',
    statusDescription: 'OK',
    headers: {
      'content-type': [{ key: 'Content-Type', value: 'text/html; charset=UTF-8' }],
      'cache-control': [{ key: 'Cache-Control', value: 'public, max-age=300' }],
    },
    body: html,
  };
}

function buildHtml({ title, description, imageUrl, url }) {
  const t = esc(title);
  const d = esc(description);
  const u = esc(url);
  const hasImage = Boolean(imageUrl);
  const imageTags = hasImage
    ? `<meta property="og:image" content="${esc(imageUrl)}"/>` +
      `<meta name="twitter:image" content="${esc(imageUrl)}"/>`
    : '';
  const card = hasImage ? 'summary_large_image' : 'summary';

  return (
    '<!doctype html><html><head><meta charset="utf-8"/>' +
    `<title>${t}</title>` +
    `<meta property="og:title" content="${t}"/>` +
    `<meta property="og:description" content="${d}"/>` +
    `<meta property="og:url" content="${u}"/>` +
    '<meta property="og:type" content="website"/>' +
    imageTags +
    `<meta name="twitter:card" content="${card}"/>` +
    `<meta name="twitter:title" content="${t}"/>` +
    `<meta name="twitter:description" content="${d}"/>` +
    '</head><body></body></html>'
  );
}

exports.handler = async (event) => {
  const request = event.Records[0].cf.request;

  try {
    const headers = request.headers || {};
    const host = headers.host && headers.host[0] ? headers.host[0].value : '';
    const ua =
      headers['user-agent'] && headers['user-agent'][0] ? headers['user-agent'][0].value : '';

    // Real users: rewrite SPA client-side routes to /index.html so S3 always
    // serves an existing object (never a 403/404 for a route it doesn't have
    // an object for). Known static assets pass through untouched.
    if (!BOT_RE.test(ua)) {
      try {
        if (shouldRewriteToIndex(request.uri)) {
          request.uri = '/index.html';
        }
      } catch (e) {
        // Fail open: never let a bug in the rewrite check break a real request.
      }
      return request;
    }

    // Generic SaaS fallback (case c).
    const fallback = {
      title: 'SaaS',
      description: 'SaaS — the multi-tenant platform.',
      imageUrl: null,
      url: `https://${host}/`,
    };

    let preview = fallback;
    try {
      const resp = await fetchPreview(host);
      if (resp.status === 200) {
        const json = JSON.parse(resp.body);
        // (a) imageUrl present  or  (b) imageUrl null -> buildHtml handles both.
        preview = {
          title: json.title || 'SaaS',
          description: json.description || '',
          imageUrl: json.imageUrl || null,
          url: json.url || `https://${host}/`,
        };
      }
      // non-200 -> keep the fallback (case c).
    } catch (e) {
      // fetch/parse/timeout error -> keep the fallback (case c).
    }

    return htmlResponse(buildHtml(preview));
  } catch (err) {
    // ANY unexpected error: never break the page for a real request.
    return request;
  }
};

exports.shouldRewriteToIndex = shouldRewriteToIndex;
