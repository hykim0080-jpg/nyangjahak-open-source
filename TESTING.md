# Validation and manual test plan

## Status discipline

This is a test **plan**, not a claim that all tests pass. Record only observed results. See `docs/VALIDATION.md` for the current preparation run. The original repository had manual testing notes but no automated XCTest target was found in the project.

## Static checks

Run `node scripts/check.mjs` with Node.js 20+. It checks publication-boundary files, placeholder signing/bundle settings, JSON/plist structure markers, icon references and selected source invariants. This is neither Swift compilation nor execution.

## Compile and simulator checks

- Build Debug and Release with signing disabled, keeping DerivedData outside the repository.
- Ensure Release does not define `DEBUG`.
- On an installed simulator, start the app and use the Debug face-down switch; real motion/proximity readings require a physical device.
- Confirm start, packing, carry, open, arrival, warehouse, collection, and carry-log screens.
- Test Korean and English switching and persisted language settings.
- Make a short synthetic carry; verify save/relaunch and local reset using the **sample** bundle ID only.
- Ensure any screenshots contain only synthetic sample state, never a user's actual history.

## Physical-device checks still required

- Check face-down threshold/hysteresis, proximity coverage, lifting, covering sensors, and different cases/surfaces.
- Verify focus-time, arrival-time and until-open modes, app foreground/background transitions, interruption, force-close and reopening behavior.
- Check time zones/date boundaries and the 12-hour bounds.
- Check local save recovery, app deletion and optional OS backup/restore semantics.
- Measure power/heat for longer carries; avoid claiming power savings without measurements.
- Verify touch interactions, two-finger gestures, accessibility text size, screen readers and animations.

No signing certificate, provisioning profile, device identity, App Store upload or OS security setting is required or changed as part of this preparation.
