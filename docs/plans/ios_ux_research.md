# iOS UX research and improvements

Updated October 17, 2026. Branch: `codex/ios-support-foundation`; [draft PR #5](https://github.com/ashwinmahesh/CurseOfStrahd/pull/5).

This comparison uses official guidance and documented game features, not hands-on testing of competing games. It builds on [the UI and utility plan](ios_ui_and_utility.md). Desktop layouts and controls remain the baseline; the changes below use the mobile presentation paths.

## Owner's requested changes

Implemented in `9f432dcf7`: nearly full-height dialogue busts (96% of safe height), speaker portraits, a smaller bottom reading panel, lower mobile text defaults, hold-to-Reveal beside Menu, desktop-style loot rows, and retained item/spell art. The UI audit covers 84 prepared states on each mobile profile. Text preferences still apply and controls retain 44–48-point touch targets. Loot keeps recipient selection, icon/name/weight/action rows, coins and bulk transfer controls. Short conversations leave the world visible; long text and choices scroll.

These changes are in the branch. Apple build **1.0.0 (1201)** predates this polish. Offscreen screenshots do not establish that an installed iOS build includes it.

## Comparison and decisions

| Area | Research | Current implementation and decision |
| --- | --- | --- |
| Layout and legibility | Apple recommends responsive placement, safe-area controls, scrolling overflow, explicit pressed feedback and touch targets of 44 points. It suggests body text around 17 points. [Handheld game interfaces](https://developer.apple.com/videos/play/meet-with-apple/243/) | Our phone HUD stays quiet; tablet exposes more shortcuts. Retain the owner's smaller 15–16-point mobile text and adjustable text setting. Keep large hit areas independently of type size. Actual-device legibility still needs review. |
| Selecting world objects | Accessibility guidance recommends alternatives to sustained or simultaneous input. [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/ensure-that-multiple-simultaneous-actions-eg-click-drag-or-swipe-are-not-required-and-included-only-as-a-supplementary-alternative-input-method/) | Keep requested hold-to-Reveal and gesture camera controls. Add Menu → Nearby objects as a tap-based route to existing object actions. Camera buttons already provide an alternative to twist/pinch gestures. |
| CRPG discovery | Planescape: Torment EE's cross-platform manual describes a Quickloot list for nearby ground piles. [Official manual, Quickloot section](https://files.beamdog.com/files/PSTEE_Manual_en.pdf) | Borrow the list principle for small/overlapping targets. Our list opens options; it does not automatically loot, move the party or reveal secrets. Existing loot rules remain authoritative. |
| Search | Apple recommends clear search fields, descriptive scope and useful results. [Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields?changes=_1) | Our application of this guidance: actionable empty states and a visible way to clear filters. Preserve item state, action preferences and sort order. |
| Tactical controls | Feral describes adapting headquarters, operations and squad control for iPhone/iPad touch. [XCOM 2 touch controls](https://www.feralinteractive.com/en/news/the-hand-of-resistance-touch-controls-in-the-xcom-2-collection-for-ios/) | Keep our dismissible combat Actions sheet, separate End Turn and contextual targeting confirmation. Detailed inspection must not spend an action or roll dice. No permanent screen-filling command panel. |
| Mixed input | Larian's official iPad launch description lists touch, gamepad and mouse/keyboard support. [Divinity: Original Sin 2 iPad launch](https://www.youtube.com/watch?v=g0phbZdROKE) | Our existing touch/controller/keyboard paths and device-aware prompts are the appropriate baseline. Hardware pairing, disconnect and input switching need physical-device qualification; synthetic events are not that evidence. |
| Battery and quality | Feral added player-selectable performance/quality choices to XCOM 2 on iOS. [Official patch announcement](https://www.feralinteractive.com/en/news/new-patch-optimises-the-xcom-2-collection-on-ios/) | We have graphics presets, mobile effect restrictions and separate 3D scaling. We do not yet have measured battery/thermal qualification. Measure before naming a preset “Battery saver” or changing quality defaults. |

## Implemented in this follow-up

**Nearby objects:** a bounded, searchable list with object names, friendly categories and distance, ordered nearest first. It reuses desktop Reveal eligibility, excluding undiscovered secrets, hidden areas, party members and offscreen/out-of-range targets. Selecting a row rechecks the current location, visibility and input lock before opening the normal context actions. Refresh and Back remain available. It adds no permanent HUD control.

**Reveal feedback:** the held button now visibly stays pressed and uses the existing optional native haptic preference. Release, drag-out and interruption still cancel it.

**Search recovery:** Inventory offers Show all items when filters exclude everything. Combat Actions explains empty Favourites/Hidden categories and offers Clear search or Show all actions. Cancel search clears its query. Typing returns lists to the top. Resetting filters changes presentation only; it does not consume inventory, unhide actions or alter combat resources.

## Evidence and remaining qualification

The capture fixture `tools/capture/mobile_research_capture.tscn` produces eight prepared states each at 844×390 and 1194×834. These are **offscreen game renders**, not native simulator screenshots or end-to-end playthroughs. The Obsidian note “iOS UX Research and Improvements” contains the paired captures and SHA-256 manifest.

Focused tests exercise raw touch search recovery without item/action mutations, held Reveal feedback, real world-menu routing, secret filtering and stale-selection rejection. Layout cases cover 667×375, 844×390 and 1194×834 with default and maximum text settings. Required `make check` is green: **165 tests passed**, all-script compilation, lint, data/rules-doc validation and iOS target dry runs. Logs are in the external `strahd-builds/ios-ux-research-20261017` directory.

Next acceptance work, in order:

1. Build the latest branch for native iPhone and iPad and repeat exploration → conversation → loot/inventory → combat → save/resume. Verify keyboard-visible search, both landscape safe areas and interruption. Publish a new Apple build only with its actual revision and results recorded.
2. Measure a 30-minute mixed-play session on physical supported devices: frame time, memory, heat, battery and finger readability. Use results to decide whether a separate power preference is useful.
3. Exercise VoiceOver/Switch Control and hardware controller journeys, including focus return, disconnect and touch takeover. A large named object list improves access but does not prove complete assistive-technology support.
4. Recheck long item/spell names, maximum text, crowded encounters and long conversations against the latest native build. Keep the desktop comparison and compact HUD requirements in the release gate.

The PR stays draft until the native and hardware qualification gaps in the main iOS plan are resolved.


## Polish cycle: keyboard, rotation and motion comfort

The owner requested an ongoing improvement loop, with a polished mobile experience as the priority. This cycle focuses on completing ordinary interactions reliably rather than expanding the permanent HUD.

| Evidence | Gap found in our app | Change |
| --- | --- | --- |
| Apple's [Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria) recommend respecting system preferences and reducing decorative spinning, scaling and depth effects while preserving useful feedback. | The game had a test/capture motion switch, but iOS preferences did not reach cosmetic camera effects. | Observe the iOS setting and offer **Reduce extra motion** in mobile Display settings. Suppress cinematic zoom/lean/shake, impact time effects, radial screen pulses and new decorative UI animations; stop existing bust breathing. Intentional camera pan, zoom, rotation and tactical view remain available. Desktop behavior is unchanged. This is scoped improvement, not certification of all Reduced Motion criteria. |
| Feral's [June 2026 XCOM 2 update](https://www.feralinteractive.com/en/news/update-1-6-has-a-100-percent-chance-to-hit-the-xcom-2-collection-for-ios-and-android-today/) added screen rotation and Bluetooth mouse/keyboard controls. | Our safe-area updates depended largely on window size. A same-size landscape flip or keyboard appearance could leave an old contact active. | Track safe area, logical size and keyboard geometry; cancel unfinished contacts and reflow mobile pages, dialogue and HUDs. Preserve the open page, search text and game state. This is our design inference from the comparison, not a claim about Feral's implementation. |
| Actual offscreen review of our inventory with keyboard geometry active. | Done wrapped into an unreadable narrow button. Filtering returned the scroll position to the top, hiding the active field. | Keep Done unwrapped and keep the focused field visible after filtering, including nested tablet scrolling. Add a regression that types successive queries with the phone keyboard open. |

The native gameplay suite now addresses the current combat HUD rather than obsolete Common/More/Round buttons. Its campaign journey includes inventory search, keyboard dismissal, landscape rotation and the motion preference; exploration includes Nearby objects search. Native results are recorded separately when the run finishes. Six prepared offscreen screenshots show Display settings and keyboard/safe-area layouts on phone and tablet; the blank keyboard reservation in those captures is not a rendered UIKit keyboard.

Remaining: real-device comfort, assistive-technology and performance qualification; broader Reduce Motion coverage beyond these effects; native acceptance of the current revision; no new Apple upload is implied.

### Native search-field finding

The first native run of this cycle passed the compact combat Actions/recovery journey, but campaign filter recovery failed after rotation. A live iPhone screenshot also exposed Godot's desktop Cut/Copy popup over the software keyboard: a slow frame made an ordinary text-field tap exceed the touch hold threshold. The same input was reproduced in a failing raw-touch regression and fixed by keeping text fields on their primary tap action. Explicit alternate commands and world hold gestures retain their context behavior. Native tests now verify the entered query and wait for the actual cleared-filter state. Fresh native qualification is required before closing the campaign finding.

A three-second sample of the slow campaign run found the main thread in the simulator's GLES 3D rendering path, including while inventory covered most of the world. The next performance investigation should compare rendering work behind full-page menus and preserve the visible world in dialogue and combat sheets. This is simulator evidence, not a physical-device frame-rate or battery measurement. Logs and the original screenshot are retained in `strahd-builds/ios-polish-cycle-20261017` on the external volume.

### Native accessibility state finding

The corrected combat journey passed on both simulator profiles, and iPad exploration passed. iPad campaign search still timed out when XCTest queried the typed value even though the screenshot visibly contained the query. A separate native utility app passed all three tests, including changing the value of an existing UIKit accessibility element. That narrows the investigation; it does not establish a UIKit setter defect.

A focused game-side regression reproduced a separate stale-state path: revalidating a queued accessibility action advanced the snapshot revision without publishing its changed data. Both periodic polling and action validation now publish through the same helper. The regression fails before the fix and passes afterward, while confirming that stale actions remain rejected. The mobile input file passes all 40 tests. Native campaign qualification of this follow-up remains pending; the fix must not be treated as proof that the observed campaign timeout is resolved.

### Native gallery refresh and review

The October 17 native gallery contains 84 prepared views per device (168 total), built from clean `fdc4ba08d` on iPhone 16 Pro and iPad Pro 11-inch (M4), iOS 27.0. Both complete manifests and all image hashes are in Obsidian's `iOS Native UI Gallery - 2026-10-17` note. Full contact-sheet review and separate key-view inspection confirm that the current loot, dialogue art, Actions popup and Level Up layouts reached native rendering. The status/preview HUD fixture omits the separate command bar; gameplay captures now wait for Actions and End Turn to appear. These remain fixture renders, not a complete playthrough.

The gallery identified cinematic-caption contrast over detailed artwork; the implemented follow-up is recorded below. Next performance refinement: measure unnecessary 3D drawing behind full-page menus, keeping visible world rendering in dialogue and combat sheets. Required checks at `0b284ea49` passed all 171 tests. Native campaign acceptance remains pending.

### Next-cycle experiments from the native review

Apple's [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) emphasizes foreground/background contrast. The cinematic captures make this a concrete target: add a compact, palette-consistent caption backdrop or scrim and compare short/long narration on both mobile sizes, without increasing the owner's chosen type size or altering desktop cutscenes. Measure contrast across the actual art rather than treating a screenshot's successful rendering as readability approval.

Godot documents [`Viewport.disable_3d`](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-disable-3d) as disabling 3D rendering while retaining 2D. This is a candidate to benchmark for fully covering mobile pages, not a measured optimization yet. Compare identical campaign state and camera with/without world rendering; preserve the visible world behind dialogue, loot and combat side sheets. Verify restoration on Back, background/resume, scene change and nested menus, and keep desktop behavior unchanged. Record frame times and memory separately for simulator GLES and device Metal.

### Current native run

Fresh runtime `0b284ea49cf99c2e190b54c31d0f9f7d6d54b0e8` with test harness `5833363c2` built successfully. The stricter combat/Actions/practice-recovery journey passes on iPhone (217.597 seconds) and iPad (351.654 seconds), including ready Actions/End Turn assertions and the closed-popup capture.

Both campaign journeys passed software-keyboard entry, rotation and filter clearing, then reached equipment, camera controls, Journal, Save and settings, and Display. They failed the ten-second native selected-state expectation after toggling Reduce extra motion (`NativeGameTests.swift:125`): iPhone 1675.240 seconds, iPad 1170.307 seconds. Both QA containers persisted `ios_reduce_motion=true`, so the tap applied; native state publication/observation timing is still unresolved. This is not a campaign pass, and save/relaunch/resume steps after that assertion did not run. The earlier search-value assertion did pass on both devices in this run.

The iPad exploration test also failed its Nearby search-value expectation after 641.593 seconds. Its diagnostic shows `Zzz` on the retained element and `Zzzz` in the fresh query chain, a stale-observation lead. The finalized iPad suite is 1 passed / 2 failed, with exported summary and attachments. iPhone exploration remains running in `strahd-builds/ios-polish-native-20261017-r3`. Retain `motion-assertion-investigation.json` and collect finalized results/attachments before competing for those simulators. The caption gallery uses separate devices. Next investigation: isolate selected-trait refresh on an existing native semantic element, then measure publication and query latency under the software-rendered world. Do not infer a UIKit defect or declare a timing fix from the persisted preference alone. Menu transitions also need explicit readiness checks if the initial snapshot is delayed; do not weaken success conditions or relabel interrupted/failed journeys as passed.


### October 17 caption readability pass

Apple's [game design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-games/) calls for legible text against the artwork and layouts that adapt to each display. Its [accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) uses 4.5:1 as the normal small-text contrast reference. Feral's [XCOM 2 touch-control description](https://www.feralinteractive.com/en/news/the-hand-of-resistance-touch-controls-in-the-xcom-2-collection-for-ios/) documents adapting tactical and management interactions to phones and tablets. Our design inference is to adapt the reading surface to its content and device, preserving the compact type and image instead of enlarging the entire interface; this is not a claim about XCOM's caption implementation.

Mobile cinematic captions now have a local `ui_black` backing at 94% opacity. Short lines sit just above Continue with a snug panel; longer lines expand to the existing reading-area limit and scroll. Tablet lines have a 900-point maximum width. The old seven-pixel text outline is removed only on mobile because the backing supplies contrast. Same-size safe-area changes reflow the caption and navigation. Desktop cutscenes retain their existing presentation.

An analytical sRGB composite over white gives 12.29:1 for `vellum` body text and 10.42:1 for `gilt_light` speaker text. This is a source-color estimate, not a physical-display measurement or full accessibility certification. Visual review uses actual detailed artwork, short narration, named speakers, long text, the scrolled end and Pause. Raw-touch regression covers phone/tablet scrolling without advancing, one Continue activation, reset/shrink on the next line and an opposite safe area. Existing maximum-text layout checks cover the scroll boundary.

The isolated native gallery accepts `-- --gallery-fixture=mobile_caption` to verify this surface without rerunning unrelated completed fixtures. Invalid fixture names stop with an error rather than yielding a misleading completed manifest. This remains native fixture evidence, separate from the ongoing campaign journeys and physical-device qualification.


Caption verification at clean source `3d44e2ea1bcf6a3efa7713e57aa98af856d8c502`: required `make check` passes 172 tests, lint and validation; final gallery-manifest initialization also passes all-script compilation. Ten approved offscreen captures and ten native simulator fixtures (five each on iPhone Duo/iOS 27.1 at 678×466 and iPad mini A17 Pro/iOS 27.0 at 1133×744 logical points) were reviewed. Both native manifests report complete/native iOS; source and image hashes are in Obsidian's `iOS Caption Polish - 2026-10-17` note. The larger tablet fits the stress line in this fixture; raw-touch/layout regressions separately exercise overflow at phone/tablet and maximum text settings. Physical-device evidence and owner sign-off remain pending. No Apple build was uploaded in this cycle.
