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

## Outstanding production and hardware work

No remote GitHub repository, cloud publication, physical-device validation, TestFlight upload, or App Store submission has been completed by this implementation. Floyd will handle the private GitHub remote; the local repository is committed on `main` and ready to push. Signing, R2/domain configuration, public policy/contact/support URLs, final artwork review, and named content owners are external release inputs.

Simulator results do not prove physical-device file protection, locked playback, calls/Bluetooth/headphone behavior, background transfers after suspension, real airplane-mode relaunch, storage exhaustion, notification delivery, or cloud-backup exclusion. VoiceOver focus, keyboard/pointer behavior, iPad resizing/landscape, Reduce Motion/Transparency, and network/log privacy inspection still require the documented device review.

The app uses clearly labeled development content. The 25 recordings are short synthetic samples; the repeated daily passage and calendar are not reviewed liturgical assignments. Real rights/editorial approval, the production content target, and the release inputs in `release.md` remain required. Support is unavailable until an HTTPS destination and supported US storefront are present.
