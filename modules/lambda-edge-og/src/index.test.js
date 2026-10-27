'use strict';

const assert = require('assert');
const { shouldRewriteToIndex } = require('./index.js');

// SPA client-side routes -> should rewrite to /index.html
assert.strictEqual(shouldRewriteToIndex('/'), true, 'root should rewrite');
assert.strictEqual(shouldRewriteToIndex('/settings'), true, 'SPA route should rewrite');
assert.strictEqual(shouldRewriteToIndex('/settings?tab=branches'.split('?')[0]), true, 'SPA route with query stripped should rewrite');
assert.strictEqual(shouldRewriteToIndex('/users/nested/route'), true, 'nested SPA route should rewrite');
assert.strictEqual(shouldRewriteToIndex('/index.html'), true, 'index.html itself should rewrite (no-op result, still correct)');

// Known static assets -> should NOT rewrite
assert.strictEqual(shouldRewriteToIndex('/favicon.ico'), false, 'favicon.ico should not rewrite');
assert.strictEqual(shouldRewriteToIndex('/sw.js'), false, 'sw.js should not rewrite');
assert.strictEqual(shouldRewriteToIndex('/assets/index-xk_J43li.js'), false, 'assets JS should not rewrite');
assert.strictEqual(shouldRewriteToIndex('/assets/vendor-redux-BtJTuzxE.js'), false, 'assets JS should not rewrite');
assert.strictEqual(shouldRewriteToIndex('/assets/index-BFBSAtVu.css'), false, 'assets CSS should not rewrite');
assert.strictEqual(shouldRewriteToIndex('/assets/nested/deep/file.png'), false, 'nested assets path should not rewrite');

// A missing /assets/* file still reports "don't rewrite" - the intentional
// accepted trade-off is that S3's real 403/404 surfaces raw for this case.
assert.strictEqual(shouldRewriteToIndex('/assets/does-not-exist.js'), false, 'missing assets file should still be treated as an asset path (raw S3 error is the accepted trade-off)');

console.log('All shouldRewriteToIndex tests passed.');
