# Curse of Strahd: the one set of commands. Godot 4.7.2 and Blender 5.2 on macOS.
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c
GODOT   ?= /Applications/Godot.app/Contents/MacOS/Godot
BLENDER ?= /Applications/Blender.app/Contents/MacOS/Blender
G       := $(GODOT) --path .
LOGCHK  := tools/logcheck.sh

.PHONY: run arena import test lint validate ci palette capture standin sprite portrait wireframes

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

## Compiles every rules/ script standalone (no autoloads allowed there).
lint: import
	tools/lint_gd.sh

## Local CI: everything main must pass before a merge (plan §4, ADR 0001).
ci: validate lint test

palette:
	python3 tools/art/build_palette.py

## Opens a window for a few seconds and writes a screenshot to captures/. LOCATION=<id> starts the story game there.
capture:
	$(G) --resolution 1600x900 res://tools/capture/capture.tscn -- --scene=$(or $(SCENE),res://scenes/test/graybox_room.tscn) --out=$(CURDIR)/captures/$(or $(NAME),capture) --frames=$(or $(FRAMES),90) $(if $(FOCUS),--focus=$(FOCUS),) $(if $(LOCATION),--location=$(LOCATION),) $(if $(ENCOUNTER),--encounter=$(ENCOUNTER),)

## Stand-in turnaround (primitive villager) so the sprite pipeline can run without generated art.
standin:
	$(BLENDER) -b --python blender/make_standin_turnaround.py -- $(CURDIR)/art/generated/standin/villager_turnaround.png

## Turnaround sheet (3 or 5 views) -> cutout rig -> 8-direction walk: make sprite TURNAROUND=<png> ID=<id>
sprite:
	$(BLENDER) -b --python blender/render_walk.py -- --turnaround $(abspath $(TURNAROUND)) --id $(ID) $(if $(SIDE),--side-faces $(SIDE),) $(if $(STATIC),--static,)

## Portrait (square crop, 512 px, palette-snapped): make portrait SRC=<png> ID=<id>
portrait:
	$(BLENDER) -b --python blender/portrait.py -- --in $(abspath $(SRC)) --id $(ID)

## UI flow wireframes (docs/ui/wireframes/*.svg) from tools/ui/wireframes.py.
wireframes:
	python3 tools/ui/wireframes.py
