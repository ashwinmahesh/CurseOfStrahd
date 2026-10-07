# Curse of Strahd: the one set of commands. Godot 4.7.2 and Blender 5.2 on macOS.
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c
GODOT   ?= /Applications/Godot.app/Contents/MacOS/Godot
BLENDER ?= /Applications/Blender.app/Contents/MacOS/Blender
G       := $(GODOT) --path .
## run and arena: Godot started by a tool skips its extra "unbundled activation hack" when the bundle id matches and no
## standard stream is a terminal; from the owner's terminal the game still comes to the front.
NOFOCUS := env __CFBundleIdentifier=org.godotengine.godot $(G)
## Agent runs that open a window go through tools/godot, which keeps Godot from ever taking focus (CLAUDE.md).
UNSEEN  := GODOT=$(GODOT) tools/godot --path . --resolution 1x1 --position 100000,100000 --max-fps 60 --audio-driver Dummy
LOGCHK  := tools/logcheck.sh
STAMP   := .godot/.last_import
FRESH   := if [ ! -f $(STAMP) ] || [ -n "$$(find . \( -path ./.godot -o -path ./captures -o -path ./builds \) -prune -o \
             \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' -o -name '*.png' -o -name '*.ogg' -o -name '*.wav' \
             -o -name '*.mp3' -o -name '*.glb' \) -newer $(STAMP) -print -quit)" ]; then \
             echo "Files changed since the last import: importing first."; $(G) --headless --import > /dev/null 2>&1; \
             touch $(STAMP); fi

.PHONY: run arena smoke import test lint validate ci check lfs-quiet palette capture standin sprite sprites anims keys portrait wireframes textures prop props models ui_art icons cursors voice creator pregens

## Imports first when scripts or assets changed since the last import (a merge can add a class_name or images that
## the editor cache doesn't know yet, and the game then stops at a parse error).
run:
	@$(FRESH)
	$(NOFOCUS) < /dev/null

## The owner's stable copy (P1, tools/play/play.sh): ~/Documents/CurseOfStrahdGame-play moves forward to the newest
## main that passed make ci (refs/play/green), imports what changed, then starts. PLAY_NO_RUN=1 only updates it.
.PHONY: play
play:
	@tools/play/play.sh

## Phase 2 exit: the combat arena (party of four level 3 pregens vs wolves and zombies).
arena:
	@$(FRESH)
	$(NOFOCUS) res://scenes/combat/arena.tscn < /dev/null

## Boots the game, or SCENE=res://..., headless for FRAMES frames (600); fails on errors. Agents check with this.
smoke:
	@$(FRESH)
	$(G) --headless --quit-after $(or $(FRAMES),600) $(SCENE) 2>&1 | $(LOGCHK)

import:
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null
	@touch $(STAMP)

test: import
	$(G) --headless --quit-after 100000 res://tests/test_runner.tscn -- $(if $(ONLY),--only=$(ONLY),) $(if $(FILES),--files=$(FILES),) 2>&1 | $(LOGCHK)


## Git LFS noise: old art and clips that only changed timestamp stop showing as modified (tools/lfs_quiet.sh).
lfs-quiet:
	@sh tools/lfs_quiet.sh

validate:
	python3 tools/data/validate_data.py
	python3 tools/data/check_implemented.py

## Compiles every rules/ script standalone (no autoloads allowed there).
lint: import
	tools/lint_gd.sh

## Local CI: everything main must pass before a merge (plan §4, ADR 0001).
ci: validate lint test

## The quick check while working (CLAUDE.md says when it is enough): only what covers the files changed since main,
## from validate to the tests that use them (tools/check.py). make check [BASE=<branch>] [DRY=1]
check:
	@$(FRESH)
	python3 tools/check.py $(if $(BASE),--base $(BASE),) $(if $(DRY),--dry-run,)

palette:
	python3 tools/art/build_palette.py

## Spoken lines (ADR 0013): generates the clips that are missing with the pinned ElevenLabs model (audio/voice/casting.json).
## make voice [SPEAKER="narrator madam_eva"] [LIMIT=n] [DRY=1] [MAX_USD=5] [RECAST=1] [PRUNE=1]
voice:
	python3 tools/audio/generate_voice.py $(if $(SPEAKER),--speaker $(SPEAKER),) $(if $(LIMIT),--limit $(LIMIT),) $(if $(DRY),--dry-run,) $(if $(MAX_USD),--max-usd $(MAX_USD),) $(if $(RECAST),--recast,) $(if $(PRUNE),--prune,)
	$(if $(DRY),,$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null)

## Writes screenshots to captures/ from a window that never takes focus or shows: it opens 1 px wide in a corner, moves
## off screen and is drawn by tools/capture (silent, 60 fps). LOCATION=<id> starts the story game there.
capture:
	$(UNSEEN) res://tools/capture/capture.tscn -- --scene=$(or $(SCENE),res://scenes/test/graybox_room.tscn) --out=$(CURDIR)/captures/$(or $(NAME),capture) --frames=$(or $(FRAMES),90) $(if $(FOCUS),--focus=$(FOCUS),) $(if $(LOCATION),--location=$(LOCATION),) $(if $(ENCOUNTER),--encounter=$(ENCOUNTER),) $(if $(LOAD),--load=$(LOAD),) $(if $(DIALOGUE),--dialogue=$(DIALOGUE),) $(if $(BEATS),--beats=$(BEATS),) $(if $(MAP),--map,) $(if $(SHOP),--shop=$(SHOP),) $(ARGS) < /dev/null

## Stand-in turnaround (primitive villager) so the sprite pipeline can run without generated art.
standin:
	$(BLENDER) -b --python blender/make_standin_turnaround.py -- $(CURDIR)/art/generated/standin/villager_turnaround.png

## Turnaround sheet (3 or 5 views) -> cutout rig -> 8-direction walk: make sprite TURNAROUND=<png> ID=<id> [SAT=1.3]
## [BODY=quadruped|float|hop|slither|lumber|swarm] (docs/art/animation.md). Then add the character to
## art/anim/animations.json and run make anims ONLY=<id> GENERATE=1 for its attack.
sprite:
	$(BLENDER) -b --python blender/render_walk.py -- --turnaround $(abspath $(TURNAROUND)) --id $(ID) $(if $(SIDE),--side-faces $(SIDE),) $(if $(STATIC),--static,) $(if $(SAT),--saturate $(SAT),) $(if $(BODY),--body $(BODY),)

## Walk and attack sheets for every character in art/anim/animations.json, or ONLY="id ...", from the keyframe
## strips in art/generated/anim (docs/art/animation.md). GENERATE=1 first draws the strips that are missing (Gemini).
anims:
	$(if $(GENERATE),python3 tools/art/anim_keyframes.py --retry 2 $(if $(ONLY),--only $(ONLY),) && python3 tools/art/anim_keyframes.py --kind walk $(if $(ONLY),--only $(ONLY),),true)
	python3 tools/art/build_anims.py $(if $(ONLY),--only $(ONLY),)
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null
	python3 tools/art/set_import.py $(wildcard art/sprites/*/walk.png) $(wildcard art/sprites/*/attack.png)
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null

## The six heroes' HD animation sheets (set v2) from their strips: make keys [ONLY="id ..."] [KINDS="walk8 ..."]
keys:
	python3 tools/art/build_keys.py $(if $(ONLY),--only $(ONLY),) $(if $(KINDS),--kinds $(KINDS),)
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null
	python3 tools/art/set_import.py --sheets $(foreach id,$(or $(ONLY),godrick_pendlebrook kip_smudgewick liriel_dawnsong ratatoille thistle wren_featherfoot),$(wildcard art/sprites/$(id)/*.png))
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null

## Re-render every character walk sheet from its turnaround with the current cutter and its recorded flags
## (art/manifest.json sprite_flags): make sprites [ONLY="id ..."]
sprites:
	python3 tools/art/rerender_sprites.py $(if $(ONLY),--only $(ONLY),)

## The custom hero's paper doll (docs/art/creator.md): cuts every piece whose art exists; GENERATE=1 first draws what's
## missing (Gemini), ONLY="bases bodies heads hair beards strips portraits" limits it.
creator:
	python3 tools/art/creator_art.py $(if $(GENERATE),--generate,) $(if $(ONLY),--only $(ONLY),) --process

## The pregenerated companions' builds and level plans (tools/data/pregen_specs.json -> data/pregens/<id>.json), made
## through the character builder so every pick is legal: make pregens [ONLY="id ..."] [VERBOSE=1]
pregens:
	$(GODOT) --headless --path . --script res://tools/data/make_pregens.gd -- $(if $(ONLY),"--only=$(ONLY)",) $(if $(VERBOSE),--verbose,)

## Portrait (square crop, 512 px, palette-snapped, flat background): make portrait SRC=<png> ID=<id> [BG=<palette name>] [SAT=1.3]
portrait:
	$(BLENDER) -b --python blender/portrait.py -- --in $(abspath $(SRC)) --id $(ID) $(if $(BG),--bg $(BG),) $(if $(SAT),--saturate $(SAT),)

## Environment texture sets (docs/art/textures.md): make textures [GENERATE=1] [ONLY="village/cobbles ..."] [HD=1]
## (HD=1: only the Modern look's smooth tiles, <surface>_hd.png)
textures:
	python3 tools/art/build_textures.py $(if $(GENERATE),--generate,) $(if $(ONLY),--only $(ONLY),) $(if $(HD),--hd,)

## Billboard prop (single view on white -> cut out, palette-snapped): make prop SRC=<png> ID=<id> HEIGHT=<world units>
prop:
	$(BLENDER) -b --python blender/prop_sprite.py -- --in $(abspath $(SRC)) --id $(ID) --height $(HEIGHT) $(if $(SAT),--saturate $(SAT),)

## Set dressing props, wall pieces and doors, four per Gemini call (docs/art/set_dressing.md):
## make props [GENERATE=1] [ONLY="sheet ..."]   then make import and tools/art/set_import.py on new files
props:
	python3 tools/art/build_props.py $(if $(GENERATE),--generate,) $(if $(ONLY),--only $(ONLY),)

## 3D set pieces modelled from the 2D props they replace (docs/art/models.md): make models [ONLY="bookcase desk"]
## [PREVIEW=captures/models.png] writes art/models/*.glb and manifest.json, then imports them.
models:
	$(BLENDER) -b --python blender/models_3d.py -- $(if $(ONLY),--only $(ONLY),) $(if $(PREVIEW),--preview $(abspath $(PREVIEW)),)
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null

## Menu ornaments and icons (black-on-white Gemini art -> white shapes with alpha, tinted in game): make ui_art
ui_art:
	$(BLENDER) -b --python blender/ui_art.py

## Spell and item icons (game-icons.net silhouettes framed in the menu colours; keys in art/icons.json): make icons
icons:
	$(G) --headless --script res://tools/art/build_icons.gd 2>&1 | $(LOGCHK)
	$(MAKE) import

## Mouse cursors from the game-icons silhouettes (tools/art/build_cursors.gd -> art/ui/cursors).
cursors:
	$(G) --headless --script res://tools/art/build_cursors.gd 2>&1 | $(LOGCHK)
	$(MAKE) import

## UI flow wireframes (docs/ui/wireframes/*.svg) from tools/ui/wireframes.py.
wireframes:
	python3 tools/ui/wireframes.py
