# Controller

Status: building (Improvement Ideas U6, owner ask 2026-10-08) · Plan: vault note "Controller Support - Audit and Plan"

Every screen, exploring and fights work on a pad as well as on the mouse and keyboard. Buttons are named by the
Xbox layout's positions (Godot's names); a PlayStation or Nintendo pad has the same buttons in the same places.

## On every screen (`ui/common/pad_nav.gd`)

The conventions are the approved ones from `character_creation.md` (cc_10), `inventory.md` and
`party_management.md`.

| Button | Does |
|---|---|
| D-pad, left stick | Move focus to the nearest choice that way (held: repeats). On a slider, left and right move it |
| A | Choose: press the button, or click the tile, row or picture |
| B | Back (each screen's own Escape) |
| X | The item's menu (a right-click) |
| Y | Explain: the rules card of what has focus; again pins it, again closes it |
| LB / RB | Previous / next tab or filter |
| LT / RT | Previous / next character, where the screen has characters |
| Right stick | Scroll |
| Start | Confirm a step (character creation) |

How it works: `PadNav` (made by the UiFeel autoload) treats the topmost visible CanvasLayer from layer 20 to 99 as
the screen in front, so the HUDs (layer 10) and the rules cards (120) are never in the way. A layer can opt in or
out with the `pad_scope` meta. When the pad is in use, focus lands on the screen's first choice (`pad_first` meta to
pick another), the D-pad moves it by position inside that screen only, and `FocusRing` draws the candle frame with
its ▸. Choices are focusable controls, every button (also those set to take no focus from the mouse, for the pad
only), controls with a rules card, and clickable widgets (a script `_gui_input`, or the `pad_target` meta);
`pad_skip` leaves a control and its children out. The pointer follows focus with a mouse move the tracker ignores,
so hover cards and tooltips work, and hides while the pad is in use; moving the mouse hands control back.

LB/RB step the screen's tabs: its `pad_tab(step)`, else the strip of tabs nearest focus (`UiParts.tab_strip` marks
its strips), else a TabContainer, TabBar or group of toggle buttons. LT/RT step its character: its
`pad_character(step)`, else the row of party chips nearest focus (`UiParts.party_chips` marks them). So the sheet,
inventory, journal, saves, shop, services, creator and Skirmish all step without code of their own.

A screen or control can take over any part (the hooks are listed at the top of `pad_nav.gd`):

| Hook | Used by |
|---|---|
| `pad_accept()` on a control, or a `pad_accept` Callable meta | Item tiles and rows (A wears or uses, as a double-click), the travel map (plans the way to the place lit) |
| `pad_menu_name()` on a control, or a `pad_menu` meta | Item tiles: the prompt bar's X ("Item menu") |
| `pad_adjust(dir)` on a control, or a `pad_adjust` Callable meta | Settings rows and the volume sliders (left and right turn them) |
| `pad_move(dir)` and `pad_context()` on a control | The Skirmish map sketch: a square cursor, A and X click the square |
| `pad_step(focus, dir)`, `pad_trigger(step)`, `pad_scroll(by)` on the screen | The travel map: the D-pad goes place to place, LT/RT zoom, the right stick pans |
| `pad_confirm()` on the screen (Start) | Character creation: the step's Next, then Confirm and the finish |
| `pad_button(button)` on the screen | The on-screen keyboard's X, Y, LB and Start |
| `pad_prompts()` on the screen | Extra prompt-bar entries, replacing the general ones for the same buttons |
| `pad_first` meta | Where a screen opens: the conversation's and ending's Continue, the travel map |

Item tiles are picked when focus lands on them (their card shows), A is their double-click and X their menu, so the
pack never needs a drag: the menu gives, stashes and wears.

## Typing (`ui/common/pad_keyboard.gd`)

A on a text field (a name, a save's note, a cheat code, the pack's search, the sheet's notes) opens an on-screen
keyboard over the screen: the D-pad moves over the keys and A types, X deletes, Y puts a space, LB switches capitals,
Start or Done puts the text in the field as if Enter were pressed there, and B leaves it as it was.

## Every screen

`tests/integration/test_pad_screens.gd` opens every screen (the title screen, the party screens and every sheet tab,
the inventory in both views, settings, saves, cheat codes, the travel map, a shop, a temple, a loot window, a
conversation and a check, the creator's every step, the ending and Skirmish's tabs), checks that one press puts focus
on it, that the D-pad reaches every choice from there (by PadNav's own rule), and that B goes back.

## Button pictures, the prompt bar and hints (`ui/common/pad_glyphs.gd`, `pad_prompts.gd`)

The pictures are Kenney's Input Prompts (CC0, `art/sourced/kenney_input_prompts/`, only the ones used): Xbox,
PlayStation and Nintendo. The family follows the pad in use (by its name or vendor), or Settings > Game > Button icons
fixes one. A button is named by its place: `PadGlyphs.texture("a")` is Cross on a PlayStation pad and B on a Nintendo
one.

While the pad is in use on a screen, the prompt bar at the bottom right shows what its buttons do there: A Choose,
B Back, X with the focused control's `pad_menu` meta (the menu's name), Y Explain when it has a rules card, LB/RB
Tabs and LT/RT Character when the screen has them, plus anything its `pad_prompts()` returns ([place, text] pairs).

Text that names keys switches too: `PadGlyphs.hint(label, "Esc: close", "{b}: close")` shows the keys while the
mouse and keyboard are in use and the pad's words otherwise ("Circle: close" on a PlayStation pad), and follows the
device as it changes. The screens' "Esc: close", the rules cards' pin hint, the conversation's and the ending's
continue hints use it.

## Exploring (`world/exploration/pad_explore.gd`)

With no screen in front, game_root hands pad events to PadExplore. The nearest thing the party can use within 8
squares (a person, door, chest, thing, way out, or a foe in sight) is marked as the mouse's hover marks it, with its
glow and hint, and the mark follows the party as it walks until the player picks one.

| Button | Does |
|---|---|
| Left stick | Walk |
| Right stick | Left or right: turn the camera a quarter (a flick); up or down: zoom (CameraRig.pad_look) |
| D-pad left / right | Mark the previous / next thing round the leader, as the screen shows them |
| A | Use the marked thing, walking there first as a click does |
| Y | Everything that can be done with it (the right-click menu) |
| X | Search |
| LB / RB | Who leads: the one before / the next, round the party |
| L3 | Sneak |
| R3 | Turn-based exploring; RT ends its round |
| LT (hold) | Names of everything usable, and what foes in sight can see |
| D-pad up | Step into the HUD's bar (Character, Inventory, Journal, Party, Map, Rest, Wait ...): D-pad along it, A presses, B or D-pad down leaves |
| D-pad down | The controls card |
| B | Close the controls card or the Narrator's box |
| Back (View) | The map |
| Start (Menu) | The menu |

The prompt bar shows the world's buttons too (`PadPrompts.world`). Each is an InputMap action (`use_marked`,
`marked_menu`, `mark_prev`, `mark_next`, `leader_prev`, `leader_next`, `hud_bar`, `show_controls`, `pause_menu`, and
pad events on `search`, `sneak`, `plan_mode`, `plan_round`, `open_map`, `show_names`, `show_sight`, `look_*`), so
Settings can rebind them.

## Fights (`world/combat/combat_view.gd`, `world/combat/pad_combat.gd`)

| Button | Does |
|---|---|
| Left stick | Move the square cursor (the camera follows it) |
| Right stick | Turn and zoom the camera (while the radial is closed) |
| A | Confirm at the cursor: move, attack, pick a target; a dying hero's Death Saving Throw |
| B | Cancel, or take back a pick |
| X | The next target |
| Y | End the turn (asks if there's something left to do); while picking targets, cast with those picked |
| LB (hold) | The radial menu: the right stick picks, release to choose |
| LT / RT, RB | Step through the hotbar's slots, use the one lit |
| D-pad up / down | The hotbar's tab |
| D-pad left / right | The spell slot's level |
| L3 | Take back the last move |
| R3 | The square's menu at the cursor (Move here, everything that can be done there, Info) |
| View | The controls card |
| Start | The menu |

The reaction prompt and the end-turn check have the `pad_modal` meta: while one shows, PadNav moves over it alone
(its "Next time" rule and targets too), A presses what has focus and B answers no. The prompt bar shows the fight's
buttons for the moment (`PadPrompts.set_world`).

## Tests

`tests/integration/test_pad_nav.gd` drives screens with synthetic `InputEventJoypadButton` and
`InputEventJoypadMotion` events, never a real pad.
