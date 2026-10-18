# iOS development builds

The branch includes universal landscape iPhone/iPad builds, touch controls and mobile UI compositions, native
Files/share integration, accessibility semantics, and interruption handling. Qualification is still in progress:
full-game native journeys, physical-device performance and signed distribution
remain release gates. See [the implementation plan](../plans/ios_ui_and_utility.md).

## What this build changes

- iOS selects Mobile rendering on Metal, caps at 30 fps, and supports both landscape orientations. Simulator
  builds use Compatibility because Godot's simulator does not support Metal.
- The universal export provisionally targets iOS 16.0. This is a deployment setting, not a tested minimum-device
  promise. The default bundle ID is `app.curseofstrahd.game`.
- iOS uses the macOS castle-and-moon icon artwork and gold frame. `art/ui/app_icon_ios.png` reuses the Mac tile
  in an opaque 1024-pixel canvas without desktop padding or shadow; iOS supplies the outer mask. Regenerate it
  with `make ios-icon` (Pillow required; `ICON_PYTHON` selects its Python). Existing desktop icons are unchanged.
- Mobile starts with Low graphics. Quality settings disable unsupported SSAO/SSIL, volumetric fog, reflections,
  and directional soft shadows; shadow maps and shadow-casting lamps are capped.
- Mobile pages use safe areas, larger controls, preview/confirmation, searchable choices, and persistent Back
  navigation. Dense campaign screens and Skirmish have separate mobile compositions.
- Saves use native Files import/share, validation before import, atomic writes and backups. Exploration checkpoints
  run proactively outside open transactions. Campaign combat writes a command journal before executing each action. A restart replays the ledger through the rules engine, including pending reactions, exact RNG states and resource costs. An unwritable save holds the action behind Retry. The existing round-start slot is used, and Honour continues to use its single slot. Ordinary desktop saves retain their round-start and fresh-load-dice behavior.
- Practice combat has its own recovery file and a Resume practice battle entry, separate from campaign slots.
- Combat Actions opens only on demand. Close is always available, and aiming hides the popup before targeting.
- Exploration on iPhone shows the world, top-right minimap, Menu and hold-to-Reveal buttons. Regular iPad layouts add Party
  and Inventory shortcuts. Menu contains location/objective details, narration history, planning, camera and
  Save and settings. Desktop retains its existing exploration HUD.
- The first [combat redesign](../plans/ios_combat_ux.md) is implemented: compact actor/resources, Battle Menu,
  contextual confirmation, separate End Turn and a temporary side sheet. Native qualification and the
  remaining tablet/targeting/camera acceptance work are still open.
- iOS ignores external executable PCK patches; script updates arrive in signed app releases.

Desktop Forward+ rendering, layouts, input bindings and saved preferences retain their existing paths.

## Version policy

The next authorized iOS upload is **1.0.1**, following 1.0.0 (2001). Increment the marketing patch version
for each subsequent new upload: 1.0.2, 1.0.3, and so on, unless the owner requests a minor or major release.
Set the explicit workflow `version` input and keep the iOS preset and local exporter default aligned.
The pipeline's independent integer build number remains generated from its run number and attempt.
A retry of the same release keeps its marketing version while using a fresh build number. Versioning policy
is not authorization to upload future builds; uploads still require the owner's current instruction.
Pin the source commit, preserve the upload/Apple processing receipt, and report success after Apple VALID.

## Prerequisites

Use macOS, Godot **4.7.2 stable**, its matching `ios.zip` export template, and full Xcode with the iOS SDK.
Complete Xcode's first launch/license setup and select its developer directory. CommandLineTools alone cannot
build the app. Configure iOS development/distribution signing in Xcode for the intended route; the macOS
Developer ID certificate is a separate signing identity.

```sh
IOS_TEAM_ID=YOURTEAMID make ios-check
```

`YOURTEAMID` is a placeholder for the ten-character team ID. The check is read-only, reports all missing
prerequisites, and exits nonzero if any are missing. It does not install software, change `xcode-select`, or
claim that a provisioning profile will work. Xcode validates signing during the build.

`GODOT=/absolute/path/to/Godot` selects another engine executable. The version must match the pinned templates.
Keep at least 20 GiB free for a fresh mobile import; actual capacity needs depend on the current asset set.

## Prepare a project without Xcode

### Installing the local toolchain

Install Xcode from the Mac App Store or [Apple Developer downloads](https://developer.apple.com/download/).
Open it once, complete first-launch setup, and install iOS support and an iOS Simulator runtime under
Settings → Components (called Platforms in some Xcode versions). Then select the full tools:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
xcrun simctl list devices available
```

In Godot 4.7.2, choose **Editor → Manage Export Templates → Download and Install**. This installs matching
templates under `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`, including `ios.zip`.
Alternatively download the matching `Godot_v4.7.2-stable_export_templates.tpz` from the official release and
choose **Install from File** in that dialog. The CI workflow installs and verifies these files automatically.

### Inspecting a stage

This optional inspection step works before signing or the iOS toolchain is configured:

```sh
make ios-prepare IOS_OUT=/absolute/path/to/ios-inspection
```

The output directory must be new and outside the source checkout. It contains `project/` and
`source-inventory.json`. Preparation preserves dynamic JSON/dialogue/voice resources and chapter saves, omits
raw generation inputs, and detects unexpanded Git LFS pointers. Files use APFS copy-on-write when available.
The import cache is never copied. Imported resources and all `.import` edits stay in the stage.

The isolated `project/project.godot` enables ETC2/ASTC imports, disables desktop S3TC/BPTC imports, and supplies the app version.
Sprite atlases use Basis Universal compression with their dimensions and mip settings preserved, so frame
coordinates and world scale remain unchanged. Fullscreen cutscene stills use 85% WebP and a 2048-pixel size
limit. Creator alpha-key inputs retain their original imports. These policies modify only staged `.import`
files and are recorded in the inventory; desktop artwork and imports are unchanged. The measured complete
simulator app is 2.99 GB uncompressed, down from the initial 9.8 GB ASTC export. Device archives still require
their own size report and visual/performance qualification.
`project/export_presets.cfg` contains only the iOS preset. Optional signing/version environment variables affect
the staged preset only. The inventory records source revision, dirty status, relative paths, sizes and SHA-256
hashes. It measures **source resources**, not the final PCK, app size or device memory.

Preparation is an inspection command, not a prerequisite command to run against the export's output directory.
`ios-export` creates its own fresh stage. Existing output directories are never overwritten or deleted. Keep
failed stages for diagnostics and choose a fresh directory for the next attempt.

## Export and build

```sh
IOS_TEAM_ID=YOURTEAMID IOS_BUNDLE_ID=app.curseofstrahd.game VERSION=1.0.1 IOS_BUILD=1 \
  make ios-export IOS_OUT=/absolute/path/to/ios-build-1
```

This performs preflight, stages source resources, imports in a headless editor with mobile texture formats,
and exports an Xcode project. A fresh import gets one retry if the initial class/resource registration pass
reports errors, matching the project's existing importer approach. Export errors fail even if Godot exits zero.
The import/export logs remain in the output directory.

The generated project is `xcode/CurseOfStrahd.xcodeproj`. Open it in Xcode, verify signing and provisioning, select
the connected iPhone or iPad, and build/run. Use the Debug scheme configuration for development installation as needed.
Capture the physical model, OS, build number and renderer with each test result.

To archive the generated Release configuration after signing has been configured:

```sh
make ios-archive IOS_OUT=/absolute/path/to/ios-build-1
```

This runs `xcodebuild archive` for a generic iOS destination and writes `CurseOfStrahd.xcarchive`, `archive.log`
and `app-size.json`. It does not upload, invite testers, or publish. An existing archive is preserved. The
exported project and its stage must remain together until the build finishes.

`toolchain.json` records the Godot, Xcode and SDK versions used by export. Preserve it with the source inventory,
archive, symbols and logs. Use a fresh build number for each distributed candidate.

## Measure the actual application

```sh
make ios-report IOS_APP=/absolute/path/to/CurseOfStrahd.app
```

The command prints a JSON inventory of the built `.app`, sums its uncompressed file sizes, and exits nonzero
above the current 4 GB iOS app limit. The archive command also enforces this check. This is an early local
check; review processed device variants in App Store Connect before distribution. A compressed IPA or a source
directory is not a substitute for this measurement. The desktop README's installed size does not determine
the size of an iOS export.

There is no separate asset-download implementation in this milestone. If the full bundle is too large, use the
inventory to decide mobile texture reductions and the subsequent asset-delivery work before distribution.

## Validation

```sh
make ios-test
make test FILES=test_mobile_graphics.gd,test_patch_loader.gd,test_atmosphere.gd
make check
```

The Python suite checks stage isolation, retained dynamic resources, missing LFS content, malformed build
identity, preservation of existing output, missing-toolchain errors, logged Godot failures and actual app size
accounting. The graphics tests check capability limits and unchanged desktop presets.

To capture the Mobile renderer on the development Mac without showing a window:

```sh
make capture SCENE=res://tools/art/preview/location_tour.tscn LOCATION=village_of_barovia \
  NAME=ios_mobile_village FRAMES=30 ARGS='--lit --shots=2' \
  UNSEEN='GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/godot --path . --rendering-method mobile --rendering-driver metal --resolution 1x1 --position 100000,100000 --max-fps 30 --audio-driver Dummy'
```

Also capture `death_house_ground`, combat and wet surfaces, then compare Forward+ using the normal `make capture`
command. Desktop Metal captures verify shader compatibility and appearance, not iPad performance or touch input.
Godot's documented simulator path uses Compatibility; it does not validate this Mobile/Metal rendering path.

Before calling P0 complete, install the signed build on an iPad, run exploration/dialogue/combat/save/reload,
record startup/transition times and peak memory, and exercise interruption/relaunch. Before a wider beta,
complete touch and layout coverage, safe-area handling, reliable checkpointing, device performance, upgrade
tests, and the distribution requirements in the plan.

## GitHub signing and release pipeline

The signing and TestFlight workflow from [PR #6](https://github.com/ashwinmahesh/CurseOfStrahd/pull/6)
(commit `5a84719d5`) is integrated into this iOS branch. See [pipeline configuration](ios-pipeline.md) for
current secrets, variables, signing validation and retained artifacts. The macOS workflow is unchanged.

Dispatch **iOS builds** on `codex/ios-support-foundation` with `build_kind=game`, `version=1.0.0` and
`upload=true` to build the full game from this branch. Leave `source_ref` blank to use the workflow commit,
or pin an exact source SHA. The pipeline tests its tooling, validates credentials, imports mobile assets into
an isolated stage, archives the device app, checks the 4 GB size limit, exports the IPA and uploads to
App Store Connect. It waits for Apple's processing result; a successful upload receipt alone is insufficient.

```sh
gh workflow run ios.yml --ref codex/ios-support-foundation -f version=1.0.0 -f build_kind=game -f upload=true
```

The earlier deployment-check upload reached Apple **VALID** in
[run 38982130266](https://github.com/ashwinmahesh/CurseOfStrahd/actions/runs/38982130266), version 1.0.0 (601).
That diagnostic app excludes campaign assets. Full-game upload is being qualified separately and does not
close the documented combat UI, Level Up layout or physical-device acceptance work.

Uploads do not submit App Store review, assign testers or publish publicly. Keys are removed after every run
and excluded from retained artifacts. Signing and uploads occur only on manual dispatch, never on PR checks.

## References

- [Godot iOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Godot renderer capabilities](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Apple build size limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes/)
- [GitHub macOS signing setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [Apple Xcode components](https://developer.apple.com/documentation/Xcode/downloading-and-installing-additional-xcode-components)
- [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/), including executable updates
  and third-party content rights before public distribution.


## Unsigned simulator checks

Full Xcode and a compatible iOS simulator runtime are required; these builds do not require signing credentials:

```sh
make ios-simulator-export IOS_OUT=/absolute/path/outside/the/checkout
make ios-simulator-build IOS_OUT=/absolute/path/outside/the/checkout
```

The isolated simulator stage uses Compatibility rendering because the Godot simulator template does not support
Mobile/Metal. Device stages retain Mobile/Metal, and the desktop checkout is never rewritten. Both stages target
iPhone and iPad. Install the resulting `derived/Build/Products/Release-iphonesimulator/CurseOfStrahd.app` with
`xcrun simctl install <device-id> <app-path>`. An installed runtime may support only a subset of devices; check
`xcrun simctl list runtimes -j` before selecting an iPhone or iPad. Simulator results do not qualify Metal performance.

The software simulator renders at logical-point resolution; physical-device exports retain Retina rendering.
Both iOS paths default to Low graphics. Mobile Low uses static title artwork to avoid the title's costly
fullscreen animated effects. Simulator VRAM textures use ETC2 instead of unsupported ASTC, and particle
turbulence is disabled to avoid a software OpenGL shader-compiler stall. Other particle motion remains;
physical devices and desktop retain turbulence. The simulator also omits real-time shadows and draws the 3D
world at half the logical-point resolution with bilinear upscaling; UI stays at logical resolution. It uses
the existing simpler tree presentation instead of dense procedural flora, and omits bloom and the fullscreen
atmospheric post-process pass. Standalone practice arenas apply this same iOS graphics budget even without a
campaign Atmosphere node. World surfaces use the existing simpler cel shader with the same geometry and
textures, avoiding the software driver's costly layered relief/weather fragment shader. Simulator character art
uses one texture sample without the device shader's supersampling, ink rim or scene lighting; billboarding,
motion, atlas frames and ghost tint remain. A native GLES probe reports a 4096-pixel texture limit. Oversized simulator sprite
sheets are imported within that limit, then their pinned Godot GST2 v1 logical-size headers are restored to the
source dimensions so existing animation atlas regions remain correct. `simulator-atlas-dimensions.json` records
the adjustments; physical-device sprite textures retain their original resolution. These are simulator execution
accommodations, not the physical-device quality settings. Error capture retains Godot's known initial unsupported mouse-position probe
in the raw log but suppresses that one exact startup notification; later errors still produce a readable
mobile notice and shareable diagnostics.

Run the shipping game's XCTest journeys after building:

```sh
make ios-game-test IOS_OUT=/absolute/path/outside/the/checkout IOS_DEVICE=<existing-qa-simulator-uuid> \
  IOS_RESULT=/absolute/path/to/a-new-result.xcresult
```

The runner attaches a test target to the generated Xcode project and drives the public UI. It covers campaign
creation, inventory, camera, saving/relaunch and interruption, plus Skirmish creation, combat Actions opening
and closing, target navigation and practice recovery. Results and screenshots are retained in the `.xcresult`.
An existing result is never overwritten and simulator data is never erased. Use a dedicated QA device because
the journeys create saves and practice setups. Screenshots capture the full display to avoid stale portrait
crop bounds in the game host after landscape rotation.

The 2026-10-16 native runs use Xcode 27.1 and iOS 27.0 on iPhone 16 Pro and iPad Pro 11 M4 simulators.
Both devices pass Skirmish creation through the real software keyboard, combat Actions opening/closing/reopening,
target-list navigation, and practice recovery after terminating and relaunching the app. The separate native
utility fixture passes Files JSON export/import and picker/share cancellation on both devices. These are
bounded journeys, not a complete campaign or physical-device qualification.

The campaign journeys also report passing new-game creation, inventory/equipment, camera, journal,
save/Continue and background/resume on both devices. Those runs predate the quiet exploration HUD. Both `game-iphone-18.xcresult` and `game-ipad-18.xcresult` are now finalized and exportable, with
two passing tests and 15 screenshot attachments per device. The iPad bundle was initially incomplete while
finalization was pending; its screenshots have since been recovered.

The subsequent quiet exploration journey passes on both devices: Continue, verify the appropriate shortcuts,
Menu, Inventory, narration history, then return to the unobstructed world. Both `quiet-iphone-19.xcresult` and
`quiet-ipad-19.xcresult` finalize successfully; their native screenshots were exported and inspected.

Native campaign testing also caught a lifecycle error when backgrounding: Godot locks child lists while
propagating application notifications. Suspension now pauses play and audio immediately, then defers attaching
the resume page until notification traversal finishes. A regression invokes suspension under that same child-list
lock and verifies preservation of an existing pause and cancellation of stale deferred UI.


## Native UI screenshot gallery

`make ios-gallery` builds a separate simulator app from an existing prepared full-game simulator stage:

```sh
make ios-gallery IOS_OUT=/absolute/path/to/prepared-simulator-output \
  IOS_GALLERY_OUT=/absolute/path/to/fresh-gallery-output
xcrun simctl install <qa-device-uuid> /absolute/path/to/fresh-gallery-output/derived/Build/Products/Release-iphonesimulator/CurseOfStrahd.app
xcrun simctl launch <qa-device-uuid> app.curseofstrahd.uigallery
xcrun simctl get_app_container <qa-device-uuid> app.curseofstrahd.uigallery data
```

The gallery clones the stage, adds only the capture fixtures and support classes, and builds under the isolated
`app.curseofstrahd.uigallery` identifier. It does not replace game saves or change the production bundle ID.
Source hashes, inherited stage provenance and build logs remain in its output. Use the same engine/native cache
environment variables as the source build. The output must be fresh and outside the checkout/source output.

The app writes `Documents/gallery/manifest.json` and PNGs to its data container. Wait for `complete: true`,
check `native_ios: true`, and copy that folder before uninstalling the gallery. The 2026-10-16 run completed
84 representative UI states on each of the iPhone 16 Pro and iPad Pro 11 M4 simulators. These are actual native
viewport renders using game screen classes with prepared state, **not gameplay E2E or physical-device evidence**.
Images use the app's logical render resolution; XCTest gameplay images capture the full simulator display.
Some fixtures intentionally show empty, invalid, loading or error states, and HUD-only fixtures omit the world.

The Obsidian project note `iOS Screenshot Gallery.md` indexes all 206 native images: 168 UI fixture images and
38 gameplay images. The paired HTML gallery supports category/evidence filters and original-PNG links; six
superseded exploration HUD images are archived separately. The current quiet exploration screenshots come from
the later `quiet-*-19.xcresult` runs. Those native combat screenshots show the earlier HUD. The compact replacement has newer offscreen phone/tablet evidence; native screenshots and gameplay journeys still need refreshing.
This pass exposed a still-open Level Up class-picker layout issue: all classes share one row, causing vertical
letter wrapping on iPhone and broken labels on iPad. Capture completion is not visual acceptance.
This collection does not claim every gameplay state or include the native Files/share sheet. Original images,
source attachment manifests and SHA-256 provenance are retained in the vault's dated attachment directory.


## Native services and reproducible simulator utility tests

Export builds the iOS-only GDExtension in `tools/native_ios` from checksum-pinned godot-cpp sources. The isolated
stage receives the device/ARM64-simulator XCFramework, export plugin and an editor-only macOS stub. None are
loaded by desktop gameplay. UIKit provides Files import, save sharing (including iPad popovers), optional touch
haptics, and the accessibility projection of the active Godot page. Import reviews a bounded JSON file before
creating a new slot; sharing copies the chosen save instead of exposing its live file to another app.

`native-inventory.json` records dependency/source hashes and generated products. `IOS_NATIVE_CACHE` optionally
relocates the reusable native build cache. It contains no signing credentials. SCons is pinned in a dedicated
Python virtual environment. The standard tools required are Python 3, full Xcode, and the matching Godot editor
and export templates.

The downloaded 4.7.2 template's simulator library was Intel-only despite its universal manifest. The simulator
build helper checks the actual architectures and, only when ARM64 is missing, verifies and builds the pinned
4.7.2 engine source, then combines the two simulator slices in the generated project. It does not alter installed
templates or the device engine. `simulator-engine.json` records this provenance; `IOS_ENGINE_CACHE` relocates
the reusable engine cache. Compatibility/software rendering remains separate from device Metal qualification.

A small fixture runs real native utility UI tests without waiting for all campaign textures to import:

```sh
make ios-native-test IOS_OUT=/absolute/fresh/output IOS_DEVICE=<existing-simulator-uuid>
```

The helper creates a generated Xcode project and XCTest target, builds the extension and simulator engine,
boots the specified simulator, and tests share/picker cancellation plus JSON export/import through Files.
`tests.xcresult` retains test screenshots. It does not erase simulator data. Use a dedicated QA simulator.
This fixture qualifies the bridge, not a campaign playthrough. Full-game journeys, physical VoiceOver/Switch
Control interaction, device rendering/performance and signed distribution remain separate acceptance gates.

Local evidence, 2026-10-16: Xcode 27.1; native utility cancellation on iPhone Duo/iOS 27.1 and iPad Pro 11 M4/iOS
27.0; successful JSON Files round trips on iPhone 16 Pro and iPad Pro 11 M4, both on iOS 27.0. The complete mobile import and refreshed game export have finished; full-game native qualification is in progress.
Desktop/mobile `make check` passes 136 tests, additional menu/dice desktop regressions pass 20 tests, and native build/signing tooling passes 27 Python tests.

## Controller support on iOS

Controller support is required alongside touch on both iPhone and iPad. The implementation reuses shared
exploration/combat commands while keeping mobile layouts. D-pad Up opens the quiet exploration Menu; LB opens
combat Actions as a dismissible popup, with no action on release. Bumpers navigate mobile categories/tabs, A
selects and confirms, and B backs out. Controller text entry uses a safe-area scrolling keyboard. Page hints
follow the controller button family without adding a persistent desktop overlay to the world.

Nonzero/reassigned device IDs are accepted on iOS, including remapped and built-in UI actions. Touch takeover
clears controller holds; controller takeover cancels unfinished gestures. Mobile modals block continuous cursor,
movement and camera input underneath them. Disconnecting the active controller pauses and clears held input;
reconnecting leaves the explicit Continue screen in place. The same page can be dismissed using touch or a pad.

The iOS export declares optional ExtendedGamepad support. No controller is required, and desktop layouts/bindings
retain their prior behavior. See `docs/ui/controller.md` for controls, automated coverage and the physical-device
matrix. Synthetic input and simulator renders cannot certify Bluetooth pairing or hardware latency.

Controller validation on 2026-10-16: repository `make check` passes 144 tests; the separate desktop controller
regression run passes 66 tests; iOS tooling passes 27 Python tests. The mobile input tests include a controller
with device ID 7 to exercise reconnect-safe mappings, plus mixed touch/controller and disconnect paths.

The refreshed native gallery adds controller focus/hints, the safe-area controller keyboard, bumper category
navigation (empty Favourites state) and the disconnect/resume page. These are native UI renders with synthetic
controller input, not paired-controller hardware tests. The built simulator app's Info.plist was checked for the
optional ExtendedGamepad profile and controller-support declaration.

## Combat presentation replacement — first implementation

The compact actor card, Battle Menu, contextual commands, separated End Turn, tablet upcoming turns and
bounded dismissible Actions sheet are now implemented. See [combat UX](../plans/ios_combat_ux.md) for remaining
acceptance work. `mobile_battle_capture.tscn` captures prepared battlefield states through `make capture` on
phone/tablet desktop mobile profiles; these must not be labelled native simulator E2E. The already-dispatched
TestFlight run at `291d4350a` predates these changes.

## Two-hand camera twist and dialogue art — 2026-10-17

Two world contacts now rotate the camera continuously by their signed angular change. Clockwise and
counterclockwise twists no longer wait for a 45-degree threshold and snap by 90 degrees. Pinch zoom and
centroid pan remain available, closely meeting fingers suppress unstable angular/zoom deltas, a third contact
cannot rotate the world, and releasing a gesture never activates a square. Quarter-turn keyboard/controller
commands remain independent. Raw viewport tests exercise both directions on phone and tablet layouts.

Mobile conversations retain nearly full-height party and NPC busts at left/right, behind a smaller bottom
reading panel with a speaker portrait, scrollable dialogue and choices. Existing lighting, moods and facing apply; missing busts use portrait art.
`mobile_dialogue_capture.tscn` captures NPC, party, Narrator, choices and history on phone/tablet desktop mobile
profiles. These new changes are not included in Apple build 1201 and have not yet been qualified natively.

## Mobile UI polish and external storage — 2026-10-17

Mobile-only typography is smaller while touch targets stay 44–48 points. Loot retains the desktop-style
recipient, icon/name/weight/action rows, coins and transfer controls. Inventory, shops, spell choices and
combat actions retain their art. Pause and battle menus use compact command grids. Hold Reveal beside Menu
to show eligible interactable labels; release, drag-out and interruptions clear it. Tapping an interactable
outlines its model or animated sprite orange for 0.5 seconds, and repeated taps renew the timer.

The offscreen audit covers 84 prepared states on each mobile profile (168 renders). These are layout/art
checks, not native simulator or gameplay E2E evidence. Latest screenshots and review notes are in the vault's
`iOS Mobile UI Audit.md` and paired HTML gallery. Apple build 1201 predates this polish.

Local iOS work now lives in the existing APFS sparsebundle
`/Volumes/ASH-SSD/Worktrees/StrahdLanes.sparsebundle`, mounted at `/Volumes/StrahdLanes`:

- Worktree: `/Volumes/StrahdLanes/CurseOfStrahdGame-ios-support`
- Build outputs and toolchains: `/Volumes/StrahdLanes/strahd-builds`

Mount with `hdiutil attach /Volumes/ASH-SSD/Worktrees/StrahdLanes.sparsebundle` before using these paths.
The two former Documents paths are compatibility symlinks. The worktree is locked against pruning while
unmounted. Default native/engine caches follow the checkout's sibling `strahd-builds` directory; explicit
`IOS_NATIVE_CACHE` and `IOS_ENGINE_CACHE` overrides still work. Virtualenv commands use their interpreter
so moving the cache does not leave executable shebangs pointing at its former location.

## Discovery and search recovery — 2026-10-17

The mobile exploration menu now offers a searchable Nearby objects list using the desktop Reveal eligibility.
Rows revalidate the active location and input state before opening existing context actions, without interacting.
Held Reveal has pressed feedback and optional haptics. Inventory and combat Actions have actionable empty
search/filter states and reset list position when typing. Desktop presentation remains unchanged.

`make check` passed 165 tests plus compilation, lint and validation. Sixteen prepared phone/tablet screenshots
were captured offscreen and visually reviewed; Obsidian's “iOS UX Research and Improvements” note contains
the comparison, gallery and hashes. These are not native simulator E2E evidence and are not in Apple build 1201.
See [research and remaining qualification](../plans/ios_ux_research.md).

## Native polish refresh — October 17, 2026

Clean source `fdc4ba08d` produced 84 native UI fixture renders each on iPhone 16 Pro and iPad Pro 11-inch (M4), iOS 27.0. Both gallery manifests report complete/native iOS. The Obsidian note `iOS Native UI Gallery - 2026-10-17.md` and paired searchable HTML gallery contain all 168 screenshots, source inventory and SHA-256 hashes. They show the compact loot rows, large dialogue busts/portraits, smaller text, current Actions popup, and fixed Level Up wrapping. The original October 16 gallery remains historical evidence. HUD-only fixtures omit the world and separate command bar; they do not establish gameplay E2E.

Required checks at `0b284ea49`: 171 passed. Its accessibility-state regression fails before the fix and passes afterward. The native utility fixture passes three tests, including an existing semantic value update. At `fdc4ba08d`, both combat journeys and iPad exploration passed, but iPad campaign search timed out; iPhone campaign passed keyboard/rotation/filter clearing and reached Journal before a scrolling stall toward Save and settings prompted interruption. Those runs are not overall green. Fresh campaign qualification of the accessibility fix and corrected test navigation is pending. See the research report for findings and remaining physical-device acceptance. No new Apple build is claimed.

The subsequent clean `0b284ea49` runtime passes the stricter combat journey on both simulators, with test harness `5833363c2`. Its campaign and exploration tests remain running; current-source full-suite acceptance is still open.


### Focused native caption gallery

After preparing a fresh source stage and building `make ios-gallery`, launch the isolated gallery with:

```sh
xcrun simctl launch <qa-device-uuid> app.curseofstrahd.uigallery -- --gallery-fixture=mobile_caption
```

This captures short narration, a named speaker, long narration, its scrolled end, and Pause. Use a fresh gallery container or copy only the current manifest's files, since a focused run does not delete historical screenshots. Confirm `complete: true`, `native_ios: true`, the source inventory and all listed image hashes. It is a prepared UI fixture, not a touch playthrough. Do not run it on a device occupied by an active campaign test.


The October 17 focused caption gallery completed all five states on iPhone Duo (iOS 27.1) and iPad mini A17 Pro (iOS 27.0), from clean `3d44e2ea1`. All ten native images were reviewed and published with source inventory, complete device manifests and image hashes in Obsidian `iOS Caption Polish - 2026-10-17`. Ten matching offscreen-profile images are separately labeled. Required checks pass 172 tests. The separate gameplay run still has failed native state-observation assertions; this caption gallery is not campaign acceptance or an Apple upload.


### Switch-state accessibility and native QA — October 17

Source `1d88d21f3` gives mobile switches explicit On/Off accessibility values, retaining selection and existing touch behavior. The focused regression fails before the fix and passes after it; 42 mobile input tests and the required 173-test `make check` pass. The unchanged native bridge's expanded fixture reports four passing tests each on iPhone and iPad, covering switch state, repeated semantic updates and Files flows. Six offscreen regression captures were reviewed and preserved with hashes in Obsidian's **iOS Switch State and Native QA - 2026-10-17** note. These checks do not close the earlier full-game native query failures or physical-device acceptance. See [the research and investigation record](../plans/ios_ux_research.md#october-17-switch-state-accessibility-pass).

This follow-up is later than Apple **1.0.0 (2001)**, source `3403c8e3f`, which is VALID and selected for the App Store draft. Its existing upload was rechecked without dispatching another build. No public release or App Review submission was made.

The separate unchanged-runtime diagnostic reached settings, saved and relaunched, then failed after background/resume with `AudioOutputUnitStart failed, code: -10851`. Its finalized result is 0 passed / 1 failed; this is an unresolved native acceptance issue, not a passing campaign. Both four-case utility fixture runs finalized successfully.
