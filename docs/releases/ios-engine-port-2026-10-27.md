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

## Qualification status

The fresh native artifact was exported from game runtime source `20bfef880a6fa52bf2f62f9f98206cbf1eb75126` and
engine `e5ba9d81b6c6b980ac2249b0da1d109ca51fcb10`. Host follow-up `f60f2e84d` records that exact engine gitlink and
adds engine LFS fetching; it changes no runtime resource. `runtime-equivalence.json` records that comparison without
relabeling the original source inventory. Later review-record changes are documentation only.

The complete simulator app is **3,250,509,754 bytes**, below 4 GB. Packaged phone landscape and all four tablet
orientations plus resizable iPad policy pass. It uses the native adapter compiled from this port and the pinned
Godot 4.7.2 simulator framework. This is Compatibility/software GLES simulation, not physical Metal qualification.

Python iOS tooling passed **50/50**, check-planner regression **1/1**, and the initial focused checks **16/16**.
The first required check's quest-query and leaked-display-preference failures are retained. Required checks are
being rerun on latest main. Native qualification includes the original 11 journeys with unchanged assertions and
timeouts, plus rarity-filter recovery on each device (13 cases total). The four finalized phone cases on the
immediately preceding source passed; the latest-main full export is getting its own results directory.

A supplemental current-main regression run passed **76/77**. The remaining Temple parlour-furniture assertion has
unchanged location/catalog/generator inputs, with hashes recorded in `inherited-interior-failure.json`. No reference
main runtime was executed, and no desktop scenery or assertion was changed. The latest asset-move golden, portrait,
sprite and engine-name regressions are also being checked separately.

Twenty-three original approved offscreen Mac captures retain individual source pairs and hashes: the first 20
use `5f4c74019` / `ffe274a1`; the three query-fixed exploration views use `48dcd6d82` / `e5ba9d81`. Native XCTest PNGs
are copied separately with source, device, test/result and SHA-256 provenance. Obsidian's iOS support note and gallery
link those indexes. Prepared macOS views, native simulator results and physical-device evidence remain distinct.

Full logs, inventories, retained failures, .xcresult bundles and screenshot indexes are under
`/Volumes/StrahdLanes/strahd-builds/ios-engine-port-20261027` on the external SSD. The existing Apple VALID 1.0.1 (4401)
source/receipt remains historical evidence for the old layout. No duplicate upload, merge or public App Review
submission occurred. Any future authorized new upload starts at marketing version 1.0.2.
