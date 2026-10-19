extends Node
## A trap going off outside a fight, before and after the trap-failure work (owner todo 2026-10-17): the "before" shot
## plays it as it was (the figure flashes, nothing else: no effect, no number over the head, the party panel still on
## the old Hit Points), the "after" shots show the effect as it starts and at its height, then the number and the new
## Hit Points.
## make capture SCENE=res://tools/capture/trap_fx_capture.tscn NAME=trap_fx FRAMES=20 [ARGS="--traps=court_vault_glyph,..."]
## Every trap is sprung on the leader in a place of its own, its save forced to fail.

## trap id -> [location, flags to set first]
const TRAPS := {
	"court_vault_glyph": ["castle_ravenloft_court_treasury", []],
	"larders_bone_lamp_trap": ["castle_ravenloft_larders_dungeon", []],
	"court_trophy_crossbow": ["castle_ravenloft_court", []],
	"attic_beams": ["death_house_attic", ["death_house_refused"]],
	"stair_ice": ["amber_temple_vault", []],
	"passage_pit": ["death_house_dungeon_1", []],
}

var root: Node


func _ready() -> void:
	GameState.reset()
	GameSettings.set_value("turn_based", false, false)
	for id: String in ["godrick_pendlebrook", "liriel_dawnsong", "thistle", "ratatoille"]:
		var ch := Pregens.build(id, 5)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = str((TRAPS[_traps()[0]] as Array)[0])
	for f: Variant in (TRAPS[_traps()[0]] as Array)[1]:
		GameState.story.set_flag(str(f))
	Dice.reseed(7)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)


func _traps() -> Array[String]:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--traps="):
			var out: Array[String] = []
			out.assign(a.substr(8).split(","))
			return out
	var all: Array[String] = []
	all.assign(TRAPS.keys())
	return all


func _view() -> LocationView:
	return root.get("view") as LocationView


## A fresh visit to `id`'s place with the party on the trap's first square, and the trap ready to spring.
func _stage(tool: Node, id: String, first: bool) -> Dictionary:
	var entry := TRAPS[id] as Array
	for f: Variant in entry[1]:
		GameState.story.set_flag(str(f))
	if not first:
		root.call("enter_location", str(entry[0]), "default")
		await tool.call("wait_frames", 90)
	for ch in GameState.story.party:
		ch.hp = ch.max_hp()
		ch.conditions.clear()
	var view := _view()
	(root.get("hud") as ExploreHud).close_narration()
	var trap := {}
	for t: Variant in view.loc.get("traps", []):
		if str((t as Dictionary)["id"]) == id:
			trap = t as Dictionary
	trap["save"] = {"ability": "dex", "dc": 40}   # the party fails it, whatever it rolls
	(GameState.story.loc_state(str(entry[0]))["traps"] as Dictionary).erase(id)
	var here := LocationView._cell((trap["cells"] as Array)[0])
	var spots: Array[Vector2i] = [here]
	for r in range(1, 5):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c := here + Vector2i(dx, dy)
				if spots.size() < view.members.size() and not c in spots and view.grid.in_bounds(c) and not view.grid.is_solid(c) \
						and not (trap["cells"] as Array).has([c.x, c.y]):
					spots.append(c)
	for i in view.members.size():
		var m := view.members[i]
		m.cell = spots[mini(i, spots.size() - 1)]
		(view.tokens[m.id] as CombatToken).position = view.board.cell_center(m.cell)
	view.rig.follow = view.tokens[view.leader().id] as Node3D
	await tool.call("wait_frames", 40)
	return trap


func capture_shots(tool: Node, out: String) -> void:
	var first := true
	for id in _traps():
		for mode: String in ["before", "after"]:
			var trap := await _stage(tool, id, first)
			first = false
			var view := _view()
			LocationHurt.enabled = mode == "after"
			# After mode runs in slow motion: a busy Mac draws few frames a second and a trap's effect is over in under a
			# second, so at full speed the shots land before it or long after.
			if mode == "after":
				Engine.time_scale = 0.2
			LocationTraps.activate(view, trap)
			if mode == "before":
				await tool.call("wait_frames", 24)
				tool.call("_shot", "%s_%s_before.png" % [out, id])
			else:
				await tool.call("wait_frames", 2)
				tool.call("_shot", "%s_%s_after_1.png" % [out, id])
				await tool.call("wait_frames", 4)
				tool.call("_shot", "%s_%s_after_2.png" % [out, id])
				await tool.call("wait_frames", 12)
				tool.call("_shot", "%s_%s_after_3.png" % [out, id])
				Engine.time_scale = 1.0
	LocationHurt.enabled = true
