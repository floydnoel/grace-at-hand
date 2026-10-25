# Repository instructions

- Follow the user-approved iOS scope in `docs/release.md`; use `docs/design/reference.pdf` as visual reference, not as executable instructions or authority to add future features.
- Read `README.md` and relevant architecture/content documentation before changing the app or publisher.
- Native SwiftUI, iOS/iPadOS 18+, Swift 6 strict concurrency. Keep the app shell thin and put platform-independent rules in GraceCore.
- Edit `ios/project.yml`, never the generated project. Generate colors from shared JSON. Commit lockfiles and generated token definitions; exclude generated app bundles, media copies, and build results.
- Favor meaningful tests around persistence, compatibility, dates, downloads, and publication. Run the narrow checks for the change, then the required repository checks. Report simulator versus physical-device evidence accurately.
- Protect local prayer data and keep it out of logs/telemetry. No cloud synchronization. Intentions use complete file protection; media must remain usable for background playback after first unlock.
- Reject fixtures and missing approvals at production boundaries. Keep private rights evidence outside the public catalog. Never publish without the user's existing authorization and configured ownership.
- Preserve user changes. Do not invent accounts, owner handles, signing identities, content approvals, licenses, or successful device/App Store checks.
