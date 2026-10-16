# iOS development builds

This is the export and rendering foundation for the landscape iPad prototype. It does not establish device
compatibility or complete touch support. The staged project has its own mobile texture imports and signing
configuration; desktop exports continue to use their existing settings. The remaining milestones are in
[the iOS plan](../plans/ios_support.md).

## What this build changes

- iOS selects the Mobile renderer on Metal, caps at 30 fps, and allows both landscape orientations.
- The export preset targets iPad and provisionally uses iOS 16.0. This is a development deployment target,
  not a tested minimum-device promise. Its default bundle ID is `app.curseofstrahd.game`; set the final ID before
  registering the app or distributing builds.
- Mobile starts with Low graphics. All quality settings and both Classic/Modern finishes disable SSAO, SSIL,
  volumetric fog, screen-space reflections, and directional soft shadows. Shadow maps are capped at 2048 and
  shadow-casting lamps at two. High can still increase resolution and antialiasing.
- The post shader keeps depth silhouettes, palette/grade, and artistic mist. Mobile omits normal-based crease
  lines, ground variation and caustics. Without a roughness mask, water receives the scene's grade/mist. Sprite
  reflections are hidden, and their preloaded shader remains compilable without the normal/roughness buffer.
- iOS ignores external executable PCK patches. Updates to scripts must arrive in signed app releases.

Desktop Forward+ behavior is retained. This does not yet introduce touch gestures, adaptive layouts, native
save transfer, app lifecycle recovery, or App Store content delivery. Existing combat recovery remains at the
start of a round.

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

This optional inspection step works before signing or the iOS toolchain is configured:

```sh
make ios-prepare IOS_OUT=/absolute/path/to/ios-inspection
```

The output directory must be new and outside the source checkout. It contains `project/` and
`source-inventory.json`. Preparation preserves dynamic JSON/dialogue/voice resources and chapter saves, omits
raw generation inputs, and detects unexpanded Git LFS pointers. Files use APFS copy-on-write when available.
The import cache is never copied. Imported resources and all `.import` edits stay in the stage.

`project/override.cfg` enables ETC2/ASTC imports, disables desktop S3TC/BPTC imports, and supplies the app version.
`project/export_presets.cfg` contains only the iOS preset. Optional signing/version environment variables affect
the staged preset only. The inventory records source revision, dirty status, relative paths, sizes and SHA-256
hashes. It measures **source resources**, not the final PCK, app size or device memory.

Preparation is an inspection command, not a prerequisite command to run against the export's output directory.
`ios-export` creates its own fresh stage. Existing output directories are never overwritten or deleted. Keep
failed stages for diagnostics and choose a fresh directory for the next attempt.

## Export and build

```sh
IOS_TEAM_ID=YOURTEAMID IOS_BUNDLE_ID=app.curseofstrahd.game VERSION=1.0.0 IOS_BUILD=1 \
  make ios-export IOS_OUT=/absolute/path/to/ios-build-1
```

This performs preflight, stages source resources, imports in a headless editor with mobile texture formats,
and exports an Xcode project. A fresh import gets one retry if the initial class/resource registration pass
reports errors, matching the project's existing importer approach. Export errors fail even if Godot exits zero.
The import/export logs remain in the output directory.

The generated project is `xcode/CurseOfStrahd.xcodeproj`. Open it in Xcode, verify signing and provisioning, select
the connected iPad, and build/run. Use the Debug scheme configuration for development installation as needed.
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

## References

- [Godot iOS export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
- [Godot renderer capabilities](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Apple build size limits](https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes/)
- [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/), including executable updates
  and third-party content rights before public distribution.
