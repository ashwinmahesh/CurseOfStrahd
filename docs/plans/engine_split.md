# Engine split: dnd_core

Plan for moving the shareable parts of this game into a separate repo, github.com/ashwinmahesh/DungeonsAndDragonsGameEngine
(renamed from DndCoreEngine and made public 2026-10-26; local copy ~/Documents/DndCoreEngine), used here as a git submodule at `addons/dnd_core`. Study (2026-10-24):
https://claude.ai/artifact/XdvkGY28acaWLp4kAQJAmh. Owner decision 2026-10-24. The switch (steps 3 and 4) was written on 2026-10-25 with the
owner's typed yes, to land in the planned full-download release (1.0.11); "Where it stands" at the end says what it did.

## Order

1. **Decouple inside this repo** (no project.godot change). Move tables to data, rename the shader and palette, add a
   campaign-module hook, and keep the guard test green (`tests/unit/test_engine_names.gd`, below).
2. Move the rules data (items, monsters, spells, feats, subclasses and the rest) with the code: the core takes all of it.
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

`story/tarokka.gd`, `story/strahd_presence.gd`, `story/oracles.gd`, `story/endings.gd`, `addons/dnd_core/story/cheat_codes.gd`,
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

The core holds all the rules data, SRD or not (owner decision 2026-10-25: no SRD flag, no srd/ and books/ split), and the
owner made the repo public on 2026-10-26 with an MIT license on the code only and a NOTICE.md that says the book content
beyond SRD 5.2.1 belongs to Wizards of the Coast and is not licensed here (owner's choice of option C, against the advice
to publish SRD-only data).

## Where it stands (2026-10-25): switched

The game now uses the core as the submodule `addons/dnd_core` (public repo DungeonsAndDragonsGameEngine, formerly DndCoreEngine). `.gitmodules` names the GitHub
url; the files of the core keep their folders there, so the engine is `res://addons/dnd_core/rules`, `combat`, `story`,
the rules data is `res://addons/dnd_core/data/<folder>` and the test runner `res://addons/dnd_core/tests/test_runner.tscn`.

- **Moved**: everything `tools/core/manifest.json` named (2,229 files: 160 combat, 54 rules, 90 story, 26 schemas, 1,598 data
  entries of the books, 140 unit tests, 8 test helpers, the runner). `combat/ravenloft_features.gd` and the Faerûn packs went
  with the core after all (combat's own code names them, so leaving them would have made the core need the game). The
  tools stayed here (`tools/run_tests.py`, `check.py`, `lint_gd.sh`, `logcheck.sh`, `godot_slot.sh`, `tools/data/*.py`);
  they find the core by its path, and `tools/data/dataroots.py` gives the Python ones both data roots.
- **Two data roots**: `Compendium.shared()` loads `addons/dnd_core/data` and then `res://data` (CoS and custom entries,
  locations, NPCs, quests ...); a game entry replaces a core entry with its id. `Compendium.data_files(folder)` lists a
  folder's files across both. The core finds its own root from where `compendium.gd` sits (`Compendium.core_root()`).
- **Host contract**: the core's runner uses the host's autoloads (Dice, GameSettings, GameState, ModeController, SaveSystem);
  the story engine reads the host's `data/campaign.json` and the host data it names (cutscenes, schedule, weather, treasure
  levels, XP, chapters, AI profiles, night visitors).
- **Dialogue grammar**: `tarokka draw|read|give` became `reading draw|read|give` (step kinds `reading_*`); the module still
  carries them out. `end_game` stays: any campaign ends.
- **Guard test**: `tests/unit/test_engine_names.gd` scans the core's rules, combat and story through the submodule; the
  baseline keeps its paths from the core's root (115 lines in 40 files) and only shrinks. A fix to the engine is a commit in
  `addons/dnd_core`, then a new submodule commit here.
- `project.godot` has no change (the autoloads are the game's); the release is a full download because every moved script
  has a new `res://` path. `export_presets.cfg`'s exclude filter no longer drops `addons/*` (it would have dropped the whole
  engine); it drops the core's unit tests, test case and runner as it did the game's.
