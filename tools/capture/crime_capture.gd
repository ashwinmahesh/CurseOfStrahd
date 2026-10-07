extends Node
## Stealing and crime (F8) and the town watch for captures, in Vallaki's Blue Water Inn: Rictavio's lockbox marked as
## his, picking Urwin's pocket from his right-click menu, what the people here can see while the party sneaks, and the
## Town Guard who comes when Urwin catches the hand.
## make capture SCENE=res://tools/capture/crime_capture.tscn NAME=crime FRAMES=40

var root: Node


func _ready() -> void:
	GameState.reset()
	GameSettings.set_value("turn_based", false, false)
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 4)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.gold = 60.0
	GameState.story.location = "vallaki_blue_water_inn"
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


func capture_shots(tool: Node, out: String) -> void:
	var view := root.get("view") as LocationView
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	# Thistle leads, to the bar where Urwin stands.
	root.call("world_action", Vector2i.ZERO, "lead:2")
	await _walk(tool, view, Vector2i(5, 3))
	await tool.call("wait_frames", 30)
	hud.close_narration()
	var urwin := Vector2i(4, 1)
	var at := view.rig.camera.unproject_position(view.board.cell_center(urwin) + Vector3(0, 0.6, 0))
	root.call("open_world_menu", urwin, at)
	await _shoot(tool, out + "_1_pickpocket_menu.png")
	(root.get("menu") as ContextMenu).hide()
	# Sneaking (badly): the people here show what they can see, cones the way they face and a ring they hear.
	view.set_sneaking(true)
	for m: Combatant in view.members:
		view.sneak_totals[m.creature] = 6
	root.call("_refresh")
	view.rig.distance = 17.0
	await tool.call("wait_frames", 30)
	await _shoot(tool, out + "_1b_townsfolk_sight.png")
	view.set_sneaking(false)
	view.rig.distance = 13.0
	# Urwin is sharper than he looks.
	(view.npc_tokens["urwin_martikov"] as CombatToken).combatant.set_meta("passive_perception", 30)
	LocationCrime.pickpocket(view, "urwin_martikov")
	await tool.call("wait_frames", 60)
	var d := root.get("dialogue") as DialogueUI
	if d != null:
		for i in 8:
			if not d.options_shown.is_empty():
				break
			d.call("_advance")
			await tool.call("wait_frames", 3)
	await _shoot(tool, out + "_2_the_watch.png")
	if d != null:
		d.queue_free()
		root.set("dialogue", null)
		hud.visible = true
	view.clear_staged()
	await _walk(tool, view, Vector2i(14, 14))
	await tool.call("wait_frames", 30)
	var box := Vector2i(16, 14)
	hud.hint(str(view.thing_at(box).get("label", "")), view.rig.camera.unproject_position(view.board.cell_center(box)) + Vector2(10, -40))
	await _shoot(tool, out + "_3_owned_lockbox.png")
