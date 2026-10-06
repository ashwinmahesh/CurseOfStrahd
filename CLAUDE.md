# Curse of Strahd — agent rules
Godot 4.7.2 (typed GDScript) · Blender 5.2 · macOS, Apple Silicon
Plan: ~/Documents/Obsidian Vault/CurseOfStrahd/Game_Plan.md (owned by the planning thread; read, don't edit)
Build logs for the owner: ~/Documents/Obsidian Vault/CurseOfStrahd/ ("Build Log NN - <title>.md")
Decisions: docs/adr/ · Tasks: docs/tasks/ · Rules coverage: docs/rules/coverage.md

## Commands (add new ones to the Makefile)
make run | test [ONLY=substr] | validate | lint | ci | palette | capture [SCENE=… NAME=… FRAMES=… FOCUS=node]
make sprite TURNAROUND=<png> ID=<id> | standin | wireframes
python3 tools/data/validate_data.py --pending (later-phase references) · python3 tools/data/data_sources.py

## Code
- Static types everywhere; `untyped_declaration` is an error.
- `rules/` is a pure library: no nodes, scenes, autoloads or UI. It takes a DiceRoller argument.
- Every die roll goes through DiceRoller (Dice.roller in game code). Cosmetic randomness uses its own RNG.
- The player controls every party member and guest; AI only drives enemies and neutrals.
- Scenes are built in code; .tscn files are thin roots. 1 world unit = one 5 ft square.
- After adding a class_name, `make import` before `make test`.

## Rules engine (ADR 0003, 0005, 0006)
- Data is read through `Compendium.shared()`; modifiers follow docs/contracts/modifiers.md (add a stat to the contract
  and the engine together, never only in data). Every number the UI shows is a `Breakdown`.
- A character is its `build` (keyed choices, see ADR 0006); `refresh()` derives the rest. The UI never computes rules:
  it reads CharacterBuilder / LevelUpController and picks widgets by `Choice.kind`.
- `make lint` compiles rules/ standalone, so an autoload reference there fails CI.

## Rules source
Full 2024 PHB (owner decision 2026-10-05, personal use only). SRD 5.2 is the import starting point.
Rule deviations go in docs/rules/deviations.md; a rule is "done" only when coverage.md says so.
Data `text` and `summary` are our own words, never copied. Set `source.checked_against` only after comparing every
number with that source (BR2024 = the free 2024 Basic Rules). SRD 5.2.1 attribution: docs/assets/LICENSES.md.

## Art
- Colours only from art/palette/palette.json (via Look) — run `make palette` after editing the list.
- Images: Gemini (gemini-3.1-flash-image, owner decision 2026-10-06) via tools/art/generate.sh only;
  provider and model pinned in art/manifest.json. Key: GEMINI_API_KEY, sent as a header. Gemini gives opaque
  images, so ask for a plain flat white background; the pipeline removes it. OpenAI is a fallback
  (tools/art/generate_openai.sh); never use OpenAI models with a shutdown date.
- Asset packs from the internet are allowed (owner, 2026-10-06): CC0 or clearly free licences only. Keep
  downloads untouched with their licence in art/sourced/<pack>/ and list each in docs/assets/LICENSES.md.
  Characters come from the Gemini pipeline so the style stays consistent.
- UI draws on CanvasLayers so the palette pass never touches it.

## Done means
`make ci` green with a clean log, plus a capture for anything visual. Never weaken tests to pass.
Never mark an owner sign-off as passed.
