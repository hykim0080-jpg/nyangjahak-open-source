# Validation record

Preparation date: 2026-10-21, Asia/Seoul. The owner confirmed authority to publish the included source, translations, icon and contributor work, and explicitly approved a new Public repository and MIT licensing on this date. The LICENSE records that grant. This is not independent legal clearance. Full build/runtime verification remains blocked as described below.

## Source and changes

Prepared from the app source snapshot at commit `794a8828b7e4459a797ff40a62f64b78b04d0979` (app 1.1, build 2). Seven application Swift files, localization catalogs and privacy manifest were copied without gameplay changes. The app icon's EXIF metadata chunk was removed while retaining its compressed pixel payload; asset references were retained. Signing-team settings were cleared in both configurations, and both bundle identifiers were changed to `org.example.meowntum` to isolate the sample from the original app. The icon renderer was retained.

The new README, testing plan and technical privacy note replace the original developer-facing documents. The privacy note explicitly distinguishes local deletion from OS backup/restore. Original contact information, store screenshots, posters, sales/support pages, feature-plan drafts and Git history were excluded.

## Historical snapshot review

All ten commits listed in the source repository were acquired as complete version-pinned ZIP snapshots through observed GitHub download links and integrity-tested. Review covered 512 file-version instances, 59 distinct paths, 254 textual instances (65 unique path/content variants) and 258 PNG instances (44 unique images).

Configured pattern scans found no apparent API credentials, password/secret assignments, private keys, certificates, provisioning files or private local-home paths. A repeated support email and non-secret developer/team/bundle settings were identified and are not included as personal configuration in this candidate. Three files present only in one historical version related to StoreKit purchase/test configuration; the name WarehouseKey referred to a purchase feature, not a cryptographic secret.

Limits: version snapshots are not a complete Git object audit. Unreachable objects, other branches, author metadata, issues, releases, Actions secrets/settings, external services, pixel-level OCR and steganography were not audited. Pattern checks and metadata inspection are not proof that no sensitive content exists. The candidate starts without original Git history.

## Checks actually executed

- Xcode installation identified as 26.6 (build 17F113).
- `plutil -lint` passed for `NyangJahak.xcodeproj/project.pbxproj` and `NyangJahak/PrivacyInfo.xcprivacy`.
- `swiftc -frontend -parse NyangJahak/*.swift` passed for all seven application Swift files. This is syntax parsing only, not typechecking, linking or an app build.
- `node scripts/check.mjs` passed 19 static checks across the exact 24-file publication boundary on Node.js v26.5.0. It is not an XCTest suite or runtime test. Hash comparison confirmed that all 56 files in the downloaded original working snapshot remained unchanged and that 13 retained app text/resource/renderer files were byte-identical to source.

## [blocked] Full build and runtime verification

A Debug build was attempted with `xcodebuild`, `-sdk iphoneos`, generic iOS destination, signing disabled, and DerivedData outside the candidate. It exited 70 before compilation because this agent sandbox blocked loading a CoreSimulator framework required by Xcode's IDESimulatorFoundation plugin. A simulator enumeration attempt was blocked by the same environment boundary. This does not establish an application compile error, nor a successful build.

No first-launch repair, software reinstall, security-setting change, entitlement change, device operation or App Store submission was attempted. Do not bypass OS security to run this candidate.

Smallest next validation step: open the prepared Xcode project in a normal permitted local Xcode session and build Debug and Release for an installed simulator, then perform the TESTING.md checks. If using an automation environment, grant only the needed tool/framework access through its supported permission flow before retrying. No physical-device motion/proximity, app execution, app screenshots, power measurements or backup/restore tests were performed here.

## Rights confirmation and publication approval

The inspected original files had no root software license. The owner subsequently affirmed the authority to publish and apply MIT to the included code, translations, icon and contributing work, and explicitly approved the exact new Public repository while retaining the documented unverified-build limitation. MIT is applied in LICENSE on that basis, not as independent legal clearance. Apple platform rights and trademarks remain separate. No statement here establishes OpenAI program eligibility, external adoption or guaranteed benefits.
