# Curse of Strahd — agent rules
Godot 4.7.2 (typed GDScript) · Blender 5.2 · macOS, Apple Silicon
Plan: ~/Documents/Obsidian Vault/CurseOfStrahd/Game_Plan.md (status updates are fine; scope changes go through the
project's coordinator)
Build logs for the owner: ~/Documents/Obsidian Vault/CurseOfStrahd/ ("Build Log NN - <title>.md")
Decisions: docs/adr/ · Tasks: docs/tasks/ · Rules coverage: docs/rules/coverage.md

## Commands (add new ones to the Makefile)
make run | arena | smoke [SCENE=… FRAMES=n] | test [ONLY=substr FILES=a.gd,b.gd] | validate | lint | check [DRY=1] | ci | palette | capture [SCENE=… NAME=… FRAMES=… FOCUS=node LOCATION=id]
make sprite TURNAROUND=<png> ID=<id> [STATIC=1|BODY=…] | anims [ONLY="id …"] [GENERATE=1] | keys [ONLY="id …"] [KINDS=…] | creator [GENERATE=1] | pregens [ONLY="id …"] | portrait SRC=<png> ID=<id> | textures | prop SRC=<png> ID=<id> HEIGHT=<units> | props [GENERATE=1] [ONLY=sheet] | ui_art | icons | standin | wireframes
make capture SCENE=res://tools/art/preview/location_tour.tscn LOCATION=<id> NAME=tour [ARGS="--lit --shots=6"] (set dressing QA)
python3 tools/data/validate_data.py --pending (later-phase references) · python3 tools/data/data_sources.py
make voice [SPEAKER="narrator …"] [LIMIT=n] [DRY=1] [MAX_USD=n] (spoken lines, ADR 0013)

## Godot windows (the owner works on this Mac)
- Never open a Godot window that can take focus or cover the owner's work. Checks without pixels run headless
  (`make test`, `make smoke` to boot the game or a scene); screenshots only through `make capture`, which draws off
  screen. Batch screenshots into few runs.
- Any other Godot run that opens a window goes through `tools/godot` (same arguments as Godot), never the Godot.app
  path: it loads tools/macos/nofocus.m so Godot can't activate itself (owner decision 2026-10-06).
- `make run` and `make arena` are for the owner to play: run them only when asked.

## Code
- Static types everywhere; `untyped_declaration` is an error.
- `rules/` is a pure library: no nodes, scenes, autoloads or UI. It takes a DiceRoller argument.
- `combat/` (grid, Encounter, spells, features, AI, action catalog) is pure logic too (ADR 0007); scenes and the
  HUD only show it and send it commands. Contract: docs/contracts/combat.md.
- Every die roll goes through DiceRoller (Dice.roller in game code). Cosmetic randomness uses its own RNG.
- The player controls every party member and guest; AI only drives enemies and neutrals.
- Scenes are built in code; .tscn files are thin roots. 1 world unit = one 5 ft square.
- After adding a class_name, `make import` before `make test`.

## Rules engine (ADR 0003, 0005, 0006)
- Data is read through `Compendium.shared()`; modifiers follow docs/contracts/modifiers.md (add a stat to the contract
  and the engine together, never only in data). Every number the UI shows is a `Breakdown`.
- A character is its `build` (keyed choices, see ADR 0006); `refresh()` derives the rest. The UI never computes rules:
  it reads CharacterBuilder / LevelUpController and picks widgets by `Choice.kind`.
- `make lint` compiles rules/ and combat/ standalone, so an autoload reference there fails CI.

## Rules source
Full 2024 PHB (owner decision 2026-10-05, personal use only). SRD 5.2 is the import starting point.
Rule deviations go in docs/rules/deviations.md; a rule is "done" only when coverage.md says so.
Data `text` and `summary` are our own words, never copied. Set `source.checked_against` only after comparing every
number with that source (BR2024 = the free 2024 Basic Rules). SRD 5.2.1 attribution: docs/assets/LICENSES.md.

## Art
- Colours only from art/palette/palette.json, plus art/palette/ui_palette.json for menus (via Look) — run
  `make palette` after editing the lists. Menu ornaments and icons: `make ui_art`.
- Spell and item icons: game-icons.net silhouettes (art/sourced/game_icons, CC BY 3.0) picked per key in
  art/icons.json as `<silhouette>@<tint>` (spells coloured by flavour, items in their natural colours; tints in the
  same file) and framed by `make icons`; a spell or item's data `icon` names its key, else its id is the key.
  Credit any new artist in art/credits.json (tests/unit/test_icons.gd checks).
- Images: Gemini (gemini-3.1-flash-image, owner decision 2026-10-06) via tools/art/generate.sh only;
  provider and model pinned in art/manifest.json. Key: GEMINI_API_KEY, sent as a header. Gemini gives opaque
  images, so ask for a plain flat white background; the pipeline removes it. OpenAI is a fallback
  (tools/art/generate_openai.sh); never use OpenAI models with a shutdown date.
- Asset packs from the internet are allowed (owner, 2026-10-06): CC0 or clearly free licences only. Keep
  downloads untouched with their licence in art/sourced/<pack>/ and list each in docs/assets/LICENSES.md.
  Characters come from the Gemini pipeline so the style stays consistent.
- Set dressing (docs/art/set_dressing.md): a location's props, containers, doors and exits are dressed from
  art/sprites/props/catalog.json by `model` or id; a new model needs art there (test_set_dressing checks). Towns are
  built by TownBuilder (houses, roofs, yard walls). Never fall back to plain boxes for new content.
- Every character sprite walks and attacks in 8 directions (docs/art/animation.md; a test checks): after
  `make sprite`, add the character to art/anim/animations.json and run `make anims ONLY=<id> GENERATE=1`. The six
  heroes have the fuller HD set instead: `make keys [ONLY=<id>]` (docs/art/animation.md).
- UI draws on CanvasLayers so the palette pass never touches it.
- Git LFS (owner decision 2026-10-07; .gitattributes): new or changed images under art/generated, art/sprites,
  art/portraits, art/creator and art/textures, and voice mp3s, are stored in LFS. Older files stay plain blobs until
  they change: never `git lfs migrate` or `git add --renormalize`, and stage only files you changed (an old image whose
  timestamp moved shows as modified and would be uploaded to LFS). This repo's worktrees share its LFS setup; a
  separate clone needs `git lfs install` (art/generated isn't used at run time, so `lfs.fetchexclude` can skip it).

## Voice (ADR 0013)
- Spoken lines: ElevenLabs (eleven_v4, owner decision 2026-10-06) via `make voice` only; model, format and each
  speaker's voice pinned in audio/voice/casting.json. Barovians, Vistani and the castle's people name `eleven_v3`
  there, which keeps their accents (owner, 2026-10-07). Key: ELEVENLABS_API_KEY, sent as a header. A clip is
  audio/voice/<speaker>/<sha1(text)[:16]>.mp3, so editing a line leaves it silent until `make voice` runs again;
  `VoiceOver.say` plays it (party lines in the speaker's voice: `VoiceOver.beat_voice`). Lines with {name},
  options and books are never voiced.

## Done means
- `make check` while working: it runs only what covers the files changed since main (tools/check.py, `DRY=1` shows
  the plan). Docs alone run nothing; art and audio files only re-import; data and dialogue run the validators and
  the tests that name the changed ids; scripts and scenes run lint and the tests that use them.
- `make check` green is enough to hand over docs, art, audio, data, dialogue, captures, tools, Makefile targets
  outside `make ci` (it dry-runs them), and ui/ or world/ scripts. Changes to rules/, combat/, story/, core/,
  tests/support or the ci targets need `make ci` green with a clean log.
  The build thread runs `make ci` before every merge to main either way.
- A capture for anything visual. Never weaken tests to pass. Never mark an owner sign-off as passed.
