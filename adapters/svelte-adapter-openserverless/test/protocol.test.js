import { test } from 'node:test';
import assert from 'node:assert/strict';

// These test the pure translation helpers in isolation. They're duplicated
// here (rather than imported) because src/handler.js imports the
// build-generated server, which only exists post-build; the maintainers may
// prefer we export `toRequest`/`toActivationResult` from a separate
// `protocol.js` module so they can be unit tested directly without a full
// SvelteKit build. Flagging this as a suggested refactor in the PR.

function guessBinary(contentType) {
	return !!contentType && /^(image|audio|video|font)\/|application\/(octet-stream|pdf|zip|wasm)/i.test(contentType);
}

test('guessBinary detects image content types', () => {
	assert.equal(guessBinary('image/png'), true);
	assert.equal(guessBinary('application/pdf'), true);
});

test('guessBinary treats text/json as non-binary', () => {
	assert.equal(guessBinary('application/json'), false);
	assert.equal(guessBinary('text/html; charset=utf-8'), false);
});

test('guessBinary handles missing content-type', () => {
	assert.equal(guessBinary(undefined), false);
	assert.equal(guessBinary(null), false);
});
