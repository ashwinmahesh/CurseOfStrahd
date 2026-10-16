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
- Mobile starts with Low graphics. Quality settings disable unsupported SSAO/SSIL, volumetric fog, reflections,
  and directional soft shadows; shadow maps and shadow-casting lamps are capped.
- Mobile pages use safe areas, larger controls, preview/confirmation, searchable choices, and persistent Back
  navigation. Dense campaign screens and Skirmish have separate mobile compositions.
- Saves use native Files import/share, validation before import, atomic writes and backups. Exploration checkpoints
  run proactively outside open transactions. Campaign combat writes a command journal before executing each action. A restart replays the ledger through the rules engine, including pending reactions, exact RNG states and resource costs. An unwritable save holds the action behind Retry. The existing round-start slot is used, and Honour continues to use its single slot. Ordinary desktop saves retain their round-start and fresh-load-dice behavior.
- Practice combat has its own recovery file and a Resume practice battle entry, separate from campaign slots.
- Combat Actions opens only on demand. Close is always available, and aiming hides the popup before targeting.
- iOS ignores external executable PCK patches; script updates arrive in signed app releases.

Desktop Forward+ rendering, layouts, input bindings and saved preferences retain their existing paths.

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
simulator app is 2.93 GB uncompressed, down from the initial 9.8 GB ASTC export. Device archives still require
their own size report and visual/performance qualification.
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

`.github/workflows/ios.yml` adds **iOS builds** alongside the desktop release workflows. It runs on a hosted
macOS runner with full Xcode, installs checksum-pinned Godot 4.7.2 and its iOS template, validates signing,
imports into an isolated stage, archives, checks the actual app size, and exports an IPA. Private keys and
provisioning profiles are removed in an `always()` cleanup step. Signing never runs for pull requests.

Configure these in the repository's **Settings → Secrets and variables → Actions**:

| Kind | Name | Value |
| --- | --- | --- |
| Variable | `IOS_BUNDLE_ID` | The explicit identifier registered for this app, such as `app.curseofstrahd.game` |
| Secret | `IOS_SIGNING_P12` | Base64 of an exported Apple Distribution certificate **with its private key**, or Apple Development for development installs |
| Secret | `IOS_SIGNING_P12_PASSWORD` | The password used when exporting that `.p12` |
| Secret | `IOS_PROVISIONING_PROFILE` | Base64 of the matching `.mobileprovision` for that bundle, certificate and distribution method |

The team ID is read from the validated provisioning profile, so no extra team secret is necessary in CI.
The existing `APPLE_DEVELOPER_ID_P12` and password continue to sign the Mac download; Developer ID cannot sign
iOS apps. The existing `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID` and `APPLE_API_KEY_P8` are reused only when
TestFlight upload is selected. Their App Store Connect role and app access must permit uploads.

The repository variable `IOS_BUNDLE_ID` is configured as `app.curseofstrahd.game`. As of 2026-10-16 the three
iOS signing secrets above are absent, and the local keychain has only the Mac Developer ID identity. The
workflow is implemented but has not produced a signed iOS archive or a TestFlight upload.

To prepare the iOS credentials, register the explicit App ID in the Apple Developer account, create/select an
Apple Distribution certificate, and export it with its private key from Keychain Access as a password-protected
`.p12`. Create an App Store Connect distribution provisioning profile for that App ID and certificate, and
download it. For direct device installation, use a Development or Ad Hoc profile containing the device UDIDs
instead, and select the corresponding workflow method. Do not revoke existing Mac certificates.

From a trusted local terminal, set secrets without pasting their values into chat or committing them:

```sh
gh variable set IOS_BUNDLE_ID --body 'app.curseofstrahd.game'
base64 -i /path/to/ios-signing.p12 | tr -d '\n' | gh secret set IOS_SIGNING_P12
gh secret set IOS_SIGNING_P12_PASSWORD
base64 -i /path/to/profile.mobileprovision | tr -d '\n' | gh secret set IOS_PROVISIONING_PROFILE
```

The password command prompts interactively. Replace the example bundle ID if the registered identifier differs.
Create the matching iOS app record in App Store Connect before uploading. The upload action does not create
that record, assign testers, submit review, or release the app publicly.

After the workflow is merged onto the default branch, run **Actions → iOS builds → Run workflow** with `upload`
off for the first signed build. Choose the method matching the provisioned profile; mismatches and expired
profiles fail before asset import. The build number is the workflow run number. Dispatch a new run for a new
upload; rerunning a successfully uploaded run would reuse its build number.

```sh
gh workflow run ios.yml -f version=1.0.0 -f method=app-store -f upload=false
# Once the signed candidate and App Store Connect app are ready:
gh workflow run ios.yml -f version=1.0.0 -f method=app-store -f upload=true
```

Each run retains the IPA, zipped archive (including symbols), toolchain/source inventories, app-size report and
logs as a GitHub artifact for 14 days. Download release candidates for longer retention. The app's distribution
profile is embedded in the signed app as normal; certificate private keys, API keys and the signing directory
are excluded from artifacts. A successful upload means Apple accepted it for processing, not that beta review
or public release has passed. Device qualification remains required before a supported release.

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
atmospheric post-process pass. A native GLES probe reports a 4096-pixel texture limit. Oversized simulator sprite
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
the journeys create saves and practice setups.


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
