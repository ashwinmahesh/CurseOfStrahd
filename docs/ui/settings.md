# Settings, keys, sizes, the party frames and the bestiary (U5, U4, U9, U8, W17)

Lane 13 of the Improvement Ideas (Settings and HUD). Captures:
`make capture SCENE=res://tools/capture/settings_capture.tscn NAME=settings/shot FRAMES=10`.

## Settings (ui/screens/pause_menu.gd)

Three pages in the pause menu's arch, picked by the names under the title:

| Page | Rows |
|---|---|
| Game | Difficulty (Story, Balanced, Tactician; lane 22's `Difficulty`), Fights (Normal, Fast), Narration (Fades, Stays), Exploring (Real time, Turn-based; lane 25's F7), the respec box |
| Display | Look (Modern, Classic), Graphics (Low, Medium, High: lane 6's `Graphics` presets), Window, Depth blur, Interface (85% to 120%), Text (Normal, Large, Larger) |
| Keys | every command's key and alternate (`KeysPage`) |

Difficulty lives in the playthrough's options, not the settings file. Honour is only listed while it's the mode (it's
chosen for a new game); leaving it shows its warning and waits for the "Leave Honour" link. A switch puts the party's
bonus on or off at once (`Difficulty.fit_party`); enemies change from the next fight.

A row is `_choice_row(y, label, options, current, on_change, tip)` at `ROW_Y + n * ROW_PITCH`; a click steps to
the next choice, a click on the left arrow steps back. A new row goes on the page it belongs to (`_game_rows` or
`_display_rows`), one pitch below the last. Up to six fit above the note; Display has six. Everything is kept in
user://settings.cfg through `GameSettings`, never in a save (the respec box is the playthrough's own option).

## Keys (core/input_actions.gd, ui/settings/keys_page.gd)

- `InputActions.BINDINGS` holds every action's default keys (the first is the key, the second its alternate);
  `COMMANDS` lists the ones the player can change, each in a list: "both" (walking, the camera, Tab), "explore" or
  "fight" (turn-based exploring's T and Space, and U10's L, are exploring keys). The player's keys are stored only where they differ ("keys" in the settings file) and put in the InputMap
  by `InputActions.apply()`; `ensure()` does it once a run.
- Two commands of one list can't share a key; "both" commands clash with every list. `bind()` swaps: the command that
  had the key takes the old one, and the page's note says what moved. Escape (menus, back) and F1 (the controls
  card) can't be taken. On the page, Escape keeps the old key and Backspace clears it.
- Code that reads keys by name uses actions (`event.is_action_pressed(&"open_map")`). The exploring keys in
  `world/game_root.gd` are matched by their defaults through `InputActions.as_default(event)`, so the player's keys
  land on the same `match` cases and a new case can still name its default key.
- Texts that name keys use `InputActions.fill("{open_journal} journal")` (the exploring and combat controls cards,
  the Quicksave button); the command bar's marks and the hotbar's slot numbers read `key_text(action)`.
- Adding a rebindable key: put the action and its default in `BINDINGS`, a row in `COMMANDS`, and read it as an
  action (or let `as_default` map it, exploring).

## Interface and text size (ui/settings/ui_scale.gd)

- Interface is the window's `content_scale_factor` while a game is on screen (`UiScale.playing(game_root)`): the HUD,
  the combat HUD, conversations, the Narrator's box and rules cards grow or shrink together. A full screen keeps its
  design size while it's open (`UiScale.full_screen(layer)`, called by `UiKit.screen_frame` and the pause menu):
  those fill the 1600x900 canvas already, and a bigger interface shrinks the canvas by the same share. The title is
  never scaled. The largest size is 120%: at 125% the combat HUD's End Turn button reaches the window's edge.
- Text grows reading text by `UiScale.text(size)`: conversations (lines, answers, the history), the Narrator's box,
  the journal (quests, codex, bestiary).
- tests/integration/test_layout.gd checks the exploring HUD, a conversation and the combat HUD at the largest of both.

## The party frames (ui/exploration/explore_hud.gd, U9)

Each party card shows Bloodied, conditions and exhaustion as small tags (the rules words open their glossary cards,
U1); then what's working on the hero as icons, each named on hover with how long it has left (`EffectIcons`, owner
request 2026-10-08, on the combat HUD's frames too): the spell they concentrate on, ringed in moonlight; abilities
switched on, in art/icons.json's "features" tiles (Rage, Bladesong, Vow of Enmity, Sacred Weapon, Reckless Attack,
Dodge, Innate Sorcery, Form of Dread and 20 more; a rune tile for the rest; `make icons KIND=features`); spells and item
powers on them in their own icons; a beast's shape. Then spell slots by level and class resources as small lozenges (past six a resource reads
"left/total"); hovering them gives every one by name, with when it comes back. The card's click (lead, or the sheet
on a right-click) lies under its content, so the tags take the pointer.

## Bestiary (story/bestiary.gd, ui/screens/bestiary_page.gd, U8)

`StoryState.bestiary`: monster id -> {n, met, where, defeated, studied}. A fight's start (new or resumed) records the
creatures met; its end, who fell and what a Study placed (`Encounter.studied`). A creature studied once shows its
defenses from the start of later fights. The journal's Bestiary tab lists them in the order met; the entry grows with
what's known: met (its picture, kind, a line about it, where and when), felled (Armor Class, Hit Points, speed, its
attacks), studied (Challenge, resistances, immunities, conditions it can't suffer, senses, traits). An older save
loads with an empty bestiary.
