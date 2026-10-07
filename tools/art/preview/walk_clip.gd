extends Node3D
## Overworld walking clip (QA for PartyGlide, owner 2026-10-07: "move and stop kind of unnaturally"): the party in a
## real location walks a few short legs with stops, a corner and a turn back, under the game's camera. Recorded with
## Godot's movie writer:
##   tools/godot --path . --write-movie out.avi --fixed-fps 30 --resolution 1280x720 \
##     res://tools/art/preview/walk_clip.tscn -- --location=village_of_barovia [--hour=21]

var view: LocationView
var _title: Label


func _ready() -> void:
	var loc_id := "village_of_barovia"
	var hour := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--location="):
			loc_id = a.get_slice("=", 1)
		elif a.begins_with("--hour="):
			hour = int(a.get_slice("=", 1))
	InputActions.ensure()
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	var ui := CanvasLayer.new()
	ui.layer = 30
	add_child(ui)
	_title = Label.new()
	_title.position = Vector2(0, 16)
	_title.size = Vector2(1280, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Look.color("vellum"))
	_title.add_theme_color_override("font_outline_color", Look.color("void"))
	_title.add_theme_constant_override("outline_size", 6)
	ui.add_child(_title)
	_run()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## The farthest square up to `n` steps from the leader along `dir` that the party can walk to.
func _toward(dir: Vector2i, n: int) -> Vector2i:
	var from := view.leader().cell
	for k in range(n, 0, -1):
		var c := from + dir * k
		if not view._path(from, c).is_empty():
			return c
	return from


func _walk(dir: Vector2i, n: int, label: String) -> void:
	_title.text = label
	view.walk_to(_toward(dir, n))
	await _wait(0.2)
	while _busy():
		await get_tree().process_frame
	await _wait(1.0)


## Still walking (the glide's tokens still moving, in the build that has it).
func _busy() -> bool:
	if not view._queue.is_empty():
		return true
	var glides: Variant = view.get("_glides")
	return glides is Dictionary and not (glides as Dictionary).is_empty()


func _run() -> void:
	await _wait(1.0)
	await _walk(Vector2i(1, 0), 6, "A short walk and a stop")
	await _walk(Vector2i(0, 1), 3, "Turning a corner")
	await _walk(Vector2i(-1, 0), 2, "Back the way we came")
	await _walk(Vector2i(1, 1), 4, "Diagonally")
	await _walk(Vector2i(-1, 0), 1, "One square")
	await _wait(0.5)
	get_tree().quit()
