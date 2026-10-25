# Release plan and gates

## Scope

Native iPhone and iPad, iOS/iPadOS 18+, English, US Roman Catholic calendar, US App Store distribution. Guest access, free prayer and downloads, private local data, Git-reviewed content, R2 delivery, and optional external support outside playback. iPad is launch scope. Journal, prayer circles, confession preparation, routine builder, accounts/sync, full Bible, Mass readings, child profiles, widgets, Android, and web remain future work.

## Milestones

| Milestone | Local implementation | Remaining release work |
| --- | --- | --- |
| 1. Foundation | Monorepo, generated Xcode project, shared contracts/tokens, app components, CI, fixtures, navigation | Connect private GitHub remote; assign owners and protection rules |
| 2. Prayer flow | Guest entry, Today/detail/player/read-along, saving, verified downloads, persistence | Physical airplane-mode/relaunch, locked audio, calls and routing checks |
| 3. Launch coverage | 17 launch screens, two states, iPad adaptation, intentions/reminders/settings/support | Accessibility/device matrix and reviewer acceptance of every flow |
| 4. Publication/assets | Validation, immutable publication, rollback, health workflow, original development artwork | R2/domain setup, restore drill, final assets, reviewed production catalog |
| 5. Release | Configuration gate, privacy manifest, release checklist | Signing, TestFlight, screenshots/metadata, privacy audit, App Review |

## Required inputs

- GitHub user/organization, private remote, real CODEOWNERS, branch and publication-environment protection.
- Apple Developer team, owned bundle identifier, App Store Connect app, US distribution selection and signing credentials outside Git.
- Cloudflare account, separate staging/delivery buckets, scoped credentials, owned custom domain, pointer cache bypass, and operational owner.
- Public privacy policy, support contact, and optional developer-support HTTPS URL.
- Named editorial, theological, permissions, accessibility/media, and US calendar owners.
- Reviewed content target: approximately 70 recordings and 40–60 texts, with accurate credits and durable offline rights. Fixtures do not count.
- Final identity/name clearance and artwork review.

## Device acceptance

- [ ] Welcome → first prayer takes at most three taps and asks no permission.
- [ ] Fresh install offline offers core readable text. Verified downloads and transcripts work after relaunch in airplane mode.
- [ ] Play with screen locked; handle incoming call, interruption recovery, Bluetooth routing, unplugged headphones, route changes, seeking, playback speed, and end/sleep timers.
- [ ] Download over Wi-Fi; switch networks; lose connectivity; suspend/terminate/relaunch; cancel/retry; reject corrupted media; replace a revision; recover from low storage. A failed download must retain the favorite.
- [ ] Test silence deadline and optional local completion notification while backgrounded, then across relaunch.
- [ ] Test reminder permission allowed/denied, weekdays, DST/time-zone changes, quiet hours, snooze, edit and deletion.
- [ ] Verify complete file protection on a physical device and intention privacy while locked/app-switching, including an open editor. Simulator file-protection attributes are not proof of device encryption.
- [ ] Inspect network and logs: no intention text, prayer history, or behavioral telemetry. Verify cloud backup exclusion, selective deletion and complete local reset.
- [ ] Compare with the PDF at 393 × 852, then small phone, landscape, largest text, dark/light, Increase Contrast, Reduce Motion, Reduce Transparency, and reading size.
- [ ] VoiceOver labels/state/focus on all flows, including return focus after player/editor dismissal; no color-only progress information.
- [ ] iPad landscape/portrait, compact windows, resizing, keyboard focus/shortcuts, pointer controls, and bounded reading width. Single app window only.

## Production and distribution

Bundle a reviewed catalog with `CONTENT_SOURCE=content/catalog.json CONTENT_MEDIA_DIR=build/approved-media make generate`. The release check rejects fixtures, stale/missing approvals, insufficient calendar coverage, missing team/bundle identity, or missing content/privacy/contact configuration. Confirm the production bundle contains no synthetic fixture audio and no private review evidence. Run the full content and native checks, then archive `GraceAtHand` with `Production` configuration and the real signing identity.

Check the Xcode Organizer privacy report and App Store privacy answers against observed behavior. `PrivacyInfo.xcprivacy` declares the disk-space check used to refuse downloads when storage is low; see [Apple's required-reason API reference](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype). Reassess when dependencies or APIs change.

The external support action requires an HTTPS URL and StoreKit USA storefront, conveys no entitlement, and sends no prayer activity. No amount-selection or in-app donation flow is implemented. Recheck the actual destination and current [App Review Guidelines, including payment rules](https://developer.apple.com/app-store/review/guidelines/) before submission; the current US external-link provisions do not guarantee review approval.

Distribute to internal TestFlight testers, record device/accessibility evidence and content approval, produce screenshots with reviewed content, finish metadata/age rating/privacy/support links, and submit with accurate review notes explaining guest access, free content, offline downloads, and the external support behavior. Do not describe development fixture screenshots or synthetic sample recordings as final content.
