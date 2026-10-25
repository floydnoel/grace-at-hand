import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { validateCatalog, publicCatalog, publishCatalog, rollbackCatalog, sha256, validDay } from '../content-lib.mjs';
const fixture = JSON.parse(await readFile(new URL('../../content/fixtures/catalog.json', import.meta.url), 'utf8'));
const clone = () => structuredClone(fixture);
const mediaDir = new URL('../../content/fixtures/media/', import.meta.url).pathname;

test('fixture catalog and every audio checksum agree', async () => {
  await validateCatalog(clone(), { mediaDir });
  assert.equal(new Set(fixture.items.filter(x => x.rosarySet).map(x => x.rosarySet)).size, 4);
});
test('production rejects fixture content', async () => {
  await assert.rejects(validateCatalog(clone(), { production: true }), /fixtures/);
});
test('unknown private fields cannot enter a public record', async () => {
  const catalog = clone(); catalog.items[0].privateRightsEvidence = 'confidential';
  await assert.rejects(validateCatalog(catalog), /unknown field/);
  const projected = publicCatalog({ ...clone(), secret: 'never public' });
  assert.ok(!JSON.stringify(projected).includes('never public'));
});
test('duplicate identifiers and broken references fail', async () => {
  const catalog = clone(); catalog.items[1].id = catalog.items[0].id;
  await assert.rejects(validateCatalog(catalog), /Duplicate/);
  const broken = clone(); broken.collections[0].itemIDs.push('missing');
  await assert.rejects(validateCatalog(broken), /Broken reference/);
});
test('transcripts, malformed cues and withdrawal contradictions fail', async () => {
  const catalog = clone(); catalog.items[0].transcript = [];
  await assert.rejects(validateCatalog(catalog), /transcript/);
  const cues = clone(); cues.items[0].cues = [{ paragraph: 100, start: 0, end: 1 }];
  await assert.rejects(validateCatalog(cues), /cues/);
  const withdrawn = clone(); withdrawn.withdrawnIDs = [withdrawn.items[0].id];
  await assert.rejects(validateCatalog(withdrawn), /Withdrawn/);
});
test('real dates are required, including leap years', async () => {
  assert.ok(validDay('2024-02-29'));
  assert.ok(!validDay('2026-02-29'));
  assert.ok(!validDay('2026-2-1'));
  const catalog = clone(); catalog.passages[0].date = '2026-02-29';
  await assert.rejects(validateCatalog(catalog), /Invalid local date/);
});
test('publication timestamps and Scripture numbering are explicit', async () => {
  const date = clone(); date.publishedAt = '2026-10-24';
  await assert.rejects(validateCatalog(date), /UTC/);
  const passage = clone(); passage.passages[0].verseNumbers = ['16'];
  await assert.rejects(validateCatalog(passage), /Verse numbers/);
  const calendar = clone(); calendar.calendar[0].id = 'calendar:2030-01-01';
  await assert.rejects(validateCatalog(calendar), /Calendar ID/);
});
test('Rosary cues cannot reference missing steps or overlap', async () => {
  const catalog = clone();
  const prayer = catalog.items.find(x => x.rosarySet);
  prayer.rosaryCues = [{ step: 68, start: 0, end: 1 }];
  await validateCatalog(catalog);
  prayer.rosaryCues[0].step = 69;
  await assert.rejects(validateCatalog(catalog), /Rosary cues/);
});
test('corrupt or replaced media fails before publication', async () => {
  const catalog = clone(); catalog.items[0].audio.sha256 = '0'.repeat(64);
  await assert.rejects(validateCatalog(catalog, { mediaDir }), /integrity/);
});
test('production requires matching substantive reviews and future coverage', async () => {
  const catalog = clone(); catalog.isFixture = false;
  for (const item of catalog.items) item.audio.url = `media/${item.audio.sha256}.m4a`;
  await assert.rejects(validateCatalog(catalog, { production: true }), /review/);
  const records = [...catalog.items, ...catalog.passages, ...catalog.calendar.map(x => ({ ...x, id: `calendar:${x.date}` }))];
  const reviews = records.map(x => ({ id: x.id, recordSHA256: sha256(Buffer.from(JSON.stringify(x))), approvals: { editorial: 'reviewer', theological: 'reviewer', permissions: 'reviewer', accessibility: 'reviewer', media: 'reviewer' }, rights: { worldwide: true, offline: true } }));
  await validateCatalog(catalog, { production: true, reviews, today: '2026-10-24' });
  await assert.rejects(validateCatalog(catalog, { production: true, reviews, today: '2027-12-01' }), /coverage/);
  catalog.items[0].text[0] += ' changed';
  await assert.rejects(validateCatalog(catalog, { production: true, reviews, today: '2026-10-24' }), /stale review/);
});

class MemoryStore {
  data = new Map(); writes = []; failVerification = false;
  async put(key, bytes) { this.writes.push(key); this.data.set(key, bytes); }
  async getJSON(key, allowMissing = false) { if (!this.data.has(key) && allowMissing) return null; return JSON.parse(this.data.get(key)); }
  async verify(key, expected) { if (this.failVerification || sha256(this.data.get(key)) !== expected) throw new Error('verification failed'); }
}
async function publishingFixture() {
  const dir = await mkdtemp(join(tmpdir(), 'grace-publish-test-'));
  const catalog = clone(); catalog.items = [catalog.items[0]];
  const asset = catalog.items[0].audio;
  const original = await readFile(join(mediaDir, asset.url.slice(7)));
  asset.url = `media/${asset.sha256}.m4a`;
  await writeFile(join(dir, `${asset.sha256}.m4a`), original);
  return { dir, catalog };
}
test('pointer promotion is last and only after public verification', async () => {
  const { dir, catalog } = await publishingFixture();
  try {
    const store = new MemoryStore();
    const pointer = await publishCatalog({ catalog, store, mediaDir: dir, baseURL: 'https://media.example.com/', now: 100 });
    assert.equal(store.writes.at(-1), 'latest.json');
    assert.equal(pointer.generation, 100);
    store.failVerification = true;
    await assert.rejects(publishCatalog({ catalog, store, mediaDir: dir, baseURL: 'https://media.example.com/', now: 200 }), /verification/);
    assert.equal((await store.getJSON('latest.json')).generation, 100);
  } finally { await rm(dir, { recursive: true, force: true }); }
});
test('rollback uses a new generation and refuses a different host', async () => {
  const { dir, catalog } = await publishingFixture();
  try {
    const store = new MemoryStore();
    const original = await publishCatalog({ catalog, store, mediaDir: dir, baseURL: 'https://media.example.com/', now: 100 });
    await publishCatalog({ catalog, store, mediaDir: dir, baseURL: 'https://media.example.com/', now: 200 });
    const rollback = await rollbackCatalog({ store, pointer: original, baseURL: 'https://media.example.com/', now: 150 });
    assert.equal(rollback.generation, 201); assert.equal(rollback.catalogURL, original.catalogURL);
    await assert.rejects(rollbackCatalog({ store, pointer: { ...original, catalogURL: 'https://other.example.com/catalogs/100/catalog.json' }, baseURL: 'https://media.example.com/' }), /content host/);
  } finally { await rm(dir, { recursive: true, force: true }); }
});
