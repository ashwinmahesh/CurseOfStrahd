extends Node
## The polish pass's own shots (docs/plans/ui_polish.md), from a level 3 party: names over everything usable with Alt
## held in the village and the Death House, the "Autosaved" note, and the game-over screen with its way back to the
## last autosave. make capture SCENE=res://tools/capture/polish_capture.tscn NAME=polish FRAMES=30 [POLISH_ONLY=alt,over]

var root: Node
var _only: Array[String] = []


## POLISH_LOOK=classic|modern picks the world's finish for the run (not saved), for before-and-after shots.
var _look := ""


func _ready() -> void:
	for s in OS.get_environment("POLISH_ONLY").split(",", false):
		_only.append(s.strip_edges())
	_look = OS.get_environment("POLISH_LOOK")
	if _look != "":
		Look.set_style(_look, false)
	# POLISH_DOF=off: the Modern look without its depth blur, for this run only.
	if OS.get_environment("POLISH_DOF") == "off":
		GameSettings.set_value("depth_blur", false, false)
		_look += "_nodof"
	GameState.reset()
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "village_of_barovia"
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _wants(what: String) -> bool:
	return _only.is_empty() or what in _only


func _shoot(tool: Node, path: String, frames: int = 10) -> void:
	await tool.call("wait_frames", frames)
	tool.call("_shot", path)


func capture_shots(tool: Node, out: String) -> void:
	var hud := root.get("hud") as ExploreHud
	hud.close_narration()
	if _wants("perf"):
		# How long the GPU takes per frame in the village and the cellar, for the finish this run uses.
		var vp := get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp, true)
		for where: String in ["village_of_barovia", "death_house_dungeon_1", "tser_pool"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 60)
			var gpu := 0.0
			var cpu := 0.0
			var t0 := Time.get_ticks_usec()
			for i in 120:
				await tool.call("wait_frames", 1)
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
				cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			var wall := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
			print("perf %s %s: frame %.2f ms (60 fps cap), gpu %.2f ms, cpu %.2f ms" % [_look, where, wall, gpu / 120.0, cpu / 120.0])
		return
	if _wants("look"):
		# The same places in either finish: the village at dusk, Death House's hall, its cellar, the misty road and a
		# fight in the cellar.
		for where: String in ["village_of_barovia", "death_house_ground", "death_house_dungeon_1", "into_the_mists_road", "tser_pool"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 40)
			hud.close_narration()
			await _shoot(tool, "%s_look_%s_%s.png" % [out, _look, where], 20)
		root.call("enter_location", "death_house_dungeon_1", "default")
		await tool.call("wait_frames", 20)
		(root.get("view") as LocationView).start_encounter("passage_ghouls")
		await _shoot(tool, "%s_look_%s_fight.png" % [out, _look], 200)
		return
	if _wants("hud"):
		# The command bar's keys, Sneak lit, the objective under the time, and two toasts in a row.
		GameState.story.set_quest_stage("death_house", "plea")
		root.call("_command", "sneak")
		hud.toast("Sneaking")
		hud.toast("Thistle found 3 gp")
		await _shoot(tool, out + "_hud.png")
		await tool.call("wait_frames", 140)
		await _shoot(tool, out + "_hud_second_toast.png", 2)
		root.call("_command", "sneak")
	if _wants("feat"):
		# Level 4's feat on the level-up screen (Godrick from level 3), scrolled to the choice, with a feat hovered.
		var godrick := Pregens.build("godrick_pendlebrook", 3)
		godrick.finish_long_rest()
		GameState.story.party[0] = godrick
		GameState.story.milestones = 10
		root.call("open_screen", "level_up", 0)
		await tool.call("wait_frames", 4)
		var screen := root.get("screen") as Node
		for l in screen.find_children("*", "Label", true, false):
			if (l as Label).text.contains("Choices"):
				for sc in screen.find_children("*", "ScrollContainer", true, false):
					var scroll := sc as ScrollContainer
					if scroll.get_parent() is PanelContainer:
						scroll.scroll_vertical = int((l as Label).global_position.y - scroll.global_position.y) - 8
		await tool.call("wait_frames", 4)
		# Hover the longest-text feat in the list, as the mouse would.
		for b in screen.find_children("*", "Button", true, false):
			if (b as Button).text.contains("Great Weapon Master"):
				(b as Button).mouse_entered.emit()
				break
		await _shoot(tool, out + "_feat_level_up.png")
		root.call("close_screen")
	if _wants("small"):
		# The F1 controls card, a small loot window with coins and a single item, and Heal up on the rest screen.
		hud.toggle_controls()
		await _shoot(tool, out + "_controls.png")
		hud.toggle_controls()
		root.call("_open_loot", "capture_purse", [{"id": "dagger", "qty": 1}], 7.0)
		await _shoot(tool, out + "_loot_small.png")
		(root.get("loot") as LootWindow).call("_close")
		GameState.story.party[0].hp = 4
		GameState.story.party[2].hp = 9
		root.call("open_screen", "rest", 0)
		await _shoot(tool, out + "_rest.png")
		(root.get("screen") as RestScreen).heal_up()
		await _shoot(tool, out + "_rest_healed.png")
		root.call("close_screen")
	if _wants("talk"):
		# Morgantha: one question asked, her options again with it dimmed, and the scroll-back.
		root.call("start_dialogue", "village_of_barovia/morgantha:start", "morgantha")
		var d := root.get("dialogue") as DialogueUI
		if d != null:
			for i in 12:
				if not d.options_shown.is_empty():
					break
				d.call("_advance")
				await tool.call("wait_frames", 2)
			d.call("_choose", 0)
			for i in 12:
				if d == null or not is_instance_valid(d) or not d.options_shown.is_empty():
					break
				d.call("_advance")
				await tool.call("wait_frames", 2)
			await _shoot(tool, out + "_talk_asked.png")
			if is_instance_valid(d):
				d.toggle_history()
				await _shoot(tool, out + "_talk_history.png")
				d.queue_free()
			root.set("dialogue", null)
			hud.visible = true
			ModeController.force(ModeController.Mode.EXPLORATION)
	if _wants("glow"):
		# The rim on the thing under the mouse: the nearest door, chest or prop to the leader.
		var view := root.get("view") as LocationView
		for where: String in ["death_house_ground", "village_of_barovia"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 30)
			hud.close_narration()
			view = root.get("view") as LocationView
			var best := Vector2i(-1, -1)
			var best_d := 1 << 30
			for entry: Array in view.call("_pickables"):
				var cell := entry[1] as Vector2i
				var k := str(view.thing_at(cell).get("kind", ""))
				if k in ["door", "container", "prop"]:
					var d := view.grid.distance_ft(view.leader().cell, 1, cell, 1)
					if d < best_d:
						best_d = d
						best = cell
			if best.x >= 0:
				(root.get("glow") as HoverGlow).show(view, best, view.thing_at(best))
				hud.hint(str(view.thing_at(best).get("label", "")), view.rig.camera.unproject_position(view.board.cell_center(best) + Vector3(0, 0.6, 0)))
			await _shoot(tool, out + "_glow_%s.png" % where)
			(root.get("glow") as HoverGlow).clear()
	if _wants("alt"):
		hud.thing_labels.pinned = true
		await _shoot(tool, out + "_alt_village.png")
		for where: String in ["death_house_ground", "death_house_dungeon_1"]:
			root.call("enter_location", where, "default")
			await tool.call("wait_frames", 20)
			hud.close_narration()
			await _shoot(tool, out + "_alt_%s.png" % where)
		hud.thing_labels.pinned = false
	if _wants("saved"):
		hud.saved_note()
		await _shoot(tool, out + "_autosaved.png", 4)
	if _wants("saves"):
		# Saves with long place names in every list that shows them: the game-over screen, the pause menu's Load and
		# the title's Load (owner report 2026-10-07: a name ran out of its box). Saves of the capture's own only.
		var real_dir := SaveSystem.save_dir
		SaveSystem.save_dir = "user://capture_saves/%d/" % OS.get_process_id()
		var made: Array[String] = []
		for loc: String in ["castle_ravenloft_court_weeping", "amber_temple_faceless_god", "death_house_dungeon_1"]:
			GameState.story.location = loc
			SaveSystem.save("cap_" + loc)
			made.append("cap_" + loc)
		SaveSystem.autosave()
		made.append(SaveSystem.AUTOSAVE)
		root.call("open_screen", "game_over", 0)
		await _shoot(tool, out + "_saves_game_over.png")
		root.call("open_screen", "menu", 0)
		(root.get("screen") as PauseMenu).call("_show_saves")
		await _shoot(tool, out + "_saves_pause_load.png")
		root.call("close_screen")
		var title := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		add_child(title)
		await tool.call("wait_frames", 4)
		title.call("_show_loads")
		await _shoot(tool, out + "_saves_title_load.png")
		title.queue_free()
		for slot in made:
			SaveSystem.delete_slot(slot)
		DirAccess.remove_absolute(SaveSystem.save_dir)
		SaveSystem.save_dir = real_dir
	if _wants("settings"):
		root.call("open_screen", "menu", 0)
		await _shoot(tool, out + "_menu.png")
		(root.get("screen") as PauseMenu).call("_show_settings")
		await _shoot(tool, out + "_settings.png")
		root.call("close_screen")
	if _wants("over"):
		# Saves of the capture's own, so the owner's never show (or change).
		var real := SaveSystem.save_dir
		SaveSystem.save_dir = "user://capture_saves/%d/" % OS.get_process_id()
		SaveSystem.save("capture_game")
		SaveSystem.autosave()
		root.call("open_screen", "game_over", 0)
		await _shoot(tool, out + "_game_over.png")
		root.call("close_screen")
		for slot: String in ["capture_game", SaveSystem.AUTOSAVE]:
			SaveSystem.delete_slot(slot)
		DirAccess.remove_absolute(SaveSystem.save_dir)
		SaveSystem.save_dir = real
