# iOS rendering performance — October 25, 2026

The owner reported that App Store review rejected 1.0.0 for performance. The October 20 rejection email confirms the rejected version and submission `82818aa9-6c9e-4c9c-b198-88c97dc64585`, but does not contain the reviewer's device, steps or detailed findings. Those details were requested; the authenticated review page is unavailable through the current browser connection. The changes below address measured wasted rendering and bounded defaults, not a claim that Apple's exact failure is resolved.

## Changes

- Opaque mobile Inventory, Journal, exploration Menu/messages, pause/settings and legacy full-page screens suspend their viewport's 3D drawing. Their native-resolution 2D UI remains active. Page ownership handles nested overlays, visibility changes and deletion in either order, preserving a viewport already disabled by another owner.
- The full-screen **Ready when you are** recovery pause uses the same ownership, avoiding a paused world redraw while Continue is waiting. Resuming retains any prior page/pause ownership.
- Full-page backdrops are opaque. Dialogue with large busts, compact loot, nearby-object sheets and combat Actions retain the world. Closing an opaque page restores drawing before returning to exploration. Desktop screen paths are unchanged.
- Every iOS/Mobile preset, including saved High and Classic, disables 3D MSAA and uses FXAA with at most 75% linear world scale. A 1,440,000-pixel world budget additionally bounds Retina fill cost. The physical output size determines the budget; UI points, safe areas and touch coordinates are unchanged. Resize/rotation reapplies it without saving a new setting.
- iOS-only initial project defaults match the cheaper path so scenes do not begin with the desktop's MSAA/shadow allocation. Existing desktop presets and overrides retain their values.

This follows [Apple's Metal profiling guidance](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app/), [Godot's separate 3D resolution scaling](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html) and [Viewport.disable_3d](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-disable-3d). Physical-device profiling remains necessary; a simulator or an offscreen Mac render cannot establish device Metal frame times or thermals.

## Evidence

All measurements use the approved `make capture` path and the Mac's Mobile/Metal renderer. Paired samples retain their original logs/JSON. They are not physical iPhone/iPad measurements.

| Measurement | Result |
| --- | --- |
| Controlled 1600×900 village page, hidden world on/off | 401 → 0 world draw calls |
| Controlled 1600×900 inn page, hidden world on/off | 277 → 0 world draw calls |
| Actual revised Inventory at 2732×2064, village/inn | 0 world draw calls; closing restores both scenes |
| Retina world scale | 0.5053428, approximately 1.44 million world pixels |
| Previous Low at that output size | 3,171,852 world pixels; new budget reduces target pixel area by about 55% |
| Mac sample frame intervals | Approximately 8.2–8.4 ms in both states; no measured FPS gain is claimed on this display-paced M6 sample |
| Focused mobile regression tests | 56 passed, 0 failed |
| Required final `make check` | 180 passed, 0 failed; compile/lint/validation green, 74 seconds |
| iOS Python build-tool tests | 43 passed |

Two additional phone/tablet recovery-page captures were inspected; the actual recovery page produces zero world draw calls in both sampled locations and drawing returns after Continue. These remain offscreen Mac evidence.

Four revised Retina inventory/world captures were individually inspected. Text, icons and layouts remain readable and the world returns after the page closes. Original source images live under `captures/ios-performance-20261025/`; external evidence under `/Volumes/StrahdLanes/strahd-builds/ios-performance-20261025/`. The final full-game native candidate is pinned to clean runtime source `9845f681c6fd61601ad503dc964fe8b08e5cf316`, version **1.0.1 (1)** for local simulator QA. Finalized XCTest bundles confirm **2/2 passed on iPhone 16 Pro and 2/2 on iPad Pro 11 M4**, both iOS/iPadOS 27.0. Each runs the original three title/campaign background/return cycles and Inventory → Journal → Inventory through real native touches. The assertions/timeouts and harness hash (`0698f955a5197a75de28891d34633ca6f0d962020b5cd6930f52ad0b04cfff33`) are unchanged. Original QA saves are retained and checked byte for byte; production saves were not touched.

Both baseline bundles at `ae90a422c` also finalized successfully. The full 43,432-file final source inventory differs only in `mobile_lifecycle.gd`. No game resources were omitted. A two-second phone stack sample captured all sampled main-thread stacks in software GLES 3D rendering. Final-source runs disabled only optional Xcode `simctl diagnose` collection after tests; screenshots, assertions, test results and runtime warnings remain. This avoided a separate 600-second Xcode diagnostic wait, which is not game execution time.

Eight final-source native screenshots (recovery, Inventory, Journal and restored world on each device) were inspected in their original form. Native provenance and finalized bundles are under `native-recovery-candidate/`; the Obsidian gallery is `Attachments/iOS/2026-10-25/native-performance/`. These show functional behavior with Godot's Compatibility/software simulator renderer. [Godot's simulator limitation](https://docs.godotengine.org/en/latest/engine_details/development/compiling/compiling_for_ios.html) and [Apple's simulator guidance](https://developer.apple.com/documentation/metal/developing-metal-apps-that-run-in-simulator) explain why this cannot qualify device Metal timing or memory. Passing the original waits also does not bound the wall-clock duration of blocked XCTest snapshot queries.

Native results retain AVAudioSession's synchronous-activation warning and iPad's full-screen/orientation deprecation warning. Audio route/latency still needs hardware testing. [Apple TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key) identifies iPad dynamic-resizing/orientation migration as a follow-up; this pass does not claim that migration or all-view native coverage.


No Apple upload, App Review resubmission or merge is part of these results. The native functional gate now passes. Version 1.0.1 remains held for review-specific/physical-device performance qualification; the newer-main PR conflicts remain open. Hourly polishing remains stopped.
