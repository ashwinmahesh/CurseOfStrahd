extends "res://tools/capture/look_capture.gd"
## The footstep puffs' shots (Visual Polish Plan 4, StepPuffs): the party mid-walk in snow, through marsh mud and in
## the rain. Not part of the game.
##   make capture SCENE=res://tools/capture/puff_capture.tscn NAME=puffs/after FRAMES=10   # LOOK_OFF=puffs: without

const WALKS := {
	"snow": {"loc": "mount_baratok", "hour": 12, "walk": [17, 18], "zoom": 7},
	"marsh": {"loc": "berez", "hour": 12, "cells": [[2, 5], [2, 6], [3, 5], [3, 6]], "walk": [8, 6], "zoom": 7},
	"rain": {"loc": "village_of_barovia", "hour": 18, "cells": [[14, 27], [15, 27], [14, 28], [15, 28]], "walk": [14, 22],
		"zoom": 7, "wet": 1.0},
}
## Frames into the walk the shot is taken (the party a few strides along).
const INTO := 50


func capture_shots(tool: Node, out: String) -> void:
	for id: String in WALKS:
		var shot := WALKS[id] as Dictionary
		_build(shot)
		await tool.call("wait_frames", 45)
		view.rig.distance = float(shot["zoom"])
		await tool.call("wait_frames", 30)
		if shot.has("wet"):
			view.atmosphere.wetness = float(shot["wet"])   # the puffs read it as the footprints do
		var to := shot["walk"] as Array
		var from := view.leader().cell
		var puffs := view.atmosphere.get_node_or_null("StepPuffs") as StepPuffs
		print("puffs %s: underfoot %s" % [id, puffs.kind_at(from) if puffs != null else "(no puffs here)"])
		view.walk_to(Vector2i(int(to[0]), int(to[1])))
		await tool.call("wait_frames", INTO)
		print("puffs %s: walked from %s to %s" % [id, from, view.leader().cell])
		tool.call("_shot", "%s_%s.png" % [out, id])
