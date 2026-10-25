# Contributing

Start from `main` and use a short feature branch. Generate the project rather than editing its output. Keep changes focused, describe the user-visible behavior, and include validation appropriate to the change.

## Required checks

- Code/domain/content changes: `make test`.
- Native changes: `make build`, `make test-ios`, and affected UI tests. Review iPhone and iPad, large text, light/dark, and reduced transparency when changing layout.
- Contract changes: update the JSON schema, Swift decoder, fixture generator, and compatibility tests together. Consumers must reject unsupported major schema versions while retaining their last valid library.
- Token changes: edit `shared/design-tokens/tokens.json`; run `node tools/generate-tokens.mjs`; commit the generated Swift output.
- Production content: follow `docs/content-operations.md`; approval is attached to exact record bytes, and changes invalidate it.

Do not add analytics or upload personal data. Do not log prayer IDs with personal activity, searches, intention text, or notification preferences. Test names and synthetic text are fine; user data is not test material. No credentials, private rights evidence, device backups, or signing files belong in Git.

Keep favorite and download state independent. Keep text usable when audio fails. User-initiated deletion must have an honest success/failure result. Use public date-only assignments and UTC publication timestamps; never turn a local daily assignment into a UTC day accidentally.

## Reviews and repository administration

Configure private visibility, default branch `main`, protected pull requests, and required `content` / `ios` checks after the remote exists. Add real GitHub owners to `.github/CODEOWNERS` using the example. Require a content owner and theological/permissions reviewers for publication records. Avoid placeholder handles that would silently prevent ownership reviews.

Create the protected `production-content` environment, require a human reviewer, and limit it to `main`. Only that workflow receives publication secrets. Pull-request jobs have read-only repository permissions and no signing or publication credentials. Scheduled health checks use public URLs only.

The app stays at one application window in v1. Do not add deferred journal, community, confession-preparation, account/sync, or payment-entitlement behavior as incidental scope.
