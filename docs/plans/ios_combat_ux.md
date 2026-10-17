# Mobile combat UX redesign

Updated 2026-10-16. Status: first implementation pass; native gameplay qualification and the remaining acceptance items are open.

The first replacement is implemented: a compact actor/resource card, Battle Menu, separate End Turn, contextual
Move/Attack/Cast controls, explicit Cancel and Targets, and a bounded Actions side sheet on sufficient safe areas.
The root browser has Close, a category chooser and optional search; review retains Back and Close. Category,
query and scroll survive reopening for the same actor. Hidden actions have an explicit category and are excluded
from All. Tablet layouts add upcoming turns. Notifications no longer replace the actor/resource card.

Phone and tablet offscreen captures show the actual battlefield using prepared states. These are desktop mobile
profiles, not native simulator screenshots or E2E. Existing native screenshots show the previous composition.
The native gameplay journeys and screenshot gallery must be refreshed before calling the redesign qualified.
Remaining design work includes the richer tablet party context, more thorough area/multi-target commitment
presentation and uncovered-region camera framing. The sections below remain the full acceptance target.

## Player needs and design rules

In order, the player needs to understand whose turn it is, what remains available, which choices are possible, what a choice will do, and whether they have committed it. Preserve the battlefield as the main surface for these decisions.

- Show the active actor and essential resources without opening a menu. HP, action, bonus action, reaction and remaining movement are distinct; do not collapse them into an ambiguous energy bar.
- Inspection, action browsing and target selection never spend resources or consume dice. A named commit control is the boundary.
- Present controls for the current state. Avoid a permanent Confirm button with no clear object.
- Keep Actions dismissible and closed by default. Returning to the list preserves the category, query and scroll position for the same actor. Changing actors revalidates the list.
- Every gesture has a discoverable button route. No required hover, tiny token hit target, timed press or drag precision.
- Keep common decisions near the player's hands. Keep End Turn separated from the primary action, with the existing unused-resource warning.
- Display unavailability with its reason; do not silently remove an action the player expects to find.
- Desktop presentation, commands, controller navigation and rules are unchanged. Apply the redesign only to mobile presentation.

## Quiet battlefield

### iPhone

Top left: a compact actor card with a readable short display name, round, HP and explicit resource state. Tapping opens the complete name, conditions, resources and party details. Do not truncate the only visible identity without an accessible full label.

Top right: one Battle Menu button. Turn order, log, camera, settings, help and accessibility routes live here. No permanent Order and Log buttons stretching across the screen.

Bottom right: Actions, sized to its content with a comfortable hit region. Bottom left: a lower-emphasis End Turn control, separated from committing a move or attack. Only contextually useful controls appear between them. No permanent full-width bar or empty background strip.

Keep action/bonus/reaction labels and movement readable at the supported text size. Collapse supplementary information into the actor card before reducing essential text. Respect both landscape safe areas and the home indicator.

### iPad

Use available logical space rather than assuming every iPad has the same usable viewport. Add a compact party column and a short upcoming-turn strip on regular layouts. These can collapse; they must not occupy the targeting surface when text enlargement or reduced width makes them intrusive. Party selection obeys the existing shared-turn rules.

Actions is still temporary. A bounded side panel can show more choices and an adjacent detail region. Do not stretch phone buttons across the entire tablet or keep the action library open by default.

## Actions popup

Use a side sheet in landscape while it leaves a useful battlefield visible. On constrained safe areas or larger text, use a larger sheet that prioritizes readable choices and reachable Close. The popup blocks world input underneath; a closing tap cannot click through.

The top contains a short Actions heading and Close. Show Back only after navigating into a review or variant selection. Actor resources occupy one compact line. Eliminate the current repeated giant heading, redundant root Back, search row, turn-options row and long tab strip.

The initial view emphasizes available primary attacks and player favourites without hiding the full catalog. Keep order stable during a turn. Use a compact category selector for the shared Common/class/Spells/Items/Reactions catalog, a separate search affordance, and an explicit route to hidden actions. Hidden entries are not promoted into the default recommended choices.

Cards show name, cost and one useful summary. Unavailable cards remain inspectable and say why. Larger tablet panels can use two columns; phone columns are allowed only when labels and minimum hit sizes fit. The content area should show materially more useful choices than the current two-and-a-half-row screenshot.

Selecting a card opens its review in the same sheet. The review provides cost, range, target requirements and supported level/variant/metamagic/ready options from the existing catalog. Put optional organisation controls after essential information. Keep the final Choose target or Use action control reachable outside the scrolling details. The selected option and availability must be refreshed at commitment.

## State-specific interaction

| State | Visible information and controls | Commitment behavior |
| --- | --- | --- |
| Player turn, no selection | Actor resources, Actions, Battle Menu, End Turn | No generic Confirm |
| Movement preview | Path, distance/cost, movement remaining, known hazards and Cancel | Named Move N ft; unavailable path gives a reason and cannot commit |
| Aiming, no valid target | Action name, targeting instruction, Cancel and Change action | No enabled attack/cast commitment |
| Valid single target | Target name, range/line-of-sight status, hit/save information where known, effect and cost | Attack target or Cast spell; no hidden auto-commit on a second tap |
| Area or multiple targets | Shape/selected targets, target count, visible affected allies and rule warnings | Cast spell only when selection is complete; details expand separately |
| Immediate/self action | Review effect, recipient if applicable and exact resource cost | Explicit Use action in review; no unnecessary target step |
| Reaction | Trigger, eligible reaction, benefit/cost, Use and Decline | Existing reaction callback and legality; accessibility stays within the prompt |
| Enemy turn / animation | Acting creature and concise outcome; optional details/log | Hide or disable player commands with clear state; preserve inspection/camera where safe |
| Death save | Active character, stakes and Roll death save | One explicit roll; repeated input cannot roll twice |
| Battle over | Outcome and Continue | No leftover target/action controls |
| Save failure / background interruption | Existing retry/resume surface | No input reaches combat until persistence/lifecycle gate permits it |

Targeting needs an alternative to accurately tapping small or overlapping creatures: a named visible-creature selector in the targeting controls, with the same legality and preview behavior as world taps. Panning and pinching cancel a pending tap without changing the selected action.

Cancel returns to the prior coherent battlefield state without spending anything. Change action returns to the popup and preserves useful browsing context. Undo movement appears only when the existing rules permit it. Movement preview must not promise undo after a committed consequence makes it illegal.

Use world highlights and concise text together; color is never the sole indication of enemy, ally, valid target or hazard. Keep targeting labels out from under the player's finger. Frame the relevant actor/target within the uncovered camera region without continuously fighting manual camera movement.

## Implementation boundaries and order

1. Consolidate mobile combat presentation state. `CombatView` supplies a read-only view of active mode, selection, readiness, target validity, costs and allowed operations. Reuse existing rules/preview results instead of recomputing legality in UI.
2. Replace stretched `MobileBattleHud` header and `MobileControls` combat bar with compact anchored controls. Ensure exploration retains its separate minimap/menu layout.
3. Add contextual movement/targeting controls, explicit cancellation and named targeting. Disable stale actions and retain command journal/persistence gates.
4. Restructure `MobileActions` layout while retaining catalog browsing, favourites/hidden actions, variants, reaction policies and cast-level validation. Do not remove advanced capabilities to simplify the first screen.
5. Add regular-tablet party/initiative context and narrow/large-text fallbacks. Reflow by safe area, not model-name checks.
6. Update combat tutorial anchors, touch guidance, accessible names/focus restoration, capture fixtures and native journeys for the new routes.
7. Capture the actual new HUD closed, popup open, target preview and reaction state on both devices. Replace the baseline gallery only after inspecting those captures. A browser concept is not a game screenshot or gameplay test.

## Acceptance and evidence

- Layout captures cover short landscape phone, notched safe areas, regular tablet, long names and largest supported text. Essential labels, Close, Cancel and commit stay reachable without overlap.
- Raw-touch tests cover opening/closing without click-through; scrolling vs selecting; drag/pinch cancellation; cancel without resources or RNG changes; double taps committing once; and targeting a named creature.
- State tests cover invalid targets, changed turns, spent resources, pending reactions, death saves, ended battles and persistence retry. UI information must match existing command legality.
- Native iPhone and iPad journeys exercise the actual action review, aim, cancel, reopen, legal commit, end-turn warning, reaction response and background/relaunch recovery. Native simulator evidence does not establish physical-device performance or ergonomics.
- Desktop comparison captures and focused desktop/controller regressions show that mobile changes do not alter desktop composition or semantics. Run repository `make check`; do not substitute screenshot inspection for behavioral checks.
- Physical testing covers thumb reach, accidental End Turn activation, small/overlapping targets, text readability, VoiceOver, interruptions and sustained combat responsiveness.

The interactive conversation concept demonstrates layout, dismiss/reopen and one illustrative Longsword target flow. Numbers and tokens in it are sample data; it is not wired to the combat engine. Use the native baseline screenshots and eventual native replacement screenshots as implementation evidence.
