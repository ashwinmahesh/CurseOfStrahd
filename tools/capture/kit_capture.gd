extends Node
## Before-and-after shots for the building kit (Improvement Ideas W7, the surfaces and architecture lane): the town
## houses, yard walls, interior walls and pillars from the game's camera, in daylight and at dusk, so a change to the
## kit can be judged side by side. Not part of the game.
##   make capture SCENE=res://tools/capture/kit_capture.tscn NAME=kit/before FRAMES=10
## Environment: KIT_SHOTS=village_dusk,vallaki_noon (default: every shot); KIT_OFF=1 builds the towns without the kit
## (the plain boxes), for the same shots before and after under the same light; KIT_LOW_WALLS=1 keeps rooms' walls at
## the cut-away height (before W8); KIT_NO_CASTLE=1 leaves Castle Ravenloft's outside as stone houses (before W19);
## KIT_FLAT_FIRE=1 keeps fires' flames 2D; KIT_LIT=1 adds a work light.

## Each shot: the place, the hour, where the party stands (empty: the place's own spawn), and optionally the square
## the camera looks at, how far it is, and how many 90-degree steps it is turned from the opening heading.
const SHOTS := {
	"village_dusk": {"loc": "village_of_barovia", "hour": 18},
	"village_noon": {"loc": "village_of_barovia", "hour": 12, "cells": [[16, 10], [17, 10], [16, 11], [17, 11]],
		"look": [12, 6], "dist": 15.0},
	"village_houses": {"loc": "village_of_barovia", "hour": 12, "cells": [[16, 10], [17, 10], [16, 11], [17, 11]],
		"look": [9, 18], "dist": 13.0, "yaw": 2},
	"village_mansion": {"loc": "village_of_barovia", "hour": 16, "cells": [[8, 7], [9, 7], [8, 8], [9, 8]],
		"look": [7, 4], "dist": 11.0, "yaw": -1},
	"village_close": {"loc": "village_of_barovia", "hour": 12, "cells": [[13, 21], [14, 21], [13, 22], [14, 22]],
		"look": [15, 21], "dist": 8.0},
	"vallaki_gate": {"loc": "vallaki", "hour": 12, "cells": [[2, 21], [3, 21], [2, 22], [3, 22]],
		"look": [4, 17], "dist": 12.0, "yaw": 1},
	"village_church_out": {"loc": "village_of_barovia", "hour": 12, "cells": [[32, 6], [33, 6], [34, 6], [35, 6]],
		"look": [33, 4], "dist": 14.0},
	"vallaki_church_out": {"loc": "vallaki", "hour": 12, "cells": [[39, 9], [40, 9], [41, 9], [42, 9]],
		"look": [40, 5], "dist": 15.0},
	"vallaki_noon": {"loc": "vallaki", "hour": 12, "cells": [[20, 19], [21, 19], [20, 20], [21, 20]],
		"look": [22, 12], "dist": 17.0},
	"krezk_noon": {"loc": "krezk", "hour": 13, "cells": [[14, 13], [15, 13], [14, 14], [15, 14]],
		"look": [12, 10], "dist": 15.0, "yaw": 1},
	"road_day": {"loc": "into_the_mists_road", "hour": 12, "cells": [[12, 15], [13, 15], [12, 16], [13, 14]]},
	"crossroads": {"loc": "svalich_crossroads", "hour": 12, "cells": [[20, 15], [21, 15], [20, 16], [21, 16]],
		"look": [20, 12], "dist": 15.0},
	"death_house_hall": {"loc": "death_house_ground", "cells": [[13, 8], [14, 8], [13, 9], [14, 9]]},
	"castle_hall": {"loc": "castle_ravenloft_main_floor", "cells": [[25, 8], [26, 8], [25, 9], [26, 9]]},
	"inn": {"loc": "vallaki_blue_water_inn", "cells": [[6, 8], [7, 8], [6, 9], [7, 9]]},
	"inn_turned": {"loc": "vallaki_blue_water_inn", "cells": [[6, 8], [7, 8], [6, 9], [7, 9]], "yaw": 2},
	"hall_turned": {"loc": "death_house_ground", "cells": [[13, 8], [14, 8], [13, 9], [14, 9]], "yaw": 1},
	"death_house_upper": {"loc": "death_house_upper"},
	"dungeon": {"loc": "death_house_dungeon_2"},
	"church": {"loc": "village_church", "cells": [[10, 14], [11, 14], [10, 15], [11, 15]]},
	"fire_krezk": {"loc": "krezk", "hour": 21, "cells": [[27, 17], [27, 18], [26, 17], [26, 18]], "look": [28, 17], "dist": 8.0},
	"fire_camp": {"loc": "vallaki_vistani_camp", "hour": 21, "cells": [[13, 12], [13, 13], [12, 12], [12, 13]],
		"look": [14, 12], "dist": 8.0},
	"fire_inn": {"loc": "vallaki_blue_water_inn", "cells": [[10, 8], [11, 8], [10, 9], [11, 9]], "look": [11, 6], "dist": 8.0},
	"fire_hall": {"loc": "castle_ravenloft_main_floor", "cells": [[44, 8], [45, 8], [44, 9], [45, 9]], "look": [46, 6], "dist": 9.0},
	"castle_gates": {"loc": "castle_ravenloft_gates", "hour": 21, "cells": [[19, 29], [20, 29], [19, 30], [20, 30]],
		"dist": 20.0},
	"castle_court": {"loc": "castle_ravenloft_gates", "hour": 21, "cells": [[19, 19], [20, 19], [19, 20], [20, 20]],
		"dist": 16.0, "flags": {"strahd_invitation": "accepted"}},
	"castle_court_turned": {"loc": "castle_ravenloft_gates", "hour": 21, "cells": [[19, 19], [20, 19], [19, 20], [20, 20]],
		"dist": 16.0, "yaw": 2, "flags": {"strahd_invitation": "accepted"}},
	"castle_keep": {"loc": "castle_ravenloft_gates", "hour": 21, "cells": [[19, 12], [20, 12], [19, 13], [20, 13]],
		"dist": 15.0, "flags": {"strahd_invitation": "accepted"}},
	"castle_far": {"loc": "castle_ravenloft_gates", "hour": 12, "cells": [[19, 19], [20, 19], [19, 20], [20, 20]],
		"dist": 40.0, "flags": {"strahd_invitation": "accepted"}},
	"castle_keep_roof": {"loc": "castle_ravenloft_gates", "hour": 12, "cells": [[19, 15], [20, 15], [19, 16], [20, 16]],
		"look": [19, 3], "dist": 30.0, "flags": {"strahd_invitation": "accepted"}},
	"castle_walk": {"loc": "castle_ravenloft_gates", "hour": 12, "cells": [[13, 17], [14, 17], [13, 18], [14, 18]],
		"look": [14, 20], "dist": 13.0, "yaw": 2, "flags": {"strahd_invitation": "accepted"}},
	"castle_on_walk": {"loc": "castle_ravenloft_gates", "hour": 12, "cells": [[12, 22], [13, 22], [14, 22], [15, 22]],
		"look": [14, 20], "dist": 14.0, "flags": {"strahd_invitation": "accepted"}},
	"castle_bridge": {"loc": "castle_ravenloft_gates", "hour": 21, "cells": [[19, 26], [20, 26], [19, 27], [20, 27]],
		"dist": 12.0, "yaw": 1},
	"castle_overlook": {"loc": "castle_ravenloft_overlook", "hour": 21, "cells": [[10, 3], [11, 3], [10, 4], [11, 4]],
		"dist": 14.0},
	"castle_roofs": {"loc": "castle_ravenloft_spires_roofs", "hour": 21, "cells": [[8, 6], [9, 6], [8, 7], [9, 7]],
		"dist": 16.0},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	if OS.get_environment("KIT_OFF") != "":
		SetDressing.catalog().erase("building_kit")
	elif OS.get_environment("KIT_LOW_WALLS") != "":
		((SetDressing.catalog()["building_kit"] as Dictionary)["interiors"] as Dictionary)["full_walls"] = false
	if OS.get_environment("KIT_NO_CASTLE") != "" and SetDressing.catalog().has("building_kit"):
		(SetDressing.catalog()["building_kit"] as Dictionary).erase("castle")   # the castle as stone houses (before W19)
	if OS.get_environment("KIT_FLAT_FIRE") != "":
		ModelPiece.manifest().erase("flame")   # the 2D flame, as before its 3D model


func capture_shots(tool: Node, out: String) -> void:
	var only := OS.get_environment("KIT_SHOTS").split(",", false)
	for id: String in SHOTS:
		if not only.is_empty() and not id in only:
			continue
		var shot := SHOTS[id] as Dictionary
		_build(shot)
		await tool.call("wait_frames", 40)
		var ruts := 0
		var decals := view.board.find_children("*", "Decal", true, false)
		for d in decals:
			if str(d.name).contains("ruts"):
				ruts += 1
		print("kit %s: %d decals, %d of them ruts" % [id, decals.size(), ruts])
		tool.call("_shot", "%s_%s.png" % [out, id])


func _build(shot: Dictionary) -> void:
	if view != null:
		view.queue_free()
		view = null
	GameState.reset()
	for pid: String in PARTY:
		var ch := Pregens.build(pid, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var st := GameState.story
	st.minute_of_day = int(shot.get("hour", 12)) * 60
	var flags := shot.get("flags", {}) as Dictionary
	for k: String in flags:
		st.flags[k] = flags[k]   # (a fight that would start on arrival, kept off for the shot)
	var loc_id := str(shot["loc"])
	var cells := shot.get("cells", []) as Array
	if not cells.is_empty():
		st.location = loc_id
		st.visited[loc_id] = true
		for c: Array in cells:
			st.positions.append(Vector2i(int(c[0]), int(c[1])))
	view = LocationView.create(loc_id, st, Narrator.new(), Dice.roller, "" if not cells.is_empty() else "default")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	var rig := view.rig
	if shot.has("look"):
		var at := shot["look"] as Array
		rig.follow = null
		rig.global_position = view.board.cell_center(Vector2i(int(at[0]), int(at[1])))
	if shot.has("dist"):
		rig.distance = float(shot["dist"])
	if shot.has("yaw"):
		rig.rotate_step(int(shot["yaw"]))
	rig.snap_to_target()
	if OS.get_environment("KIT_LIT") != "":
		# A work light, to judge shapes in a dark interior (as location_tour's --lit).
		var env := view.get("_env") as Environment
		if env != null:
			env.ambient_light_energy = 2.2
		var lamp := OmniLight3D.new()
		lamp.light_color = Look.color("bone")
		lamp.omni_range = 16.0
		lamp.light_energy = 2.0
		rig.add_child(lamp)
		lamp.position = Vector3(0, 5, 0)
