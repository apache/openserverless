import type { Adapter } from '@sveltejs/kit';

export interface AdapterOptions {
	/** Output directory for the built action. Defaults to `build`. */
	out?: string;
	/**
	 * Name of the entry file OpenServerless will invoke as the action's
	 * `main`. Defaults to `action.js`.
	 */
	entry?: string;
	/** Directory (relative to `out`) where static assets are copied. Defaults to `client`. */
	assets?: string;
	/**
	 * Precompress static assets with gzip/brotli, same behavior as adapter-node.
	 */
	precompress?: boolean;
	/**
	 * Emit an `ops` package/action manifest (`packages/<name>.yaml`) alongside the build,
	 * so `ops project deploy` can pick it up with no extra configuration.
	 */
	emitManifest?: boolean;
	/** Name of the OpenServerless package the action should be deployed under. Defaults to `web`. */
	packageName?: string;
	/** Name of the action itself. Defaults to the SvelteKit project name or `sveltekit-app`. */
	actionName?: string;
}

export default function plugin(options?: AdapterOptions): Adapter;
