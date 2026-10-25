import { createHmac } from 'node:crypto';
import { sha256 } from './content-lib.mjs';
const hmac = (key, value) => createHmac('sha256', key).update(value).digest();
export class R2Store {
  constructor(env = process.env) {
    for (const k of ['R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET', 'CONTENT_BASE_URL']) if (!env[k]) throw new Error(`Configure ${k} before publishing`);
    this.env = env;
    this.baseURL = env.CONTENT_BASE_URL.endsWith('/') ? env.CONTENT_BASE_URL : env.CONTENT_BASE_URL + '/';
    const url = new URL(this.baseURL);
    if (url.protocol !== 'https:' || url.hostname.endsWith('.r2.dev')) throw new Error('Production requires an HTTPS custom domain');
  }
  async request(method, key, bytes = Buffer.alloc(0), extra = {}) {
    const e = this.env;
    const host = `${e.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`;
    const path = '/' + [e.R2_BUCKET, ...key.split('/')].map(encodeURIComponent).join('/');
    const time = new Date().toISOString().replace(/[:-]|\.\d{3}/g, '');
    const day = time.slice(0, 8);
    const payloadHash = sha256(bytes);
    const headers = { host, 'x-amz-content-sha256': payloadHash, 'x-amz-date': time, ...extra };
    const names = Object.keys(headers).sort();
    const canonicalHeaders = names.map(k => `${k}:${headers[k].trim()}\n`).join('');
    const signed = names.join(';');
    const canonical = [method, path, '', canonicalHeaders, signed, payloadHash].join('\n');
    const scope = `${day}/auto/s3/aws4_request`;
    const toSign = ['AWS4-HMAC-SHA256', time, scope, sha256(canonical)].join('\n');
    const signingKey = hmac(hmac(hmac(hmac(`AWS4${e.R2_SECRET_ACCESS_KEY}`, day), 'auto'), 's3'), 'aws4_request');
    const signature = createHmac('sha256', signingKey).update(toSign).digest('hex');
    headers.authorization = `AWS4-HMAC-SHA256 Credential=${e.R2_ACCESS_KEY_ID}/${scope}, SignedHeaders=${signed}, Signature=${signature}`;
    return fetch(`https://${host}${path}`, { method, headers, body: method === 'PUT' ? bytes : undefined, signal: AbortSignal.timeout(120_000), redirect: 'error' });
  }
  async getJSON(key, allowMissing = false) {
    const response = await this.request('GET', key);
    if (allowMissing && response.status === 404) return null;
    if (!response.ok) throw new Error(`R2 read failed (${response.status})`);
    return response.json();
  }
  async put(key, bytes, type, cacheControl) {
    const response = await this.request('PUT', key, bytes, { 'content-type': type, 'cache-control': cacheControl });
    if (!response.ok) throw new Error(`R2 write failed (${response.status})`);
  }
  async verify(key, expectedHash) {
    const response = await fetch(new URL(key, this.baseURL), { signal: AbortSignal.timeout(120_000), redirect: 'error' });
    if (!response.ok || sha256(Buffer.from(await response.arrayBuffer())) !== expectedHash) throw new Error('Public asset verification failed; publication has not advanced');
  }
}
