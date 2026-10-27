# Rebased iOS 1.0.1 qualification — October 25, 2026

Runtime source: `d623cd4bc7656849513bd8a860442e97198918b2`, based on main `5ebbf0679c55078b25fc6f326c6ddcbfcc352342`. Work remains on `codex/ios-support-foundation`, PR #5. The owner renewed authorization for one full-game 1.0.1 App Store Connect upload after qualification; no merge or public App Review submission.

## Terrain compatibility correction

A fresh full-game native attempt after the rebase passed title interruption, then surfaced a real campaign error: the blended terrain shader requested 17 fragment samplers against the software GLES simulator's 16-unit limit. The original failed result, screenshot, saved error report, stack sample and QA Documents remain preserved.

The software-iOS variant omits four ORM samplers while retaining all four painted albedo layers, normal maps, blend controls, boundaries, macro variation and light defaults. It uses a cached shader variant only for iOS Compatibility. Desktop and physical-device Metal keep the original shader resource and ORM detail. No engine limit or error guard was relaxed.

Required `IMPORT_HEADLESS=1 make check JOBS=3`: **213/213 passed**, including lint, compilation and validation, 111 seconds. Focused terrain/material regressions: **23/23 passed**. Unchanged iOS Python tooling: **46/46 passed**; automatic PR tooling CI also passed.

Six approved offscreen renders were inspected: road and crossroads for software-style Compatibility, desktop Forward+/Metal and device-style Mobile/Metal on the Mac. The final Compatibility previews match the simulator's existing no-flora policy. Initial flora/uniform-budget diagnostics remain retained. These are prepared macOS renders, separate from native simulator screenshots and physical-device evidence.

## Native full-game qualification

**Native functional gate passed: 5/5 iPhone and 6/6 iPad journeys, zero failures/skips in the qualified set. Full-game 1.0.1 (4401) subsequently uploaded and Apple confirmed VALID.**

All five phone journeys and the first three tablet journeys passed with the original harness, assertions and waits. They exercise title/campaign background recovery, full-page return to world, combat Actions open/close/reopen and practice recovery, native software keyboard, inventory/search/rotation, equipment, camera, Journal, save/relaunch and quiet exploration/Nearby/messages.

The first tablet campaign attempt failed its unchanged ten-second Reduce extra motion selected-state assertion. The settings file persisted Off about 15 seconds before the failed assertion completed, while the displayed/accessible state was delayed. The complete failure, original recording and post-failure Documents are retained. An isolated diagnostic on the unchanged game then passed three real On/Off transitions with the same ten-second assertion; the shipping harness remains unchanged. Native stack samples show software GLES shader compilation during world entry and 2D software drawing in Settings, with no hidden 3D drawing in the Settings sample. This supports investigating delayed simulator delivery rather than changing toggle logic speculatively. The unchanged original full campaign subsequently passed, including its ten-second toggle assertion, save/relaunch and interruption recovery. Quiet exploration/Nearby/native keyboard/messages also passed, followed by exact-query retention through portrait, upside-down portrait and landscape, filter recovery and Back to the world. The earlier failure remains in the ledger alongside the successful requalification; no game change or timeout extension was made to obtain that pass.

The complete simulator app is 3,241,412,904 bytes, below 4 GB. Actual packaged orientation and privacy validation pass. The exported 1024 icon is byte-identical to the iOS castle/moon art derived from the Mac game icon. Source inventory, native extension/engine hashes and original harness SHA-256 are retained.

Evidence: `/Volumes/StrahdLanes/strahd-builds/ios-release-1.0.1/qualification-20261025/`. Original native results remain in `terrain-fixed/`, isolated switch diagnostics in `toggle-probe/`, and distinct continuation results in `tablet-continuation/`. The Obsidian note **iOS 1.0.1 - Release Summary** links **82 unchanged native screenshots** and per-image hashes. `qualification.json` validates every finalized passing result bundle and retains references to both original failures. No MR review threads remain unresolved. Original failures are not overwritten or relabeled.

## Apple processing receipt

[Workflow 40240102630](https://github.com/ashwinmahesh/CurseOfStrahd/actions/runs/40240102630) completed successfully. The single owner-authorized full-game upload is **1.0.1 (4401)**, bundle `app.curseofstrahd.game`, App Store app `6823801189`. Game source remains `d623cd4bc7656849513bd8a860442e97198918b2`; workflow source is documentation commit `b32a6e65dce6944d3cb2086ee3d20a2b7a4fc3c9` on the existing iOS branch.

Apple's API reported **VALID** at **2026-10-25 23:51:50 UTC**, build **`3cc6697a-7884-4308-b976-f565dccdd951`**. The archived app is **3,231,159,332 bytes**, below the 4,000,000,000-byte cap. Signing, packaged privacy validation, signed IPA export and upload all passed. The complete workflow log distinguishes actual archive-job confirmation from the build-tool unit test's simulated `build-1` response.

IPA, zipped archive, raw Apple response, source inventories, toolchain, logs, actual packaged Info.plist/privacy/icon checks and per-artifact SHA-256 provenance are retained under `qualification-20261025/workflow-40240102630/` in the external release directory. `validated-release.json` records the source/build/receipt linkage. The 1024-pixel source game icon remains SHA-256 `1088a76b7ab89b9bc5c2055733c3a5d43c96beec92a3fb1af1099f20beb2dbd9`.

This is Apple build processing, distinct from App Review acceptance. No public App Review submission, tester invitations, merge or automation restart occurred. The next new marketing version is **1.0.2**, requiring current owner authorization.

## Release and evidence boundary

Native simulator functional passes do not establish device Metal timing, frame pacing, memory, thermals or audible route behavior. Apple's [OpenGL ES simulator guidance](https://developer.apple.com/library/archive/documentation/OpenGLES/Conceptual/OpenGLESHardwarePlatformGuide_iOS/OpenGLESiniOSSimulator/OpenGLESiniOSSimulator.html) explicitly separates simulator performance from device performance. No physical device is connected. AVAudioSession's synchronous-activation warning remains visible. Native dialogue/loot/shop/Files gameplay journeys, physical controller/VoiceOver/Switch Control and actual Stage Manager/external-display transitions remain broader qualification gaps.

The performance changes and earlier measurements are documented in [the performance investigation](ios-performance-2026-10-25.md); responsive composition refinements in [QoL qualification](ios-qol-2026-10-25.md); current-main behavior in [the rebase record](ios-rebase-2026-10-25.md). Earlier source-pinned results remain historical. Apple processing VALID, once achieved, is distinct from App Review approval. Hourly polishing remains stopped.
