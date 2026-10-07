# Saves and save slots (lane 16)

Status: the slot picker built 2026-10-07 (owner: "When clicking Save Game, we should be able to select the slot to
save to, or save to a new slot") · not yet seen by the owner
Code: `ui/screens/saves_screen.gd` (the page), `core/save_system.gd` (the files). Hooks: `ui/screens/pause_menu.gd`
(Save Game, Load a Save, the game-over arch), `ui/menu/main_menu.gd` (the title's Load).
Tests: `tests/integration/test_save_slots.gd`, and the saves pages in `tests/integration/test_layout.gd`.
Capture: `make capture SCENE=res://tools/capture/saves_capture.tscn NAME=saves FRAMES=30` (saves of its own only).

## The saves page

One framed page (the Crimson gothic frame every screen uses) for saving and for loading, opened over whatever asked
for it. The list scrolls, so any number of saves fits; every line of a row ends in an ellipsis rather than spilling,
and the full text is in the row's tooltip.

- **Save Game** (pause menu): New Save writes a new slot (`save_<date>T<time>`, never a name already taken), or Save
  Here on one of the player's own saves asks first (Overwrite or Cancel) and writes over it. Only the player's games
  still being played are offered: the autosave and a fight's round start are the game's, and a finished game is kept
  as its ending. A save goes back to the menu with "Saved."; the slot saved to becomes the game's own (F5 saves there).
- **Load a Save** (pause menu, the game-over arch, the title's Load): every save, the autosave and round start too,
  newest first. A save from a newer build says so instead of loading.
- **Ways back**: Back, or Escape. Escape closes the overwrite question first, then the page, then (in the game) the
  pause menu. The page hides what opened it (the pause menu's arch, the title's column) until it closes.

## The game-over arch

"The party has fallen", where the last autosave was made, and Load a Save, Last Autosave (when there is one) and Quit
to Title at the foot of the arch.

## Files

`SaveSystem.save_dir` (`user://saves/`, a folder per process in tests) holds one `<slot>.json` per save. Other files
kept there (N8's `achievements.json`) aren't listed: every save says its `version`. `describe(slot)` is what the lists
show of one save.
