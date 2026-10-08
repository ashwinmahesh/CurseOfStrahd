extends Node3D
## The interiors lane's audit and before-and-after shots (lane 29, docs/art/interiors.md): every interior, or the ones
## named, built as in the game and shot from above whole, one image each, with the party at its spawn. Not part of
## the game.
##   make capture SCENE=res://tools/capture/interiors_capture.tscn NAME=interiors/before FRAMES=10
## Environment: INTERIORS_LOCS=death_house_ground,death_house_upper (default: every interior and dungeon map),
## INTERIORS_LIT=1 (a work light and brighter ambient, to see what's in a dark room), INTERIORS_HOUR=12,
## INTERIORS_SPOTS=death_house_ground@4,3@21,3|death_house_upper@4,4 (close shots of those squares too, named
## <out>_<loc>_<x>_<z>.png; places are split by | and squares by @, since make capture's ARGS can't hold a ;).

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()


## Every location whose map is an interior or a dungeon (ArenaBoard's themes), in id order.
static func interiors() -> Array[String]:
	var out: Array[String] = []
	for id: String in Compendium.shared().tables["locations"] as Dictionary:
		var theme := ArenaBoard.theme_for((Compendium.shared().get_entry("locations", id)["map"]) as Dictionary)
		if theme in ArenaBoard.INTERIORS or theme == "dungeon":
			out.append(id)
	out.sort()
	return out


func capture_shots(tool: Node, out: String) -> void:
	var ids := interiors()
	if OS.get_environment("INTERIORS_LOCS") != "":
		ids.assign(OS.get_environment("INTERIORS_LOCS").split(",", false))
	var hour := int(OS.get_environment("INTERIORS_HOUR")) if OS.get_environment("INTERIORS_HOUR") != "" else 12
	var spots := {}
	for part: String in OS.get_environment("INTERIORS_SPOTS").split("|", false):
		var bits := part.split("@", false)
		var cells: Array[Vector2i] = []
		for b: String in bits.slice(1):
			cells.append(Vector2i(int(b.get_slice(",", 0)), int(b.get_slice(",", 1))))
		spots[bits[0]] = cells
	if not spots.is_empty() and OS.get_environment("INTERIORS_LOCS") == "":
		ids.assign(spots.keys())
	for id in ids:
		_build(id, hour)
		await tool.call("wait_frames", 30)
		tool.call("_shot", "%s_%s.png" % [out, id])
		for c: Vector2i in spots.get(id, []):
			view.rig.distance = 8.0
			view.rig.global_position = view.board.cell_center(c)
			view.rig.snap_to_target()
			await tool.call("wait_frames", 12)
			tool.call("_shot", "%s_%s_%d_%d.png" % [out, id, c.x, c.y])
		view.queue_free()
		view = null
		await tool.call("wait_frames", 2)


func _build(loc_id: String, hour: int) -> void:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	var rig := view.rig
	rig.follow = null
	if OS.get_environment("INTERIORS_LIT") != "":
		var env := view.get("_env") as Environment
		if env != null:
			env.ambient_light_energy = 2.2
		var lamp := OmniLight3D.new()
		lamp.light_color = Look.color("bone")
		lamp.omni_range = 40.0
		lamp.light_energy = 1.4
		lamp.position = Vector3(view.grid.width / 2.0, 12.0, view.grid.depth / 2.0)
		view.add_child(lamp)
	rig.zoom_max = 60.0
	rig.distance = maxf(view.grid.width, view.grid.depth) * 1.05
	rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
	rig.snap_to_target()
