import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, basename } from 'node:path';
import { R2Store } from './r2.mjs';
import { sha256, validateCatalog } from './content-lib.mjs';
try {
  const catalog = JSON.parse(await readFile(process.env.CONTENT_SOURCE ?? 'content/catalog.json', 'utf8'));
  await validateCatalog(catalog);
  if (catalog.isFixture) throw new Error('Cannot stage a fixture publication');
  const output = resolve(process.env.CONTENT_MEDIA_DIR ?? 'build/approved-media');
  await mkdir(output, { recursive: true });
  const store = new R2Store();
  const assets = new Map(catalog.items.filter(x => x.audio).map(x => [x.audio.sha256, x.audio]));
  for (const asset of assets.values()) {
    if (asset.url !== `media/${asset.sha256}.m4a`) throw new Error('Staging accepts only immutable checksum keys');
    const response = await store.request('GET', asset.url);
    if (!response.ok) throw new Error(`Staging read failed (${response.status})`);
    const bytes = Buffer.from(await response.arrayBuffer());
    if (bytes.length !== asset.bytes || sha256(bytes) !== asset.sha256) throw new Error('Staging media integrity failure');
    await writeFile(resolve(output, basename(asset.url)), bytes);
  }
  console.log(`Retrieved ${assets.size} verified assets from private staging.`);
} catch (error) { console.error(error.message); process.exitCode = 1; }
