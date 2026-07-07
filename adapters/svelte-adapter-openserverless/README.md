# svelte-adapter-openserverless

A [SvelteKit](https://svelte.dev/docs/kit) adapter that builds your app as an
**Apache OpenServerless** web action, so it can be deployed to OpenServerless
the same way you'd deploy to Vercel or Netlify.

## Usage

Install:

```bash
npm i -D svelte-adapter-openserverless
```

`svelte.config.js`:

```js
import adapter from 'svelte-adapter-openserverless';

export default {
	kit: {
		adapter: adapter({
			// all options are optional, these are the defaults
			out: 'build',
			entry: 'action.js',
			assets: 'client',
			precompress: false,
			emitManifest: true,
			packageName: 'web',
			actionName: 'sveltekit-app'
		})
	}
};
```

Build:

```bash
npm run build
```

This produces:
build/
action.js        # the OpenServerless action entrypoint (exports main)
package.json      # { "type": "module" }
server/           # SvelteKit's generated server + manifest
src/handler.js     # protocol bridge (web action <-> Request/Response)
client/           # static assets
packages/
web.yaml          # ops action manifest (deploy config)

## Deploying

With the `ops` CLI:

```bash
ops action update web/sveltekit-app build/action.js \
  --kind nodejs:20 --web true --main main
```

Or, if `emitManifest` is enabled (default), simply:

```bash
ops project deploy
```

Static assets under `build/client` should be uploaded to the OpenServerless
web bucket (`ops project deploy` does this automatically); alternatively
serve them from any CDN and point SvelteKit's `paths.assets` config at it.

## How it works

OpenServerless (built on Apache OpenWhisk) invokes a **web action** with a
params object containing `__ow_method`, `__ow_headers`, `__ow_path`,
`__ow_query`, and `__ow_body`, and expects the action to return
`{ statusCode, headers, body }`. `src/handler.js` translates that shape
into a Web standard `Request`, passes it to SvelteKit's platform-agnostic
`Server`, and converts the resulting `Response` back into the shape
OpenServerless expects (base64-encoding binary bodies as needed).

This mirrors the approach of `@sveltejs/adapter-node`, replacing the Node
HTTP server with the OpenWhisk web-action protocol.

## Limitations / open questions for review

- Binary detection for request/response bodies currently relies on the
  `Content-Type` header. If OpenServerless's runtime exposes an explicit
  `__ow_isBase64Encoded`-style flag on inbound params, we should prefer it
  over guessing.
- Static asset upload/hosting is left to `ops project deploy`; this PR does
  not change the CLI. A follow-up could teach `ops` to serve `build/client`
  directly from the action's package for smaller projects.
- Only tested against `nodejs:20`; should be validated against the other
  supported Node runtime versions.
