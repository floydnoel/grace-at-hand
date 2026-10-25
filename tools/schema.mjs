// Small validator for the deliberately constrained, dependency-free contract vocabulary.
// Unsupported schema keywords fail closed instead of silently skipping validation.
import { readFile } from 'node:fs/promises';
export async function loadSchema() {
  return JSON.parse(await readFile(new URL('../shared/content-schema/catalog.schema.json', import.meta.url), 'utf8'));
}
const annotations = new Set(['$schema', '$id', 'title', 'description', '$defs']);
const keywords = new Set(['$ref', 'type', 'required', 'properties', 'additionalProperties', 'items', 'minItems', 'uniqueItems', 'minimum', 'minLength', 'pattern', 'enum', 'const', 'anyOf', ...annotations]);
export function validateSchema(value, schema, root = schema, path = '$') {
  for (const key of Object.keys(schema)) if (!keywords.has(key)) throw new Error(`Unsupported schema keyword: ${key}`);
  if (schema.$ref) {
    const target = schema.$ref.split('/').slice(1).reduce((v, k) => v?.[k], root);
    if (!target) throw new Error(`Unknown reference ${schema.$ref}`);
    return validateSchema(value, target, root, path);
  }
  if (schema.anyOf) {
    for (const option of schema.anyOf) { try { validateSchema(value, option, root, path); return; } catch {} }
    throw new Error(`${path}: no allowed shape matched`);
  }
  const type = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;
  if (schema.type && (schema.type === 'integer' ? !Number.isInteger(value) : type !== schema.type)) throw new Error(`${path}: expected ${schema.type}`);
  if ('const' in schema && value !== schema.const) throw new Error(`${path}: incorrect constant`);
  if (schema.enum && !schema.enum.includes(value)) throw new Error(`${path}: invalid enum`);
  if (typeof value === 'number' && (!Number.isFinite(value) || (schema.minimum !== undefined && value < schema.minimum))) throw new Error(`${path}: invalid number`);
  if (typeof value === 'string') {
    if (value.length < (schema.minLength ?? 0) || (schema.pattern && !new RegExp(schema.pattern).test(value))) throw new Error(`${path}: invalid string`);
  }
  if (Array.isArray(value)) {
    if (value.length < (schema.minItems ?? 0)) throw new Error(`${path}: too few items`);
    if (schema.uniqueItems && new Set(value.map(v => JSON.stringify(v))).size !== value.length) throw new Error(`${path}: duplicates`);
    if (schema.items) value.forEach((v, i) => validateSchema(v, schema.items, root, `${path}[${i}]`));
  } else if (value && typeof value === 'object') {
    for (const key of schema.required ?? []) if (!(key in value)) throw new Error(`${path}.${key}: missing`);
    for (const [key, child] of Object.entries(value)) {
      if (schema.properties?.[key]) validateSchema(child, schema.properties[key], root, `${path}.${key}`);
      else if (schema.additionalProperties === false) throw new Error(`${path}.${key}: unknown field`);
    }
  }
}
