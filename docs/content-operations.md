# Content operations

## Public contract

`shared/content-schema/catalog.schema.json` is the version 1 contract. It defines prayers, collections, seven-session journeys, daily passages, US Roman Catholic calendar entries, media assets, and optional paragraph/Rosary-step timing cues. Stable IDs survive edits; record revisions identify editorial changes and audio revisions identify changed recordings. Public records carry language, text, transcripts, suitability, credits, and downloadable media integrity metadata. Passage `verseNumbers` are explicit labels; clients never assume a passage begins at verse one.

Daily assignments are `YYYY-MM-DD` values interpreted in the device's local calendar day. `publishedAt` is a UTC timestamp. A cached passage must retain its assigned date. There is no full-Bible or daily-Mass-reading entitlement in this contract.

The schema rejects unknown fields, including accidental private rights evidence. Public output is an explicit allowlist. For schema evolution, bump the major version for incompatible changes and test the older client's retained-library recovery. Do not reuse withdrawn IDs for unrelated content.

## Editorial workflow

1. Author a complete record in a content branch, with text, transcript, source credits, suitability, language, and the actual recording duration. Put approved AAC in an M4A container; calculate SHA-256 and byte size. Use `media/<sha256>.m4a` as the production key.
2. Review editorial accuracy, Catholic theology, exact-edition permissions, offline/worldwide distribution rights, transcript/accessibility, and media quality. Review the US calendar and daily passages for at least 90 future days. Calendar ownership must be named before launch.
3. Store confidential licenses, contracts, evidence, and original media in a private backed-up archive outside this repository's public output. Put only approval references and the minimum publication assertions in `content/reviews/*.json`.
4. Each review file is an array of records with `id`, `recordSHA256`, `approvals`, and `rights`. Hash the exact `JSON.stringify(record)` UTF-8 bytes. Calendar review IDs are `calendar:YYYY-MM-DD`, hashed over the calendar record plus that `id` property. An edit invalidates the hash and requires renewed review.
5. Use real reviewer identifiers or review references, never generated approvals. Required approval keys are `editorial`, `theological`, `permissions`, `accessibility`, and `media`. Rights assertions require `worldwide: true`, `offline: true`, and no expiry; durable public downloads cannot reliably be recalled from offline devices.
6. Run the production validator with the approved media directory; open a PR; obtain the configured owners' review. Publish only the reviewed commit.

```sh
node tools/content.mjs validate --production --source content/catalog.json --media-dir build/approved-media
```

This checks schema, IDs/references, dates, credits, transcripts/cues, rights assertions, review freshness, 90-day coverage, byte/checksum agreement, AAC codec, decodability, and actual duration. Human review remains necessary; nonempty approval strings are not a substitute for governance.

Development fixtures are reproducible with `node tools/create-fixtures.mjs` on macOS with `say`, `ffmpeg`, and `ffprobe`. Regenerating them changes media hashes; commit the catalog and media together. This is not a production narration workflow.

## R2 provisioning and publication

Use separate private source/staging and public-delivery buckets. Configure the delivery bucket on an owned HTTPS custom domain; the `r2.dev` endpoint is unsuitable for production. Scope a read-only credential to staging retrieval and a write credential to the delivery bucket. No account-wide credential belongs in CI or the app. Configure GitHub's protected `production-content` environment and variables/secrets in `.env.example` and `.github/workflows/publish-content.yml`. See [Cloudflare's public-bucket documentation](https://developers.cloudflare.com/r2/buckets/public-buckets/).

Set cache rules so `latest.json` bypasses cache and immutable `media/` and `catalogs/` objects keep their cache headers. Do not apply a blanket cache-everything rule to the pointer or negative responses. R2 object consistency does not eliminate stale CDN responses; the publisher verifies through the public custom domain before promotion. See [R2 consistency and caching](https://developers.cloudflare.com/r2/reference/consistency/).

The manual publishing workflow fetches approved media from private staging, validates the source and reviews, uploads media, retrieves each public object to verify its hash, uploads an immutable catalog snapshot, verifies it, stores the previous pointer in `history/`, and replaces `latest.json` last. GitHub serializes publication jobs. Use only this single writer; do not run a second local publisher concurrently.

```sh
# Environment variables are injected by the protected CI environment.
node tools/content.mjs publish --source content/catalog.json --media-dir build/approved-media
```

No publication, cloud bucket, DNS record, or hosted content has been created by the initial local implementation.

## Corrections, withdrawals, and rollback

Text correction: keep the ID, increment revision, obtain fresh approvals, publish. Changed audio: use new hash/path and audio revision; resume resets and downloads replace only after verification. Withdrawal: remove the item and its collection/journey/passage references, add the ID to `withdrawnIDs`, obtain review, publish. Clients apply withdrawals after their next successful refresh. Deleted media may remain in CDN cache or on an offline device; document the limitation in the rights review.

Rollback is another monotonic generation pointing to an earlier verified immutable snapshot. Retrieve `history/<generation>/previous.json` using the operator's authenticated tooling, inspect the exact target, and use it as the workflow's rollback pointer. Never decrement a generation or overwrite an old catalog object.

```sh
node tools/content.mjs rollback --pointer private/approved-rollback-pointer.json
```

If public retrieval fails before promotion, the existing pointer remains live. If a pointer write has an ambiguous network outcome, read both R2 and the public pointer before retrying; do not assume failure means the write did not commit. If the active pointer is bad, publish a new verified generation or perform the reviewed rollback. The client retains the last valid catalog throughout failed refreshes.

## Backups and operations

The source repository, approved masters, rights evidence, and public snapshots need separate recoverable backups. Keep at least one backup outside the delivery account. Operators should record a quarterly restore exercise: restore source/media to staging, validate checksums and approvals, publish under a test domain, verify download/range behavior, and compare the catalog to the retained source commit.

`.github/workflows/content-health.yml` checks catalog/hash and media range delivery every six hours when `CONTENT_BASE_URL` is configured. GitHub failure notifications are the initial operator alert; assign a responding owner before launch. Run a full checksum audit through a staging publication/restore for stronger integrity validation. Health checks must never include private prayer activity.

Apple crash diagnostics and a user-initiated redacted support report are the v1 support path. The report is visible before sharing and excludes titles, searches, history, and intentions. No behavioral analytics SDK is installed.
