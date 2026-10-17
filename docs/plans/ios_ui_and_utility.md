# iOS interface and utility plan

Status: implemented mobile screen groups; native qualification in progress, 2026-10-16. Applies to the ongoing iOS support branch and PR. This extends [the platform plan](ios_support.md) and the existing desktop UI contracts; it does not replace the desktop designs or claim that mobile qualification is complete.

The iOS game will expose the complete campaign and Skirmish through an interface designed for fingers, small displays, and interrupted sessions. iPhone and iPad layouts must be designed together. Every screen receives a mobile review, including secondary dialogs and error states. Enlarging the desktop canvas or placing it inside a scroll view is insufficient.

Latest direction, 2026-10-17: phone exploration keeps the world, top-right minimap, Menu and hold-to-Reveal;
regular tablets add compact Party/Inventory shortcuts. The [compact combat HUD](ios_combat_ux.md) is implemented,
with a dismissible Actions popup that closes before targeting. The latest polish reduces mobile text, restores
computer-style loot rows and item/spell icons, and puts near-full-height dialogue busts behind a smaller bottom
reading panel. All 84 prepared audit states have phone/tablet captures; native qualification remains separate.

## Implementation progress

The first UI batch implements safe-area pages with persistent navigation, gesture ownership and cancellation, visible world controls, a mobile inventory composition, and a combat action browser. The inventory keeps a list with larger rows, separate equipment/stash views, phone detail navigation, and independently scrolling tablet panes. The action browser provides categories, search, readable details, variant and casting-level selection, explicit commitment, and a fresh legality check. Desktop builders remain selected on computers.

Verification includes raw-touch integration tests, compact/regular layout tests, the largest existing text/interface settings, desktop inventory/controller regressions, and offscreen phone/tablet previews. These previews run on macOS; they are not native simulator or physical-device qualification.

The second UI batch adds a separate mobile battlefield HUD, reaction and confirmation sheets, turn order/log/party pages, target lists, advanced spell configuration, mobile exploration notices and party controls, conversations, character-sheet sections, creation/level-up navigation, shop inspection, rest and settings layouts. Stock option selectors and context menus now stay within the touch viewport. Keyboard avoidance and an explicit Done control are implemented. The universal iPhone/iPad export has an unsigned simulator build path; dedicated simulator runtimes and QA devices are installed. Focused checks currently pass 66 tests, including desktop layouts and mobile touch/layout cases; phone/tablet captures are recorded locally.

The native utility batch adds UIKit Files/share integration, semantic accessibility elements with current-surface validation, keyboard avoidance, mobile save review, atomic autosave rotation, optional haptics, interruption pause/resume and proactive exploration checkpoints. Native utility XCTest cancellation and Files round-trip journeys run in a dedicated fixture; these are distinct from full-game journeys.

The next screen batch adds mobile loot, service purchase review, searchable choice inspection, spell preparation, party and roster sections, wait controls, journal list-to-detail navigation, and travel pan/pinch with a searchable destination list and explicit departure. Large-text layout checks include middle/end scroll positions; raw-touch tests cover map ownership and preview/commit, stale choices, and exactly-once purchases. `make check` passes 81 focused tests, including desktop layouts. Phone/tablet captures cover these pages.

The Skirmish/secondary batch adds touch setup, reviewed field edits with undo, results, achievements, guidance, scrolling cutscene captions, endings/tallies, loading cards, and mobile tutorial navigation. Tutorial sheet and combat movement tests preserve command restrictions and campaign dice. Desktop tutorial, Skirmish, cutscene and guidance regressions pass 83 tests. The corresponding `make check` passes 87 tests, including multi-contact cancellation, stale native scrolling and read-only accessibility controls. Phone/tablet captures include map placement, captions, loading cards and ending/tally screens. The latest iPad native utility fixture passes both Files cancellation and export/import round-trip tests.

The recovery batch adds save format 3 with a write-ahead combat command journal. It restores exact dice, full character costs, shared turns, enemy turns, pending reactions and point allocation through deterministic replay. Storage failure holds the pending command until Retry succeeds. The same combat/Honour slots are used. Tests exercise JSON round trips, retry, legacy-round conversion and malformed records; the version 3 campaign golden saves were generated by 31 passing campaign/ending checks. `make check` is green for this batch, and compact/regular captures cover the storage retry screen.

The menu/performance batch adds readable mobile new-game choices and difficulty rules, Credits and update pages, a keyboard-safe cheat-code page, compact dice results, and semantic selection-card labels. Large inventories render at most 40 rows while search covers the entire bag. Skirmish and arena recovery use a separate durable practice file. Combat Actions is a temporary popup with Back and an always-visible Close button; it hides before targeting. `make check` passes 109 tests, additional desktop menu/dice regressions pass 20 tests, and native build tooling passes 24 Python tests. Native utility cancellation and Files round trips pass on both iPhone 16 Pro and iPad Pro 11 M4.

The native runtime batch adds mobile error recovery and diagnostic sharing, mouse-free touch tracking, correct modal accessibility scope, nested scrolling, touch loading hints, smaller mobile texture packaging, and reproducible shipping-game XCTest journeys. Simulator-specific texture and particle fallbacks address Apple's software OpenGL limitations; physical-device Metal and desktop rendering retain their paths.

Stages 1–4 remain under qualification. Native campaign/combat journeys report passing on both QA devices;
broader gameplay, physical accessibility, performance and a full-game signed archive remain acceptance gates.
Distribution credentials are now configured. PR #6's separate deployment-check app reached Apple VALID;
its finalized workflow/helper must be reconciled into this branch. Full iOS release qualification is not complete.

## Desktop remains unchanged

This is a release requirement, not a preference:

- Ordinary macOS, Windows, and Linux builds retain their existing screen layouts, fonts, button sizes, hotbars, menus, camera behavior, shortcuts, mouse interactions, controller navigation, graphics defaults, and saved preferences.
- Select the mobile presentation from the iOS platform. Allow a clearly marked development-only mobile preview for tests. A small desktop window, touchscreen, or controller must not silently select the mobile layout.
- Within iOS, choose compact or regular composition from the available safe area and text setting. Input modality selects hints and input handling separately. Attaching a keyboard to an iPad must not turn it into the desktop interface.
- Keep desktop builders intact where practical. Add mobile builders around shared view data and game commands. Shared rules, item legality, costs, combat outcomes, and save compatibility remain authoritative.
- Do not change global theme constants or existing preferences to make mobile fit. Mobile spacing, typography, hit areas, and graphics overrides need their own scope. Imported saves must not carry device UI settings onto another platform.
- Capture the existing desktop baseline before changing shared UI, and compare representative screens at identical resolution, UI scale, game state, and camera. Any unexplained visual or interaction difference blocks the mobile change.

Mobile pages now have dedicated compositions around shared game commands. A generic drawer listing every action and a horizontally scrolling desktop panel do not satisfy this specification.

## Layout and visual language

Preserve the game's palette, portraits, ornament, readable silhouettes, and atmosphere. Use simpler framing and fewer simultaneous panels when space is limited. Keep decorative elements outside the space needed for reading and tapping.

The following are starting design tokens to tune on devices, not measurements of the current implementation:

| Element | Mobile starting target |
| --- | --- |
| Interactive hit area | At least 44 × 44 logical points; usually 48–56 points for important buttons |
| List rows and action cards | 56–72 points high, increasing for wrapped labels |
| Separation | Usually 8–12 points between adjacent controls; extra separation around destructive actions |
| Body text | Approximately 15–16 points at the default setting |
| Supporting text | Approximately 12–14 points, with user text scaling preserved |
| Large text | Default, Large, and Extra Large presets, tested through approximately 150% body text |
| Feedback | Immediate pressed/selected state; ordinary input feedback target under 100 ms |

Apple recommends a 44-point target for frequently used game controls. Our project deliberately applies that floor to secondary interactive controls as well. Logical points must be verified against native display scale; raw texture pixels and Godot canvas units must not be assumed equivalent. [Apple game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls)

Use runtime safe areas for cutouts, the home indicator, and window chrome. Recompute after rotation, keyboard changes, and iPad window resizing. Reflow before reducing text. Regular iPad windows can show related panes together; compact and short landscape windows use one principal task at a time. Width alone is insufficient: available height and larger text can force a compact composition. Apple's layout guidance calls for respecting safe areas and adapting to resized windows. [Apple layout](https://developer.apple.com/design/human-interface-guidelines/layout)

Support both landscape directions for gameplay. iPad window layouts must remain usable when narrow or tall; this does not require a separate portrait phone gameplay design. At extreme sizes, simplify HUD and use full-page selection flows. Define the minimum supported window size from verified platform behavior rather than relying on a rotate-device message to hide inaccessible controls.

## Navigation and touch behavior

Exploration uses the minimap and one Menu button on phone; regular tablets can add Party and Inventory
shortcuts. Journal, narration, camera, planning and save/settings live inside Menu. Combat uses the separate
compact actor/resources and contextual controls defined in the combat redesign. Keep frequently used functions
within thumb reach and allow the main action side to be mirrored. Do not fill the bottom edge with every command.

Every page and sheet has a visible Back or Close action. Maintain a navigation stack: closing item details returns to the same item and scroll position; closing inventory returns to the same world selection. Back cancels the innermost transient operation first. Switching characters preserves sensible filters but clears actions that no longer apply.

Touch rules:

- Activate buttons on a valid release. Scrolling, dragging off a button, cancellation, or a second finger must not activate it.
- A contact keeps its original UI or world owner. A gesture starting inside a list cannot pan the world behind it. Closing a modal must not pass its dismissal tap into the game.
- Use single-finger world dragging to pan and pinch to zoom. Offer visible camera controls for zoom, rotation, tactical view, and recentering; multi-finger gestures are optional shortcuts.
- Expose Inspect and More actions wherever desktop uses hover or right-click. Long press is an optional shortcut, never the sole way to read a rule or perform an action.
- Drag and drop is optional convenience. Equip, transfer, assign, reorder, and place also have explicit tap workflows.
- Prevent synthetic mouse events from duplicating touch commands. Test native popup windows, selectors, sliders, text editing, scroll inertia, and nested scroll areas as well as ordinary buttons.
- Cancel active contacts on app interruption, scene changes, lost focus, or owner deletion. Restore a stable selection when appropriate, never a held input.

## Combat

### Compact battlefield and action panel

Keep the battlefield visible with a compact turn strip, active hero summary, action economy, and an Actions button. Collapse the combat log to a clearly labeled button with recent-event feedback. Party portraits and conditions open readable detail panels. Keep End Turn separate from the primary action confirmation to reduce mistakes.

Actions opens a temporary popup with large labeled buttons on both iPhone and iPad. Keep it closed during ordinary battlefield play. An always-visible Close button dismisses it from both browsing and action review; Back moves within the popup or dismisses its root. Selecting a targeted action hides the popup before targeting. It must never automatically remain open over the battlefield between actions.

The panel offers Common, Class, Spells, Items, and Reactions categories, with text search for long lists. Show action or bonus-action cost, remaining resource, range, and a concise effect on each card. Disabled choices remain inspectable and state why they cannot be used. Group variants and upcast levels in a readable second step. Preserve the chosen category and scroll position per character. Support optional favorites without hiding the complete catalog.

Selecting an action closes or minimizes the selector and enters targeting. It does not spend resources. Read-only inspection must remain available while other creatures act, without enabling illegal commands.

### Targeting and confirmation

Use the sequence: choose action → configure variant → select target or area → review → confirm. Cancel returns without resource use. The targeting UI names the acting character and action, highlights legal targets, displays cost and odds from the shared rules, and provides an explicit Cancel button.

For movement, show the route, movement cost, hazards, and opportunity attacks before Move. For attacks, show the selected creature and odds in a fixed information region away from the finger. For area effects, display a reticle plus an affected-creature list, including allies. Provide target cycling and fine adjustment controls for crowded squares and small creatures. A target picker resolves overlapping occupants; do not make the player repeatedly tap a tiny sprite.

Support every existing targeting type: self, single creature, multiple creatures, ground point, line, cone, area, jump, throw, and chained choices. Show a selected-target count and an explicit Done action when fewer than the maximum targets are legal. Revalidate before committing; if the game state changed, explain the change and require a fresh confirmation.

The primary button describes the commitment, such as “Move 20 ft,” “Attack,” or “Cast Fireball.” Avoid unlabeled confirmation icons. An especially dangerous choice, such as an area spell hitting allies, needs a clear warning in this review; ordinary actions should not acquire repetitive extra dialogs. Retain Undo Move only where the existing rules permit it.

### Reactions and turn state

Reaction prompts take precedence over ordinary action panels. Show trigger, reacting character, cost, effect, and large Use and Pass buttons. Expose Ask, Automatic, and Off policies with an inspectable explanation. Preserve existing game timing semantics; UI animation must not create a decision timer. Handle simultaneous eligible characters, resource allocation sliders, death saves, shared turns, summons, concentration, and nested reactions.

End Turn stays distinct from “finish selecting targets.” If useful resources remain, provide a concise optional warning that can be disabled. A touch tutorial teaches preview, cancellation, camera, inspection, reactions, and confirmation in context. Desktop tutorial instructions remain unchanged.

## Inventory, equipment, loot, and commerce

Keep the backpack as a list, honoring the existing inventory design. Enlarge and reorganize it; do not replace it with an icon grid.

| Task | iPhone and compact window | Regular iPad |
| --- | --- | --- |
| Browse belongings | Bag, Equipment, and Stash sections with large rows | Bag and selected-item details side by side; equipment can occupy an additional pane only when it fits |
| Inspect item | Dedicated detail page with comparison and actions | Detail pane with comparison |
| Equipment | Scrollable paper doll at readable scale, plus labeled slot selection | Larger paper doll beside bag where space allows |
| Change character | Current portrait/name opens party picker; optional previous/next | Readable party strip or picker |
| Filters and sort | Search plus a Filters sheet, active filter summary, clear/reset | Visible controls where they fit, same underlying filter state |
| Transfers | Give opens recipient picker with capacity; quantity control | Same tap flow, optional drag convenience |

An item row shows name, quantity, relevant marks, and concise weight/value information without squeezing a desktop table into the phone. Item details expose Equip, Unequip, Use, Give, Stash, Split, Junk, Drop, attunement, weapon set, and quick-slot assignment when legal. Put rare actions under More. Explain locked quest items, unidentified properties, full attunement, encumbrance, unavailable stash withdrawal, and training restrictions.

Comparison values still come from the existing character and item logic. Show words and symbols alongside positive/negative colors. Use a large quantity stepper with direct numeric entry and useful shortcuts. Confirm destructive batch actions with item count and total; ordinary inspection and equip remain fast. Preserve item identity, charges, and selection after mutations. Virtualize or reuse rows so 300+ items remain smooth.

Loot uses large item rows and clear Take, Take All, Take Gold, Give, and Stash actions with results for skipped items. Shops separate Buy and Sell on compact screens, retain the purse and selected character, show quantity and total before commitment, and preserve merchant filters and haggle behavior. Sell All Junk must preview what will be sold and preserve existing exclusions. Services show price, recipient, requirements, and effect before purchase.

## Every remaining screen

Track every screen and its subordinate dialogs as a checklist with compact capture, regular capture, touch test, large-text test, and desktop comparison. The following groups are all required:

| Screen group | Mobile treatment and required interactions |
| --- | --- |
| Title, new game, difficulty, updates | Large vertical choices, readable descriptions, continue status; no inaccessible desktop Quit flow |
| Character creation and appearance | Step-based choices, visible progress and Back/Next, preview that yields space to controls, native keyboard for names, final review before creation |
| Party, roster, approval | Character picker, readable status and relationship detail, recruit/dismiss confirmation, leadership and party order controls |
| Character sheet | Overview plus sections for attributes, skills, defenses, features, and conditions; tap any derived value for its breakdown |
| Level up and spell preparation | Guided choices, visible remaining selections and resource totals, searchable spells, inspectable prerequisites, review before committing |
| Exploration | Large party selector; visible interact, search, sneak, split/group, turn-based planning, and camera actions; crowded-object picker; accessible exits and discovered objects |
| Dialogue and cinematics | Wrapping text and large choices, scroll without advancing, speaker switching, history, skill/guidance prompts, explicit skip; portraits yield to text at large sizes |
| Journal, books, bestiary, glossary | List-to-detail navigation, scalable reading text, search and filters, tap definitions, preserved reading position and quest tracking |
| Map and travel | Pinch/pan plus visible alternatives, selectable destination list, route/time/risk summary and explicit travel confirmation |
| Rest, camp, wait | Readable party/resource summary, spell changes, costs and consequences, visible time selection and confirmation |
| Pause, settings, help | Mobile display/input settings, independent text and HUD scale, touch tutorial, controller options, visible navigation; desktop-specific options stay on desktop |
| Saves and recovery | Large slot rows with campaign/location/time, load and overwrite review, native import/export, readable compatibility and storage errors |
| Skirmish setup and results | Step-based Party/Foes/Field/Saved views, searchable lists, tap-to-place editing with preview/commit, erase and undo controls, no right-click-only tools |
| Tutorials, achievements, endings | Touch-aware coach marks, readable completion/reward screens, accessible continuation and replay paths |
| Notices, loading, bug reporting | Nonblocking status, inspectable history, meaningful progress, keyboard-safe report form, optional native share/export of diagnostics |

Secondary surfaces count: dropdown menus, context menus, quantity pickers, confirmations, dice details, nested glossary cards, loading errors, empty search results, and disabled states. A screen is incomplete if its main page fits but one of these surfaces cannot be operated.

## Native utility and interruption handling

Native keyboard support covers focus, text selection, autocorrection choices, numeric input, Done/Cancel, hardware keyboard, and keeping the active field and confirmation visible. Restore the prior layout and focus when dismissed. Unsaved creator selections or search text must survive routine resizing and app switching.

Use iOS Files import and the system share/export interface for saves. Validate an imported file before offering replacement, explain newer or invalid formats, preserve the original on failure, and handle picker cancellation. Manual desktop/iOS save transfer is required; automatic cloud synchronization remains separate work.

Checkpoint committed progress during play rather than relying on a final write when iOS suspends the app. Persist combat state at agreed transaction boundaries, including RNG and resumable reactions. On interruption, stop accepting input and audio appropriately; on return, rebuild safe-area and keyboard state and offer a clear continuation. Test termination and relaunch, not only pause/resume. Honour mode must retain its existing restrictions.

Test disk-full and interrupted writes, autosave rotation, restore from backup, app updates, and migrations. A recovery notice tells the player what was recovered. Do not expose raw filesystem paths as the normal iOS save experience.

Handle headphones, Bluetooth audio, calls, Siri, screen lock, Control Center, and background/foreground transitions. Voice and captions remain synchronized after interruptions. Offer optional haptics with a disable control and equivalent visual feedback. Keep the campaign playable offline after required content is installed. Game settings, save storage, and diagnostics need clear user-facing storage management without accidentally deleting saves.

## Accessibility and comfort

Provide independent text and interface scaling, high-contrast text backgrounds, color-independent state indicators, readable subtitles, reduced motion, and optional camera shake/flash reduction. Essential prompts stay until answered; toasts can be reviewed later. Default layouts must fit the larger text settings without shrinking text back down.

Use semantic labels, logical focus order, meaningful selected/disabled states, and accessible names for icon controls. Prototype actual VoiceOver and Switch Control access early, including world-target selection through lists. Verify the shipped Godot/native accessibility bridge on devices; native accessibility support cannot be claimed from visual readability or controller support alone. If a bridge is needed, include it in implementation and qualification. Apple recommends equivalent visual cues for audio information and avoiding timed dismissal that impedes assistive navigation. [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

Controller, keyboard, pointer, and touch can coexist on iPad. Changing the active device updates prompts and focus without losing selections or creating accidental actions. Test controller disconnect during targeting and dialogs. A physical controller is never required to complete the game.

## Implementation structure

Use `MobileDevice` for platform, available geometry, scale, and modality; `TouchGesture` and `TouchRouter` for arbitration; and reusable mobile pages, sheets, large selectors, list rows, and confirmation controls. Keep UI scale separate from 3D render resolution. Introduce explicit modal ownership and a navigation stack rather than relying on unrelated panels to synthesize Escape at one another.

`CombatHud`, `InventoryScreen`, and other dense screens should choose desktop or mobile composition while sharing presentation data and command handlers. Mobile controls should call stable command interfaces, not reach into private scene methods or recompute game rules. Every command rechecks legality at commit. Expensive list rebuilding and per-frame layout work should be driven by changes instead.

Before adding more screens, audit the experimental branch for global scale changes, duplicate hotbars, fixed-width content, direct private-method calls, popup-window handling, and stale closures when a scene changes. Replace temporary horizontal scrolling of whole pages with actual responsive composition. Horizontal scrolling remains appropriate for a turn order, map, or deliberate short tab strip.

## Delivery sequence and acceptance gates

| Stage | Deliverable | Required evidence |
| --- | --- | --- |
| 1 Baselines and shared controls | Desktop baselines, screen inventory, mobile tokens, safe areas, navigation, touch ownership, keyboard and accessibility prototype | Compact/regular examples, no input duplication, desktop unchanged |
| 2 Combat and exploration slice | Action panel, preview/confirm, target picker, reactions, camera, exploration commands and tutorial | One demanding touch-only battle and exploration/dialogue route on phone and tablet |
| 3 Inventory and progression | Inventory, loot, shops, services, party, creator, sheets, level up, spell preparation | Complete create → earn loot → equip → buy/sell → level-up route |
| 4 Remaining screens and utility | Reading/travel/rest, Skirmish, settings, native files, interruption/recovery, accessibility integration | Every screen and error-state checklist covered; save transfer and resume tests pass |
| 5 Device qualification and polish | Performance, ergonomics, audio, accessibility, installed upgrades, campaign coverage | Release matrix passes with recorded devices/builds and desktop comparisons |

Build phone and tablet layouts in each stage. Do not defer discovery of phone constraints until every tablet screen has been implemented. The existing platform milestones still cover rendering, assets, signing, and distribution; these UI stages refine the work inside them.

For each implementation handoff, run the repository's focused tests and `make check`; add each new panel to `tests/integration/test_layout.gd` and capture visual changes through the approved capture tooling. The build coordinator owns the full integration suite. Keep the PR draft until required completion evidence exists.

## Test matrix and release definition

Automated layout cases include short landscape 667×375, ordinary phone 844×390, tablet 1024×768 and 1194×834 logical points, narrow iPad windows, both landscape safe-area configurations, keyboard-visible layouts, and all text presets. These are test geometries, not a promised hardware support list. Derive additional cases from actual simulator and device metrics.

Test tap versus scroll, release outside a control, two-finger cancellation, modal ownership, scene replacement, rapid repeated taps, disabled controls, native selectors, nested overlays, focus return, and mixed input devices. Assert that preview/cancel cannot consume resources or advance RNG, and a valid confirmation commits once. Desktop tests cover hover/right-click, drag/drop, hotkeys, controller focus, window resizing, and existing scale settings.

Run native iPhone and iPad simulator journeys through new game, creation, exploration, dialogue, combat with reactions and area targeting, inventory, shops, progression, rest, travel, save/load, file transfer, and Skirmish. Desktop mobile-preview runs are useful layout tests but are not native simulator evidence. Use physical devices for finger ergonomics, display scale, Metal rendering, performance, audio, haptics, accessibility, memory pressure, and thermals.

Proposed usability targets: common commands reachable within two navigation steps, no horizontally scrolling forms, no essential hover-only information, no clipped primary action at maximum supported text, and no accidental gameplay commitment during scrolling. Aim for responsive 300-item inventories and smooth UI while AI is thinking. Measure frame times and input latency in release builds; keep a 30-minute mixed-play performance and interruption run on the eventual minimum supported devices.

Full iOS support means all shipped features are reachable by touch, every screen has passed compact and regular review, interruptions preserve the promised committed state, native utility flows work, and a campaign coverage pass plus demanding Skirmish cases have completed. It also means the desktop baseline and interaction checks show no changes from this UI work. A successful export, a scalable wrapper, or one playable encounter does not establish completion.

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

## Camera and conversation refinement — 2026-10-17

Implemented continuous two-finger twist rotation in both directions, alongside existing pan and pinch zoom.
Updated exploration/combat help describes the two-hand gesture. Mobile conversations preserve participant
busts beside the text/choice column, including speaker emphasis and moods, with a portrait fallback.
Phone/tablet offscreen captures and raw viewport/layout tests cover the update, including large text; native
qualification and a new Apple upload remain separate from the already processed build 1201.

## Research follow-up — 2026-10-17

See [iOS UX research and improvements](ios_ux_research.md) for the official-source comparison, implemented nearby-object list and search recovery, screenshot evidence, and remaining native/hardware qualification.
