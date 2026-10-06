extends Node
## Frames of the switch from exploring into a fight and back, for judging how it feels:
## make capture SCENE=res://tools/capture/combat_transition.tscn LOCATION=<id> ENCOUNTER=<id> NAME=<name>
## The party walks a few squares, the fight starts mid-walk (as stepping into an area does), its first seconds are
## shot every few frames; then the fight is played out and the return to exploring is shot the same way. Writes
## <out>_in_NN.jpg, <out>_out_NN.jpg and a contact sheet of each, <out>_in_sheet.jpg and <out>_out_sheet.jpg.

const EVERY := 5          ## frames between shots
const IN_SHOTS := 36
const OUT_SHOTS := 18
const THUMB := Vector2i(400, 225)
const COLUMNS := 6

var game: Node


func _ready() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)


func capture_shots(tool: Node, out: String) -> void:
	var view := game.get("view") as LocationView
	var encounter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--encounter="):
			encounter = a.get_slice("=", 1)
	view.input_locked = true
	# Walk a few squares toward the first foe, and start the fight two steps in.
	var goal := view.leader().cell
	for en: Variant in view.loc.get("encounters", []):
		var spec := en as Dictionary
		if str(spec["id"]) == encounter:
			var cell: Variant = ((spec["monsters"] as Array)[0] as Dictionary)["cell"]
			var toward := Vector2i(int((cell as Array)[0]), int((cell as Array)[1])) - goal
			goal += Vector2i(signi(toward.x), signi(toward.y)) * 4
			break
	view.walk_to(goal)
	await tool.call("wait_frames", 22)
	if not view.start_encounter(encounter):
		push_warning("combat_transition: no encounter %s here" % encounter)
		return
	var shots_in: Array[Image] = []
	for i in IN_SHOTS:
		shots_in.append(_grab(out + "_in_%02d.jpg" % i))
		await tool.call("wait_frames", EVERY)
	_sheet(shots_in, out + "_in_sheet.jpg")
	# Play the fight out (as the story bot does) and watch the way back.
	var cv := view.combat_view
	PartyAutopilot.new(cv.e).run(40)
	await tool.call("wait_frames", 30)
	cv.finished.emit(cv.e.outcome if cv.e.state == Encounter.State.OVER else "victory")
	var shots_out: Array[Image] = []
	for i in OUT_SHOTS:
		shots_out.append(_grab(out + "_out_%02d.jpg" % i))
		await tool.call("wait_frames", EVERY)
	_sheet(shots_out, out + "_out_sheet.jpg")


func _grab(path: String) -> Image:
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_jpg(path, 0.85)
	return img


func _sheet(shots: Array[Image], path: String) -> void:
	var rows := ceili(float(shots.size()) / COLUMNS)
	var sheet := Image.create(THUMB.x * COLUMNS, THUMB.y * rows, false, Image.FORMAT_RGB8)
	for i in shots.size():
		var t := shots[i].duplicate() as Image
		t.convert(Image.FORMAT_RGB8)
		t.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, THUMB), Vector2i((i % COLUMNS) * THUMB.x, (i / COLUMNS) * THUMB.y))
	sheet.save_jpg(path, 0.85)
	print("capture: ", path)
