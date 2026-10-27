import { readFile, readdir } from 'node:fs/promises';
import { validateCatalog, sha256 } from './content-lib.mjs';
import { validateReadingLibrary, readingDocuments, validateReadingPublication } from './reading-library-lib.mjs';
const catalog = JSON.parse(await readFile(new URL('../ios/App/Resources/catalog.json', import.meta.url), 'utf8'));
const errors = [];
try {
  const root = new URL('../ios/App/Resources/ReadingLibrary/', import.meta.url);
  const library = JSON.parse(await readFile(new URL('library.json', root), 'utf8'));
  const schema = JSON.parse(await readFile(new URL('../shared/content-schema/reading-library.schema.json', import.meta.url), 'utf8'));
  validateReadingLibrary(library, schema);
  const expectedIndex = Buffer.from(JSON.stringify(await readingDocuments(library, root)));
  const actualIndex = await readFile(new URL('search-index.json', root));
  if (!actualIndex.equals(expectedIndex) || actualIndex.length !== library.searchIndex.bytes || sha256(actualIndex) !== library.searchIndex.sha256) throw new Error('Bundled reading search index does not match reviewed source files.');
  const directory = new URL('../content/reading-reviews/', import.meta.url);
  const reviews = [];
  for (const name of await readdir(directory)) if (name.endsWith('.json')) reviews.push(...JSON.parse(await readFile(new URL(name, directory), 'utf8')));
  validateReadingPublication(library, reviews);
} catch (error) { errors.push(`Reading library is not approved: ${error.message}`); }
if (catalog.isFixture) errors.push('Production cannot contain development content. Bundle a reviewed catalog.');
else {
  try {
    const directory = new URL('../content/reviews/', import.meta.url);
    const reviews = [];
    for (const name of await readdir(directory)) if (name.endsWith('.json')) reviews.push(...JSON.parse(await readFile(new URL(name, directory), 'utf8')));
    await validateCatalog(catalog, { production: true, reviews });
  } catch (error) { errors.push(`Bundled content is not approved: ${error.message}`); }
}
for (const [key, label] of [['GRACE_TEAM_ID','Apple team'],['GRACE_BUNDLE_ID','bundle identifier'],['GRACE_CONTENT_BASE_URL','content domain'],['GRACE_PRIVACY_URL','privacy policy URL'],['GRACE_HELP_EMAIL','support contact']]) {
  const value = process.env[key];
  if (!value || /unconfigured|example|YOUR_|your-owned/i.test(value)) errors.push(`Configure the ${label} (${key}).`);
}
for (const key of ['GRACE_CONTENT_BASE_URL','GRACE_PRIVACY_URL','GRACE_SUPPORT_URL']) {
  if (process.env[key]) {
    try { const url = new URL(process.env[key]); if (url.protocol !== 'https:' || !url.hostname || url.username || url.password) throw new Error(); }
    catch { errors.push(`${key} must be an HTTPS URL without embedded credentials.`); }
  }
}
if (errors.length) { console.error(errors.join('\n')); process.exitCode = 1; }
else console.log('Production configuration and bundled-content checks passed. Run the editorial publication checks and release checklist before upload.');
