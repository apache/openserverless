import { fileURLToPath } from 'node:url';
import { existsSync, mkdirSync, writeFileSync, cpSync } from 'node:fs';
import path from 'node:path';

const files = fileURLToPath(new URL('./src', import.meta.url));

/**
 * @param {import('./index.js').AdapterOptions} [opts]
 * @returns {import('@sveltejs/kit').Adapter}
 */
export default function adapter(opts = {}) {
	const {
		out = 'build',
		entry = 'action.js',
		assets = 'client',
		precompress = false,
		emitManifest = true,
		packageName = 'web',
		actionName
	} = opts;

	return {
		name: 'svelte-adapter-openserverless',

		async adapt(builder) {
			const tmp = builder.getBuildDirectory('openserverless');
			builder.rimraf(out);
			builder.rimraf(tmp);
			builder.mkdirp(tmp);

			builder.log.minor('Copying assets...');
			builder.writeClient(path.join(out, assets));
			builder.writePrerendered(path.join(out, assets));

			if (precompress) {
				builder.log.minor('Compressing assets...');
				await builder.compress(path.join(out, assets));
			}

			builder.log.minor('Building server...');
			builder.writeServer(path.join(tmp, 'server'));

			// SvelteKit's generated server expects to sit next to the handler that
			// imports it, so we assemble the final layout in `out/`.
			mkdirSync(path.join(out, 'server'), { recursive: true });
			cpSync(path.join(tmp, 'server'), path.join(out, 'server'), { recursive: true });
			cpSync(files, path.join(out, 'src'), { recursive: true });

			writeFileSync(
				path.join(out, 'server', 'manifest.js'),
				`export const manifest = ${builder.generateManifest({ relativePath: '.' })};\n`
			);

			// Thin entry file: this is the `main` OpenServerless will call.
			writeFileSync(
				path.join(out, entry),
				`export { main } from './src/handler.js';\n`
			);

			// So Node treats the build output as ESM regardless of the user's
			// own package.json (OpenServerless's nodejs runtime honours this).
			writeFileSync(path.join(out, 'package.json'), JSON.stringify({ type: 'module' }, null, 2));

			if (emitManifest) {
				builder.log.minor('Writing ops action manifest...');
				writeOpsManifest({ out, entry, packageName, actionName: actionName ?? 'sveltekit-app' });
			}

			builder.log.success(
				`Built. Deploy with:\n  ops action update ${packageName}/${actionName ?? 'sveltekit-app'} ${out}/${entry} --kind nodejs:20 --web true --main main`
			);
		}
	};
}

/**
 * Emits a minimal `packages/<name>.yaml` action manifest, so the build
 * output can be picked up directly by `ops project deploy` with zero
 * additional configuration — matching how the Vercel/Netlify adapters
 * auto-wire their respective platform configs.
 */
function writeOpsManifest({ out, entry, packageName, actionName }) {
	const manifestDir = path.join(out, '..', 'packages');
	mkdirSync(manifestDir, { recursive: true });

	const manifestPath = path.join(manifestDir, `${packageName}.yaml`);
	const contents = `packages:
  ${packageName}:
    actions:
      ${actionName}:
        function: ${path.join(out, entry)}
        runtime: nodejs:20
        web: true
        main: main
        annotations:
          web-export: true
`;

	if (!existsSync(manifestPath)) {
		writeFileSync(manifestPath, contents);
	}
}
