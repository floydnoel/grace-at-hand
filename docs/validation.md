# Validation evidence

Verified locally on October 24, 2026 with Xcode 26.0.1, Swift 6.2, XcodeGen 2.46.0, Node 24.18.0, and pnpm 11.25.0. Native tests ran on iOS 26.0 simulators. The deployment target is iOS/iPadOS 18.0; an iOS 18 runtime was not available for this review.

## Completed checks

| Check | Result | Evidence |
| --- | --- | --- |
| Toolchain, dependency lockfile, tokens, offline bundle, generated project | Passed `make setup` | `build/setup.log` |
| Fixture catalog and media integrity | Passed: 25 items, 730 daily assignments/calendar days | `node tools/content.mjs validate` |
| Content/publication tests | 12 passed | `build/content-tests.log` |
| Swift domain tests | 9 passed | `build/core-final.log` |
| iPhone 17 Pro native tests | 9 passed; HTTP-only test skipped in Debug and run separately below | `build/iphone-verified.log` |
| iPhone 17 Pro UI flows | 4 passed | `build/iphone-verified.log` |
| iPad Pro 11-inch (M4) native and UI flows | 9 native and 4 UI tests passed | `build/ipad-verified.log` |
| Preview catalog refresh and HTTP audio download | 1 passed, including checksum verification and reopening the saved recording | `build/network-test.log` |
| iPhone 16e accessibility configuration | Guest → player → read-along passed with the largest accessibility text size, dark appearance, and Increase Contrast | `build/accessibility-test.log` |
| Preview byte-range delivery | HTTP 206, correct Content-Range and bytes; catalog HTTP 200 and matching SHA-256 | Local loopback server on port 8787 |
| Privacy manifest | Property-list validation passed | `ios/App/Resources/PrivacyInfo.xcprivacy` |
| Production rejection | Fixture publication and incomplete production configuration rejected as intended | `build/production-rejection.log`, `build/release-rejection.log` |

Build logs and full `.xcresult` bundles are local, ignored artifacts under `build/`. CI uploads its own test results when a GitHub remote is connected; no hosted CI run is claimed here.

Domain coverage includes all four Rosary sets and complete decade counts, local dates across time zones, quiet hours and daylight-saving snooze behavior, audio-revision resume invalidation, and incompatible catalogs. Native coverage includes reopening the version-1 SwiftData store, independent favorites/history, intention deletion and unreadable/locked-store protection, interrupted transfer reconciliation, bundled media verification, offline recording selection on paused restore, invalid cached-catalog fallback, and dynamic color resolution from a rendering thread. There is no version-2 migration yet; future schema changes must add an actual migration fixture.

Publication tests cover malformed records/references/cues, private-field exclusion, corrupt/replaced audio, fixture rejection, approval hashes and required review roles, future date coverage, upload/retrieval before pointer promotion, and rollback as a new generation. These use local test doubles, not a live Cloudflare account.

The four UI flows cover guest prayer without a permission prompt, reading, search recovery, private intention creation, independent saving/downloading, Scripture, and manual Rosary progression. They run on both iPhone and iPad. The focused large-text test supplements those flows; it is not a full accessibility audit.

## Visual evidence

See the [native screen gallery](design/screenshots/native-gallery.png), [largest-text/dark/contrast gallery](design/screenshots/accessibility-gallery.png), [screen-to-design mapping](design/coverage.md), and [artwork provenance](design/assets.md). The checked-in screenshots show the development edition, with short synthetic recordings and clearly labeled sample content. They are not App Store screenshots. The focused guest test was rerun successfully on all three simulators after correcting the Today capture to wait for the destination to appear (`build/iphone-captures.log`, `build/ipad-captures.log`, `build/accessibility-captures.log`).

Reviewed native welcome, Today, detail, player, read-along, Rosary, Scripture, My prayer, and empty-intention layouts against the supplied book. iPad uses a bounded reading column and sidebar/detail navigation. The dark, largest-text review confirmed expanding text/buttons and scrollable player/reading content; long words can wrap on the narrow reading column. Final review still needs the complete device and accessibility matrix in [release.md](release.md).

## Review-fix verification

The eight review findings were addressed and checked on October 24, 2026 with the same toolchain and iOS 26 simulators. These checks use development fixtures.

| Check | Result | Evidence |
| --- | --- | --- |
| Required domain/content checks | `make test` passed: 14 Swift domain tests and 13 publication tests; fixture validation passed | `build/review-fixes-all-tests.log` |
| Simulator build | `make build` passed | `build/review-fixes-build.log` |
| Native persistence/download checks | 14 passed; the HTTP-only case skipped in Debug and passed separately below | `build/review-fixes-native-final.log` |
| HTTP catalog and verified download | `make test-network` passed, including reopening the saved recording | `build/review-fixes-network.log` |
| iPhone 17 Pro UI flows | All 5 passed, including personalization changing Today and playback | `build/review-fixes-iphone-ui-final.log` |
| iPad Pro 11-inch (M4) UI flows | All 5 passed | `build/review-fixes-ipad-ui.log` |
| iPhone 16e accessibility configuration | Guest/read-along and personalization flows passed with the largest accessibility text size, dark appearance, and Increase Contrast | `build/review-fixes-accessibility.log`, `build/review-fixes-accessibility-captures/` |
| App icon | Visually inspected the regenerated 1024 × 1024 opaque RGB PNG and the installed iPad app's compiled icon; both contain the arch-and-leaf artwork | `ios/App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |

Added regression coverage preserves an unreadable download index through startup and attempted mutations until explicit reset, retries a repaired index, reapplies transfer/quiet-hour defaults immediately after reset, and retains the matching recording, transcript, and resume revision after a catalog update and relaunch. The replacement test also completes the new download and verifies playback switches to it with a reset position. Completed recordings restore at the beginning. Domain/publication checks cover supported language agreement, all audience labels, interest-based suggestions, available-time limits, and stable defaults.

Captured normal and largest-text preference/Today layouts were inspected. The UI test targets the native switch control and verifies its selected state before asserting the suggested prayer. These focused checks do not replace the full device/accessibility matrix below.

## Personal practice verification — October 27, 2026

Implemented the user-authorized personal practice phase: ordered weekday routines, flexible weekly prayer-day goals, activity calendar and editable/backfilled manual entries, optional streaks and hidden progress, private journal/gratitude/reflection entries with content connections, tags/search, intention updates/status/follow-ups, selected/all readable exports, and optional biometric/device-passcode app locking. New private records use a separate complete-protection store; the existing SwiftData V1 schema remains unchanged. Original intention files decode with defaults for the new fields.

| Check | Result | Evidence |
| --- | --- | --- |
| Required content/domain/publication checks | `make test` passed: fixture validation, 21 Swift domain tests, 13 publication tests | `build/personal-practice-domain-tests.log` |
| Final unsigned simulator build | `make build` passed | `build/personal-practice-build-final.log` |
| Native persistence and service checks | Final suite: 24 passed, one HTTP-only case skipped in Debug; passed on iPad Pro 11-inch (M4) and iPhone 16e. Earlier focused/full native runs also passed on iPhone 17 Pro | `build/personal-practice-ipad.log`, `build/personal-practice-accessibility-final.log`, `build/personal-practice-native-tests.log` |
| iPhone 17 Pro UI | All 10 existing/new flows passed, including routines, goals, manual activity, journal export preview, and intention updates/export preview | `build/personal-practice-iphone-ui-final.log` |
| iPad UI | All five new practice flows passed; additional landscape calendar navigation passed | `build/personal-practice-ipad.log`, `build/personal-practice-ipad-landscape.log` |
| Small phone, largest accessibility text, dark, Increase Contrast | Guest/read-along and all five new practice flows passed; focused landscape calendar navigation passed after correcting the test’s system-overlay-triggering full-screen swipes. The corrected compact date typography and wrapping date heading passed a final manual-activity flow | `build/personal-practice-accessibility.log`, `build/personal-practice-accessibility-final.log`, `build/personal-practice-calendar-accessibility.log` |
| Visual review | Inspected iPhone/iPad routine, goal, calendar/activity and export screenshots, plus largest-text dark layouts and corrected date numerals | `build/practice-first-ui-captures/`, `build/practice-ipad-captures/`, `build/practice-accessibility-flow-captures/`, `build/practice-calendar-accessibility-captures/` |
| Working-tree whitespace | `git diff --check` passed | Local command |

New regression checks cover original intention decoding and update preservation; V1 favorites/bookmarks/listening retention; protected practice-store reopening and selective deletion; corrupt/unsupported files being preserved until explicit reset; locked-write refusal; idempotent playback completion; routine-scoped reading completion/undo; manual backfill/edit and future-date rejection; protected journal drafts without overwriting saved writing; authentication success/failure, persistence and relocking; Monday–Sunday goals across DST; stable recorded days/periods after travel; optional streaks and readable exports.

Authentication service tests inject a controlled authenticator and do not prove real Face ID, Touch ID or passcode behavior. Simulator checks verify backup-exclusion attributes and access guards; the complete file-protection assertion is reserved for physical devices, as in the existing intention tests. The UI checks reach export previews and confirm share/save actions; actual destination selection, device notification delivery, locked editors/exports and continued locked-screen playback remain physical/manual acceptance items in `release.md`. No real prayer writing is used in tests or logs. The iPhone 16e review settings were restored and the simulator returned to its original shutdown state.

## Initial expanded reading library verification — October 27, 2026

The initial iteration had 505 bibliographic works and 1,491 local Markdown sections: the complete 73-book Douay–Rheims Bible, three historical spiritual works, 428 papal records reconciled from the user's read-only `encyclicals` project and Vatican indexes, and a separate *Salvifici doloris* record. At that stage, 76 works were offline and papal records were source-only. The catalog completion below supersedes those counts and closes the seven recorded source-link gaps, following the user's subsequent authorization to include research texts for local demos and personal use.

| Check | Result | Evidence |
| --- | --- | --- |
| Required content/domain/publication checks | `make test` passed: both libraries validated, 26 Swift domain tests and 18 Node tests passed | `build/readings-tests-final.log` |
| Final unsigned simulator build | `make build` passed after the iPad accessibility navigation change | `build/readings-build-final.log` |
| iPhone 17 Pro native suite | 28 passed; one existing HTTP-only case skipped in Debug | `build/readings-native.log` |
| iPhone 17 Pro UI | Five existing core flows and four initial reading flows passed | `build/readings-iphone-ui-final.log` |
| iPad Pro 11-inch (M4) | Four new native and four initial reading UI cases passed; verse navigation and actual in-app dark appearance with largest accessibility text passed in focused follow-ups | `build/readings-ipad.log`, `build/readings-ipad-final.log` |
| Small phone reading UI | All five reading cases passed on iPhone 16e, including `Romans 8:18` opening at verse 18 and largest accessibility text with actual in-app dark appearance | `build/readings-small-phone.log` |
| Final iPad accessibility layout | Focused largest-text/dark reader case passed after replacing the crowded sidebar with native tabs at accessibility text sizes; final screenshots inspected | `build/readings-ipad-accessibility-final.log`, `build/readings-ipad-accessibility-captures/` |
| Production rejection | Reading publication rejects the development library; release checking also rejects the bundled development content and missing release configuration | `build/readings-production-rejection.log`, `build/readings-release-rejection.log` |
| Working-tree whitespace | `git diff --check` passed | Local command |

New domain/publication checks cover all 73 books and chapter totals, traditional Bible aliases and Psalm numbering, verse anchors, topic aliases and ranking, source-only results without excerpts, guide references, malformed/unsupported schemas, traversal, missing or corrupt files, and edition-specific publication approvals. Native checks exercise checksum verification, bundled search without network services, shelf reopening, clearing activity while retaining bookmarks, backup exclusion, and locked/corrupt shelf write refusal. Search is local; these tests do not prove an actual airplane-mode device relaunch.

Visually inspected search results, source-only documents, saved readings, chapter reading and verse jumps on iPhone/iPad, plus the small-phone and iPad dark largest-text reader captures. The final iPad tabs preserve the full reading column and legible navigation labels. Native evidence uses the same Xcode 26.0.1/iOS 26 simulator toolchain; iOS 18 and physical devices remain untested. No complete VoiceOver, keyboard, landscape/resizing, physical file-protection or hardware acceptance audit is claimed. The collection and guides remain development content pending the named reviews; no publication or permissions approval has been performed.

## Catalog completion and local research editions — October 27, 2026

The user explicitly authorized all collected papal texts offline for local development, demonstration and personal reading, with exact-edition legal clearance or removal to follow before distribution. The library now has 646 offline works and 2,061 Markdown sections, including 570 papal editions. All 486 entries in 20 refreshed Vatican index snapshots resolve exactly once; the seven former source-directory records have verified direct links and corrected dates/types. Added *Sollicita ac provida* retains all 27 numbered Latin sections. Thirty-one retained machine translations are labeled before reading; original Italian/Latin editions identify their reading language. These are research editions, not publication approvals or a claim to every papal writing in history.

| Check | Result | Evidence |
| --- | --- | --- |
| Required content/domain/publication checks | `make test` passed: 28 Swift domain tests, 19 Node tests; both libraries and all Markdown/index hashes validated | `build/readings-gap-tests-final.log` |
| Final unsigned simulator build | `make build` passed with the complete corpus and cleaned export headings | `build/readings-gap-build-final.log` |
| iPhone 17 Pro native suite | 28 passed; one existing HTTP-only case skipped in Debug | `build/readings-gap-iphone-final.log` |
| iPhone 17 Pro reading UI | All six reading flows passed: verse jump, deuterocanonical chapter navigation, offline papal body with source access, topic/save flow, largest-text dark Bible reader and largest-text light translation notice | `build/readings-gap-iphone-final.log`, `build/readings-gap-iphone-captures/` |
| iPad Pro 11-inch (M4) reading UI | All six reading flows passed with sidebar/detail at regular text sizes and native tabs at accessibility sizes | `build/readings-gap-ipad-final.log`, `build/readings-gap-ipad-captures/` |
| Final source formatting on small phone | Four native reading cases and both affected papal UI cases passed on iPhone 16e after cleaning export headings; the bundled-reading case took 1.92 seconds | `build/readings-gap-small-phone-final.log`, `build/readings-gap-small-phone-captures/` |
| Final source formatting on iPad | Both affected papal UI cases passed after the Markdown cleanup, including the largest-text light translation notice; final captures inspected | `build/readings-gap-ipad-formatting-final.log`, `build/readings-gap-ipad-formatting-captures/` |
| Source/catalog reconciliation | 569 papal catalog records plus *Salvifici doloris*, all with local editions; 486 official-index mappings; no directory fallbacks; 31 labeled retained DeepL translations | `content/readings/encyclical-inventory.json`, `catalog-corrections.json`, `development-source-lock.json` |
| Search performance | The native bundled-reading case fell from 26.01 seconds to 2.24 seconds after deferring excerpts until after ranking, using prepared text/literal matching and canceling stale searches; final Mac benchmark topic searches were 1.20–1.30 seconds | `build/readings-gap-native.log`, `build/readings-gap-iphone-final.log`, `build/readings-gap-search-benchmark.log` |
| Production and removal boundaries | Development publication rejected as intended; regression tests also reject changing only the manifest flag and prove stripped editions leave neither files nor indexed text in the generated bundle | `build/readings-gap-production-rejection.log`, `build/readings-gap-release-rejection.log`, Node tests |

The reading manifest is version 2; tests retain version-1 English compatibility and reject version-2 editions under the old schema. New checks cover prepared-text accent matches, cancellation, hidden text on source-only records, the seven corrections, exact official-index coverage, distinct same-year/same-incipit documents, retained translation notices, and malformed export-heading cleanup. All source-project access was read only; no CMS, account configuration, credentials, generated summaries, or remote publication were used.

Inspected the final small-phone and iPad papal reader and translation-notice captures. Catalog headings replace the old duplicated export headings, orphan italic markers are removed from capitalized front matter, and original source translation notes remain visible. The complete reading-flow captures also cover the largest-text dark Bible reader. These focused visual checks do not constitute the full accessibility acceptance audit.

The text payload is approximately 21.10 MiB; the index is approximately 41.13 MiB including prepared normalized text. This trades bundle size for less startup work. Source and original-edition review remain pending. Physical-device, iOS 18, actual airplane-mode relaunch, complete VoiceOver/keyboard/resizing, and legal clearance are not established by these iOS 26 simulator checks. The removal workflow is documented in [reading-library.md](reading-library.md); it also keeps unused local research files out of the next app bundle.

## Source-project backport and duplicate correction — October 27, 2026

The user subsequently requested the findings be added to the `encyclicals` project.
The backport also identified the remaining duplicate: *Firmissimam constantiam*
and *Nos es muy conocida* are one letter with two Vatican URLs. Both sources are
retained in that project, with one canonical record. The app now has 645 offline
works and 2,060 Markdown sections, including 569 papal editions (568 catalog records
plus *Salvifici doloris*). All 486 official-index entries still resolve once.
The current text payload is approximately 21.07 MiB and the index 41.07 MiB.

The source project contains 569 canonical works and 572 retained source records.
All 802 original source and summary Markdown files are preserved byte for byte.
Its local suite has eight passing tests, including repeated extraction that
preserves editor fields and source bodies. A comparison import of its expanded
index reproduces all 568 app catalog IDs with no missing or unexpected IDs.
Nine Pius XII records also inherit the source project's address classification;
their app categories, dates, IDs and reading text remain unchanged.
This supersedes the earlier collection totals; the simulator evidence above
describes the prior iteration. No CMS write or deployment is part of this backport.

`make test` passes after this reconciliation (28 Swift domain tests and 19 Node
tests), and `make generate` rebuilds the 645-work, 2,060-section bundle. Evidence:
`build/readings-backport-tests.log`, `build/readings-backport-generate.log`.

## Encyclical metadata, summaries and recovered text sync — October 27, 2026

The current bundle contains 645 offline works and 2,629 Markdown sections. All
569 papal works now have a source section and a separate English editorial
summary. The sync includes the 170 recently added source-project summaries,
curated English finding aliases, 12 corrected original document types, and the
source project's generic-letter classifications. Both archival date resolutions
are retained: *In consistorio*, April 6, 1843; *Maximis angustiis*, April 27, 1844.
The recovered Pius XII lay-apostolate address is dated October 5, 1957 and retains
its separately marked congress appendix. Its historical English translation is
distinguished from the 31 retained DeepL translations.

All 645 work IDs, all 2,060 preexisting section IDs and every guide destination
remain stable. Bible/classic manifests and their acquisition fingerprints are
unchanged. New summary sections use the existing version-2 contract and version-1
reading shelf; no stored-data migration is required. Original and converted
summary hashes are recorded independently. Comparison of 1,735 source-project
file hashes confirms that this sync did not modify the `encyclicals` project.

| Check | Result | Evidence |
| --- | --- | --- |
| Required content/domain/publication checks | `make test` passed: 30 Swift domain tests and 29 Node tests | `build/readings-sync-tests-final.log` |
| Unsigned simulator build | `make build` passed with the regenerated 645-work, 2,629-section bundle | `build/readings-sync-build-final.log` |
| iPhone 17 Pro native suite | 29 passed, one existing HTTP-only case skipped in Debug; all five reading cases passed | `build/readings-sync-native-final.log` |
| iPhone 17 Pro reading UI | All eight cases passed across the full run and targeted follow-ups: Bible/reference navigation, topic search/save, source reading, recovered body and saved summary, English summary with Latin source, DeepL/source distinction and largest-text dark reader. Final contents-row fix also passed source navigation at largest text | `build/readings-sync-iphone-ui.log`, `build/readings-sync-iphone-summary-final.log`, `build/readings-sync-iphone-contents-final.log` |
| iPad Pro 11-inch (M4) reading UI | All eight cases passed across the full run and focused contents-row follow-up, including recovered-text search/read/save and English-summary-to-Latin-source navigation at largest text | `build/readings-sync-ipad-ui.log`, `build/readings-sync-ipad-contents-final.log` |
| Bundled reading and search | Bible/topic, recovered-body phrase, Latin-document English-summary search and checksum-verified Markdown reading passed using local files; the combined native case took about 2.5 seconds | `build/readings-sync-native-final.log` |
| Source/summary persistence | Both bookmarks and the summary resume point survived reopening the protected shelf; clearing activity preserved both bookmarks | Native reading tests |
| Publication and stripping | Both source and summary remain development-only; stripping removes both files and their indexed prose; source metadata imports no approvals or private evidence | `tools/tests/encyclical-sync.test.mjs` |
| Identity and source audit | Existing work/section IDs, Bible/classics and all 486 official-index mappings preserved; 1,735 source-file fingerprints unchanged | `build/readings-sync-audit.json` |

The iPad checks exposed empty space in plain contents links that did not activate
the row. Contents labels now define a full-width rectangular hit area, including
their minimum 48-point height. Both previously missed taps passed after that fix.
Inspected iPhone and iPad light/dark and largest-text captures, including the
recovered body and English summaries. Evidence is in
`build/readings-sync-iphone-captures/`,
`build/readings-sync-iphone-summary-captures/`,
`build/readings-sync-ipad-captures/`, and
`build/readings-sync-ipad-contents-captures/`.

The text payload is approximately 22.59 MiB and the prepared search index
44.10 MiB. All summaries remain unreviewed editorial drafts. Offline search and
reading use checksum-verified bundle files, with no external search service.
These are Xcode 26.0.1 / iOS 26 simulator results; they do not establish a
physical-device or actual airplane-mode relaunch result.

## Outstanding production and hardware work

No remote GitHub repository, cloud publication, physical-device validation, TestFlight upload, or App Store submission has been completed by this implementation. Floyd will handle the private GitHub remote; the latest work remains local. Signing, R2/domain configuration, public policy/contact/support URLs, final artwork review, and named content owners are external release inputs.

Simulator results do not prove physical-device file protection, locked playback, calls/Bluetooth/headphone behavior, background transfers after suspension, real airplane-mode relaunch, storage exhaustion, notification delivery, or cloud-backup exclusion. VoiceOver focus, keyboard/pointer behavior, iPad resizing/landscape, Reduce Motion/Transparency, and network/log privacy inspection still require the documented device review.

The app uses clearly labeled development content. The 25 recordings are short synthetic samples; the repeated daily passage and calendar are not reviewed liturgical assignments. Real rights/editorial approval, the production content target, and the release inputs in `release.md` remain required. Support is unavailable until an HTTPS destination and supported US storefront are present.
