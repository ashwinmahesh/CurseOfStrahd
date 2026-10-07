extends TestCase
## Traps the party can and can't see (owner playtest 2026-10-06): a noticed trap shows its own piece with a red border
## that doesn't cover it (no red box); passive Perception notices any trap in sight whose DC it meets, the moment the
## party arrives; a trap above it, or out of sight, stays hidden until a Search finds it. A pit is a real hole: the one
## who springs it falls in and climbs out with a rope (or an Athletics check).

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


func test_passive_perception_notices_traps_in_sight_on_arrival() -> void:
	assert_eq(_state("plain_wolf_trap"), "found", "in sight and under everyone's passive Perception: noticed at once, ten squares off")
	assert_eq(_state("subtle_tripwire"), "", "in sight but above it: still hidden")
	assert_eq(_state("walled_pit"), "", "behind a wall: nobody can see it, however easy")


func test_a_noticed_trap_shows_its_piece_and_a_border_not_a_box() -> void:
	var view := root.get("view") as LocationView
	var marks := view.trap_marks.get("plain_wolf_trap", []) as Array
	var names: Array = marks.map(func(n: Node3D) -> String: return str(n.name))
	assert_true(names.has("Dressing_trap_plain_wolf_trap_0"), "the wolf trap itself is drawn")
	assert_true(names.has("TrapBorder"), "with a red border round its square")
	for n: Node3D in marks:
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
			var bm := (mi as MeshInstance3D).mesh as BoxMesh
			assert_true(bm == null or minf(bm.size.x, bm.size.z) < 0.2, "no box covering the square")
	assert_false(view.trap_marks.has("subtle_tripwire"), "an unnoticed trap shows nothing")


func test_a_search_finds_what_passive_perception_missed() -> void:
	var view := root.get("view") as LocationView
	view.search()
	assert_eq(_state("walled_pit"), "found", "the Search's Perception check meets the pit's DC")
	assert_true(view.trap_marks.has("walled_pit"))
	assert_eq(_state("subtle_tripwire"), "", "no roll finds a DC 40 tripwire")


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
