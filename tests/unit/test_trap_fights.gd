extends TestCase
## Traps in a fight (owner, 2026-10-08): whoever moves onto a trap's square springs it, friend or foe, walking or
## shoved; a sprung trap is spent; a pit drops its victim; a flyer passes over; a saved fight keeps them
## (combat/encounter_traps.gd).


func _trap(id: String, cells: Array, extra: Dictionary = {}) -> Dictionary:
	var t := {"id": id, "label": "a test trap", "cells": cells, "detect_dc": 15, "disarm_dc": 15,
		"save": {"ability": "dex", "dc": 30}, "damage": "2d6", "damage_type": "piercing", "condition": "poisoned"}
	t.merge(extra, true)
	return t


## A trap across the whole of column 3 of the open field, so any way east crosses it.
func _wall_of_trap(id: String, extra: Dictionary = {}) -> Dictionary:
	var cells: Array = []
	for y in 8:
		cells.append([3, y])
	return _trap(id, cells, extra)


func test_walking_onto_a_trap_springs_it_once() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2))
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	e.traps.add(_wall_of_trap("snare"))
	TestCombat.start_with(e, c)
	var hp := c.creature.hp
	var r := e.move(c, Vector2i(5, 2))
	assert_true(r.ok, r.reason)
	assert_true(c.creature.hp < hp, "its damage")
	assert_true(c.creature.has_condition(&"poisoned"), "a failed DC 30 save: its condition")
	assert_eq(",".join(e.traps.sprung_ids()), "snare")
	hp = c.creature.hp
	c.movement_left = c.speed()
	assert_true(e.move(c, Vector2i(1, 2)).ok)
	assert_eq(c.creature.hp, hp, "a sprung trap is spent")


func test_a_foe_shoved_onto_a_trap_springs_it() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2))
	var foe := TestCombat.punching_bag(e, Vector2i(2, 2), 200)
	e.traps.add(_trap("snare", [[3, 2]]))
	TestCombat.start_with(e, c)
	e.movement.forced_move(foe, Vector2(1.5, 2.5), 5)
	assert_eq(foe.cell, Vector2i(3, 2), "pushed onto the trap")
	assert_true(foe.creature.hp < 200, "and it goes off under the foe")


func test_a_pit_drops_whoever_fails_the_save() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2))
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	e.traps.add(_wall_of_trap("pit", {"pit_ft": 20, "damage": "1d4", "condition": ""}))
	TestCombat.start_with(e, c)
	var hp := c.creature.hp
	assert_true(e.move(c, Vector2i(5, 2)).ok)
	assert_true(c.creature.hp < hp, "the fall and the stakes")
	assert_true(c.creature.has_condition(&"prone"), "it lands Prone")


func test_a_flyer_passes_over_a_trap() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2), 5)
	c.creature.add_effect(Effect.new("Wings", &"spell", "test_wings").with_modifier("speed_set", {"kind": "fly", "value": 60}))
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	e.traps.add(_wall_of_trap("snare"))
	TestCombat.start_with(e, c)
	assert_true(e.fly_vertical(c, 10).ok)
	var hp := c.creature.hp
	assert_true(e.move(c, Vector2i(5, 2)).ok)
	assert_eq(c.creature.hp, hp, "10 ft up, nothing goes off")
	assert_true(e.traps.sprung_ids().is_empty())


func test_a_saved_fight_keeps_its_traps() -> void:
	var e := TestCombat.open_field(3)
	var c := TestCombat.hero(e, "ilse_varga", Vector2i(1, 2))
	TestCombat.foe(e, "zombie", Vector2i(10, 6))
	e.traps.add(_wall_of_trap("snare"))
	e.traps.add(_trap("spare", [[8, 6]]))
	TestCombat.start_with(e, c)
	assert_true(e.move(c, Vector2i(5, 2)).ok)
	var back := EncounterSnapshot.restore(EncounterSnapshot.capture(e), DiceRoller.new(3))
	assert_eq(",".join(back.traps.sprung_ids()), "snare", "the sprung one stays spent")
	assert_false(back.traps.armed_at(Vector2i(8, 6)).is_empty(), "the other is still armed")
