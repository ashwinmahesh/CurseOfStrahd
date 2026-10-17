# iOS support implementation

The rollout starts with a landscape iPad technical prototype. Design and verify compact iPhone and regular iPad
interfaces together throughout implementation, with full support for both required for completion. Keep desktop
layouts and behavior unchanged and the existing rules, combat and campaign code shared across platforms. The detailed
design is in the owner's Obsidian note `CurseOfStrahd/iOS Support Plan.md` (2026-10-16).

The [iOS interface and utility plan](ios_ui_and_utility.md) specifies the mobile combat action panel, targeting,
inventory, every secondary screen, native utility, accessibility, and desktop regression gates. It supersedes
the earlier sequencing that postponed compact UI design until the end of the tablet implementation.

## Current milestone

The implementation includes a universal iPhone/iPad export preset, isolated mobile asset preparation, prerequisite checks,
Xcode export/archive commands, source and app-size reports, a Mobile renderer profile and shader fallbacks,
protection against loading external executable patches on iOS, atomic save replacement, and a manual signed
archive/TestFlight workflow. See [the runbook](../releases/ios.md).

The UI implements touch routing, safe-area navigation, separate mobile campaign and Skirmish screens, inventory paging, and a dismissible combat action popup. Native Files/share, accessibility projection, interruption handling, and write-ahead campaign/practice battle recovery are implemented. Xcode, templates and simulator runtimes are installed; native Files utility tests pass on iPhone and iPad.
See the [UI progress and remaining work](ios_ui_and_utility.md#implementation-progress). Native simulator and
physical-device qualification remain open; offscreen desktop previews do not satisfy those gates.

P0 remains open until a signed build is installed and exercised on a physical iPad. Desktop rendering and
source-tree tests are evidence for the foundation, not a device qualification or a full mobile release.

## Remaining milestones

| Milestone | Next deliverable | Completion evidence |
| --- | --- | --- |
| P0 Device build | Configure iOS distribution signing and qualify the exported game | Named iPad/OS, successful exploration/dialogue/combat/save/reload, actual bundle size |
| P1 Rendering and assets | Profile real hardware, optimize textures and costly effects, decide bundle/content delivery | Matched visual captures, memory and frame-time budgets, full export inventory |
| P2 Input and layout | Touch modality, gesture arbitration, safe areas, logical point sizing, native keyboard | No duplicate input, correct modal ownership, readable compact/regular layouts |
| P3 Touch gameplay | Exploration, camera, combat preview/confirmation, targeting and reactions | Touch-only route through a demanding battle and conversation |
| P4 Recovery | Atomic save replacement, lifecycle handling, committed combat checkpoints and migrations | Fault injection, interruption/relaunch, deterministic RNG and Honour-mode checks |
| P5 iPad feature coverage | Inventory, shops, creation, progression, travel, Skirmish, save transfer and accessibility | Every feature reachable by touch, screen and campaign checklist complete |
| P6 Qualification | Device performance, thermals, CI archives, upgrades and eligible beta distribution | Minimum device/OS matrix, sustained play, clean upgrade/recovery and campaign QA |
| P7 iPhone qualification | Qualify compact layouts developed throughout P2–P5; finish finger occlusion and smaller-device tuning | Complete phone interaction/campaign pass on the chosen minimum hardware |

## Decisions to settle through the prototype

Choose the minimum OS/device from actual measurements. iOS 16.0 in the preset is provisional. Preserve the art's
palette, silhouettes and atmosphere while measuring which desktop effects can be omitted. Measure an iOS bundle
before choosing separate art/audio downloads; optional content must remain distinct from executable updates.

Round-start combat recovery is acceptable only for the prototype. The complete beta needs reliable recovery of
committed progress, including reactions, shared turns and RNG. Keep manual saves and Honour semantics intact.
Touch support must expose visible actions for context menus, inspection, camera rotation and confirmation;
multi-finger gestures and long-press cannot be the only way to perform an essential action.

Physical-device installation is the next gate. Public distribution also needs the account, rights, privacy,
age-rating and App Review preparation described in the detailed plan. Cloud save synchronization remains a
separate feature after manual cross-platform save transfer.
