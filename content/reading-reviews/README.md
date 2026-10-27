# Reading approvals

No reading-library publication approvals exist yet. Source public-domain notices and
automated import checks are provenance, not editorial or legal approval.

After reviewing the exact edition and converted text, add arrays of review records
with `id`, `recordSHA256` (SHA-256 of `JSON.stringify(record)`), and `approvals` containing
real `editorial`, `theological`, `permissions`, and `accessibility` references. Review
each work, topic, and reading guide. Offline works also require `rights.offline: true`,
`rights.territory: "US"`, and no expiry. The reading library currently targets US
distribution; another territory needs a new exact-edition assessment.

Keep confidential licenses and supporting evidence outside public content output.
Never manufacture approvals or treat a fair-use label as permission for full-text
offline distribution. Set `isDevelopment` to false only after the release review.

The user authorized `developmentOnly` papal texts for local demos and personal
reading on October 27, 2026. This status records pending review; it is not a
license or approval. Before distribution, obtain exact-edition clearance and
replace that status with the documented basis, or rebuild without the development
overlay to remove the texts and their indexed bytes. Merely changing
`isDevelopment` is rejected. See `docs/reading-library.md` for the removal command.
