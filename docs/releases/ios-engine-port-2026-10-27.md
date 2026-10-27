# iOS engine-split review follow-up — 27 October 2026

MR #5 is rebuilt on game main `ece5991ab7a862b8e8593be34e5dc9e18277008c`, including the physical engine move and the
later monster-art move. The original head `6ef3d7e` is preserved in the local branch/worktree
`codex/ios-support-before-engine-20261027`. The active SSD worktree is `CurseOfStrahdGame-ios-support-on-core` on
`codex/ios-support-foundation`. GitHub reports the updated MR conflict-free.

The owner requested **one MR**. The additional engine PR was closed without merging; this game MR pins published
engine commit `e5ba9d81b6c6b980ac2249b0da1d109ca51fcb10` on retained branch `codex/ios-support`, based on engine main
`ff162caf4e948ee1d49bc1b321361334ba00ab0d`. [Review the shared engine changes](https://github.com/ashwinmahesh/DungeonsAndDragonsGameEngine/compare/ff162caf4e948ee1d49bc1b321361334ba00ab0d...e5ba9d81b6c6b980ac2249b0da1d109ca51fcb10).
This owner direction replaces the review's proposed two-PR landing sequence. Engine main has not been advanced.
Keep the published engine branch reachable until its commits are incorporated into main; do not reset the game to
an engine revision without mobile support. No merge or new Apple upload is part of this follow-up.

## Review resolutions

| Review item | Resolution and evidence |
| --- | --- |
| Stale branch and modify/delete conflicts | Rebuilt the game changes on current main rather than restoring moved root folders. The final ending-screen conflict retains ArtPaths and mobile sizing together. Main's `.gitmodules`, autoload paths and asset layout remain. |
| Shared code and assets belong in the engine | Touch/controller input, adaptive UI, safe areas/keyboard avoidance, lifecycle, mobile rendering, atomic saves and combat continuation are in the engine. Generic fonts/icons/SFX and monster art follow main's engine paths. The host keeps its identity/icon, native adapter, export/signing/listing tools, campaign screens and integration/native tests. |
| Preserve campaign hooks | The port applies recovery recording around current `Campaign.module()` fight hooks and retains `CampaignLook`. Defeat copy is a CampaignModule hook; shared transfer validation no longer needs a campaign pregen, native registration is `MobileIOS`, filenames derive from the host title and checkpoint eligibility uses a host scene group. No new engine-name baseline allowance is added. |
| Shared save format and issued iOS saves | Shared writes stay at version 2; issued preview version-3 envelopes retain their narrow read alias. Golden-save and save-transfer regressions cover compatibility. |
| Checkpoint versus story autosaves | `mobile_checkpoint` does not rotate arrival/rest/victory autosaves. Command continuation, round-start retry and Honour retain distinct slot policies. |
| Accessibility traversal cost | Production projection remains gated by assistive access; native testing opts in explicitly. Collection stops at Node3D and visits registered combat canvases separately. |
| Current-main inventory and merchant feedback | Mobile keeps Attuned/inactive-attunement tags, framed rarity icons/tags and rarity filtering, with touch multi-selection and empty-filter recovery. Shops retain Potions categories and rarity edges. Raw-touch regression and original prepared phone/tablet captures are retained. |
| Main's tracked-quest HUD | Fresh checks found a retired `_objective()` call in the mobile menu/info pages. Both now use the shared desktop `followed_quest()` query, with a tracked-objective regression. |
| Wall rendering after the move | Four approved offscreen Mac Mobile/Metal and four Compatibility wall views cover inn and Death House headings. QA work lights make them geometry checks; they are not native lighting or device-performance evidence. |
| Recursive engine checkout and iOS export | Workflow initializes/verifies the submodule and explicitly fetches runtime LFS in both repositories. Export rejects an uninitialized engine before staging, inventories both revisions and handles both art roots for textures, simulator ETC2 and atlas dimensions. Main's engine export inclusion/test exclusions remain. |
| Check completeness after the split | The quick-check planner discovers changed engine tests and selects the relocated compile test. That test compiles host and engine scripts. The layout suite saves/restores display preferences so main's maximum-scale case cannot contaminate later checks; no assertions or timeouts are weakened. |
| Project settings and release scope | Main's project paths are retained, with the previously authorized iOS-only renderer, orientation and 30 fps overrides. Desktop renderer values remain. This belongs to the coordinated full-download engine-layout batch; no new release was dispatched. |
| Native evidence must match the port | A fresh full-game export uses the new layout and strict iPhone/iPad journeys. Earlier source-pinned results remain separate; see the qualification status below. |
| Authorship and hardware limits | Commits use the existing Ashwin author/committer identity without generated/coauthor trailers. Physical Metal timing/thermals, physical controller and assistive-technology sign-off, and actual Stage Manager remain unverified; the MR stays draft. |


| Earlier review follow-up | Resolution |
| --- | --- |
| Mobile inventory's private-field coupling | The mobile builder now uses the host screen's public `mobile_*` access/mutation helpers; it has no `screen._...` accesses. |
| Unused SaveSystem `_move` | Removed after the autosave rotation rewrite; no dead helper remains. |
| Required-reason API privacy declarations | The preset declares file timestamp, system boot time and disk-space reasons. The actual new simulator package contains C617.1, 35F9.1 and E174.1, with tracking disabled. The retained 1.0.1 upload log has no ITMS-91053 entry; this port has not been uploaded, so no new Apple acceptance is claimed. |
| README processing/download wording | Updated to 1.0.1 (4401), clearly distinguishing Apple processing for internal testing from a public iOS download, and distinguishing old-layout evidence from this migration. |
| Mobile settings keys | `ios_reduce_motion` and `ios_haptics` remain intentionally additive, mobile-only preferences. No device smoothness or thermal result is inferred from the 30 fps cap. |
| Atomicity on other operating systems | The `.bak` recovery path and its tests remain. Cross-platform crash atomicity has not been qualified; iOS/simulator evidence does not establish Windows filesystem behavior. |
| Listing workflow protection suggestion | Listing changes still require the explicit manual `update-listing` operation; PR CI cannot edit the listing. A new protected Environment/reviewer gate was considered but not created, and no such protection is claimed. No listing write ran in this follow-up. |
| Splitting marketing/listing changes | The owner explicitly requested one MR. Listing tools/assets remain in their separate directories within MR #5, with their existing provenance. No second review is kept open. |
| App icon blob/LFS consistency | The iOS icon remains derived from the macOS artwork, using the existing plain-blob policy for `art/ui`; marketing JPEG/video files retain their LFS policy. |

## Qualification status

The Godot resource pack uses game `20bfef880a6fa52bf2f62f9f98206cbf1eb75126` and core `e5ba9d81b6c6b980ac2249b0da1d109ca51fcb10`. The original export inventory records core E5
checked out before host `f60f2e84d` committed that exact gitlink; it is retained without relabelling. The current
branch pins E5 cleanly. Native adapter `283e32485727936829b7889077bf5690b6af22ab` is built into the final app; its source SHA-256 is
`06292b8ccaf3f1533899ec79c1cbcbfd7c6d530f7dcdb9fe8060213a49b1be74`. `native-state-refresh/runtime-equivalence.json` verifies the unchanged resource
pack/privacy file and the intentionally changed native libraries/executable. The original inventories and the separate component equivalence record remain alongside the results.

The final full simulator app is **3,250,509,834 bytes**, below 4 GB. Packaged phone landscape, all four tablet
orientations, resizable iPad policy and required-reason privacy declarations are verified. ARM64 simulator
profile `arm64-simulator-logical-points-v1` uses pinned Godot 4.7.2 source and a verified patch/library hash.
It pairs UIKit drawable scale with Godot's screen scale, keeping touch, keyboard and safe-area coordinates
consistent. The original device-engine library hash is unchanged. Desktop and physical Retina rendering
remain unchanged by that simulator accommodation. This is Compatibility/software GLES simulation; elapsed
XCTest polling/snapshot time is not a physical-device performance measurement.

The main native matrix passed **13/13 journeys: six iPhone and seven iPad, zero skipped**, followed by a second
full tablet campaign run with motion reduction initially On: **14/14 full-game case executions**. That follow-up
reproduces the original On-to-Off direction and requires the unchanged 10-second selection assertion. It changes
only a backed-up dedicated-QA preference before launch, with no test-only game commands. The original native
methods, assertions and timeouts are unchanged. Rarity recovery is an added method; its initial offscreen-checkbox
failure was corrected by scrolling to the control and adding a reachability assertion, without relaxing timing.
The separate native bridge fixture passed **4/4** semantic-state and Files tests.

The retained failures are part of the record. The first tablet combat run missed the original Actions deadline:
Replaying the exact saved journal and exercising the AI worker reached the hero, while native traces and a
process sample showed slow Retina software drawing. Lowering the 3D render scale alone did not resolve the
delay; using logical points for both the drawable and screen sizing did.
A later campaign run changed the saved motion setting but retained an old native selected state. The native
bridge now notifies clients when retained values/labels/traits change, while keeping element identities and
requesting no explicit focus target. The main matrix and exact-direction follow-up pass with that bridge.
The preserved final tablet practice journal records `start` then `ai`; the original native method never presses
End Turn, confirming that the passing run exercised an enemy-first opening. Earlier failed bundles, diagnostics
and logging-only apps remain separate from qualification. UIKit's
[custom accessibility elements](https://developer.apple.com/documentation/uikit/uiaccessibilityelement) and
[layout-change notification](https://developer.apple.com/documentation/uikit/uiaccessibility/notification/layoutchanged)
are the API references; physical VoiceOver behavior is still unverified.

Required `IMPORT_HEADLESS=1 make check JOBS=1` passed **217/217**, including compilation, 159-script lint,
2,567-file validation and target dry runs (`make-check-native-state.log`, 4m14 including orchestration).
Python iOS tooling passed **53/53**, check-planner regression **1/1**, initial focused checks **16/16**, and
separate latest-art golden-save/portrait/sprite/engine-name checks **34/34**. GitHub tooling CI passed on native
code commit `283e32485`; archive/listing jobs were skipped. Documentation-only follow-ups do not change the
qualified game/native code.

A supplemental run passed **76/77**. The Temple parlour-furniture assertion remains unresolved. Its
location/catalog/generator inputs match main, with hashes in `inherited-interior-failure.json`; no reference-main
runtime was executed. No desktop scenery or assertion was changed to make it pass.

Twenty-three original approved offscreen Mac captures retain source pairs and hashes: the first 20 use
`5f4c74019` / `ffe274a1`; the three query-fixed exploration views use `48dcd6d82` / E5. Original native XCTest PNGs
remain separate by phase, with game/core/native-bridge/profile/test/result/SHA-256 provenance in their indexes
and Obsidian. Rotation captures retain original display pixels, including upside-down device orientation;
images are not reformatted for presentation. The extracted failure-video frame is labelled diagnostic and is
not an original XCTest still or an App Store asset.

[The compact validation record](ios-engine-port-2026-10-27-validation.json) lists component pins and native cases.
Full logs, source inventories, retained failures, `.xcresult` bundles and screenshot indexes remain under
`/Volumes/StrahdLanes/strahd-builds/ios-engine-port-20261027` on the external SSD. Physical Metal frame time/memory/thermals, physical controller and assistive
technology, actual Stage Manager and Windows crash atomicity remain unqualified; MR #5 stays draft. Historical
Apple VALID 1.0.1 (4401) from `d623cd4` does not qualify this port. No merge, new upload or public App Review
submission occurred. The next new marketing patch is 1.0.2 once qualification permits a new build.
