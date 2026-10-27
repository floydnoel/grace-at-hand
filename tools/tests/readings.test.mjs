import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, writeFile, mkdir, mkdtemp, rm, symlink, access } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sha256 } from '../content-lib.mjs';
import { validateReadingLibrary, readingDocuments, validateReadingPublication, safeReadingPath, bundleReadingLibrary } from '../reading-library-lib.mjs';

const root = fileURLToPath(new URL('../../content/readings/', import.meta.url));
const source = JSON.parse(await readFile(join(root, 'library.json'), 'utf8'));
const schema = JSON.parse(await readFile(new URL('../../shared/content-schema/reading-library.schema.json', import.meta.url), 'utf8'));
const inventory = JSON.parse(await readFile(join(root, 'encyclical-inventory.json'), 'utf8'));

test('all Markdown and the generated full-text index agree with the reading contract', async () => {
  validateReadingLibrary(source, schema);
  const documents = await readingDocuments(source, root);
  const bytes = Buffer.from(JSON.stringify(documents));
  assert.equal(bytes.length, source.searchIndex.bytes);
  assert.equal(sha256(bytes), source.searchIndex.sha256);
  const bible = source.works.filter(w => w.kind === 'bible');
  assert.equal(bible.length, 73);
  assert.equal(bible.flatMap(w => w.sections).length, 1334);
  assert.equal(bible.flatMap(w => w.sections).reduce((sum, s) => sum + s.verseCount, 0), 35811);
  const imitation = source.works.find(w => w.id === 'imitation');
  assert.equal(imitation.sections.find(s => s.id === 'imitation-book-2-chapter-12').title, 'Book II · Chapter XII');
});

test('the reconciled papal catalog has direct sources and every work has a development offline edition', async () => {
  const papal = source.works.filter(w => ['encyclical', 'papalDocument', 'apostolicLetter'].includes(w.kind));
  assert.equal(papal.length, 570);
  assert.ok(papal.every(w => w.rights.status === 'developmentOnly' && w.sections.length > 0 && w.sourceIsDirectory !== true));
  assert.equal(inventory.sourceDocumentCount, 401);
  assert.equal(inventory.records.filter(r => r.translated).length, 32);
  assert.equal(inventory.completeHistoricalCensusVerified, false);
  assert.equal(inventory.unresolvedSourceLinks.length, 0);
  const snapshot = JSON.parse(await readFile(join(root, 'vatican-index.json'), 'utf8'));
  assert.equal(inventory.officialIndexCoverage.length, snapshot.records.length);
  for (const item of snapshot.records) {
    const coverage = inventory.officialIndexCoverage.find(c => c.sourceURL === item.sourceURL);
    assert.equal(source.works.find(w => w.id === coverage?.workID)?.sourceURL, item.sourceURL);
  }
  const corrections = JSON.parse(await readFile(join(root, 'catalog-corrections.json'), 'utf8'));
  assert.equal(Object.keys(corrections.overrides).length, 7);
  for (const [key, correction] of Object.entries(corrections.overrides)) {
    const work = source.works.find(w => w.id === 'papal-' + key.replace('/', '-'));
    assert.equal(work.sourceURL, correction.sourceURL); assert.equal(work.date, correction.date); assert.equal(work.kind, correction.kind);
  }
  const lock = JSON.parse(await readFile(join(root, 'development-source-lock.json'), 'utf8'));
  assert.equal(lock.sources.filter(s => s.machineTranslated).length, 31);
  const constitution = source.works.find(w => w.id === 'papal-ben14-sollicita-ac-provida');
  assert.equal(constitution.language, 'la');
  const text = await readFile(join(root, constitution.sections[0].file.path), 'utf8');
  assert.equal(new Set([...text.matchAll(/§\s*(\d+)/g)].map(m => Number(m[1]))).size, 27);
  const spe = source.works.find(w => w.id === 'papal-ben16-spe-salvi');
  const speText = await readFile(join(root, spe.sections[0].file.path), 'utf8');
  assert.ok(speText.startsWith('# ' + spe.title + '\n'));
  assert.ok(!speText.includes('ENCYCLICAL LETTER_') && !speText.includes('_OF THE SUPREME'));
  const translation = source.works.find(w => w.id === 'papal-ben14-bolla-providas-romanorum');
  const translationText = await readFile(join(root, translation.sections[0].file.path), 'utf8');
  assert.ok(translationText.startsWith('# ' + translation.title + '\n'));
  assert.ok(translationText.includes('Translation provided by DeepL'));
});

test('rights, private fields, references, and duplicate sections fail closed', () => {
  let changed = structuredClone(source); changed.works[0].rights.status = 'linkOnly';
  assert.throws(() => validateReadingLibrary(changed, schema), /redistribution/);
  changed = structuredClone(source); changed.works[0].rights.privateContract = 'must not leak';
  assert.throws(() => validateReadingLibrary(changed, schema), /unknown field/);
  changed = structuredClone(source); changed.guides[0].steps[0].sectionID = 'missing-section';
  assert.throws(() => validateReadingLibrary(changed, schema), /Broken/);
  changed = structuredClone(source); changed.works[1].sections.push(changed.works[0].sections[0]);
  assert.throws(() => validateReadingLibrary(changed, schema), /Duplicate/);
});

test('corrupt Markdown and symlinks outside the library are rejected', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'grace-reading-integrity-'));
  const outside = await mkdtemp(join(tmpdir(), 'grace-reading-outside-'));
  try {
    const library = structuredClone(source); library.works = [library.works[0]]; library.guides = [];
    const section = library.works[0].sections[0]; library.works[0].sections = [section];
    await mkdir(join(directory, 'markdown'), { recursive: true }); section.file.path = 'markdown/chapter.md';
    await writeFile(join(directory, section.file.path), 'corrupted');
    await assert.rejects(readingDocuments(library, directory), /integrity/);
    await rm(join(directory, section.file.path));
    await writeFile(join(outside, 'chapter.md'), '# Outside');
    await symlink(join(outside, 'chapter.md'), join(directory, section.file.path));
    await assert.rejects(readingDocuments(library, directory), /symlink/);
  } finally { await rm(directory, { recursive: true, force: true }); await rm(outside, { recursive: true, force: true }); }
});

test('production rejects development readings and missing or stale human approvals', () => {
  assert.throws(() => validateReadingPublication(source, []), /Development/);
  const changed = structuredClone(source); changed.isDevelopment = false;
  assert.throws(() => validateReadingPublication(changed, []), /Development-only/);
  assert.throws(() => validateReadingLibrary(changed, schema), /Development-only/);
  changed.works = changed.works.filter(w => w.rights.status !== 'developmentOnly'); changed.guides = [];
  assert.throws(() => validateReadingPublication(changed, []), /Missing or stale/);
  const work = changed.works[0];
  const reviews = [{ id: work.id, recordSHA256: sha256(Buffer.from(JSON.stringify(work))), approvals: { editorial: 'test-review' } }];
  assert.throws(() => validateReadingPublication(changed, reviews), /theological/);
  assert.equal(safeReadingPath('../outside.md'), false);
  assert.equal(safeReadingPath('markdown/../outside.md'), false);
  assert.equal(safeReadingPath('markdown/book/chapter.md'), true);
});

test('removing research editions also removes their bytes from the app bundle and search index', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'grace-reading-strip-'));
  try {
    const library = structuredClone(source); library.works = [library.works[0]]; library.guides = [];
    library.works[0].sections = [library.works[0].sections[0]];
    const documents = await readingDocuments(library, root); const bytes = Buffer.from(JSON.stringify(documents));
    library.searchIndex = { path: 'search-index.json', sha256: sha256(bytes), bytes: bytes.length };
    await mkdir(join(directory, 'markdown'), { recursive: true });
    await writeFile(join(directory, 'markdown', 'removed-research.md'), 'An old research copy');
    await bundleReadingLibrary(library, root, directory);
    await assert.rejects(access(join(directory, 'markdown', 'removed-research.md')));
    const excluded = source.works.find(w => w.rights.status === 'developmentOnly').sections[0];
    await assert.rejects(access(join(directory, excluded.file.path)));
    assert.deepEqual(JSON.parse(await readFile(join(directory, 'search-index.json'), 'utf8')), documents);
    assert.equal(await readFile(join(directory, library.works[0].sections[0].file.path), 'utf8'), await readFile(join(root, library.works[0].sections[0].file.path), 'utf8'));
  } finally { await rm(directory, { recursive: true, force: true }); }
});
