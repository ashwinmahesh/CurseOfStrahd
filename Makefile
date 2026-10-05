# Curse of Strahd: the one set of commands. Godot 4.7.2 and Blender 5.2 on macOS.
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c
GODOT   ?= /Applications/Godot.app/Contents/MacOS/Godot
BLENDER ?= /Applications/Blender.app/Contents/MacOS/Blender
G       := $(GODOT) --path .
LOGCHK  := tools/logcheck.sh

.PHONY: run import test validate ci palette capture

run:
	$(G)

import:
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null

test: import
	$(G) --headless --quit-after 100000 res://tests/test_runner.tscn $(if $(ONLY),-- --only=$(ONLY),) 2>&1 | $(LOGCHK)

validate:
	python3 tools/data/validate_data.py

## Local CI: everything main must pass before a merge (plan §4, ADR 0001).
ci: validate test

palette:
	python3 tools/art/build_palette.py

## Opens a window for a few seconds and writes a screenshot to captures/.
capture:
	$(G) --resolution 1600x900 res://tools/capture/capture.tscn -- --scene=$(or $(SCENE),res://scenes/test/graybox_room.tscn) --out=$(CURDIR)/captures/$(or $(NAME),capture) --frames=$(or $(FRAMES),90)
