extends Node
## G3 boss presentation (lane 21):
## make capture SCENE=res://tools/capture/boss_capture.tscn LOCATION=<id> ENCOUNTER=<fight id> NAME=<name>
## Starts a boss fight and shoots its entrance 12 times a second (<out>_entrance_NN.jpg and <out>_entrance_sheet.jpg),
## then, on the party's first turn, the plates over the hotbar as the first boss is hurt, Bloodied with a Legendary
## Resistance spent, and gone (<out>_plates.png, _hurt.png, _bloodied.png, _gone.png). The Hit Points it sets are only
## shown; the fight's round-start save goes to a folder of the capture's own.

const FPS := 12.0
const SIZE := Vector2i(800, 450)
const ENTRANCE_SECONDS := 6.0

var game: Node


func _ready() -> void:
	SaveSystem.save_dir = "user://capture_saves/%d/" % OS.get_process_id()
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)


func capture_shots(tool: Node, out: String) -> void:
	var encounter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--encounter="):
			encounter = a.get_slice("=", 1)
	var view := game.get("view") as LocationView
	view.input_locked = true
	if not view.start_encounter(encounter):
		push_warning("boss_capture: no encounter %s here" % encounter)
		return
	var cv := view.combat_view
	cv.input_locked = true
	await _film(out + "_entrance", ENTRANCE_SECONDS)
	for guard in 600:
		if cv.mode == CombatView.Mode.IDLE:
			break
		await tool.call("wait_frames", 5)
	await tool.call("wait_frames", 30)
	tool.call("_shot", out + "_plates.png")
	if cv.boss_bar == null:
		push_warning("boss_capture: no bosses in %s" % encounter)
		return
	var boss := cv.boss_bar.bosses[0]
	var cr := boss.creature
	cr.hp = int(cr.max_hp() * 0.6)
	cv.call("_refresh_all")
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_hurt.png")
	cr.hp = int(cr.max_hp() * 0.35)
	if int(Legendary.data_of(boss).get("legendary_resistance", 0)) > 0:
		boss.set_meta("legendary_resistance_used", 1)
	cv.call("_refresh_all")
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_bloodied.png")
	# The last plate's boss falls (or, alone, Strahd leaves as mist).
	var last := cv.boss_bar.bosses[-1]
	if last == boss and Legendary.data_of(boss).has("misty_escape"):
		cv.e.legendary.departed[boss.id] = "mist"
	else:
		last.creature.hp = 0
		last.creature.dead = true
	cv.call("_refresh_all")
	await tool.call("wait_frames", 40)
	tool.call("_shot", out + "_gone.png")


## Shoots `seconds` of real time FPS times a second, keeping the frames in memory until the end.
func _film(prefix: String, seconds: float) -> void:
	var shots: Array[Image] = []
	var start := Time.get_ticks_msec()
	var next := 0.0
	while next <= seconds:
		await get_tree().process_frame
		if (Time.get_ticks_msec() - start) / 1000.0 < next:
			continue
		var img := get_viewport().get_texture().get_image()
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
		shots.append(img)
		next += 1.0 / FPS
	for i in shots.size():
		shots[i].save_jpg("%s_%02d.jpg" % [prefix, i], 0.85)
	var cols := 8
	var thumb := SIZE / 4
	var sheet := Image.create(thumb.x * cols, thumb.y * ceili(float(shots.size()) / cols), false, Image.FORMAT_RGB8)
	for i in shots.size():
		var t := shots[i].duplicate() as Image
		t.convert(Image.FORMAT_RGB8)
		t.resize(thumb.x, thumb.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, thumb), Vector2i((i % cols) * thumb.x, (i / cols) * thumb.y))
	sheet.save_jpg(prefix + "_sheet.jpg", 0.85)
	print("capture: %s (%d frames)" % [prefix, shots.size()])
