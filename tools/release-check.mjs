import { readFile, readdir } from 'node:fs/promises';
import { validateCatalog } from './content-lib.mjs';
const catalog = JSON.parse(await readFile(new URL('../ios/App/Resources/catalog.json', import.meta.url), 'utf8'));
const errors = [];
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
