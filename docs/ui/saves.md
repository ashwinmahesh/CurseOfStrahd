# Saves and save slots (lane 16)

Status: the slot picker built 2026-10-07 (owner: "When clicking Save Game, we should be able to select the slot to
save to, or save to a new slot"); Q9 (pictures, notes, sorting, more autosaves, backups), Q12 (jump-in saves for
each chapter), Q3 ("Previously in Barovia") and F1's one-save rule for Honour the same day · not yet seen by the
owner
Code: `ui/screens/saves_screen.gd` (the page), `core/save_system.gd` (the files). Hooks: `ui/screens/pause_menu.gd`
(Save Game, Load a Save, the game-over arch), `ui/menu/main_menu.gd` (the title's Load).
Tests: `tests/integration/test_save_slots.gd`, `tests/integration/test_recap.gd`, and the saves pages in
`tests/integration/test_layout.gd`.
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
- **Pictures and notes (Q9)**: each row shows a picture of the game as it was saved, framed in gilt (the travel map
  around the place for a fight's round start or a save from before pictures), the party's level, and the player's own note in quotes. The note is
  typed above the list when saving (60 letters at most; Enter makes a new save with it). Writing over a save keeps
  its note unless a new one is typed, and the overwrite question shows the note the save will have.
- **Sorting (Q9)**: Newest first, By place or By day (the latest day in Barovia first), kept with the player's
  settings (`saves_sort`).
- **Chapters (Q12)**: loading's second tab: a jump-in save at the start of each chapter, in story order, with the
  travel map around where it starts, its number and title, the party's level and the day; the travel map's line
  about the place is its tooltip. Begin starts a game there with no slot of its own (its first save makes one), with
  the roster's heroes at the chapter's level: the first four travel (as New game picks them) and the other two wait at
  camp. The chapter saves were made with the tests' party, so `SaveSystem.begin_chapter` swaps it out, moving the
  magic items it had found into the new travellers' packs (one member's to one member) and its coin to the purse.
- **Backups (Q9)**: loading's third tab, Backups: each update's copies under a heading saying when they were
  kept. A game loaded from a backup has no slot of its own, so its first save makes a new one and the backup stays
  as it was.
- **Ways back**: Back, or Escape. Escape closes the overwrite question first, then the page, then (in the game) the
  pause menu. The page hides what opened it (the pause menu's arch, the title's column) until it closes.

## "Previously in Barovia" (Q3)

Loading a game saved at least 30 minutes ago (`SaveSystem.RECAP_AFTER`, by the computer's clock) opens the
Narrator's box with a recap once the game has arrived (`ui/exploration/recap.gd`, shown on the tree's
`scene_changed`, so only the game itself shows one):

- the Narrator's opening (`recap:open`, three variants) and where the party is (`recap:where:<region>`, a line for
  each of the 19 regions), both in `narrative/narrator/recap.dialogue` and spoken in the Narrator's voice;
- "Ahead of you:" and up to two objectives of the quests that moved most recently (each quest notes the game minute
  it last moved as `"at"`, a one-line hook in `story/story_state.gd`; older saves' quests count as long ago);
- "Not long ago, ..." and the newest moment a companion remembers (`story/approval.gd`), when there is one.

A quick reload (F9 on a save made minutes ago) and a fight's round start show none. The last two parts are text only:
they are built from the quests and the companions' memories, so there is no fixed line to record.

## The game-over arch

"The party has fallen", where the last autosave was made, and Load a Save, Last Autosave (when there is one) and Quit
to Title at the foot of the arch. An Honour run says instead that it ends here and that its save carries on in
Tactician, and offers Carry On in place of Last Autosave.

## Honour's one save (F1)

An Honour run (`combat/difficulty.gd`, `one_save`) keeps one save, its own slot, which the game keeps up to date
(`SaveSystem.honour()`):

- the autosaves (arriving, a rest, a won fight) write over it instead of the rotating autosaves, and the first one
  makes it;
- each fight is kept as it starts: round 1 writes over it, later rounds leave it alone, and there's no round-start
  save beside it, so leaving a fight comes back to its start, never past it;
- Save Game shows only that save (Save Here asks nothing, since there's nothing else to lose) and no New Save once it
  exists; F5 writes over it too;
- a wipe ends the Honour run as the game-over arch opens (`SaveSystem.end_honour`): the game and its save switch to
  Tactician for good (lane 22's pick, docs/plans/difficulty.md), so quitting can't bring Honour back; Carry On loads it.

Every save row shows its difficulty after its kind ("This game · Honour · Day 4 ..."), Balanced shown as nothing.

## Files

`SaveSystem.save_dir` (`user://saves/`, a folder per process in tests) holds one `<slot>.json` per save and its
picture, `<slot>.webp`. Other files kept there (N8's `achievements.json`) aren't listed: every save says its
`version`. `describe(slot, dir)` is what the lists show of one save.

- **The player's note** is the save's top-level `"note"`, like a finished game's `"finished"` and an autosave's
  `"home_slot"`: only the lists read it, so it needs no `SaveSystem.upgrade` step and older builds ignore it.
- **Pictures**: the middle 16:9 of the screen at 320 x 180, WebP. The pause menu holds the frame it opened over
  (`SaveSystem.hold_view`), so a save from its pages shows the world rather than the menu; F5 takes the screen as it
  is; an autosave waits 0.8 s, so arriving somewhere shows the place. Taking one costs a frame of 30 to 80 ms on the
  busy Mac Mini (the screen read back from the graphics card), so a fight's round start has none (that would be a
  stall every round), and headless runs take none.
- **Autosaves**: the newest five, `autosave` then `autosave_2` ... `autosave_5`; each new one moves the others along
  and the oldest goes. Every one of them goes back to its game's slot when loaded, like the round start.
- **Backups**: the first time a new build of the play copy starts (`builds/play_build.json`'s commit, written by
  `make play`), before anything reads a save, every save and picture is copied to
  `backups/<date>T<time>_<commit>/`. Once per build; the newest eight builds' copies are kept. A working checkout has
  no build file, so it never backs up.
- **Chapters**: `SaveSystem.chapters()` offers the golden saves P4 keeps in `tests/saves` (made by the auto-player
  the playthrough tests use, so the same saves every test run loads): each chapter's newest save version, in the
  story order of `SaveSystem.CHAPTERS` (13 chapters, Into the Mists to the Gates of Castle Ravenloft; the new game and
  the ending are left out). They load through `SaveSystem.upgrade` like any save, so they keep loading as the format
  changes, and `make golden-saves` refreshing them refreshes the chapters too.
