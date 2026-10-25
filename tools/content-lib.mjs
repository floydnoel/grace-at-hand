import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { join, basename } from 'node:path';
import { execFileSync } from 'node:child_process';
import { loadSchema, validateSchema } from './schema.mjs';
export const sha256 = data => createHash('sha256').update(data).digest('hex');
export const validDay = d => typeof d === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d) && Number.isFinite(Date.parse(`${d}T12:00:00Z`)) && new Date(`${d}T12:00:00Z`).toISOString().slice(0, 10) === d;
function requireThat(condition, message) { if (!condition) throw new Error(message); }
export async function validateCatalog(catalog, { production = false, reviews = [], today = new Date().toISOString().slice(0, 10), mediaDir } = {}) {
  validateSchema(catalog, await loadSchema());
  requireThat(!production || !catalog.isFixture, 'Development fixtures cannot be published to production');
  requireThat(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/.test(catalog.publishedAt) && validDay(catalog.publishedAt.slice(0,10)) && Number.isFinite(Date.parse(catalog.publishedAt)), 'Publication timestamp must be UTC');
  const ids = new Set(catalog.items.map(x => x.id));
  requireThat(ids.size === catalog.items.length, 'Duplicate content IDs');
  for (const group of [catalog.collections, catalog.journeys, catalog.passages]) requireThat(new Set(group.map(x => x.id)).size === group.length, 'Duplicate identifiers');
  for (const group of [catalog.passages, catalog.calendar]) {
    requireThat(new Set(group.map(x => x.date)).size === group.length, 'Duplicate dates');
    requireThat(group.every(x => validDay(x.date)), 'Invalid local date');
  }
  requireThat(catalog.calendar.every(x => x.id === `calendar:${x.date}`), 'Calendar ID must match its local date');
  requireThat(catalog.withdrawnIDs.every(id => !ids.has(id)), 'Withdrawn content is still published');
  for (const group of [...catalog.collections, ...catalog.journeys]) requireThat(group.itemIDs.every(id => ids.has(id)), `Broken reference in ${group.id}`);
  for (const journey of catalog.journeys) requireThat(journey.itemIDs.length === 7, 'Beginner path must have seven sessions');
  for (const passage of catalog.passages) {
    requireThat(!passage.audioItemID || ids.has(passage.audioItemID), 'Broken passage audio reference');
    requireThat(passage.verseNumbers?.length === passage.verses.length, 'Verse numbers must match the passage');
  }
  for (const item of catalog.items) {
    const asset = item.audio;
    if (asset) {
      requireThat(item.transcript.length > 0, `Missing transcript: ${item.id}`);
      requireThat(!production || /^media\/[a-f0-9]{64}\.m4a$/.test(asset.url), 'Production assets must use immutable media/<checksum>.m4a keys');
      if (production) requireThat(asset.url === `media/${asset.sha256}.m4a`, 'Media key must match checksum');
      if (mediaDir) {
        const file = join(mediaDir, basename(asset.url.replace(/^bundle:/, '')));
        const bytes = await readFile(file);
        requireThat(bytes.length === asset.bytes && sha256(bytes) === asset.sha256, `Media integrity mismatch: ${item.id}`);
        requireThat(bytes.subarray(4, 8).toString() === 'ftyp', `Expected MPEG-4 audio: ${item.id}`);
        if (production) {
          const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration:stream=codec_name,codec_type', '-of', 'json', file], { encoding: 'utf8' }));
          requireThat(probe.streams.some(s => s.codec_type === 'audio' && s.codec_name === 'aac'), `Expected AAC audio: ${item.id}`);
          requireThat(Math.abs(Number(probe.format.duration) - item.durationSeconds) < 0.5, `Incorrect duration: ${item.id}`);
          execFileSync('ffmpeg', ['-v', 'error', '-i', file, '-f', 'null', '-'], { stdio: ['ignore', 'ignore', 'pipe'] });
        }
      }
    }
    let lastEnd = 0;
    for (const cue of item.cues ?? []) {
      requireThat(cue.start >= lastEnd && cue.end > cue.start && cue.end <= item.durationSeconds + 0.1 && cue.paragraph < item.transcript.length, `Invalid transcript cues: ${item.id}`);
      lastEnd = cue.end;
    }
    lastEnd = 0;
    for (const cue of item.rosaryCues ?? []) {
      requireThat(item.rosarySet && cue.step < 69 && cue.start >= lastEnd && cue.end > cue.start && cue.end <= item.durationSeconds + 0.1, `Invalid Rosary cues: ${item.id}`);
      lastEnd = cue.end;
    }
  }
  if (production) {
    const approved = new Map(reviews.map(x => [x.id, x]));
    for (const record of [...catalog.items, ...catalog.passages, ...catalog.calendar.map(x => ({ ...x, id: `calendar:${x.date}` }))]) {
      const review = approved.get(record.id);
      requireThat(review && review.recordSHA256 === sha256(Buffer.from(JSON.stringify(record))), `Missing or stale review for ${record.id}`);
      for (const step of ['editorial', 'theological', 'permissions', 'accessibility', 'media']) requireThat(typeof review.approvals?.[step] === 'string' && review.approvals[step].trim().length > 0, `Missing ${step} approval: ${record.id}`);
      requireThat(review.rights?.worldwide === true && review.rights?.offline === true && !review.rights?.expiresAt, `Rights must permit durable public/offline delivery: ${record.id}`);
    }
    for (let offset = 0; offset < 90; offset++) {
      const date = new Date(`${today}T12:00:00Z`); date.setUTCDate(date.getUTCDate() + offset);
      const day = date.toISOString().slice(0, 10);
      requireThat(catalog.passages.some(x => x.date === day) && catalog.calendar.some(x => x.date === day), `Calendar coverage missing: ${day}`);
    }
  }
  return catalog;
}

export function publicCatalog(source) {
  // Validation rejects extra properties. Round-trip the explicitly enumerated top-level fields.
  return Object.fromEntries(['schemaVersion', 'revision', 'publishedAt', 'isFixture', 'items', 'collections', 'journeys', 'passages', 'calendar', 'withdrawnIDs'].map(k => [k, source[k]]));
}

export async function publishCatalog({ catalog, store, mediaDir, baseURL, now = Date.now() }) {
  const old = await store.getJSON('latest.json', true);
  const generation = Math.max(now, (old?.generation ?? 0) + 1);
  const media = new Map(catalog.items.filter(x => x.audio).map(x => [x.audio.sha256, x.audio]));
  for (const asset of media.values()) {
    const bytes = await readFile(join(mediaDir, basename(asset.url)));
    if (sha256(bytes) !== asset.sha256 || bytes.length !== asset.bytes) throw new Error('Media changed after validation');
    await store.put(asset.url, bytes, asset.mimeType, 'public, max-age=31536000, immutable');
    await store.verify(asset.url, asset.sha256);
  }
  const key = `catalogs/${generation}/catalog.json`;
  const bytes = Buffer.from(JSON.stringify(publicCatalog(catalog)));
  await store.put(key, bytes, 'application/json', 'public, max-age=31536000, immutable');
  await store.verify(key, sha256(bytes));
  const pointer = { schemaVersion: 1, generation, catalogURL: new URL(key, baseURL).href, sha256: sha256(bytes) };
  if (old) await store.put(`history/${generation}/previous.json`, Buffer.from(JSON.stringify(old)), 'application/json', 'no-store');
  await store.put('latest.json', Buffer.from(JSON.stringify(pointer)), 'application/json', 'no-cache, max-age=0, must-revalidate');
  return pointer;
}

export async function rollbackCatalog({ store, pointer, baseURL, now = Date.now() }) {
  const current = await store.getJSON('latest.json');
  const url = new URL(pointer.catalogURL);
  const base = new URL(baseURL);
  if (url.origin !== base.origin || !url.pathname.startsWith(base.pathname) || !/\/catalogs\/\d+\/catalog\.json$/.test(url.pathname)) throw new Error('Rollback target must be a verified snapshot on this content host');
  const key = url.pathname.slice(base.pathname.length);
  await store.verify(key, pointer.sha256);
  const next = { ...pointer, generation: Math.max(now, current.generation + 1) };
  await store.put(`history/${next.generation}/previous.json`, Buffer.from(JSON.stringify(current)), 'application/json', 'no-store');
  await store.put('latest.json', Buffer.from(JSON.stringify(next)), 'application/json', 'no-cache, max-age=0, must-revalidate');
  return next;
}
