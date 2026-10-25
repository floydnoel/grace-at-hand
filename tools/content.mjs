import { readFile, writeFile, mkdir, copyFile, readdir, rm } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve, basename, extname, join, sep } from 'node:path';
import { createServer } from 'node:http';
import { validateCatalog, publishCatalog, rollbackCatalog, sha256 } from './content-lib.mjs';
import { R2Store } from './r2.mjs';
const root = fileURLToPath(new URL('../', import.meta.url));
const args = process.argv.slice(2);
const command = args[0] ?? 'validate';
const option = (name, fallback) => args.includes(name) ? args[args.indexOf(name) + 1] : fallback;
try {
  if (command === 'health') {
    const base = process.env.CONTENT_BASE_URL;
    if (!base) throw new Error('Configure CONTENT_BASE_URL');
    const pointerResponse = await fetch(new URL('latest.json', base), { signal: AbortSignal.timeout(20_000) });
    if (!pointerResponse.ok) throw new Error('Catalog pointer unavailable');
    const pointer = await pointerResponse.json();
    const response = await fetch(pointer.catalogURL, { signal: AbortSignal.timeout(20_000) });
    const bytes = Buffer.from(await response.arrayBuffer());
    if (!response.ok || sha256(bytes) !== pointer.sha256) throw new Error('Catalog verification failed');
    const catalog = JSON.parse(bytes);
    await validateCatalog(catalog);
    for (const item of catalog.items.filter(i => i.audio)) {
      const response = await fetch(new URL(item.audio.url, base), { headers: { Range: 'bytes=0-31' }, signal: AbortSignal.timeout(20_000) });
      if (response.status !== 206) throw new Error(`Media range request failed: ${item.id}`);
      await response.body.cancel();
    }
    console.log('Catalog and media range requests are healthy.');
  } else if (command === 'rollback') {
    const store = new R2Store();
    const pointer = JSON.parse(await readFile(option('--pointer', ''), 'utf8'));
    const result = await rollbackCatalog({ store, pointer, baseURL: store.baseURL });
    console.log(`Rolled back with generation ${result.generation}`);
  } else {
    const source = resolve(root, option('--source', process.env.CONTENT_SOURCE ?? 'content/fixtures/catalog.json'));
    const mediaDir = resolve(root, option('--media-dir', process.env.CONTENT_MEDIA_DIR ?? 'content/fixtures/media'));
    const catalog = JSON.parse(await readFile(source, 'utf8'));
    const production = args.includes('--production') || command === 'publish';
    let reviews = [];
    if (production) {
      const path = resolve(root, option('--reviews', 'content/reviews'));
      for (const name of await readdir(path)) if (name.endsWith('.json')) reviews.push(...JSON.parse(await readFile(join(path, name), 'utf8')));
    }
    await validateCatalog(catalog, { production, reviews, mediaDir });
    if (command === 'validate') console.log(`Validated ${catalog.items.length} prayers and ${catalog.passages.length} daily passages${catalog.isFixture ? ' (development fixtures)' : ''}.`);
    else if (command === 'bundle') {
      const destination = join(root, 'ios/App/Resources');
      await rm(join(destination, 'Media'), { recursive: true, force: true });
      await mkdir(join(destination, 'Media'), { recursive: true });
      await writeFile(join(destination, 'catalog.json'), JSON.stringify(catalog));
      for (const item of catalog.items) if (item.audio?.url.startsWith('bundle:')) {
        const name = basename(item.audio.url.slice(7));
        await copyFile(join(mediaDir, name), join(destination, 'Media', name));
      }
      console.log(`Bundled the offline text library${catalog.isFixture ? ' (development fixtures)' : ''}.`);
    } else if (command === 'preview') {
      const output = resolve(root, 'build/preview');
      await mkdir(join(output, 'media'), { recursive: true });
      for (const item of catalog.items) if (item.audio) {
        const name = basename(item.audio.url.replace(/^bundle:/, ''));
        await copyFile(join(mediaDir, name), join(output, 'media', `${item.audio.sha256}.m4a`));
        item.audio.url = `media/${item.audio.sha256}.m4a`;
      }
      const bytes = Buffer.from(JSON.stringify(catalog));
      await writeFile(join(output, 'catalog.json'), bytes);
      await writeFile(join(output, 'latest.json'), JSON.stringify({ schemaVersion: 1, generation: Date.now(), catalogURL: 'catalog.json', sha256: sha256(bytes) }));
      createServer(async (req, res) => {
        try {
          const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
          const file = resolve(output, '.' + pathname);
          if (!file.startsWith(output + sep)) { res.writeHead(403).end(); return; }
          const data = await readFile(file);
          const mime = extname(file) === '.m4a' ? 'audio/mp4' : 'application/json';
          const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range ?? '');
          if (range) {
            const start = +range[1], end = Math.min(range[2] ? +range[2] : data.length - 1, data.length - 1);
            if (start > end || start >= data.length) { res.writeHead(416).end(); return; }
            res.writeHead(206, { 'Content-Type': mime, 'Accept-Ranges': 'bytes', 'Content-Range': `bytes ${start}-${end}/${data.length}`, 'Content-Length': end-start+1 });
            res.end(data.subarray(start, end + 1));
          } else { res.writeHead(200, { 'Content-Type': mime, 'Content-Length': data.length, 'Accept-Ranges': 'bytes', 'Cache-Control': 'no-store' }); res.end(data); }
        } catch { res.writeHead(404).end(); }
      }).listen(8787, '127.0.0.1', () => console.log('Preview: http://127.0.0.1:8787/latest.json'));
    } else if (command === 'publish') {
      const store = new R2Store();
      const pointer = await publishCatalog({ catalog, store, mediaDir, baseURL: store.baseURL });
      console.log(`Published generation ${pointer.generation}`);
    } else throw new Error('Commands: validate, bundle, preview, publish, rollback, health');
  }
} catch (error) { console.error(error.message); process.exitCode = 1; }
