extends Node
## Turn-based exploring (F7) for captures, in the Wizard of Wines cellar with the druid and his blights at their dig:
## the party sneaking in rounds with the turn-based panel, the foes in plain view, a walk's trail and cost, Attack on a
## foe's right-click menu, and the fight opening with the unaware foes surprised and a hidden member.
## make capture SCENE=res://tools/capture/plan_capture.tscn NAME=plan FRAMES=40

var root: Node


func _ready() -> void:
	GameState.reset()
	GameSettings.set_value("turn_based", false, false)
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 6)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "wizard_of_wines_cellar"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _shoot(tool: Node, path: String) -> void:
	await tool.call("wait_frames", 10)
	tool.call("_shot", path)


func _walk(tool: Node, view: LocationView, cell: Vector2i) -> void:
	view.walk_to(cell)
	for i in 600:
		if view._queue.is_empty():
			break
		await tool.call("wait_frames", 1)


## Walks the leader to `cell` over as many rounds as it takes, each leg as far as this round's movement goes.
func _walk_far(tool: Node, view: LocationView, cell: Vector2i) -> void:
	for leg in 6:
		var path := view._path(view.leader().cell, cell)
		if path.size() < 2:
			return
		var stop := path[0]
		for i in range(1, path.size()):
			if LocationPlan.why_not(view, path.slice(0, i + 1)) == "":
				stop = path[i]
		if stop != path[0]:
			await _walk(tool, view, stop)
		if view.leader().cell == cell:
			return
		root.call("_command", "plan_round")


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	view.set_sneaking(true)
	for m: Combatant in view.members:
		view.sneak_totals[m.creature] = 26
	LocationPlan.start(view)   # not through GameSettings, so the player's own choice stays as it is
	root.call("_refresh")
	hud.close_narration()
	# One at a time they slip up to the doorway of the dig: the leader at its edge, one behind the wall beside it.
	await _walk_far(tool, view, Vector2i(15, 6))
	root.call("world_action", Vector2i.ZERO, "lead:1")
	await _walk_far(tool, view, Vector2i(15, 5))
	root.call("world_action", Vector2i.ZERO, "lead:2")
	await _walk_far(tool, view, Vector2i(14, 7))
	root.call("world_action", Vector2i.ZERO, "lead:2")
	root.call("_command", "plan_round")
	view.rig.distance = 18.0
	await tool.call("wait_frames", 30)
	hud.close_narration()
	LocationPlan.preview(view, Vector2i(17, 6))
	hud.hint(LocationPlan.hover_text(view, Vector2i(17, 6)), Vector2(900, 420))
	await _shoot(tool, out + "_1_turn_based.png")
	var foe := Vector2i(-1, -1)
	for w in view.waiting:
		if LocationStealth.is_shown(w):
			foe = (w["foe"] as Combatant).cell
			break
	if foe.x >= 0:
		var at := view.rig.camera.unproject_position(view.board.cell_center(foe) + Vector3(0, 0.6, 0))
		root.call("open_world_menu", foe, at)
		await _shoot(tool, out + "_2_attack_menu.png")
		(root.get("menu") as ContextMenu).hide()
	root.call("_command", "strike")
	await tool.call("wait_frames", 90)
	await _shoot(tool, out + "_3_surprise.png")
