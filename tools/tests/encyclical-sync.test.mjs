import test from 'node:test';
import assert from 'node:assert/strict';
import { access, copyFile, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sha256 } from '../content-lib.mjs';
import { bundleReadingLibrary, readingDocuments, validateReadingLibrary, validateReadingPublication } from '../reading-library-lib.mjs';

const root = fileURLToPath(new URL('../../content/readings/', import.meta.url));
const load = async name => JSON.parse(await readFile(join(root, name), 'utf8'));
const [library, catalog, inventory, overlay, lock, schema] = await Promise.all([
  load('library.json'), load('encyclicals.json'), load('encyclical-inventory.json'),
  load('development-texts.json'), load('development-source-lock.json'),
  readFile(new URL('../../shared/content-schema/reading-library.schema.json', import.meta.url), 'utf8').then(JSON.parse),
]);
const works = new Map(library.works.map(work => [work.id, work]));
const records = new Map(inventory.records.map(record => [record.id, record]));
const sources = new Map(lock.sources.map(source => [source.id, source]));
const digestIDs = ids => sha256(Buffer.from([...ids].sort().join('\n')));
const isSHA256 = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
let documentsPromise;
const documents = () => documentsPromise ??= readingDocuments(library, root);

// IDs captured before adding summaries. Persisted bookmarks and guide targets
// must keep identifying the same body sections after the content sync.
const baseline = {
  workIDs: 'f4e2e86a39a75c0dbce19db4a789ea147d828d981bc8477c37d901e29e0b1460',
  sectionIDs: 'a924e34880d4534d11eb7fd2a34075727f173fe2ba4336558f344e48f92c4ac0',
  catalogIDs: '0e1a5813d5a8fa3ea22a43ab422bbb4df586145316f3fba67e7295f9768a4966',
};
const guideTargets = [
  { id: 'guide-suffering', targets: [
    ['drb-job', 'drb-job-19', 'verse-25'], ['drb-psa', 'drb-psa-22', null],
    ['drb-rom', 'drb-rom-8', 'verse-18'], ['imitation', 'imitation-book-2-chapter-12', null],
    ['papal-ben16-spe-salvi', 'papal-ben16-spe-salvi-text', null],
    ['salvifici-doloris', 'salvifici-doloris-text', null],
  ] },
  { id: 'guide-begin-reading', targets: [
    ['drb-mrk', 'drb-mrk-1', null], ['drb-luk', 'drb-luk-15', null],
    ['drb-jhn', 'drb-jhn-1', null], ['drb-rom', 'drb-rom-8', null],
  ] },
];

test('the summary sync preserves every work ID, legacy section ID, and guide destination', () => {
  const sections = library.works.flatMap(work => work.sections);
  const legacySections = sections.filter(section => !section.id.endsWith('-summary'));
  assert.equal(library.works.length, 645);
  assert.equal(sections.length, 2629);
  assert.equal(legacySections.length, 2060);
  assert.equal(digestIDs(works.keys()), baseline.workIDs);
  assert.equal(digestIDs(legacySections.map(section => section.id)), baseline.sectionIDs);
  assert.equal(catalog.works.length, 568);
  assert.equal(digestIDs(catalog.works.map(work => work.id)), baseline.catalogIDs);
  assert.deepEqual(library.guides.map(guide => ({
    id: guide.id,
    targets: guide.steps.map(step => [step.workID, step.sectionID ?? null, step.anchor ?? null]),
  })), guideTargets);
});

test('all canonical source works map once, including the existing Salvifici doloris ID', () => {
  assert.equal(inventory.sourceDocumentCount, 569);
  assert.equal(inventory.sourcePopeCount, 43);
  assert.equal(inventory.originalCorpus.sourceDocumentCount, 401);
  assert.equal(inventory.completeHistoricalCensusVerified, false);
  assert.equal(inventory.records.length, 569);
  assert.equal(records.size, 569);
  assert.equal(new Set(inventory.records.map(record => record.localRecord)).size, 569);
  assert.equal(lock.sources.length, 569);
  assert.deepEqual([...records.keys()].sort(), [...sources.keys()].sort());
  assert.deepEqual([...records.keys()].sort(), Object.keys(overlay.works).sort());
  assert.ok(inventory.records.every(record => works.has(record.id)));
  assert.equal(records.get('salvifici-doloris').localRecord, 'jp02/salvifici-doloris');
  assert.ok(!works.has('papal-jp02-salvifici-doloris'));
  assert.ok(!inventory.records.some(record => record.localRecord === 'pius10/pope-st-pius-x'));

  const mexicanLetter = catalog.works.filter(work => work.author === 'Pope Pius XI' &&
    (work.title.toLowerCase().includes('firmissimam') || work.aliases.some(alias => /firmissimam/i.test(alias))));
  assert.equal(mexicanLetter.length, 1, 'the two 1937 source URLs must share one canonical work');
  const ubiPrimum = catalog.works.filter(work => work.author === 'Pope Leo XII' && /^ubi primum$/i.test(work.title));
  assert.equal(ubiPrimum.length, 1, 'the alternate Ubi primum edition must remain consolidated');
});

test('every English editorial summary has independent provenance, Markdown, and indexed text', async () => {
  validateReadingLibrary(library, schema);
  const indexed = new Map((await documents()).map(document => [document.sectionID, document]));
  assert.equal([...indexed.keys()].filter(id => id?.endsWith('-summary')).length, 569);
  for (const [id, source] of sources) {
    const work = works.get(id);
    assert.equal(work.sections.length, 2, id);
    const [body, summary] = work.sections;
    assert.equal(body.id, `${id}-text`, id);
    assert.equal(body.order, 1, id);
    assert.equal(summary.id, `${id}-summary`, id);
    assert.equal(summary.order, 2, id);
    assert.equal(summary.title, 'English editorial summary', id);
    assert.equal(summary.reference, `${work.title} · English editorial summary`, id);
    assert.notEqual(body.file.path, summary.file.path, id);
    assert.equal(source.summary.sectionID, summary.id, id);
    assert.equal(source.summary.localRecord, `${records.get(id).localRecord}-summary`, id);
    assert.equal(source.summary.language, 'en', id);
    assert.equal(source.summary.status, 'available-unreviewed', id);
    assert.ok(isSHA256(source.summary.sha256), `missing original summary hash: ${id}`);
    assert.ok(source.summary.bytes > 0, `missing original summary byte count: ${id}`);
    assert.equal(source.summary.convertedSHA256, summary.file.sha256, id);
    assert.equal(source.summary.convertedBytes, summary.file.bytes, id);
    assert.equal(work.language, source.readingLanguage, id);
    const markdown = await readFile(join(root, summary.file.path));
    assert.equal(markdown.length, summary.file.bytes, id);
    assert.equal(sha256(markdown), summary.file.sha256, id);
    const document = indexed.get(summary.id);
    assert.equal(document.workID, id, id);
    assert.equal(document.id, summary.id, id);
    assert.ok(document.text.length > 80, `summary absent from local search: ${id}`);
    assert.ok(document.normalizedText.includes('english editorial summary'), id);
    assert.notEqual(document.text, indexed.get(body.id).text, id);
  }
});

test('curated English finding titles remain aliases without replacing canonical incipits', () => {
  for (const record of inventory.records) {
    assert.equal(typeof record.englishTitle, 'string', record.id);
    assert.ok(record.englishTitle.trim(), record.id);
    const work = works.get(record.id);
    if (record.englishTitle.length <= 180) {
      assert.ok(work.aliases.includes(record.englishTitle), record.id);
    } else {
      // A legacy source field contains a body paragraph. It is audit material,
      // not a valid finding title or an excuse to change the stable work ID.
      assert.ok(!work.aliases.includes(record.englishTitle), record.id);
      assert.ok(work.aliases.includes(work.title), record.id);
    }
  }
  const id = 'papal-greg16-in-consistorio';
  assert.equal(works.get(id).title, 'In consistorio');
  assert.ok(works.get(id).aliases.includes('On the Patriarch of Lisbon and Freedom of Episcopal Appointment'));
});

test('archival dates and source document types survive stale Vatican labels', () => {
  const expected = [
    ['papal-greg16-in-consistorio', '1843-04-06', 'letter', 'papalDocument'],
    ['papal-greg16-maximis-angustiis', '1844-04-27', 'letter', 'papalDocument'],
    ['papal-greg16-hanno-sempre', '1838-09-18', 'motu-proprio', 'papalDocument'],
    ['papal-john23-religiosorum-institutio', '1961', 'instruction', 'papalDocument'],
    ['papal-pius12-guiding-principles-of-the-lay-apostolate', '1957-10-05', 'address', 'papalDocument'],
  ];
  for (const [id, date, type, kind] of expected) {
    const metadata = catalog.works.find(work => work.id === id);
    assert.equal(metadata.date, date, id);
    assert.equal(metadata.originalType, type, id);
    assert.equal(metadata.kind, kind, id);
    assert.equal(works.get(id).date, date, id);
    assert.equal(records.get(id).date, date, id);
    assert.equal(records.get(id).originalType, type, id);
  }
  for (const [id, oldLabel] of [
    ['papal-greg16-in-consistorio', '1841-08-29'],
    ['papal-greg16-maximis-angustiis', '1845-04-27'],
  ]) {
    const conflict = records.get(id).dateConflict;
    assert.equal(conflict.indexLabelDate, oldLabel, id);
    assert.equal(conflict.resolvedDate, works.get(id).date, id);
    assert.equal(conflict.status, 'resolved-by-archival-edition', id);
    assert.match(conflict.resolutionSourceURL, /^https:\/\/archive\.org\//, id);
  }
});

test('the recovered Pius XII body and separate congress appendix are available to offline search', async () => {
  const id = 'papal-pius12-guiding-principles-of-the-lay-apostolate';
  const work = works.get(id);
  const source = sources.get(id);
  const [body, summary] = work.sections;
  const markdown = await readFile(join(root, body.file.path), 'utf8');
  const appendix = '## Appendix: SUMMARY OF CONCLUSIONS OF THE CONGRESS';
  assert.ok(markdown.indexOf(appendix) > 10000, 'a recovered full address must precede the appendix');
  assert.match(markdown, /conclusions were adopted by the congress; they are distinct from the papal address above/);
  assert.ok(markdown.includes('Original numbering, including the repeated paragraph label 27, is retained.'));
  const indexed = new Map((await documents()).map(document => [document.sectionID, document]));
  assert.ok(indexed.get(body.id).normalizedText.includes('the value and efficacy of the apostolate exercised by a teacher of religion'));
  assert.ok(indexed.get(body.id).normalizedText.includes('summary of conclusions of the congress'));
  assert.notEqual(indexed.get(body.id).id, indexed.get(summary.id).id);
  assert.equal(work.language, 'en');
  assert.equal(records.get(id).translated, true);
  assert.equal(records.get(id).machineTranslated, false);
  assert.equal(records.get(id).sourceRecovery.congressAppendixIncluded, true);
  assert.equal(records.get(id).sourceRecovery.congressAppendixIsPapalText, false);
  assert.equal(source.machineTranslated, false);
  assert.match(work.rights.edition, /National Catholic Welfare Conference|NCWC/);
  assert.doesNotMatch(work.rights.edition, /DeepL|machine translation/i);
  assert.equal(lock.sources.filter(item => item.machineTranslated).length, 31);
  assert.equal(inventory.records.filter(item => item.machineTranslated).length, 31);
});

test('papal bodies and editorial summaries both remain behind the development publication gate', () => {
  for (const id of sources.keys()) assert.equal(works.get(id).rights.status, 'developmentOnly', id);
  for (const suffix of ['-text', '-summary']) {
    const changed = structuredClone(library);
    changed.isDevelopment = false;
    const work = structuredClone(works.get('papal-greg16-in-consistorio'));
    work.sections = work.sections.filter(section => section.id.endsWith(suffix));
    changed.works = [work]; changed.guides = [];
    assert.throws(() => validateReadingLibrary(changed, schema), /Development-only/, suffix);
    assert.throws(() => validateReadingPublication(changed, []), /Development-only/, suffix);
  }
});

test('stripping a papal edition removes both source and summary files and their indexed text', async () => {
  const destination = await mkdtemp(join(tmpdir(), 'grace-encyclical-strip-'));
  const changed = structuredClone(library);
  const work = structuredClone(works.get('papal-greg16-in-consistorio'));
  changed.works = [work]; changed.guides = [];
  const refreshIndex = async () => {
    const indexed = await readingDocuments(changed, root);
    const bytes = Buffer.from(JSON.stringify(indexed));
    changed.searchIndex = { path: 'search-index.json', sha256: sha256(bytes), bytes: bytes.length };
  };
  try {
    const files = work.sections.map(section => section.file.path);
    assert.equal(files.length, 2);
    await refreshIndex();
    await bundleReadingLibrary(changed, root, destination);
    for (const file of files) await access(join(destination, file));
    work.sections = []; work.rights.status = 'linkOnly';
    await refreshIndex();
    await bundleReadingLibrary(changed, root, destination);
    for (const file of files) await assert.rejects(access(join(destination, file)), { code: 'ENOENT' });
    assert.deepEqual(JSON.parse(await readFile(join(destination, 'search-index.json'), 'utf8')), [
      { id: work.id, workID: work.id, sectionID: null, text: '', normalizedText: '' },
    ]);
  } finally { await rm(destination, { recursive: true, force: true }); }
});

const privateKeys = new Set(['approvals', 'privateEvidence', 'privateRightsEvidence', 'permissionsEvidence', 'credentials', 'apiKey', 'token', 'secret']);
function assertPublicMetadata(value, location = 'metadata') {
  if (!value || typeof value !== 'object') return;
  for (const [key, child] of Object.entries(value)) {
    assert.ok(!privateKeys.has(key), `private source field leaked at ${location}.${key}`);
    assertPublicMetadata(child, `${location}.${key}`);
  }
}
test('public sync metadata imports no approvals, private evidence, or local source paths', () => {
  for (const value of [catalog, inventory, overlay, lock, library]) {
    assertPublicMetadata(value);
    assert.doesNotMatch(JSON.stringify(value), /\/Users\/|\/private\/tmp\/|C:\\\\Users\\/);
  }
  const allowedConflict = new Set(['status', 'resolvedDate', 'resolvedOn', 'resolutionSourceURL', 'resolutionEvidence', 'indexLabelDate']);
  const allowedRecovery = new Set(['status', 'sourceRevision', 'sourceArtifactSHA256', 'congressAppendixIncluded', 'congressAppendixIsPapalText']);
  for (const record of inventory.records) {
    for (const field of Object.keys(record.dateConflict ?? {})) assert.ok(allowedConflict.has(field), field);
    for (const field of Object.keys(record.sourceRecovery ?? {})) assert.ok(allowedRecovery.has(field), field);
  }
});

test('a local importer fixture gives curated sidecar dates, types, and aliases precedence over index labels', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'grace-encyclical-import-'));
  const content = join(directory, 'content', 'readings');
  const project = join(directory, 'source');
  const source = join(project, 'encyclicals', 'markdown');
  const url = slug => `https://www.vatican.va/content/gregorius-xvi/it/documents/${slug}.html`;
  const fixtureItems = [
    { slug: 'in-consistorio', incipit: 'In consistorio', sourceURL: url('epistola-in-consistorio-29-agosto-1841'), date: '1841-08-29', year: 1841, type: 'letter' },
    { slug: 'hanno-sempre', incipit: 'Hanno sempre', sourceURL: url('epistola-hanno-sempre-18-settembre-1838'), date: '1838-09-18', year: 1838, type: 'letter' },
  ];
  const writeJSON = async (path, value) => writeFile(path, JSON.stringify(value));
  try {
    await mkdir(join(directory, 'tools'), { recursive: true });
    await mkdir(content, { recursive: true });
    await mkdir(join(source, 'greg16'), { recursive: true });
    await copyFile(new URL('../import-encyclical-catalog.py', import.meta.url), join(directory, 'tools', 'import-encyclical-catalog.py'));
    const items = fixtureItems.map(item => ({ ...item, popeSlug: 'greg16', popeName: 'Gregory XVI', englishTitle: null, translated: false, machineTranslated: false, language: 'it', tags: [] }));
    await writeJSON(join(source, 'index.json'), { generatedAt: '2026-10-27T00:00:00Z', totalPopes: 1, documents: items });
    for (const item of items) {
      const metadata = { ...item, englishTitle: item.slug === 'in-consistorio' ? 'On Episcopal Appointment in Lisbon' : 'On the Capitoline Museum',
        aliases: ['Synthetic editorial finding alias'], date: item.slug === 'in-consistorio' ? '1843-04-06' : item.date,
        type: item.slug === 'hanno-sempre' ? 'motu-proprio' : item.type,
        privateRightsEvidence: 'SYNTHETIC_PRIVATE_MUST_NOT_COPY', approvals: { permissions: 'SYNTHETIC_PRIVATE_MUST_NOT_COPY' },
      };
      if (item.slug === 'in-consistorio') metadata.dateConflict = { status: 'resolved-by-archival-edition', resolvedDate: '1843-04-06', indexLabelDate: item.date,
        resolutionSourceURL: 'https://archive.org/details/example', resolutionEvidence: 'Synthetic archival fixture', privateEvidence: 'SYNTHETIC_PRIVATE_MUST_NOT_COPY' };
      await writeJSON(join(source, 'greg16', `${item.slug}.json`), metadata);
      await writeFile(join(source, 'greg16', `${item.slug}.md`), `# ${item.incipit}\n\nSYNTHETIC_SOURCE_BODY_MUST_NOT_COPY\n`);
    }
    await writeJSON(join(content, 'vatican-index.json'), { indexes: [], records: items.map(item => ({
      title: item.incipit, sourceURL: item.sourceURL, label: `Epistola ${item.incipit} (${item.slug === 'in-consistorio' ? '29 agosto 1841' : '18 settembre 1838'})`,
      pope: 'greg16', kind: 'apostolicLetter', originalType: 'letter',
    })) });
    await writeJSON(join(content, 'source-links.json'), { links: {} });
    await writeJSON(join(content, 'catalog-corrections.json'), { overrides: {}, sourceAliases: {}, additionalWorks: [] });
    await writeJSON(join(content, 'curation.json'), { sourceWorks: [], guides: [], topics: [] });
    await writeJSON(join(content, 'encyclicals.json'), { works: [] });
    await writeJSON(join(content, 'encyclical-inventory.json'), {
      sourceDocumentCount: 401, sourceIndexSHA256: '0'.repeat(64), sourcePopeCount: 43,
      originalCorpus: { sourceDocumentCount: 401, sourceIndexSHA256: '0'.repeat(64), translatedRecords: 32 },
      records: items.map(item => ({ id: `papal-greg16-${item.slug}`, localRecord: `greg16/${item.slug}`, translated: false })),
    });
    execFileSync('python3', [join(directory, 'tools', 'import-encyclical-catalog.py'), '--project', project], { cwd: directory, encoding: 'utf8', timeout: 30000 });
    const result = JSON.parse(await readFile(join(content, 'encyclicals.json'), 'utf8'));
    const audit = JSON.parse(await readFile(join(content, 'encyclical-inventory.json'), 'utf8'));
    const letter = result.works.find(work => work.id === 'papal-greg16-in-consistorio');
    const museum = result.works.find(work => work.id === 'papal-greg16-hanno-sempre');
    assert.equal(letter.date, '1843-04-06');
    assert.equal(letter.title, 'In consistorio');
    assert.ok(letter.aliases.includes('On Episcopal Appointment in Lisbon'));
    assert.ok(letter.aliases.includes('Synthetic editorial finding alias'));
    assert.equal(museum.originalType, 'motu-proprio');
    assert.equal(museum.kind, 'papalDocument');
    assert.equal(audit.originalCorpus.sourceDocumentCount, 401);
    assert.equal(audit.officialIndexCoverage.length, 2);
    assert.doesNotMatch(JSON.stringify([result, audit]), /SYNTHETIC_PRIVATE_MUST_NOT_COPY|SYNTHETIC_SOURCE_BODY_MUST_NOT_COPY/);
    assertPublicMetadata(result); assertPublicMetadata(audit);
  } finally { await rm(directory, { recursive: true, force: true }); }
});
