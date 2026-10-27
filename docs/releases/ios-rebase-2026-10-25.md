# iOS integration with current main — October 25, 2026

> Subsequent full-game qualification passed all eleven native phone/tablet journeys at `d623cd4bc`, and 1.0.1 (4401) processed Apple VALID. See [the final qualification and receipt](ios-qualification-2026-10-25.md). The source-pinned integration results below remain historical.

The iOS branch is rebased onto main `5ebbf0679c55078b25fc6f326c6ddcbfcc352342`. All 78 non-merge commits were replayed; the original remote tip `858ea88bcdeaccc4a3b30afebd8f464370fb7b36` is retained under `refs/backup/ios-support-before-rebase-20261025`. Main advanced three commits during integration, and those commits were included before final verification.

Runtime source for this record: `e8cd3e8ae6510b5b0ee9e1299464e5363581f157`. Later test/documentation edits do not change that runtime. This record supersedes the unresolved-main status in the [earlier QoL qualification](ios-qol-2026-10-25.md); its source-pinned native evidence remains historical.

## Integration behavior

- Retained main's current signing verification, WWDR certificate checks, palette/shader rename, guest and quest signal handling, noncombatant filtering and fight-resume behavior. The mobile renderer guard and command recovery remain.
- Retained main's concentration confirmation as a distinct command from End Turn. Mobile Drop/Keep actions use the same command, consume no turn resources and preserve concentration when cancelled.
- Mobile dialogue shows main's quest-ending consequence beside the choice before selection, retaining large busts, speaker portraits and compact text. Desktop retains main's existing warning/footer presentation.
- Mobile Journal exposes main's status filters/counts and search recovery without revealing unreached quest summaries. A short-window touch test swipes to the recovery command before tapping it.
- Mobile rest pages use main's actual choice title and explanation, including short-rest Fiendish Resilience. Shop rarity cards use a private mobile builder compatible with main's current four-argument shared row helper; desktop retains its builder.
- Retained main's Attuned/rarity/scroll inventory filters. Removed mobile test references to the WhatsNew and build-upgrade Backups features that main intentionally retired. Removed a duplicated Makefile target introduced by old merge replay.
- Kept shared save format 2 writes and the issued iOS format 3 read alias. Main's negative future-save fixture now uses a version beyond every supported schema and explicitly checks rejection, ordering and Continue behavior. Production compatibility was not changed to satisfy the test.

The quiet phone world/minimap/Menu/hold-Reveal HUD, orange touch feedback, dismissible combat Actions, desktop-style loot, compact text, icons and dialogue art remain. Desktop presentation follows current main's paths.

## Verification

| Check | Result |
| --- | --- |
| Required `IMPORT_HEADLESS=1 make check JOBS=3` | **212/212 passed**, 1m40s; every script compiles, 156 standalone scripts lint, 2,564 data files and rules docs validate; iOS target dry runs pass. |
| Focused current-main regressions | **85/85 passed** in 17s: concentration, noncombatants, step-down, guest walking, Journal search/controller, rest changes, inventory filters/scrolls and save slots. |
| New real-touch main integration checks | **4/4 passed**, also included in the required check: concentration Drop/Keep, consequence visibility, Journal filter/swipe/recovery and rest explanation. |
| iOS Python tooling | **46/46 passed**. |
| Approved offscreen captures | **15/15 rendered and inspected**: four integration views each at phone 844×390, portrait iPad 834×1194 and desktop 1600×900, plus quiet world, held Reveal and orange touch outline. Original PNGs copied unchanged and SHA-256 verified in Obsidian. |
| Git/resource audit | No missing reachable objects; nonconflicting upstream/iOS changes match the three-way integration tree. Existing LFS assets hydrated without renormalizing history. |

Evidence is under `/Volumes/StrahdLanes/strahd-builds/ios-rebase-20261025/`, including `check-final.log`, `main-regressions-final.log`, `mobile-main-final.log`, `ios-python-tests.log`, `capture-index.json`, `range-diff.txt` and `rebase.json`. Obsidian note **iOS Main Rebase - 2026-10-25** contains the separately labeled gallery.

Retained diagnostics include the initial editor import stall, successful supported headless-import fallback, shop helper arity error, the newly authored Journal test's clipped tap point and the original invalid future-save fixture failure. Final checks above pass; earlier failed logs were retained. The Journal journey was corrected to swipe to its button, without weakening assertions or extending waits.

## Evidence and release limits

These new captures are prepared offscreen macOS renders of actual screen/location classes. They are not native iOS screenshots, complete player journeys or physical-device evidence. Earlier native gameplay results at `5de0c572b` and prepared native fixtures at `c376655b5` predate the rebase. They must not be relabeled as validation of this source.

Fresh native phone/tablet qualification of the rebased source remains before release, alongside Apple's detailed rejection/device/steps, physical-device Metal performance/audio/memory/thermals, native dialogue/loot/shop/Files journeys, physical controller/accessibility and actual iPad window dragging/external displays. Version 1.0.1 remains held and undispatched. No Apple upload, public submission, merge or automation restart is part of this rebase.
