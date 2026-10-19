extends Node3D
## Shots of Mount Baratok (or another place) from any square, camera distance and heading, for before and after pairs
## (the vault's "Mount Baratok Look Plan"). Not part of the game.
##   make capture SCENE=res://tools/capture/baratok_tour.tscn NAME=baratok/x FRAMES=10
## Environment (each for this run only):
## - BT_SHOTS="x,y,dist,yaw[,tilt]|...": the square the camera looks at, its distance, quarter turns (0 from the SW
##   looking NE, the default view; 1 from the SE, 2 from the NE, 3 from the NW) and 1 for the tilted horizon view.
## - BT_HOUR=12: the hour. BT_LOC=mount_baratok: the place. BT_FLAGS=a,b: story flags set first.
## - BT_WEATHER=overcast: the world's weather for the whole run (default the new game's own).

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()
	var weather := OS.get_environment("BT_WEATHER")
	if weather != "":
		# Every climate has only that weather, for this run.
		var d := Weather.data().duplicate(true)
		var climates := {}
		for c: String in d.get("climates", {}) as Dictionary:
			climates[c] = {weather: 1}
		d["climates"] = climates
		Weather.use(d)


func capture_shots(tool: Node, out: String) -> void:
	var loc := OS.get_environment("BT_LOC") if OS.get_environment("BT_LOC") != "" else "mount_baratok"
	var hour := int(OS.get_environment("BT_HOUR")) if OS.get_environment("BT_HOUR") != "" else 12
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	for flag: String in OS.get_environment("BT_FLAGS").split(",", false):
		GameState.story.set_flag(flag)
	view = LocationView.create(loc, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	view.update_daylight()
	view.atmosphere.settle()
	var rig := view.rig
	rig.follow = null
	rig.zoom_max = maxf(rig.zoom_max, 60.0)
	await tool.call("wait_frames", 40)
	print("tour %s: mood %s, plants %s" % [loc, view.atmosphere.mood_id, Flora.set_for(view.atmosphere.mood_id)])
	var n := 0
	var cur := 0
	for part: String in OS.get_environment("BT_SHOTS").split("|", false):
		var b := part.split(",", false)
		var cell := Vector2i(int(b[0]), int(b[1]))
		var dist := float(b[2]) if b.size() > 2 else 16.0
		var yaw := int(b[3]) if b.size() > 3 else 0
		var tilt := b.size() > 4 and int(b[4]) == 1
		rig.distance = dist
		rig.horizon = 1.0 if tilt else 0.0
		rig.global_position = view.board.cell_center(cell)
		rig.rotate_step(yaw - cur)
		cur = yaw
		rig.snap_to_target()
		await tool.call("wait_frames", 25)
		tool.call("_shot", "%s_%d_%d_d%d_y%d%s.png" % [out, cell.x, cell.y, int(dist), yaw, "_t" if tilt else ""])
		n += 1
	view.queue_free()
	view = null
