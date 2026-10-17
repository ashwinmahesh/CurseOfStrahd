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
