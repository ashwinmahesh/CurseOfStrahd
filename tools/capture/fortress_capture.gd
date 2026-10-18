extends Node3D
## Daern's Instant Fortress before and after, and the tower's three maps (docs/story/fortress.md). Not part of the game.
##   make capture SCENE=res://tools/capture/fortress_capture.tscn NAME=fortress/after FRAMES=10
## Environment: FORTRESS_AT=forest_clearing,village_of_barovia (the maps to raise it on; default forest_clearing),
## FORTRESS_BEFORE=1 (the map as it is without the tower: the "before" picture), FORTRESS_INSIDE=1 (also the three
## maps inside), FORTRESS_HOUR=12 (the hour of the day outside), FORTRESS_TURNS=1 (also shoot from the other three
## camera headings).

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]

var view: LocationView = null


func _ready() -> void:
	InputActions.ensure()


func capture_shots(tool: Node, out: String) -> void:
	var hour := int(OS.get_environment("FORTRESS_HOUR")) if OS.get_environment("FORTRESS_HOUR") != "" else 12
	var places := (OS.get_environment("FORTRESS_AT") if OS.get_environment("FORTRESS_AT") != "" else "forest_clearing").split(",", false)
	var before := OS.get_environment("FORTRESS_BEFORE") != ""
	for place in places:
		_build(place, hour)
		await tool.call("wait_frames", 30)
		if before:
			tool.call("_shot", "%s_%s_before.png" % [out, place])
			view.queue_free()
			view = null
			continue
		var plot := LocationFortress.plot_in(view)
		if plot.is_empty():
			push_warning("fortress_capture: no room on %s" % place)
			view.queue_free()
			view = null
			continue
		var st := GameState.story
		FortressSite.raise(st, plot, st.party[0])
		view.apply_spell_effect("fortress_raise")
		await tool.call("wait_frames", 8)
		tool.call("_shot", "%s_%s_rising.png" % [out, place])
		await tool.call("wait_frames", 70)
		tool.call("_shot", "%s_%s_after.png" % [out, place])
		var fs := FortressSite.state(st)
		var door := Vector2i(int((fs["front"] as Array)[0]), int((fs["front"] as Array)[1]))
		view.rig.follow = null
		view.rig.distance = 8.0
		view.rig.global_position = view.board.cell_center(door)
		view.rig.snap_to_target()
		await tool.call("wait_frames", 12)
		tool.call("_shot", "%s_%s_door.png" % [out, place])
		if OS.get_environment("FORTRESS_TURNS") != "":
			for k in 3:
				view.rig.rotate_step(1)
				await tool.call("wait_frames", 20)
				tool.call("_shot", "%s_%s_turn%d.png" % [out, place, k + 1])
		if OS.get_environment("FORTRESS_INSIDE") != "":
			view.queue_free()
			view = null
			await tool.call("wait_frames", 2)
			for id in FortressSite.INTERIORS:
				await _inside(tool, out, id, hour)
		if view != null:
			view.queue_free()
			view = null
		await tool.call("wait_frames", 2)


## The map `loc_id` as the game builds it with the party at its spawn, a whole-map shot and a close one.
func _inside(tool: Node, out: String, loc_id: String, hour: int) -> void:
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	await tool.call("wait_frames", 30)
	tool.call("_shot", "%s_%s.png" % [out, loc_id])
	view.rig.zoom_max = 60.0
	view.rig.follow = null
	view.rig.distance = 9.0
	view.rig.global_position = Vector3(view.grid.width / 2.0, 0, view.grid.depth / 2.0)
	view.rig.snap_to_target()
	await tool.call("wait_frames", 12)
	tool.call("_shot", "%s_%s_whole.png" % [out, loc_id])
	view.queue_free()
	view = null
	await tool.call("wait_frames", 2)


func _build(loc_id: String, hour: int) -> void:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.party[0].add_item(FortressSite.ITEM)
	GameState.story.party[0].attune(FortressSite.ITEM)
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
