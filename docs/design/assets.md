# Asset provenance

## Cloister and olive tree

Shared source: `shared/assets/cloister.png`. Generated app copy: `ios/App/Resources/Assets.xcassets/Cloister.imageset/cloister.png` (created by `make generate`).

Created October 24, 2026 using the built-in `image_gen` tool. The PDF supplied a mood and composition reference; no absent prototype artwork was extracted or represented as an original source asset. Generation used this prompt:

> Use case: photorealistic-natural. Asset type: original hero artwork for Grace at Hand, an iOS Catholic prayer app. Create a beautiful, peaceful, warm photographic view of an ancient pale limestone monastery cloister courtyard with graceful rounded Romanesque arches and one mature olive tree with gently twisting trunk. Morning sunlight, dappled soft shadows, olive green foliage, muted ivory stone and restrained gold light. Vertical portrait composition, centered olive tree with enough architectural context for square crops; quiet foreground paving in bottom quarter for a dark UI gradient. Editorial, contemplative, natural, no people, no text, no logos, no watermark. Image only; no phone frame, app UI or typography. High detail, subtle natural texture.

Status: original development artwork; final identity/suitability/rights review required before release. Do not imply it depicts a verified monastery or place.

## Native artwork

- `ArchShape` in `Components.swift` draws the rounded architectural mask.
- Evening artwork is a still native composition of circles and the SF Symbol `moon.stars.fill`; no animated ambience or external image request.
- The provisional app icon is original arch-and-leaf geometry in `tools/create-icon.swift`, rendered through an opaque Core Graphics context to the 1024-pixel asset, using colors from the shared design tokens. Run `swift -module-cache-path build/ModuleCache tools/create-icon.swift` to reproduce it on macOS. Final brand clearance is pending.
- SF Symbols and system typography are used through Apple platform APIs. No third-party icon or font pack is bundled.

The private design reference is supplied by the user at `docs/design/reference.pdf`; its authorship and any embedded assets remain governed by their original provenance. It is not included in the built app or public content output.
