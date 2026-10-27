# Design book coverage

Reference: `reference.pdf`, edition 01, October 24, 2026. The user's implementation plan promotes the iPad concept to launch, keeps Git-reviewed publishing, and replaces mock amount selection with an external support link. The PDF's suggestions do not authorize its future features.

| Book ID / page | Experience | Native implementation |
| --- | --- | --- |
| 01 / 3 | Welcome | Immediate guest entry; optional personalization sheet |
| 02 / 3 | Today | Time-appropriate featured prayer, passage, continuation, path, calendar, offline recovery |
| 03 / 3 | Discover | Categories, collections, prayer rows, beginner path, silence |
| 04 / 4 | Search & filters | Reversible query, duration, downloaded, family filters and empty-state reset |
| 05 / 4 | Prayer detail | Context, independent save/download, text, suitability, visible credits |
| 06 / 4 | Full player | Native audio, seek/skip/rate/routing/sleep, read-along, retry |
| 07 / 5 | Read along | Scaled reading, size controls, optional validated cue-following |
| 08 / 5 | Guided Rosary | All four mystery sets, suggested set, five decades, ten beads, explicit manual progression |
| 09 / 5 | Scripture | Local-date assignments, source/translation/numbering, save/read/listen |
| 10 / 6 | Beginner path | Seven accessible sessions; reversible completion, no streak penalty |
| 11 / 6 | My prayer | Saved prayers/passages, downloads, intentions, reminders, progress, history, settings |
| 12 / 6 | Downloads | Progress, verified offline state, retry/cancel/delete, capacity feedback, Wi-Fi policy |
| 13 / 7 | Intentions | Local add/edit/delete; protected storage and lock state |
| 14 / 7 | Reminders | Time/weekdays/prayer, permission at creation, neutral preview, quiet hours, snooze |
| 15 / 8 | Evening prayer | Matte forest player and still moon artwork |
| 16 / 7 | Settings & privacy | Appearance, text size, local controls, quiet hours, privacy/help, report, reset |
| 17 / 8 | Optional support | External action gated by configured HTTPS URL and USA storefront; no amounts or entitlement |
| 22 / 8 | Offline recovery | Bundled readable text, downloads, retry and honest unavailable-current-day copy |
| 23 / 10 | Empty intentions | Empty first-use state with one add action and no invented personal data |
| 24 / 11 | iPad | Sidebar/detail, bounded reading measure, compact fallback, native controls |

Supporting native screens include saved prayers/passages, collection lists, reading tools, reminder and intention editors, silence timer, history, privacy/help, and deletion confirmations. Sheet dismissal preserves its source navigation context.

## Visual decisions

Reconstructed semantic JSON uses ivory `#F7F6F0`, forest `#253E32`, olive `#44634D`, sage `#E9ECDF`, stone `#DCDFD2`, gold `#977645`, and the book's forest dark appearance. Swift is generated from that file. System serif replaces prototype Lora, system sans replaces Inter. No prototype font assets were supplied or copied.

The 24-point compact margin, 24-point card family, 52-point primary action minimum, 70-point playback control, and 44-point project touch target are represented in native components. Text scales and reading height is not fixed. The image, arch, and evening art have provenance in `assets.md`.

## Intentional adaptations and boundaries

- Actual sample audio durations replace the mock five/ten-minute labels; a thirteen-second sample must never be presented as a full devotional recording.
- Rosary audio is a labeled development introduction; the complete prayer sequence is available through manual text guidance. No paragraph highlight appears without valid cues.
- The sample calendar is explicitly unreviewed; repeated Psalm assignments demonstrate local-date behavior, not a liturgical publication.
- Native navigation, sheets, menus, routing, and notification permission use current platform behavior. iPad is launch scope by the user's request.
- The CMS in the book becomes Git metadata, approval records, validation, and protected publication.
- The user authorized personal practice on October 27, 2026: journal (18) and routine builder (21) now have native implementations, with additional goals/activity, private exports, intention updates, and optional app locking. Circle (19) and confession preparation (20) remain deferred.

Simulator screenshots and test evidence are recorded in `../validation.md`. Physical VoiceOver, pointer/keyboard, resizing, and device audio checks are release gates, not claims established by the PDF or simulator screenshots.
