# iOS review response — October 17, 2026

Review: [PR #5, review 5561240107](https://github.com/ashwinmahesh/CurseOfStrahd/pull/5#pullrequestreview-5561240107).
The PR is a draft. Final-source checks and native phone/tablet recovery now pass on runtime `9845f681c`; 1.0.1 remains held for performance-rejection qualification and newer-main integration.
Hourly polish was stopped at the owner's request; the current work is manual verification and review follow-up.

## Requested changes

| Concern | Change | Verification status |
| --- | --- | --- |
| Save format compatibility | Write version 2; remove the empty 2→3 step and branch-only v3 chapter fixtures. Recognize the already-issued iOS preview's version 3 envelope as a reserved legacy alias, normalize it to 2 and retain nested import/journal validation. Unknown future versions are refused. | All ten focused save-transfer regressions pass, including legacy read/import and new version-2 writes; golden saves remain in the required check. |
| Stale main/conflicts | Merge current main and resolve inventory conflict with both main's Attuned empty state and mobile paging/reset controls. | The reviewed October 17 main merge completed and all 13 focused inventory-category/wall-cutaway tests passed. Main has since advanced again: the PR currently has conflicts and needs another integration before merge. Latest required check is green (180/180). |
| Mobile inventory/shop parity | Add Attuned filtering, identified rarity and charges to mobile rows; share potion/quest category filtering on both shop sides, including the merchant-acceptance filter and rarity edges. Replace adapter access to private inventory fields with a typed composition contract. | Phone/tablet inventory parity and raw-touch shop filtering regressions pass. Mobile Sell filters are dismissible to leave the list readable; layout checks pass. Representative Inventory/Journal native routes now pass on phone/tablet; the latest native run does not cover every shop route. |
| Checkpoints consuming autosave history | Write `mobile_checkpoint` independently of all five event autosaves, preserving quicksave ownership and Honour's one-save policy. | Eight successive checkpoints preserve all five event-autosave files byte for byte; quicksave ownership and Honour single-slot regressions pass. |
| Accessibility overhead | Poll a cheap native atomic preference flag; build semantic projections only for VoiceOver, Switch Control or the explicit `--native-ui-testing` launch argument. Skip Node3D branches; registered HUD CanvasLayers beneath the world remain explicit UI roots. | Final native source compiles for device and simulator. Disabled/enabled projection and world-pruning/registered-HUD regressions pass. Final-source native recovery journeys pass on both phone and tablet. Physical-device profiling remains open. |
| Draft/status mismatch | Restore draft status and describe the current release hold. | GitHub draft status confirmed. |

## Confirmations

Normal mobile combat now offers distinct choices: **Fight, continue last action** replays the command journal; **Fight, round start** restores the independent round snapshot. Completing a fight removes only that campaign's command-continuation slot, retaining the round retry. Honour keeps one slot and does not offer an independent rewind. Existing preview files whose round-start slot contains a journal still load as command continuations. Same-second saves consistently prefer the command continuation for Continue, including ties with ordinary, checkpoint and round slots.

The 30 fps iOS cap remains. Desktop frame settings are unchanged. Native simulator software rendering and offscreen Mac Mobile/Metal captures cannot establish physical-device frame pacing, memory, battery or thermal performance; those measurements remain open rather than being inferred from the cap.

Godot 4.7.2 already supplies timestamp, system-boot-time and disk-space reasons by default. The existing packaged native simulator manifest contains them and disables tracking; the real build 2001 workflow log contains no ITMS-91053 string. That is not proof that no Apple warning email was sent, nor a direct inspection of its processed production archive. The preset now explicitly selects C617.1 (app-container file timestamps), 35F9.1 (on-device timing) and E174.1 (disk access for file writes/deletes). The archive workflow validates the actual packaged manifest and saves its hash/reasons before IPA export. The new archive-boundary regression passes with the 43-case Python tooling suite.

Sources: [Apple required-reason categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), [Godot 4.7 iOS exporter](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformios.html). The pinned exporter source and native manifest establish the actual reason-bit mapping used here.

## Smaller points and scope

- Remove unused `SaveSystem._move`; keep the existing game icon blobs and artwork unchanged.
- Update the README to distinguish processed TestFlight/App Store Connect builds from public availability.
- Keep `ios_reduce_motion` and `ios_haptics` additive and mobile-only.
- Describe the Windows rename crash window accurately: validated backups provide recovery; replacement there is not claimed to be atomic.
- Listing writes remain an explicit `workflow_dispatch` operation with reviewed manifest/media and separate provenance. A protected GitHub Environment is a useful optional follow-up; no account protection or extra approval requirement was silently introduced. No listing update or public release is part of this verification.
- Retain the existing requested PR and history rather than moving already reviewed listing commits/assets into another PR. Read `tools/release/ios_store.py`, `tests/tools/test_ios_store.py` and `docs/releases/app-store/` as a separate listing group; runtime port changes live under `ui/`, `world/`, `core/`, `combat/` and `tools/native_ios/`.

## Evidence

External records: `/Volumes/StrahdLanes/strahd-builds/ios-review-20261017/`.
Current implementation is not yet release-qualified for the reported performance rejection. Focused review regressions pass after fixing a typed-array mismatch caught by the new shop test; the original failure is retained. Required `make check` passes 180/180 plus compile/lint/validation. Two current-source native journeys pass on each phone/tablet, with eight inspected original native screenshots. See [the October 25 performance report](ios-performance-2026-10-25.md) for pinned source, simulator limitations and remaining warnings. Newer-main integration and device performance/reviewer-specific qualification remain open. Eight approved Mac offscreen wall captures were inspected in Mobile/Metal and Compatibility/OpenGL at Ravenloft gates and Tsolenka guard tower, including two camera directions each: party silhouettes remain visible through obstructing walls. Lighting differs between renderers. These are not native iOS or physical-device performance evidence. Earlier 44-case input results and the pre-review iPad pass do not qualify these new changes.
