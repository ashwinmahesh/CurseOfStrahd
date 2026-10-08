extends TestCase
## Traps the party can and can't see (owner playtests 2026-10-06 and 10-08): a found trap shows its own piece with a red
## border that doesn't cover it (no red box); nothing is noticed passively, only a Search (15 ft, its reach shown on the
## ground for a moment) finds a trap; a found trap isn't walked round and still goes off when walked onto, and can be
## set off on purpose from within 5 ft. A pit is a real hole: the one who springs it falls in and climbs out with a rope
## (or an Athletics check).

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Compendium.shared().tables["locations"]["test_trap_hall"] = {"id": "test_trap_hall", "name": "Trap Hall", "region": "test",
		"summary": "", "map": {"rows": ["############", "#..........#", "#..........#", "#..........#", "######.#####",
			"#....#.....#", "############"], "theme": "manor"},
		"spawns": {"default": [2, 2]}, "exits": [],
		"traps": [
			{"id": "plain_wolf_trap", "label": "a hunter's wolf trap", "cells": [[10, 1]], "detect_dc": 1, "disarm_dc": 10,
				"save": {"ability": "dex", "dc": 10}, "damage": "1d4", "damage_type": "piercing", "text": "Snap."},
			{"id": "subtle_tripwire", "label": "a fine tripwire", "cells": [[9, 3]], "detect_dc": 40, "disarm_dc": 10,
				"save": {"ability": "dex", "dc": 10}, "damage": "1d4", "damage_type": "piercing", "text": "Twang."},
			{"id": "walled_pit", "label": "a covered pit", "cells": [[2, 5]], "detect_dc": 0, "disarm_dc": 10,
				"save": {"ability": "dex", "dc": 10}, "damage": "1d4", "damage_type": "piercing", "text": "Down."}]}
	GameState.story.location = "test_trap_hall"
	GameState.story.visited["test_trap_hall"] = true
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 4:
		await get_tree().process_frame


func after_each() -> void:
	root.queue_free()
	Compendium.shared().tables["locations"].erase("test_trap_hall")


func _state(id: String) -> String:
	return str((GameState.story.loc_state("test_trap_hall")["traps"] as Dictionary).get(id, ""))


func test_nothing_is_noticed_passively_on_arrival() -> void:
	assert_eq(_state("plain_wolf_trap"), "", "in sight and under everyone's passive Perception, yet only a Search finds it")
	assert_eq(_state("subtle_tripwire"), "")
	assert_eq(_state("walled_pit"), "")


func test_a_found_trap_shows_its_piece_and_a_border_not_a_box() -> void:
	var view := root.get("view") as LocationView
	view.leader().cell = Vector2i(9, 1)
	view.search()
	assert_eq(_state("plain_wolf_trap"), "found", "a Search beside it finds it")
	var marks := view.trap_marks.get("plain_wolf_trap", []) as Array
	var names: Array = marks.map(func(n: Node3D) -> String: return str(n.name))
	assert_true(names.has("Dressing_trap_plain_wolf_trap_0"), "the wolf trap itself is drawn")
	assert_true(names.has("TrapBorder"), "with a red border round its square")
	for n: Node3D in marks:
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
			var bm := (mi as MeshInstance3D).mesh as BoxMesh
			assert_true(bm == null or minf(bm.size.x, bm.size.z) < 0.2, "no box covering the square")
	assert_false(view.trap_marks.has("subtle_tripwire"), "an unnoticed trap shows nothing")


func test_a_search_finds_traps_within_15_ft_and_shows_its_reach() -> void:
	var view := root.get("view") as LocationView
	view.search()
	assert_eq(_state("walled_pit"), "found", "the Search's Perception check meets the pit's DC, 15 ft off")
	assert_true(view.trap_marks.has("walled_pit"))
	assert_eq(_state("plain_wolf_trap"), "", "40 ft off: past the Search's reach")
	assert_eq(_state("subtle_tripwire"), "", "no roll finds a DC 40 tripwire")
	assert_true(view.has_node("SearchReach"), "the squares it reached show on the ground for a moment")
	var tint := (view.get_node("SearchReach/Layer_area") as MultiMeshInstance3D).material_override as StandardMaterial3D
	assert_between(tint.albedo_color.a, LocationTraps.REACH_ALPHA - 0.01, LocationTraps.REACH_ALPHA + 0.01,
		"a light tint, the ground showing through (owner: about 25%)")
	await get_tree().create_timer(LocationTraps.REACH_SHOWN + 0.5).timeout
	await get_tree().process_frame
	assert_false(view.has_node("SearchReach"), "and fade")


func test_a_found_trap_isnt_walked_round_and_still_goes_off() -> void:
	var view := root.get("view") as LocationView
	(GameState.story.loc_state("test_trap_hall")["traps"] as Dictionary)["plain_wolf_trap"] = "found"
	var to := Vector2i(10, 2)
	assert_eq(view._path(Vector2i(8, 1), to), view._path(Vector2i(8, 1), to, false), "a found trap doesn't change the way")
	assert_eq(str(view.thing_at(Vector2i(10, 1)).get("kind", "")), "trap", "the found trap is a thing to point at")
	view.walk_to(Vector2i(10, 1))
	for i in 300:
		if _state("plain_wolf_trap") == "triggered":
			break
		await get_tree().process_frame
	assert_eq(_state("plain_wolf_trap"), "triggered", "found, and walked onto: it goes off")
	assert_false(view.trap_marks.has("plain_wolf_trap"), "a spent trap loses its marks")


func _action(view: LocationView, cell: Vector2i, id: String) -> Dictionary:
	for a: Variant in view.actions_at(cell)["actions"] as Array:
		if str((a as Dictionary)["id"]) == id:
			return a as Dictionary
	return {}


func test_a_found_trap_can_be_set_off_on_purpose_from_within_5_ft() -> void:
	var view := root.get("view") as LocationView
	(GameState.story.loc_state("test_trap_hall")["traps"] as Dictionary)["plain_wolf_trap"] = "found"
	var far := _action(view, Vector2i(10, 1), "activate")
	assert_false(far.is_empty(), "right-click offers to set it off")
	assert_false(bool(far.get("enabled", true)), "but not from across the hall")
	assert_false(_action(view, Vector2i(10, 1), "disarm").is_empty(), "disarming stays a choice")
	view.leader().cell = Vector2i(9, 1)
	assert_true(bool(_action(view, Vector2i(10, 1), "activate").get("enabled", true)), "from beside it")
	var hp := view.leader().creature.hp
	view.act(Vector2i(10, 1), "activate")
	assert_eq(_state("plain_wolf_trap"), "triggered")
	assert_eq(view.leader().creature.hp, hp, "nobody in it: it snaps shut on nothing")


func _pit_hall() -> void:
	root.queue_free()
	await get_tree().process_frame
	var hall := Compendium.shared().get_entry("locations", "test_trap_hall").duplicate(true)
	hall["traps"] = [{"id": "hall_pit", "label": "a covered spiked pit", "cells": [[4, 2]], "pit_ft": 10, "detect_dc": 40,
		"disarm_dc": 15, "save": {"ability": "dex", "dc": 40}, "damage": "1d4", "damage_type": "piercing", "text": "Down you go."}]
	Compendium.shared().tables["locations"]["test_trap_hall"] = hall
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 4:
		await get_tree().process_frame


func test_a_pit_drops_whoever_springs_it_and_shows_the_hole() -> void:
	await _pit_hall()
	var view := root.get("view") as LocationView
	var victim := view.leader()
	var hp := victim.creature.hp
	view.walk_to(Vector2i(4, 2))
	for i in 200:
		if _state("hall_pit") == "triggered":
			break
		await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_state("hall_pit"), "triggered", "unnoticed, stepped on: it opens")
	assert_true(PitFall.holds(view, victim), "a DC 40 save fails: in the pit")
	assert_true(victim.creature.hp < hp, "the fall and the stakes hurt")
	assert_true(victim.creature.has_condition(&"prone"), "and they land Prone")
	var tok := view.tokens[victim.id] as CombatToken
	assert_true(tok.sprite.global_position.y < -1.5, "the figure is at the bottom, ten feet down")
	var marks := view.trap_marks.get("hall_pit", []) as Array
	assert_true(marks.any(func(n: Node3D) -> bool: return str(n.name) == "Pit_hall_pit"), "the hole is on the board")
	var acts: Array = (view.actions_at(victim.cell)["actions"] as Array).map(func(a: Dictionary) -> String: return str(a["id"]))
	assert_true(acts.has("climb"), "right-click offers the climb")


func test_a_rope_gets_them_out() -> void:
	await _pit_hall()
	var view := root.get("view") as LocationView
	var victim := view.leader()
	view.walk_to(Vector2i(4, 2))
	for i in 200:
		if PitFall.holds(view, victim):
			break
		await get_tree().process_frame
	assert_true(PitFall.holds(view, victim))
	GameState.story.give_item("rope", 1, GameState.story.party[1])
	view.act(victim.cell, "climb")
	assert_false(PitFall.holds(view, victim), "out on the rope, no check")
	assert_ne(victim.cell, Vector2i(4, 2), "standing beside the pit")
	assert_false(victim.creature.has_condition(&"prone"))
	assert_true((view.tokens[victim.id] as CombatToken).sprite.global_position.y > -0.1, "back at floor level")


func test_every_pit_trap_is_a_pit() -> void:
	# Owner (2026-10-07): any pit trap is a real drop. A trap that speaks of a pit, a shaft or an oubliette has `pit_ft`.
	var c := Compendium.shared()
	var pits := 0
	for lid: String in c.table("locations"):
		if lid.begins_with("test_"):
			continue   # this file's own hall
		for t: Variant in c.get_entry("locations", lid).get("traps", []):
			var trap := t as Dictionary
			var words := ("%s %s %s" % [trap["id"], trap.get("label", ""), trap.get("text", "")]).to_lower()
			if words.contains(" pit") or words.contains("_pit") or words.contains("shaft") or words.contains("oubliette"):
				assert_true(PitFall.is_pit(trap), "%s/%s is a pit with a depth" % [lid, trap["id"]])
				pits += 1
	assert_true(pits >= 2, "the Death House passage and the castle's open cell")
