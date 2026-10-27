# Grace at Hand

A native, guest-first Catholic prayer app for iPhone and iPad. iOS/iPadOS 18+, English, US Roman Catholic calendar. Prayer text and downloads are free; personal prayer data stays on the device.

This repository contains a working **development edition** with 25 sample recordings, core prayer text, a seven-session path, and an explicitly unreviewed sample calendar. Production archives and publication reject these fixtures. The proposed 70 recordings and 40–60 texts are a separate content-production target.

## Run locally

Use Xcode **26.0.1** (Swift **6.2**), XcodeGen **2.46.0**, Node **24.18.0**, and pnpm **11.25.0**. No service account or signing credentials are needed for the simulator.

```sh
make setup
open ios/GraceAtHand.xcodeproj
```

Choose the `GraceAtHand` scheme and an iPhone or iPad simulator. The generated Xcode project is intentionally ignored; edit `ios/project.yml`, then run `make generate`.

| Command | Purpose |
| --- | --- |
| `make generate` | Generate Swift tokens, bundle offline fixtures, generate Xcode project |
| `make build` | Build an unsigned simulator app |
| `make test` | Validate content; run Swift domain and Node publishing tests |
| `make test-ios` | Run native persistence/download tests |
| `make test-ui` | Run guest prayer, search, intention, and download flows |
| `make test-network` | Verify catalog refresh and HTTP downloads with `make preview` running |
| `make preview` | Serve a local catalog and audio on port 8787 |
| `make release-check` | Check production configuration; intentionally fails with fixtures |

Override the simulator with `make test-ios DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro'`. Tests can also run from Xcode. A physical device is required to validate file protection, background delivery, audio interruptions, and hardware routing.

For network development, run `make preview`, choose `GracePreview`, and use a simulator on this Mac. Preview serves real range-capable M4A transfers. `GraceStaging` uses an owned HTTPS content domain configured in an ignored `ios/Config/Local.xcconfig`. `Debug` and `Release` use bundled fixtures; archive uses `Production` and refuses missing release inputs.

## Repository

```text
ios/          SwiftUI app, GraceCore package, native/unit/UI tests, XcodeGen spec
shared/       Versioned content contract and semantic design tokens
content/      Development fixtures and Git-reviewed publication records
tools/        Validation, preview, token generation, publishing, rollback, health
docs/         Design coverage, architecture, content operations, release evidence
.github/      Independent content/native CI and protected publication workflow
```

Future applications belong in `android/` and `web/` once work begins. They will consume `shared/` JSON contracts and assets; neither depends on Swift models. No unused app scaffold is included.

## Implemented experience

Four stable destinations—Today, Discover, Scripture, My prayer—with native iPad sidebar/detail navigation, saved navigation paths, a persistent mini-player, full player/read-along, four Rosary sets, silence timer, local intentions, reminders, offline downloads, and support/settings. Playback uses AVPlayer, the audio session, system routing, and remote controls. Downloads verify checksums and retain text/credits. Content refresh keeps the last valid catalog.

My prayer also offers ordered routines on selected weekdays, flexible weekly prayer-day goals, an activity calendar with manual backfill/edit/delete and optional streaks, private journal/gratitude entries linked to prayers or Scripture, searchable tags, intention updates and neutral follow-up reminders, selected/all readable exports, and an optional biometric/device-passcode app lock. Practice records and writing stay local under complete file protection. Existing favorites and listening storage retain their V1 schema; original intention files upgrade without discarding writing. Progress can be hidden and activity recording disabled. These additions still require the physical-device acceptance checks in the release plan.

See [design coverage](docs/design/coverage.md), [architecture](docs/architecture.md), [content operations](docs/content-operations.md), [release checklist](docs/release.md), and [validation evidence](docs/validation.md). The supplied [design book](docs/design/reference.pdf) is a reference; its future features and mock payment controls are not launch requirements.

[View the native iPhone and iPad screen gallery](docs/design/screenshots/native-gallery.png). Local native, UI, domain, and publication checks passed; the validation record distinguishes simulator evidence from outstanding device and release checks.

## Before production

The local repository is initialized on `main` and ready to push. Floyd will create and connect the private GitHub remote; no GitHub plugin is required for local development. Configure remote ownership and protection using [CONTRIBUTING.md](CONTRIBUTING.md).

Apple team/bundle identity, Cloudflare R2 buckets/custom domain, support/privacy/contact URLs, reviewed content, named editorial/calendar owners, and final artwork review remain release inputs. CI publication is configured but has not been run against live R2. No TestFlight or App Store submission has been made.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing content or contracts. Code and content have separate licensing notices; no third-party content is implicitly relicensed.
