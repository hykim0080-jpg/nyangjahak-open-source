# Asset provenance and license scope

## Included and approved scope

On 2026-10-21, the repository owner affirmed authority to publish and license the included source, translated text, catalog, icon and contributing work, and explicitly approved MIT licensing and a new Public repository. LICENSE applies on that basis. This affirmation is not an independent legal opinion or proof against every possible third-party claim.

- Swift source, localization strings and catalog data were taken from the reviewed source snapshot.
- `Drawing.swift`: cats/boxes are composed with SwiftUI Canvas, paths, shapes and colors. No separate cat-photo assets were found in the inspected app catalog. Code generation is a provenance indicator, not legal clearance.
- `Assets.xcassets/AppIcon.appiconset/AppIcon.png`: the only bundled PNG, taken from the original app with EXIF removed and compressed pixel data preserved. `tools/render_icon.swift` provides a Core Graphics recipe; byte-for-byte reproduction was not tested.
- Apple framework imports and runtime SF Symbols names remain subject to Apple's SDK/platform terms. MIT does not grant rights to redistribute or relicense Apple-owned assets.

## Excluded

Original AppStore screenshots, creative posters, listings/support pages, poster tooling, feature-plan drafts, personal contact information, original Git history, developer signing team, original bundle identifier, signing certificates/profiles and build output.

## Separate rights and downstream duties

MIT covers the included Software as described in LICENSE. It does not by itself grant app-name/brand/trademark rights or override Apple platform conditions. Downstream developers must review their own added content, provide accurate privacy/support materials, and use their own signing identity and bundle identifier. Report any provenance concern without posting private credentials or personal data.
