import { cp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const flutter = resolve(root, '..', 'build', 'web');
const dist = resolve(root, 'dist');

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });
await cp(flutter, dist, { recursive: true });

await build({
  entryPoints: [resolve(root, 'src', 'glue.js')],
  outfile: resolve(dist, 'ait_glue.js'),
  bundle: true,
  format: 'iife',
  platform: 'browser',
  target: ['es2022'],
  sourcemap: false,
});

await build({
  entryPoints: [resolve(root, 'src', 'origin-storage-migration.mjs')],
  outfile: resolve(dist, 'ait-storage-migration.js'),
  bundle: true,
  external: ['./flutter_bootstrap.js'],
  format: 'esm',
  platform: 'browser',
  target: ['es2022'],
  sourcemap: false,
});

const indexPath = resolve(dist, 'index.html');
const index = await readFile(indexPath, 'utf8');
const bootstrap = '<script src="flutter_bootstrap.js" async></script>';
if (!index.includes(bootstrap)) {
  throw new Error('Flutter bootstrap tag not found; refusing unordered migration injection');
}
await writeFile(
  indexPath,
  index.replace(bootstrap, '<script type="module" src="ait-storage-migration.js"></script>'),
  'utf8',
);
