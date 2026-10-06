# Curse of Strahd — agent rules
Godot 4.7.2 (typed GDScript) · Blender 5.2 · macOS, Apple Silicon
Plan: ~/Documents/Obsidian Vault/CurseOfStrahd/Game_Plan.md (owned by the planning thread; read, don't edit)
Build logs for the owner: ~/Documents/Obsidian Vault/CurseOfStrahd/ ("Build Log NN - <title>.md")
Decisions: docs/adr/ · Tasks: docs/tasks/ · Rules coverage: docs/rules/coverage.md

## Commands (add new ones to the Makefile)
make run | test [ONLY=substr] | validate | ci | palette | capture [SCENE=… NAME=… FRAMES=… FOCUS=node]
make sprite TURNAROUND=<png> ID=<id> | standin

## Code
- Static types everywhere; `untyped_declaration` is an error.
- `rules/` is a pure library: no nodes, scenes, autoloads or UI. It takes a DiceRoller argument.
- Every die roll goes through DiceRoller (Dice.roller in game code). Cosmetic randomness uses its own RNG.
- The player controls every party member and guest; AI only drives enemies and neutrals.
- Scenes are built in code; .tscn files are thin roots. 1 world unit = one 5 ft square.
- After adding a class_name, `make import` before `make test`.

## Rules source
Full 2024 PHB (owner decision 2026-10-05, personal use only). SRD 5.2 is the import starting point.
Rule deviations go in docs/rules/deviations.md; a rule is "done" only when coverage.md says so.

## Art
- Colours only from art/palette/palette.json (via Look) — run `make palette` after editing the list.
- Images: Gemini (gemini-3.1-flash-image, owner decision 2026-10-06) via tools/art/generate.sh only;
  provider and model pinned in art/manifest.json. Key: GEMINI_API_KEY, sent as a header. Gemini gives opaque
  images, so ask for a plain flat white background; the pipeline removes it. OpenAI is a fallback
  (tools/art/generate_openai.sh); never use OpenAI models with a shutdown date.
- UI draws on CanvasLayers so the palette pass never touches it.

## Done means
`make ci` green with a clean log, plus a capture for anything visual. Never weaken tests to pass.
Never mark an owner sign-off as passed.
