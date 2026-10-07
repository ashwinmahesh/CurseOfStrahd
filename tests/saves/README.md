# Golden saves (P4)

Saves written by older builds of the game. `tests/integration/test_golden_saves.gd` loads every one in every test
run, through `SaveSystem.upgrade` like any load, and fails if one no longer loads, names something that no longer
exists, puts a pregen in someone else's look, starts anywhere but where it was saved, or changes when saved again.

- `v<save version>_<chapter>.json`: the start of each chapter, kept by the playthrough tests when `make golden-saves`
  runs them (`tests/support/golden_saves.gd`). The `golden` field says which test made it and on which commit.
- `owner_<date>_<what>.json`: the owner's own saves from earlier builds (copied with the owner's yes, 2026-10-07): the first
  four pregens, the six wearing borrowed looks (the portraits bug), a fight's round start and the created party of
  the Phase 3 exit.

Never edit or remake a save here: its worth is that an older build wrote it. When the save format changes, bump
`GameState.SAVE_VERSION`, add a step to `SaveSystem.upgrade`, and run `make golden-saves`, which adds the new
version's set beside the old ones.
