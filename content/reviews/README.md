# Publication reviews

Put JSON arrays of real review records here after human review. The validator reads only `.json` files. There are no production approvals in this initial repository.

Required shape (example values are documentation, not an approval):

```json
{
  "id": "stable-content-id",
  "recordSHA256": "SHA-256 of the exact public record JSON",
  "approvals": {
    "editorial": "review reference",
    "theological": "review reference",
    "permissions": "review reference",
    "accessibility": "review reference",
    "media": "review reference"
  },
  "rights": { "worldwide": true, "offline": true }
}
```

The publishing job never copies this directory to the public bucket. Store confidential evidence separately. Read `docs/content-operations.md` for hashing, calendar IDs, rights requirements, and correction/withdrawal procedures.
