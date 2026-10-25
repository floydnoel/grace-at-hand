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

## Known release limitations

No remote GitHub repository, cloud publication, physical-device validation, TestFlight upload, or App Store submission has been completed by this implementation. Floyd will handle the private GitHub remote; the local repository is committed on `main` and ready to push. Signing, R2/domain configuration, public policy/contact/support URLs, final artwork review, and named content owners are external release inputs.

Simulator results do not prove physical-device file protection, locked playback, calls/Bluetooth/headphone behavior, background transfers after suspension, real airplane-mode relaunch, storage exhaustion, notification delivery, or cloud-backup exclusion. VoiceOver focus, keyboard/pointer behavior, iPad resizing/landscape, Reduce Motion/Transparency, and network/log privacy inspection still require the documented device review.

The app uses clearly labeled development content. The 25 recordings are short synthetic samples; the repeated daily passage and calendar are not reviewed liturgical assignments. Real rights/editorial approval, the production content target, and the release inputs in `release.md` remain required. Support is unavailable until an HTTPS destination and supported US storefront are present.
