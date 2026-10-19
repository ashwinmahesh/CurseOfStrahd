extends Node
## Build times of a place with and without the buildings' bend (natural maps B1, BuildingBend), in a hidden window (headless
## misses GPU readbacks), alternating builds without and with the bend and reporting medians: a first arrival each time
## (the kept meshes forgotten first), then a repeat arrival (BuildingKit keeps a bent roof and palisade). Not part of the game.
##   make capture SCENE=res://tools/capture/bend_time.tscn NAME=bendtime FRAMES=2
## Environment: BT_LOCS=a,b (default a handful of towns), BT_RUNS=n (default 4, alternating straight and bent).

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]


func capture_shots(tool: Node, _out: String) -> void:
	InputActions.ensure()
	var locs: Array[String] = ["village_of_barovia", "vallaki", "krezk", "wizard_of_wines", "abbey_of_st_markovia", "argynvostholt",
		"old_bonegrinder_hill", "mount_baratok_hut", "berez"]
	if OS.get_environment("BT_LOCS") != "":
		locs.assign(OS.get_environment("BT_LOCS").split(",", false))
	var runs := int(OS.get_environment("BT_RUNS")) if OS.get_environment("BT_RUNS") != "" else 4
	var kit := (SetDressing.catalog()["building_kit"] as Dictionary)
	var models := (SetDressing.catalog()["models3d"] as Dictionary)
	var bend_kit: Variant = kit.get("bend")
	var bend_models: Variant = models.get("bend")
	for id in locs:
		var times := {"straight": [] as Array[float], "bent": [] as Array[float]}
		# One build first, to warm the caches the same for both.
		await _build(tool, id)
		for i in runs * 2:
			var bent := i % 2 == 1
			if bent:
				kit["bend"] = bend_kit
				models["bend"] = bend_models
			else:
				kit.erase("bend")
				models.erase("bend")
			BuildingKit.forget()
			var ms := await _build(tool, id)
			(times["bent" if bent else "straight"] as Array[float]).append(ms)
		kit["bend"] = bend_kit
		models["bend"] = bend_models
		var repeat: Array[float] = []
		BuildingKit.forget()
		await _build(tool, id)   # (a first arrival, to keep the roofs)
		for i in runs:
			repeat.append(await _build(tool, id))
		var s := _median(times["straight"] as Array[float])
		var b := _median(times["bent"] as Array[float])
		var r := _median(repeat)
		print("bendtime %s: straight %.0f ms, bent %.0f ms (%+.1f%%), bent on a repeat arrival %.0f ms (%+.1f%%)  runs %s | %s" % [id, s, b, (b / s - 1.0) * 100.0, r, (r / s - 1.0) * 100.0, times["straight"], times["bent"]])


func _median(a: Array[float]) -> float:
	var sorted := a.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2] as float


func _build(tool: Node, loc_id: String) -> float:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	var t0 := Time.get_ticks_usec()
	var view := LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	await tool.call("wait_frames", 2)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	view.queue_free()
	await tool.call("wait_frames", 2)
	return ms
