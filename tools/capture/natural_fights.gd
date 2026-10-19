extends Node3D
## The battle grid in a fight, place by place (Natural Maps plan N1; the pair to natural_audit.gd, which shoots the
## places exploring): each place built as in the game, a fight started in it, shot round the creature whose turn it is
## from the play camera and again in the tactical view (O). Not part of the game.
##   make capture SCENE=res://tools/capture/natural_fights.tscn NAME=natural/grid FRAMES=10
## Environment: NF_LOCS=a,b (default a few outdoor places), NF_SHOTS=fight,tactical,explore (default fight,tactical),
## NF_HOUR=12, NF_GRID=always (the setting for the run: fights, always or never; default fights), NF_ENCOUNTER=id (with
## one place only; default the first of its fights that can start).
## Shots: <out>_<loc>_fight.png, _tactical.png, _explore.png (the grid with no fight, under "always").

const PARTY: Array[String] = ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]
const PLACES: Array[String] = ["svalich_crossroads", "yester_hill", "village_of_barovia", "krezk", "mount_baratok", "vallaki"]

var view: LocationView = null


func capture_shots(tool: Node, out: String) -> void:
	InputActions.ensure()
	if OS.get_environment("NF_GRID") != "":
		GameSettings.set_battle_grid(OS.get_environment("NF_GRID"))
	var ids := PLACES.duplicate()
	if OS.get_environment("NF_LOCS") != "":
		ids.assign(OS.get_environment("NF_LOCS").split(",", false))
	var shots := OS.get_environment("NF_SHOTS").split(",", false)
	if shots.is_empty():
		shots = PackedStringArray(["fight", "tactical"])
	var hour := int(OS.get_environment("NF_HOUR")) if OS.get_environment("NF_HOUR") != "" else 12
	for id: String in ids:
		_build(id, hour)
		await tool.call("wait_frames", 30)
		if "explore" in shots:
			view.rig.follow = view.tokens[view.leader().id] as Node3D
			await tool.call("wait_frames", 40)
			tool.call("_shot", "%s_%s_explore.png" % [out, id])
		if "fight" in shots or "tactical" in shots:
			if not _fight(id):
				push_warning("natural_fights: no fight could start at %s" % id)
				view.queue_free()
				await tool.call("wait_frames", 2)
				continue
			# The opening beat (a boss's entrance too) and the first turn's start: the grid fades in with it.
			for i in 900:
				await tool.call("wait_frames", 1)
				if not view.combat_view._opening and view.combat_view.mode != CombatView.Mode.BUSY:
					break
			await tool.call("wait_frames", 120)
			if "fight" in shots:
				tool.call("_shot", "%s_%s_fight.png" % [out, id])
			if "tactical" in shots:
				view.combat_view.rig.tactical = true
				await tool.call("wait_frames", 60)
				tool.call("_shot", "%s_%s_tactical.png" % [out, id])
		view.queue_free()
		view = null
		await tool.call("wait_frames", 2)


## Starts the first fight of the place that will start (or NF_ENCOUNTER).
func _fight(loc_id: String) -> bool:
	var wanted := OS.get_environment("NF_ENCOUNTER")
	var tried := {}
	for spec: Variant in view.loc.get("encounters", []):
		var eid := str((spec as Dictionary).get("id", ""))
		if tried.has(eid) or (wanted != "" and eid != wanted):
			continue
		tried[eid] = true
		if view.start_encounter(eid):
			return true
	return false


func _build(loc_id: String, hour: int) -> void:
	GameState.reset()
	for id: String in PARTY:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.minute_of_day = hour * 60
	view = LocationView.create(loc_id, GameState.story, Narrator.new(), Dice.roller, "default")
	add_child(view)
	view.input_locked = true
	view.update_daylight()
	view.atmosphere.settle()
