import { readFile, writeFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';
import { sha256 } from './content-lib.mjs';
import { validateReadingLibrary, readingDocuments, validateReadingPublication, bundleReadingLibrary } from './reading-library-lib.mjs';

const source = fileURLToPath(new URL('../content/readings/', import.meta.url));
const schema = JSON.parse(await readFile(new URL('../shared/content-schema/reading-library.schema.json', import.meta.url), 'utf8'));
const command = process.argv[2] ?? 'validate';
try {
  if (!['index', 'validate', 'bundle'].includes(command)) throw new Error('Commands: index, validate, bundle [--production]');
  const library = JSON.parse(await readFile(join(source, 'library.json'), 'utf8'));
  validateReadingLibrary(library, schema);
  const documents = await readingDocuments(library, source);
  const bytes = Buffer.from(JSON.stringify(documents));
  if (command === 'index') {
    library.searchIndex = { path: 'search-index.json', sha256: sha256(bytes), bytes: bytes.length };
    await writeFile(join(source, 'library.json'), JSON.stringify(library, null, 2) + '\n');
  } else if (sha256(bytes) !== library.searchIndex.sha256 || bytes.length !== library.searchIndex.bytes) throw new Error('Search index is stale. Run node tools/readings.mjs index.');
  if (process.argv.includes('--production')) {
    const directory = fileURLToPath(new URL('../content/reading-reviews/', import.meta.url));
    const reviews = [];
    for (const file of await readdir(directory)) if (file.endsWith('.json')) reviews.push(...JSON.parse(await readFile(join(directory, file), 'utf8')));
    validateReadingPublication(library, reviews);
  }
  if (command === 'bundle') {
    const destination = fileURLToPath(new URL('../ios/App/Resources/ReadingLibrary/', import.meta.url));
    await bundleReadingLibrary(library, source, destination);
  }
  console.log(`${command === 'bundle' ? 'Bundled' : 'Validated'} ${library.works.length} reading works, ${documents.filter(d => d.sectionID).length} offline sections. ${library.isDevelopment ? 'Editorial/rights approval is still pending.' : ''}`);
} catch (error) { console.error(error.message); process.exitCode = 1; }
