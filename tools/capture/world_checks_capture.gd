extends Node
## Skill checks in the world (docs/story/world_checks.md), in the Village of Barovia's churchyard: the raven's name
## plate saying what it offers, its right-click menu with the check (who rolls, the bonus, Advantage, the chance), the
## big d20 rolling Animal Handling, and the Narrator's line for how it went.
## make capture SCENE=res://tools/capture/world_checks_capture.tscn NAME=world_checks FRAMES=30

var root: Node


func _ready() -> void:
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "village_of_barovia"
	GameState.story.minute_of_day = 10 * 60   # mid-morning
	# The village's arrival picture has been seen: the capture is of the place itself.
	var cut := Cutscenes.for_trigger("enter:village_of_barovia", GameState.story)
	if cut != "":
		Cutscenes.mark_played(cut, GameState.story)
	Dice.reseed(11)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	var raven := Vector2i(27, 8)
	view.walk_to(Vector2i(28, 8))
	for i in 900:
		if (view.get("_queue") as Array).is_empty():
			break
		await tool.call("wait_frames", 1)
	await tool.call("wait_frames", 20)
	hud.close_narration()
	hud.thing_labels.pinned = true
	await _shoot(tool, out + "_1_plates.png")
	hud.thing_labels.pinned = false
	var at := view.rig.camera.unproject_position(view.board.cell_center(raven) + Vector3(0, 0.6, 0))
	root.call("open_world_menu", raven, at)
	await _shoot(tool, out + "_2_menu.png")
	(root.get("menu") as ContextMenu).hide()
	UiMotion.reduced = false   # the die rolls, then lands
	view.act(raven, "check:raven_coax")
	var panel := root.find_child("DiceRoll", true, false) as DiceRoll
	if panel != null:
		panel.seek(2.4)
	await _shoot(tool, out + "_3_d20.png", 12)
