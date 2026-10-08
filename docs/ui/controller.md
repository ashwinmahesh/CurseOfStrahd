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

A screen can add `pad_tab(step)` (LB/RB) and `pad_character(step)` (LT/RT) methods; without `pad_tab`, a
TabContainer, TabBar or group of toggle buttons is stepped instead.

## Exploring and fights

Exploring and fights read the pad themselves (`world/game_root.gd`, `world/combat/combat_view.gd`); see
`combat_view.md` for the fight's map. Both get their full pass in later steps of the plan.

## Tests

`tests/integration/test_pad_nav.gd` drives screens with synthetic `InputEventJoypadButton` and
`InputEventJoypadMotion` events, never a real pad.
