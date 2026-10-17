# iOS App Store media and listing

The English listing in `listing.json` targets version 1.0.0 of `app.curseofstrahd.game`, App Store app 6823801189. `description.txt` is a readable copy. The manifest pins every reviewed media file by SHA-256.

Run the existing iOS workflow on `codex/ios-support-foundation` with operation `update-listing` to apply this reviewed package using the existing GitHub-held Apple credentials. The operation preserves other localizations and assets, verifies Apple processing and placement, and selects build 2001 only after Apple reports VALID. It never submits App Review, releases publicly, changes pricing, or assigns testers. `inspect-listing` only reads the current state. Receipts are retained in the workflow artifact.

## Preview provenance

The source is the website’s current `media/trailer-v4.mp4`, referenced by its checked-in page. A 30-second cut retains 0–23.2 and 69.2–76 seconds, omitting desktop HUDs and the desktop download card. Original art, narration and music remain. Both encodes preserve the image proportions with letterboxing; the last 0.8 seconds fade to black after the final narration line ends. Phone: 1920×886. Tablet: 1600×1200. H.264, 30 fps, stereo AAC, 48 kHz. The preview is website promotional footage, not a native mobile recording. Source and edit hashes are in `trailer-provenance.json`.

Music: “Dark Gothic Haunted Masquerade” by ISAo, OGA-BY 3.0. This is a shortened edit. Existing source attribution is retained in the app description.

## Icon

The iOS export uses `art/ui/app_icon_ios.png`, derived from the macOS castle-and-moon game icon. Apple obtains the listing icon from the selected build. Build 2001 is Apple VALID and selected for version 1.0.0. Its processed 1024×1024 masked and unmasked App Store icons were downloaded and visually compared with the source on 2026-10-17: both use the correct castle-and-moon game artwork. The successful preview/listing update receipt is in workflow run 39079005786.

## Native screenshots

Eight screenshots per device show Tser Pool camp, rain over Vallaki, dialogue, combat Actions, snow in Krezk, the Blue Water Inn, the misty Old Svalich Road and inventory. The website gallery informed the location choices. A roof-obscured Ravenloft candidate and an underlit Berez candidate were rejected after native visual review.

The images are unaltered `simctl` JPEG screenshots: iPhone 18 Pro Max at 2868×1320 and iPad Pro 13-inch (M5) at 2752×2064, both iOS 27.0. Native XCTest sets landscape orientation. The capture-only gallery loads real game/UI states in an isolated app and save container; it does not change production gameplay. SHA-256 hashes, source commit, device IDs, ordering and capture provenance are in `screenshot-provenance.json`.

These are native simulator presentation captures, not touch E2E or physical-device evidence. The shipping simulator compatibility fallback uses half-resolution 3D, reduced shadows and no antialiasing; physical devices use the Metal renderer. The native screenshot dimensions are retained without cropping, resizing, compositing or adding marketing overlays.
