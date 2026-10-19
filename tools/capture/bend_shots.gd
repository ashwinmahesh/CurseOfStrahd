extends Node
## Before-and-after shots for the buildings' natural shapes (natural maps B1, BuildingBend; docs/art/building_kit.md
## "Natural shapes"): the same house, the same overcast noon and the same camera, bent and then ruler-straight, so a
## stranger can see the difference at a glance. Not part of the game.
##   make capture SCENE=res://tools/capture/bend_shots.tscn NAME=bend/after FRAMES=10
##   BEND_OFF=1 make capture SCENE=res://tools/capture/bend_shots.tscn NAME=bend/before FRAMES=10
## Environment: BEND_SHOTS=village_a,vallaki_a (default every shot), BEND_OFF=1 builds every building straight, as before B1.

## Each shot: the place, the square the camera looks at, how far off it is, how many 90-degree steps it is turned from the
## opening heading, and how far it is tilted toward the horizon (0 looks down, 1 along the ground). A "whole" shot looks
## straight down on the whole map.
const SHOTS := {
	"village_whole": {"loc": "village_of_barovia", "whole": true},
	"village_a": {"loc": "village_of_barovia", "look": [10, 17], "dist": 11.0, "horizon": 0.4},
	"village_b": {"loc": "village_of_barovia", "look": [30, 17], "dist": 12.0, "yaw": 1, "horizon": 0.35},
	"village_mansion": {"loc": "village_of_barovia", "look": [8, 4], "dist": 14.0, "horizon": 0.35},
	"village_lane": {"loc": "village_of_barovia", "look": [18, 22], "dist": 15.0, "yaw": 2, "horizon": 0.3},
	"vallaki_whole": {"loc": "vallaki", "whole": true},
	"vallaki_a": {"loc": "vallaki", "look": [7, 15], "dist": 12.0, "horizon": 0.4},
	"vallaki_row": {"loc": "vallaki", "look": [24, 30], "dist": 16.0, "horizon": 0.4},
	"vallaki_palisade": {"loc": "vallaki", "look": [4, 21], "dist": 13.0, "yaw": 1, "horizon": 0.35},
	"krezk_whole": {"loc": "krezk", "whole": true},
	"krezk_a": {"loc": "krezk", "look": [5, 26], "dist": 11.0, "horizon": 0.4},
	"krezk_wall": {"loc": "krezk", "look": [20, 28], "dist": 16.0, "yaw": 2, "horizon": 0.3},
	"wizard_whole": {"loc": "wizard_of_wines", "whole": true},
	"wizard_a": {"loc": "wizard_of_wines", "look": [23, 4], "dist": 18.0, "horizon": 0.35},
	"wizard_b": {"loc": "wizard_of_wines", "look": [6, 4], "dist": 11.0, "horizon": 0.4},
	"abbey_whole": {"loc": "abbey_of_st_markovia", "whole": true},
	"abbey_a": {"loc": "abbey_of_st_markovia", "look": [18, 5], "dist": 18.0, "horizon": 0.35},
	"argynvostholt_whole": {"loc": "argynvostholt", "whole": true},
	"argynvostholt_a": {"loc": "argynvostholt", "look": [37, 23], "dist": 11.0, "horizon": 0.4},
	"bonegrinder_mill": {"loc": "old_bonegrinder_hill", "look": [14, 8], "dist": 10.0, "horizon": 0.4},
	"baratok_hut": {"loc": "mount_baratok", "look": [25, 9], "dist": 9.0, "horizon": 0.4},
	"berez_hut": {"loc": "berez", "look": [30, 16], "dist": 10.0, "horizon": 0.4},
	"abbey_bell_tower": {"loc": "abbey_of_st_markovia", "look": [12, 14], "dist": 12.0, "horizon": 0.4},
	"vrt_tower": {"loc": "van_richtens_tower", "look": [17, 11], "dist": 12.0, "horizon": 0.4},
}
const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	# Overcast all round, for every shot (the world's weather for the whole run), so left and right differ only in the buildings.
	var d := Weather.data().duplicate(true)
	var climates := {}
	for c: String in d.get("climates", {}) as Dictionary:
		climates[c] = {"overcast": 1}
	d["climates"] = climates
	Weather.use(d)
	if OS.get_environment("BEND_OFF") != "":
		(SetDressing.catalog().get("building_kit", {}) as Dictionary).erase("bend")   # ruler-straight, as before B1
		(SetDressing.catalog().get("models3d", {}) as Dictionary).erase("bend")


func capture_shots(tool: Node, out: String) -> void:
	var only := OS.get_environment("BEND_SHOTS").split(",", false)
	for id: String in SHOTS:
		if not only.is_empty() and not id in only:
			continue
		var shot := SHOTS[id] as Dictionary
		_build(str(shot["loc"]))
		await tool.call("wait_frames", 30)
		var rig := view.rig
		rig.follow = null
		if bool(shot.get("whole", false)):
			rig.horizon = 0.0
			rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
			rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
		else:
			if shot.has("look"):
				var at := shot["look"] as Array
				rig.global_position = view.board.cell_center(Vector2i(int(at[0]), int(at[1])))
			elif view.leader() != null:
				rig.global_position = view.board.cell_center(view.leader().cell)
			rig.distance = float(shot.get("dist", 14.0))
			rig.horizon = float(shot.get("horizon", 0.0))
			if shot.has("yaw"):
				rig.rotate_step(int(shot["yaw"]))
		rig.snap_to_target()
		await tool.call("wait_frames", 12)
		tool.call("_shot", "%s_%s.png" % [out, id])
		view.queue_free()
		view = null
		await tool.call("wait_frames", 2)


func _build(loc_id: String) -> void:
	GameState.reset()
	for pid: String in PARTY:
		var ch := Pregens.build(pid, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = 12 * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	view.rig.zoom_max = maxf(view.rig.zoom_max, 60.0)
