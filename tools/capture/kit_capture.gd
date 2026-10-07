extends Node
## Before-and-after shots for the building kit (Improvement Ideas W7, the surfaces and architecture lane): the town
## houses, yard walls, interior walls and pillars from the game's camera, in daylight and at dusk, so a change to the
## kit can be judged side by side. Not part of the game.
##   make capture SCENE=res://tools/capture/kit_capture.tscn NAME=kit/before FRAMES=10
## Environment: KIT_SHOTS=village_dusk,vallaki_noon (default: every shot).

## Each shot: the place, the hour, where the party stands (empty: the place's own spawn), and optionally the square
## the camera looks at, how far it is, and how many 45-degree steps it is turned from the opening heading.
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
	"death_house_hall": {"loc": "death_house_ground", "cells": [[13, 8], [14, 8], [13, 9], [14, 9]]},
	"castle_hall": {"loc": "castle_ravenloft_main_floor", "cells": [[25, 8], [26, 8], [25, 9], [26, 9]]},
	"church": {"loc": "village_church", "cells": [[10, 14], [11, 14], [10, 15], [11, 15]]},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()


func capture_shots(tool: Node, out: String) -> void:
	var only := OS.get_environment("KIT_SHOTS").split(",", false)
	for id: String in SHOTS:
		if not only.is_empty() and not id in only:
			continue
		var shot := SHOTS[id] as Dictionary
		_build(shot)
		await tool.call("wait_frames", 40)
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
