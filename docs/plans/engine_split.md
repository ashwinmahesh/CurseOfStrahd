# Engine split: dnd_core

Plan for moving the shareable parts of this game into a separate private repo, github.com/ashwinmahesh/DndCoreEngine
(local copy ~/Documents/DndCoreEngine), used here as a git submodule at `addons/dnd_core`. Study (2026-10-24):
https://claude.ai/artifact/XdvkGY28acaWLp4kAQJAmh. Owner decision 2026-10-24. Nothing is pushed to the core repo and
project.godot is not changed until the planned full-download release (1.0.11 or later, owner's typed yes in the release
thread). Until then main keeps its layout and every step below is an ordinary patch.

## Order

1. **Decouple inside this repo** (no project.godot change). Move tables to data, rename the shader and palette, add a
   campaign-module hook, and keep the guard test green (`tests/unit/test_engine_names.gd`, below).
2. Move the rules data (items, monsters, spells, feats, subclasses and the rest) with the code: the core is private and takes all of it.
3. **Extract** the engine files listed below into the core repo.
4. **Consume** it as a submodule at `addons/dnd_core`, landing with the project.godot path change in one release.
5. A skeleton game proves the core boots on its own (a later task).

## The guard test

`tests/unit/test_engine_names.gd` scans `rules/`, `combat/` and `story/` (minus the campaign modules listed in
`CAMPAIGN_MODULES`) for code lines naming a campaign id, place or character. `tests/fixtures/engine_campaign_baseline.json`
holds today's count per file (43 files, 147 lines on 2026-10-24). A file may only lose hits; when it does, lower its
entry (`ENGINE_NAMES_WRITE=1 make test FILES=test_engine_names.gd` prints the new baseline). A campaign name in an engine
file belongs in data or behind a campaign-module hook instead.

## What moves to dnd_core

| Part | Files |
|---|---|
| Rules engine | `rules/` (27 files), the Compendium (`rules/data/compendium.gd`) |
| Combat and AI | `combat/` except `ravenloft_features.gd` and the Faerûn packs (`faerun_*.gd`, optional supplement modules, off by default) |
| Story engine core | `story/` minus the campaign modules: state, dialogue file and runner, conditions, quest log, narrator, banter, schedule, services, crime, long rest, rest rules, camp, captives, approval, check aids, field items and casting |
| Schemas | the 31 `data/schemas/*.schema.json` except the campaign ones (`tarokka_*`, `strahd_*`, `ending`, `ally_visits`, `night_visitors`) |
| Rules data | `data/` spells, items, magic_items, monsters, feats, subclasses, species, classes, backgrounds, conditions (all of it, SRD or not; see Licence) |
| Test framework | `tests/test_case.gd`, `tests/test_runner.*`, `tests/support/` (generic files), `tools/run_tests.py`, `tools/check.py`, `tools/data/validate_data.py`, `tools/data/dialogue_lint.py`, `tools/lint_gd.sh`, `tools/logcheck.sh` |

Unit tests of rules and combat move with the code; integration tests that name campaign content stay here.

## Campaign modules (stay in the Strahd game)

`story/tarokka.gd`, `story/strahd_presence.gd`, `story/oracles.gd`, `story/endings.gd`, `story/cheat_codes.gd`,
`combat/ravenloft_features.gd`, the Strahd AI profile, `data/strahd`, `data/tarokka`, `data/endings`, `data/visits`, all
locations, NPCs, quests, cutscenes, dialogue, art and audio. The hook (campaign modules register with the engine instead
of the engine naming them) is queued: it touches `story_state`, `dialogue_runner`, `game_root`, `long_rest`, which other
lanes are editing.

## Already data-driven, or being made so (step 1)

- `CombatToken.HEIGHTS` (sprite height per creature id) → a JSON file.
- `SaveSystem.CHAPTERS` (the save screen's chapter list) → data. SAVE_VERSION unchanged.
- `BossBrain.TREASURES` (the three Tarokka treasures as boss targets) → data.
- Audio mood tables still in code → `art/audio.json`.
- `shaders/post/strahd_post.gdshader` and `art/palette/strahd_palette.png` get neutral names.

## Licence

`docs/assets/LICENSES.md`: content beyond SRD 5.2.1 is personal-use only and never distributed. The core repo stays
private and holds all the data (owner decision 2026-10-25: no SRD flag, no srd/ and books/ split). Anything made public
from it would need its own licence review first.

## Where it stands (2026-10-25)

- Done in this repo: the guard test, creature heights as data, the screen pass and palette renamed, the campaign-module hook
  (`Campaign.module()`: story_state, dialogue_runner, long_rest, travel, weather, quest log and the rest ask it instead of
  naming Tarokka, StrahdPresence, Oracles or Endings; world/, ui/ and core/achievements.gd still name them and stay in the game).
- `make core-extract` (tools/core/manifest.json) works out what moves: 2,250 files today (160 combat, 54 rules, 96 story, 24
  schemas, 1,598 data entries of the books, 140 unit tests, 8 test helpers, the test runner and tools). The 78 CoS and custom
  data entries stay in the game. `make core-extract WRITE=1` writes the files into ~/Documents/DndCoreEngine; the core's first
  commit is local, not pushed, until the owner says so.
- The only things the moving scripts still need from the game are five autoloads (Dice, GameSettings, GameState,
  ModeController, SaveSystem), all through tests/test_runner.gd; the engine code itself is clean (`--leaks`).

## What the switch (one full-download release) has to do

1. Add the submodule at `addons/dnd_core` and delete the game's copies of everything `make core-extract --list` names.
2. Rewrite the `res://` paths that point at moved folders (about 55 in code) and change project.godot's autoload paths if
   any autoload moves; this is the project.godot change that makes the release a full download.
3. `Compendium` reads two data roots, the core's and the game's own (CoS and custom entries, locations, NPCs, quests).
4. Point the Makefile, tools/check.py, lint and the test runner at the new paths; the runner needs the five autoloads above.
5. Dialogue grammar still names `tarokka_draw/read/give` and `end_game`: rename them to neutral statements in the grammar,
   the linters and the dialogue data, or keep them as the Strahd module's own statements.
6. The guard baseline (122 lines in 40 files) keeps shrinking: flags and ids in story_state, long_rest, travel and the
   combat AI profile still name Strahd.
