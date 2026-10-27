import { readFile, realpath, mkdir, cp, rm, writeFile } from 'node:fs/promises';
import { resolve, sep, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sha256 } from './content-lib.mjs';
import { validateSchema } from './schema.mjs';

const requireThat = (condition, message) => { if (!condition) throw new Error(message); };
export function safeReadingPath(path) {
  return typeof path === 'string' && !path.startsWith('/') && !/[\\:]/.test(path) && path.split('/').every(p => p && p !== '.' && p !== '..');
}
export function validateReadingLibrary(library, schema) {
  validateSchema(library, schema);
  requireThat(library.schemaVersion === 2, 'Unsupported reading-library version');
  const ids = new Set(library.works.map(w => w.id));
  const topicIDs = new Set(library.topics.map(t => t.id));
  requireThat(ids.size === library.works.length, 'Duplicate reading-work IDs');
  requireThat(topicIDs.size === library.topics.length, 'Duplicate reading topics');
  const sectionIDs = new Set(); const paths = new Set();
  const https = value => { try { const url = new URL(value); return url.protocol === 'https:' && !url.username && !url.password; } catch { return false; } };
  for (const work of library.works) {
    requireThat(https(work.sourceURL) && https(work.rights.evidenceURL), `Missing secure source/evidence: ${work.id}`);
    requireThat(!work.sections.length || ['publicDomain', 'licensed', 'developmentOnly'].includes(work.rights.status), `Offline text has no redistribution basis: ${work.id}`);
    requireThat(work.rights.status !== 'developmentOnly' || library.isDevelopment, `Development-only text cannot become production content: ${work.id}`);
    requireThat(work.topics.every(id => topicIDs.has(id)), `Unknown topic on ${work.id}`);
    const orders = new Set();
    for (const section of work.sections) {
      requireThat(!sectionIDs.has(section.id), 'Duplicate reading-section IDs'); sectionIDs.add(section.id);
      requireThat(!orders.has(section.order), `Duplicate section order: ${work.id}`); orders.add(section.order);
      requireThat(safeReadingPath(section.file.path) && section.file.path.startsWith('markdown/') && section.file.path.endsWith('.md'), 'Unsafe Markdown path');
      requireThat(!paths.has(section.file.path), 'A Markdown file belongs to more than one section'); paths.add(section.file.path);
      requireThat(section.topics.every(id => topicIDs.has(id)), `Unknown topic on ${section.id}`);
      if (work.kind === 'bible') requireThat(section.verseCount > 0, `Missing verse inventory: ${section.id}`);
    }
  }
  requireThat(library.searchIndex.path === 'search-index.json', 'Unexpected search-index path');
  requireThat(new Set(library.guides.map(g => g.id)).size === library.guides.length, 'Duplicate guide IDs');
  for (const guide of library.guides) {
    requireThat(guide.topics.every(id => topicIDs.has(id)), 'Unknown reading-guide topic');
    for (const step of guide.steps) {
      const work = library.works.find(w => w.id === step.workID);
      requireThat(work, `Unknown guide work: ${step.workID}`);
      requireThat(step.sectionID ? work.sections.some(s => s.id === step.sectionID) : !step.anchor, 'Broken reading-guide section/anchor');
    }
  }
}

export async function readingDocuments(library, root) {
  root = root instanceof URL ? fileURLToPath(root) : root;
  const documents = []; const content = new Map();
  const actualRoot = await realpath(root);
  for (const work of library.works) {
    if (!work.sections.length) documents.push({ id: work.id, workID: work.id, sectionID: null, text: '', normalizedText: '' });
    for (const section of work.sections) {
      requireThat(safeReadingPath(section.file.path), 'Unsafe Markdown path');
      const path = await realpath(resolve(root, section.file.path));
      requireThat(path.startsWith(actualRoot + sep), 'Markdown symlink escapes the reading library');
      const bytes = await readFile(path);
      requireThat(bytes.length === section.file.bytes && sha256(bytes) === section.file.sha256, `Reading integrity mismatch: ${section.id}`);
      const markdown = bytes.toString('utf8'); content.set(section.id, markdown);
      requireThat(markdown.startsWith('# ') && !markdown.includes('\uFFFD'), `Malformed Markdown: ${section.id}`);
      if (work.kind === 'bible') {
        const verses = [...markdown.matchAll(/^\*\*(\d+)\.\*\* /gm)].map(m => Number(m[1]));
        requireThat(verses.length === section.verseCount && verses.every((v, i) => v === i + 1), `Missing, repeated or reordered verse: ${section.id}`);
        requireThat(!markdown.includes('strong=') && !/\\(?:w|v|c)\b/.test(markdown), 'Unconverted Bible markup');
      }
      const text = section.id.endsWith('-source-notice') ? '' : markdown.replace(/^#{1,6}\s+/gm, '').replace(/\*\*/g, '').replace(/\s+/g, ' ').trim();
      const normalizedText = text.normalize('NFD').replace(/\p{M}/gu, '').toLocaleLowerCase('en-US').replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
      documents.push({ id: section.id, workID: work.id, sectionID: section.id, text, normalizedText });
    }
  }
  for (const guide of library.guides) for (const step of guide.steps) if (step.anchor) {
    const number = /^verse-(\d+)$/.exec(step.anchor)?.[1];
    requireThat(number && content.get(step.sectionID)?.includes(`**${number}.** `), `Broken guide anchor: ${step.anchor}`);
  }
  return documents;
}

export async function bundleReadingLibrary(library, source, destination) {
  const bytes = Buffer.from(JSON.stringify(await readingDocuments(library, source)));
  requireThat(sha256(bytes) === library.searchIndex.sha256 && bytes.length === library.searchIndex.bytes, 'Search index is stale');
  await rm(destination, { recursive: true, force: true });
  await mkdir(destination, { recursive: true });
  // Unreferenced research files must not survive stripping their catalog sections.
  for (const work of library.works) for (const section of work.sections) {
    const path = join(destination, section.file.path);
    await mkdir(dirname(path), { recursive: true });
    await cp(join(source, section.file.path), path);
  }
  await writeFile(join(destination, 'library.json'), JSON.stringify(library));
  await writeFile(join(destination, 'search-index.json'), bytes);
}

export function validateReadingPublication(library, reviews) {
  requireThat(!library.isDevelopment, 'Development reading library cannot ship in production');
  requireThat(!library.works.some(w => w.rights.status === 'developmentOnly'), 'Development-only texts need rights clearance or removal before production');
  const approved = new Map(reviews.map(r => [r.id, r]));
  for (const record of [...library.works, ...library.guides, ...library.topics]) {
    const review = approved.get(record.id);
    requireThat(review?.recordSHA256 === sha256(Buffer.from(JSON.stringify(record))), `Missing or stale reading review: ${record.id}`);
    for (const role of ['editorial', 'theological', 'permissions', 'accessibility']) requireThat(typeof review.approvals?.[role] === 'string' && review.approvals[role].trim(), `Missing ${role} reading approval: ${record.id}`);
    if (record.rights && record.sections.length) requireThat(review.rights?.offline === true && review.rights?.territory === 'US' && !review.rights?.expiresAt, `Missing durable US offline approval: ${record.id}`);
  }
}
