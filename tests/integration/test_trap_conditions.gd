extends TestCase
## What a trap leaves on a hero outside a fight (owner todo 2026-10-17: "how to stand up if we fall prone from a trap?"):
## Prone is a state, not a duration, and outside a fight there is no turn to spend standing (2024 PHB, Prone), so the hero
## stands as the party moves on or acts, or a moment after the fall; a pit's victim climbs out instead, and a hero at 0 Hit
## Points waits for healing. Any other condition a trap gives (Poisoned, Frightened...) is a lasting effect that runs out
## with the clock (`condition_minutes`; a minute for Frightened, ten for anything else), in a fight as outside one: before
## this it stayed on the hero for good, long rests and all.

const HALL := {
	"id": "test_trap_cond_hall", "name": "Trap Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"##############",
		"#............#",
		"#............#",
		"#............#",
		"##############"], "light": "dim"},
	"spawns": {"default": [2, 2]},
	"traps": [
		{"id": "c_slick", "label": "black ice", "cells": [[4, 2]], "detect_dc": 40, "disarm_dc": 40, "save": {"ability": "dex", "dc": 40},
			"damage": "1d4", "damage_type": "bludgeoning", "condition": "prone", "text": "You slip."},
		{"id": "c_soot", "label": "a breath of soot", "cells": [[6, 2]], "detect_dc": 40, "disarm_dc": 40, "save": {"ability": "con", "dc": 40},
			"damage": "1d4", "damage_type": "poison", "condition": "poisoned", "condition_minutes": 10, "text": "Cough."},
		{"id": "c_gaze", "label": "a blank face", "cells": [[8, 2]], "detect_dc": 40, "disarm_dc": 40, "save": {"ability": "wis", "dc": 40},
			"damage": "1d4", "damage_type": "psychic", "condition": "frightened", "text": "Brr."},
		{"id": "c_glare", "label": "a flash", "cells": [[10, 2]], "detect_dc": 40, "disarm_dc": 40, "save": {"ability": "dex", "dc": 40},
			"damage": "1d4", "damage_type": "radiant", "condition": "blinded", "text": "Flash."},
		{"id": "c_pit", "label": "a covered pit", "cells": [[12, 2]], "pit_ft": 10, "detect_dc": 40, "disarm_dc": 40,
			"save": {"ability": "dex", "dc": 40}, "damage": "1d4", "damage_type": "piercing", "text": "Down."}]}

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	Compendium.shared().tables["locations"]["test_trap_cond_hall"] = HALL.duplicate(true)
	GameState.story.location = "test_trap_cond_hall"
	GameState.story.visited["test_trap_cond_hall"] = true
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(4)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	get_tree().paused = false
	await _frames(1)
	(Compendium.shared().tables["locations"] as Dictionary).erase("test_trap_cond_hall")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _spring(id: String) -> Combatant:
	var view := _view()
	var trap: Dictionary = {}
	for t: Variant in HALL["traps"]:
		if str((t as Dictionary)["id"]) == id:
			trap = t as Dictionary
	var victim := view.leader()
	victim.cell = LocationView._cell((trap["cells"] as Array)[0])
	LocationTraps.activate(view, trap)
	return victim


## The condition tags on the party panel, all cards together.
func _tags() -> Array[String]:
	var out: Array[String] = []
	for l in (root.get("hud") as ExploreHud).find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func test_a_hero_thrown_down_shows_prone_and_then_gets_up_on_their_own() -> void:
	var victim := _spring("c_slick")
	await _frames(2)
	assert_true(victim.creature.has_condition(&"prone"), "thrown down")
	assert_true("Prone" in _tags(), "the party panel says so: %s" % [_tags()])
	await get_tree().create_timer(LocationCare.STAND_AFTER + 0.8).timeout
	assert_false(victim.creature.has_condition(&"prone"), "a moment later they are on their feet")
	assert_false("Prone" in _tags(), "and the panel has dropped the tag")


func test_the_party_moving_on_stands_them_at_once() -> void:
	var view := _view()
	var victim := _spring("c_slick")
	await _frames(2)
	assert_true(victim.creature.has_condition(&"prone"))
	view.walk_to(victim.cell + Vector2i(0, 1))
	for i in 120:
		if not victim.creature.has_condition(&"prone"):
			break
		await get_tree().process_frame
	assert_false(victim.creature.has_condition(&"prone"), "the first step gets them up, long before they would have")
	assert_false("Prone" in _tags(), "panel too")


func test_acting_or_searching_stands_them_first() -> void:
	var view := _view()
	var victim := _spring("c_slick")
	assert_true(victim.creature.has_condition(&"prone"))
	view.search()
	assert_false(victim.creature.has_condition(&"prone"), "a Search starts from their feet")
	var again := _spring("c_slick")
	assert_true(again.creature.has_condition(&"prone"))
	view.act(Vector2i(2, 3), "walk")
	assert_false(again.creature.has_condition(&"prone"), "so does anything picked from the menu")


func test_a_pit_victim_stays_down_until_they_climb_out() -> void:
	var view := _view()
	var victim := _spring("c_pit")
	assert_true(PitFall.holds(view, victim), "in the pit")
	assert_true(victim.creature.has_condition(&"prone"))
	await get_tree().create_timer(LocationCare.STAND_AFTER + 0.8).timeout
	assert_true(victim.creature.has_condition(&"prone"), "no standing at the bottom of a pit: the climb comes first")
	assert_true(LocationCare.lying(view).is_empty(), "so they aren't among those who get up")


func test_nobody_at_zero_hit_points_gets_up_on_their_own() -> void:
	var view := _view()
	var victim := view.leader()
	victim.creature.hp = 0
	victim.creature.add_condition(&"prone", "a fall")
	assert_true(LocationCare.lying(view).is_empty(), "healing gets them up, not the clock")
	await get_tree().create_timer(LocationCare.STAND_AFTER + 0.5).timeout
	assert_true(victim.creature.conditions.has(&"prone"))


func test_nobody_starts_a_fight_lying_down() -> void:
	var view := _view()
	var victim := _spring("c_slick")
	var tended := [0]
	view.party_tended.connect(func() -> void: tended[0] += 1)
	assert_true(LocationCare.stand_up(view, true), "the start of a fight stands them")
	assert_false(victim.creature.has_condition(&"prone"))
	assert_eq(tended[0], 0, "quietly: the fight's start does the refreshing")


func test_poison_from_a_trap_runs_out() -> void:
	var victim := _spring("c_soot")
	assert_true(victim.creature.has_condition(&"poisoned"), "poisoned")
	await _frames(2)
	assert_true("Poisoned" in _tags(), "the panel says so: %s" % [_tags()])
	GameState.story.advance_minutes(9)
	assert_true(victim.creature.has_condition(&"poisoned"), "still, nine minutes on")
	GameState.story.advance_minutes(2)
	assert_false(victim.creature.has_condition(&"poisoned"), "gone after its ten minutes (before this it stayed for good)")


func test_a_fright_is_a_minute() -> void:
	var victim := _spring("c_gaze")
	assert_true(victim.creature.has_condition(&"frightened"))
	GameState.story.advance_minutes(1)
	assert_false(victim.creature.has_condition(&"frightened"), "the default for Frightened is a minute")


func test_any_other_condition_lasts_ten_minutes_unless_the_trap_says() -> void:
	var victim := _spring("c_glare")
	assert_true(victim.creature.has_condition(&"blinded"))
	GameState.story.advance_minutes(9)
	assert_true(victim.creature.has_condition(&"blinded"))
	GameState.story.advance_minutes(1)
	assert_false(victim.creature.has_condition(&"blinded"))


func test_a_trap_condition_survives_a_save_and_load_and_still_runs_out() -> void:
	var victim := _spring("c_soot")
	var twin := Pregens.build("ilse_varga", 3)
	twin.state_from_dict(victim.creature.state_to_dict())
	assert_true(twin.has_condition(&"poisoned"), "kept")
	twin.advance_minutes(11)
	assert_false(twin.has_condition(&"poisoned"), "and it still runs out")


func test_the_same_in_a_fight() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2))
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	var trap := {"id": "snare", "label": "a snare", "cells": [[3, 2]], "detect_dc": 15, "disarm_dc": 15,
		"save": {"ability": "dex", "dc": 40}, "damage": "1d4", "damage_type": "piercing", "condition": "poisoned"}
	e.traps.add(trap)
	TestCombat.start_with(e, c)
	assert_true(e.move(c, Vector2i(3, 2)).ok)
	assert_true(c.creature.has_condition(&"poisoned"), "a failed save: poisoned")
	c.creature.advance_minutes(11)
	assert_false(c.creature.has_condition(&"poisoned"), "and it runs out, in a fight's aftermath too")
