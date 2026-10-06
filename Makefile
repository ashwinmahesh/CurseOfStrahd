# Curse of Strahd: the one set of commands. Godot 4.7.2 and Blender 5.2 on macOS.
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c
GODOT   ?= /Applications/Godot.app/Contents/MacOS/Godot
BLENDER ?= /Applications/Blender.app/Contents/MacOS/Blender
G       := $(GODOT) --path .
LOGCHK  := tools/logcheck.sh

.PHONY: run arena import test lint validate ci palette capture standin sprite sprites portrait wireframes textures prop props ui_art

run:
	$(G)

## Phase 2 exit: the combat arena (party of four level 3 pregens vs wolves and zombies).
arena:
	$(G) res://scenes/combat/arena.tscn

import:
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null

test: import
	$(G) --headless --quit-after 100000 res://tests/test_runner.tscn $(if $(ONLY),-- --only=$(ONLY),) 2>&1 | $(LOGCHK)

validate:
	python3 tools/data/validate_data.py
	python3 tools/data/check_implemented.py

## Compiles every rules/ script standalone (no autoloads allowed there).
lint: import
	tools/lint_gd.sh

## Local CI: everything main must pass before a merge (plan §4, ADR 0001).
ci: validate lint test

palette:
	python3 tools/art/build_palette.py

## Opens a window for a few seconds and writes a screenshot to captures/. LOCATION=<id> starts the story game there.
capture:
	$(G) --resolution 1600x900 res://tools/capture/capture.tscn -- --scene=$(or $(SCENE),res://scenes/test/graybox_room.tscn) --out=$(CURDIR)/captures/$(or $(NAME),capture) --frames=$(or $(FRAMES),90) $(if $(FOCUS),--focus=$(FOCUS),) $(if $(LOCATION),--location=$(LOCATION),) $(if $(ENCOUNTER),--encounter=$(ENCOUNTER),) $(if $(LOAD),--load=$(LOAD),) $(if $(DIALOGUE),--dialogue=$(DIALOGUE),) $(if $(BEATS),--beats=$(BEATS),) $(if $(MAP),--map,) $(if $(SHOP),--shop=$(SHOP),) $(ARGS)

## Stand-in turnaround (primitive villager) so the sprite pipeline can run without generated art.
standin:
	$(BLENDER) -b --python blender/make_standin_turnaround.py -- $(CURDIR)/art/generated/standin/villager_turnaround.png

## Turnaround sheet (3 or 5 views) -> cutout rig -> 8-direction walk: make sprite TURNAROUND=<png> ID=<id> [SAT=1.3]
sprite:
	$(BLENDER) -b --python blender/render_walk.py -- --turnaround $(abspath $(TURNAROUND)) --id $(ID) $(if $(SIDE),--side-faces $(SIDE),) $(if $(STATIC),--static,) $(if $(SAT),--saturate $(SAT),)

## Re-render every character walk sheet from its turnaround with the current cutter and its recorded flags
## (art/manifest.json sprite_flags): make sprites [ONLY="id ..."]
sprites:
	python3 tools/art/rerender_sprites.py $(if $(ONLY),--only $(ONLY),)

## Portrait (square crop, 512 px, palette-snapped, flat background): make portrait SRC=<png> ID=<id> [BG=<palette name>] [SAT=1.3]
portrait:
	$(BLENDER) -b --python blender/portrait.py -- --in $(abspath $(SRC)) --id $(ID) $(if $(BG),--bg $(BG),) $(if $(SAT),--saturate $(SAT),)

## Environment texture sets (docs/art/textures.md): make textures [GENERATE=1] [ONLY="village/cobbles ..."]
textures:
	python3 tools/art/build_textures.py $(if $(GENERATE),--generate,) $(if $(ONLY),--only $(ONLY),)

## Billboard prop (single view on white -> cut out, palette-snapped): make prop SRC=<png> ID=<id> HEIGHT=<world units>
prop:
	$(BLENDER) -b --python blender/prop_sprite.py -- --in $(abspath $(SRC)) --id $(ID) --height $(HEIGHT) $(if $(SAT),--saturate $(SAT),)

## Set dressing props, wall pieces and doors, four per Gemini call (docs/art/set_dressing.md):
## make props [GENERATE=1] [ONLY="sheet ..."]   then make import and tools/art/set_import.py on new files
props:
	python3 tools/art/build_props.py $(if $(GENERATE),--generate,) $(if $(ONLY),--only $(ONLY),)

## Menu ornaments and icons (black-on-white Gemini art -> white shapes with alpha, tinted in game): make ui_art
ui_art:
	$(BLENDER) -b --python blender/ui_art.py

## UI flow wireframes (docs/ui/wireframes/*.svg) from tools/ui/wireframes.py.
wireframes:
	python3 tools/ui/wireframes.py
