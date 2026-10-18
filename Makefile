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
## Imports with the editor's window kept off screen, so textures import several at once (tools/import.sh: about twice
## as fast; headless outside a desktop session or with IMPORT_HEADLESS=1). Its own notes go to stderr, shown here; a
## refused import (exit 75: a full one with under 20 GB free) or a stopped one stops FRESH without marking it done.
IMPORT  := GODOT=$(GODOT) tools/import.sh
STAMP   := .godot/.last_import
FRESH   := if [ ! -f $(STAMP) ] || [ -n "$$(find . \( -path ./.godot -o -path ./captures -o -path ./builds \) -prune -o \
             \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' -o -name '*.png' -o -name '*.ogg' -o -name '*.wav' \
             -o -name '*.mp3' -o -name '*.glb' \) -newer $(STAMP) -print -quit)" ]; then \
             echo "Files changed since the last import: importing first."; $(IMPORT) > /dev/null; s=$$?; \
             case $$s in 75|129|130|137|143) exit $$s ;; esac; touch $(STAMP); fi

.PHONY: run run-main arena smoke import test lint validate ci check lfs-quiet art-spend palette capture standin sprite sprites anims keys portrait wireframes textures prop props models ui_art icons cursors voice creator pregens plants vistas

## make run plays the edge build (owner, 2026-10-17; tools/edge/edge.py): main plus every lane branch that has been
## handed off but not merged yet, assembled in a throwaway worktree (CurseOfStrahdGame-edge, in the SSD lanes' image), so
## lane work can be tried as soon as it is handed off. It runs on its own user data folder, "Curse of Strahd Edge", which
## holds a copy of your saves and settings made at launch: the real ones are only read, never written. The branches are
## listed in ~/.curse-of-strahd/edge/branches.txt, kept out of git: make edge-add BRANCH=<branch> · make edge-remove
## BRANCH=<branch> · make edge-list · make edge-prune (drops the merged ones) · make edge-reset (removes the worktree;
## the next run makes it again) · make edge (assembles and imports, no window) · make edge-test (the script's tests).
## EDGE_BASE=origin/main starts from the last ci-green main instead of main; EDGE_KEEP_DATA=1 keeps the edge's own saves.
run:
	@python3 tools/edge/edge.py run

## The old make run: this checkout's own code, as it is. Imports first when scripts or assets changed since the last
## import (a merge can add a class_name or images that the editor cache doesn't know yet, and the game then stops at a
## parse error).
run-main:
	@$(FRESH)
	$(NOFOCUS) < /dev/null

.PHONY: edge edge-list edge-add edge-remove edge-prune edge-reset edge-test
edge:
	@python3 tools/edge/edge.py build
edge-list:
	@python3 tools/edge/edge.py list
edge-add:
	@python3 tools/edge/edge.py add $(BRANCH)
edge-remove:
	@python3 tools/edge/edge.py remove $(BRANCH)
edge-prune:
	@python3 tools/edge/edge.py prune
edge-reset:
	@python3 tools/edge/edge.py reset
edge-test:
	python3 -m unittest discover -s tests/tools -p 'test_edge*.py' -v

## Release builds (owner, 2026-10-08): the Windows export (export_presets.cfg) and, from the same pack, the Mac app
## (tools/release/mac_app.py; Godot's own macOS export wants ETC2/ASTC textures we don't import), zipped for download.
## Needs the 4.7.2 export templates installed. make release [OUT=<folder>] [VERSION=1.0.0]; OUT defaults to ../strahd-builds.
RELEASE_OUT = $(abspath $(or $(OUT),../strahd-builds))
.PHONY: release ios-pipeline-test
ios-pipeline-test:
	python3 -m unittest discover -s tests/tools -p 'test_ios_*.py' -v

release:
	@$(FRESH)
	mkdir -p "$(RELEASE_OUT)/windows" "$(RELEASE_OUT)/macos"
	$(GODOT) --headless --path . --export-release "Windows" "$(RELEASE_OUT)/windows/CurseOfStrahd.exe"
	python3 tools/release/mac_app.py --pck "$(RELEASE_OUT)/windows/CurseOfStrahd.pck" --out "$(RELEASE_OUT)/macos" --version $(or $(VERSION),1.0.0)
	rm -f "$(RELEASE_OUT)/CurseOfStrahd-windows.zip"
	cd "$(RELEASE_OUT)/windows" && zip -q -6 -r ../CurseOfStrahd-windows.zip CurseOfStrahd.exe CurseOfStrahd.pck

## Phase 2 exit: the combat arena (party of four level 3 pregens vs wolves and zombies).
arena:
	@$(FRESH)
	$(NOFOCUS) res://scenes/combat/arena.tscn < /dev/null

## Boots the game, or SCENE=res://..., headless for FRAMES frames (600); fails on errors. Agents check with this.
smoke:
	@$(FRESH)
	$(G) --headless --quit-after $(or $(FRAMES),600) $(SCENE) 2>&1 | $(LOGCHK)

import:
	$(IMPORT) | $(LOGCHK) > /dev/null
	@touch $(STAMP)

## The test files share several headless Godot processes (tools/run_tests.py); JOBS=n sets how many, JOBS=1 is one.
test: import
	python3 tools/run_tests.py --godot $(GODOT) $(if $(JOBS),--jobs $(JOBS),) $(if $(ONLY),--only=$(ONLY),) $(if $(FILES),--files=$(FILES),) 2>&1 | $(LOGCHK)

## Lane folders that cost almost no disk (tools/lane.sh): a worktree whose files and import cache are APFS clones of
## the main checkout's. make lane NAME=<name> BRANCH=<branch> [BASE=main] · make lane-reclone NAME=<name> (a running
## lane's unchanged files become clones again) · make lane-done NAME=<name> (once merged). SSD=1 on any of them: the
## lane is on the external SSD's disk image (/Volumes/StrahdLanes), cloned from a seed there. The seed is refreshed only
## when it has drifted from the lane's base (LANE_SEED_DRIFT files, 1500; LANE_SEED_ART_DRIFT textures, 40); make lane-seed SSD=1 refreshes it on its own,
## LANE_REFRESH_SEED=1 on make lane forces a refresh first, LANE_NO_IMPORT=1 skips the seed's import.
LANE = $(if $(SSD),LANE_ROOT=/Volumes/StrahdLanes )tools/lane.sh
.PHONY: lane lane-reclone lane-done lane-seed
lane:
	$(LANE) new $(NAME) $(BRANCH) $(or $(BASE),main)
lane-reclone:
	$(LANE) reclone $(NAME)
lane-done:
	$(LANE) done $(NAME)
lane-seed:
	$(LANE) seed

## Where the disk goes (tools/disk/disk.py report, read-only): free space on each volume with a worktree (the SSD
## lanes' image too), each worktree's branch, whether it's merged, and the bytes it holds on its own (what removing
## it frees), then git's packs, LFS objects and leftovers. FAST=1 skips measuring each worktree.
.PHONY: disk
disk:
	python3 tools/disk/disk.py report $(if $(FAST),--fast)

## The repo's git hooks (tools/git/), into the hooks folder every worktree shares: pre-push refuses a push of main
## unless STRAHD_PUSH_MAIN=1 (the build thread's), then runs Git LFS's own pre-push.
.PHONY: hooks
hooks:
	cp tools/git/pre-push "$$(git rev-parse --git-common-dir)/hooks/pre-push"

## Golden saves (P4): the playthrough tests keep a save at the start of each chapter in tests/saves
## (v<save version>_<chapter>.json, tests/support/golden_saves.gd); one already there is never made again.
.PHONY: golden-saves
golden-saves:
	GOLDEN_SAVES=$$(git rev-parse --short HEAD) $(MAKE) test FILES=test_golden_saves.gd,test_phase3_exit.gd,test_phase4_exit.gd,test_phase5_exit.gd,test_phase6_exit.gd


## Git LFS noise: old art and clips that only changed timestamp stop showing as modified (tools/lfs_quiet.sh).
lfs-quiet:
	@sh tools/lfs_quiet.sh

## Cheat Codes.md in the vault: every playable item's cheat code, rebuilt from the item data (tools/data/cheat_codes.py).
.PHONY: cheat-codes
cheat-codes:
	python3 tools/data/cheat_codes.py

## Magic item prices from Sane Magical Prices (data/treasure/magic_prices.json) written into the items' cost_gp.
.PHONY: magic-prices
magic-prices:
	python3 tools/data/magic_prices.py --apply

## The spoiler wiki in the vault (Wiki/), rebuilt from the game's data (tools/wiki/build_wiki.py). What people wrote on
## its pages outside the generated blocks is kept. wiki-shots first takes its screenshots in one off-screen run
## (tools/wiki/wiki_shots.gd; shots already in captures/wiki are kept, so delete one to retake it).
.PHONY: wiki wiki-shots
wiki:
	python3 tools/wiki/build_wiki.py $(if $(wildcard captures/wiki/*.png),--shots $(CURDIR)/captures/wiki,)
wiki-shots:
	python3 tools/wiki/build_wiki.py --shot-list $(CURDIR)/captures/wiki_shots.json
	$(UNSEEN) res://tools/capture/capture.tscn -- --scene=res://tools/wiki/wiki_shots.tscn --out=$(CURDIR)/captures/wiki --frames=30 --list=$(CURDIR)/captures/wiki_shots.json --dir=$(CURDIR)/captures/wiki < /dev/null
	python3 tools/wiki/build_wiki.py --shots $(CURDIR)/captures/wiki

validate:
	python3 tools/data/validate_data.py
	python3 tools/data/check_implemented.py
	python3 tools/data/check_rules_docs.py

## Compiles every rules/ script standalone (no autoloads allowed there).
lint: import
	tools/lint_gd.sh

## F1's balance tool (tools/balance/balance_sim.gd): a fight played RUNS times (20) in each difficulty mode by the
## pregens on autopilot. ENC=<data/encounters id>, or LOCATION=<id> FIGHT=<fight id> [LEVEL=n] [PARTY="a b c d"].
.PHONY: balance
balance:
	@$(FRESH)
	$(G) --headless --script res://tools/balance/balance_sim.gd -- $(if $(ENC),--encounter=$(ENC),) $(if $(LOCATION),--location=$(LOCATION),) $(if $(FIGHT),--fight=$(FIGHT),) $(if $(LEVEL),--level=$(LEVEL),) $(if $(PARTY),"--party=$(PARTY)",) $(if $(MODES),"--modes=$(MODES)",) $(if $(RUNS),--runs=$(RUNS),) $(if $(JSON),--json=$(JSON),) $(if $(NO_WARD),--no_ward,) 2>&1 | $(LOGCHK)

## XP levelling's simulator (tools/balance/xp_sim.py, docs/plans/xp_mode.md §5): replays the awards in data/progression/
## xp.json against the fight data and prints the party's level at every story gate for five kinds of player (under a
## minute, no Godot). Re-run it after retuning an award or a fight. RULES=build (default: what story/xp.gd does) | plan
## (the plan's model, which reproduces its tables) | literal.
.PHONY: xp-sim
xp-sim:
	python3 tools/balance/xp_sim.py . --tables --rules $(or $(RULES),build)

## Local CI: everything main must pass before a merge (plan §4, ADR 0001).
ci: validate lint test

## The quick check while working (CLAUDE.md says when it is enough): only what covers the files changed since main,
## from validate to the tests that use them (tools/check.py). make check [BASE=<branch>] [DEPTH=n|all] [DRY=1]
check:
	@$(if $(DRY),,$(FRESH))
	python3 tools/check.py $(if $(BASE),--base $(BASE),) $(if $(DEPTH),--depth $(DEPTH),) $(if $(DRY),--dry-run,)

palette:
	python3 tools/art/build_palette.py

## Gemini spend (tools/art/gemini_budget.py): each key's credit and today's requests, then spend per day and thread.
## make art-spend [DAYS=n] · after a top-up: make art-spend [KEY=backup] BALANCE=<usd> KEEP=<usd to leave untouched>
art-spend:
	python3 tools/art/gemini_budget.py $(if $(DAYS),--days $(DAYS),) $(if $(KEY),--key $(KEY),) $(if $(BALANCE),--balance $(BALANCE),) $(if $(KEEP),--keep $(KEEP),)

## Spoken lines (ADR 0013): generates the clips that are missing with the pinned ElevenLabs model (audio/voice/casting.json).
## make voice [SPEAKER="narrator madam_eva"] [LIMIT=n] [DRY=1] [MAX_USD=5] [RECAST=1] [PRUNE=1]
voice:
	python3 tools/audio/generate_voice.py $(if $(SPEAKER),--speaker $(SPEAKER),) $(if $(LIMIT),--limit $(LIMIT),) $(if $(DRY),--dry-run,) $(if $(MAX_USD),--max-usd $(MAX_USD),) $(if $(RECAST),--recast,) $(if $(PRUNE),--prune,)
	$(if $(DRY),,$(IMPORT) | $(LOGCHK) > /dev/null)

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
## The sheets it built get their import settings (VRAM, no mipmaps: the crisp sprite shader never reads them).
anims:
	$(if $(GENERATE),python3 tools/art/anim_keyframes.py --retry 2 $(if $(ONLY),--only $(ONLY),) && python3 tools/art/anim_keyframes.py --kind walk $(if $(ONLY),--only $(ONLY),),true)
	python3 tools/art/build_anims.py $(if $(ONLY),--only $(ONLY),)
	$(IMPORT) | $(LOGCHK) > /dev/null
	python3 tools/art/set_import.py --sheets $(foreach id,$(or $(ONLY),*),$(wildcard art/sprites/$(id)/walk.png) $(wildcard art/sprites/$(id)/attack.png))
	$(IMPORT) | $(LOGCHK) > /dev/null

## The six heroes' HD animation sheets (set v2) from their strips: make keys [ONLY="id ..."] [KINDS="walk8 ..."]
keys:
	python3 tools/art/build_keys.py $(if $(ONLY),--only $(ONLY),) $(if $(KINDS),--kinds $(KINDS),)
	$(IMPORT) | $(LOGCHK) > /dev/null
	python3 tools/art/set_import.py --sheets $(foreach id,$(or $(ONLY),godrick_pendlebrook kip_smudgewick liriel_dawnsong ratatoille thistle wren_featherfoot),$(wildcard art/sprites/$(id)/*.png))
	$(IMPORT) | $(LOGCHK) > /dev/null

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
	$(IMPORT) | $(LOGCHK) > /dev/null

## The Modern look's trees and plants (docs/art/plants.md): paints the leaf cards, builds art/plants/*.glb and
## manifest.json, then imports them. make plants [ONLY="spruce_a fern_a"] (rebuilds only those models).
plants:
	python3 tools/art/plant_cards.py
	$(BLENDER) -b --python blender/plants_3d.py -- $(if $(ONLY),--only $(ONLY),)
	$(IMPORT) | $(LOGCHK) > /dev/null

## The painted backdrops past a map's edge (docs/art/atmosphere.md "Vistas"): cuts art/generated/vistas into
## art/vistas, then imports them.
vistas:
	python3 tools/art/build_vistas.py
	$(G) --headless --import 2>&1 | $(LOGCHK) > /dev/null

## Menu ornaments and icons (black-on-white Gemini art -> white shapes with alpha, tinted in game): make ui_art
ui_art:
	$(BLENDER) -b --python blender/ui_art.py

## Spell and item icons (game-icons.net silhouettes framed in the menu colours; keys in art/icons.json): make icons
icons:
	$(G) --headless --script res://tools/art/build_icons.gd $(if $(KIND),-- --kind=$(KIND),) 2>&1 | $(LOGCHK)
	$(MAKE) import

## Mouse cursors from the game-icons silhouettes (tools/art/build_cursors.gd -> art/ui/cursors).
cursors:
	$(G) --headless --script res://tools/art/build_cursors.gd 2>&1 | $(LOGCHK)
	$(MAKE) import

## UI flow wireframes (docs/ui/wireframes/*.svg) from tools/ui/wireframes.py.
wireframes:
	python3 tools/ui/wireframes.py
