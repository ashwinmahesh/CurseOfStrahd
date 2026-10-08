extends TestCase
## A real location's fight and its breakable things (F5, world/combat/battle_scenery.gd from LocationFights): its
## closed door, the prop on a '=' square and a chandelier hanging over a trap become objects (a door the story watches
## doesn't); what broke stays broken when the fight is over (a door for good, a dropped chandelier's trap sprung), and
## the next fight there starts so.

const LOC := {
	"id": "test_scenery_hall", "name": "Test Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"############",
		"#....#.....#",
		"#..=.#..=..#",
		"#..........#",
		"#..........#",
		"############"], "light": "dim"},
	"spawns": {"default": [2, 3]},
	"doors": [{"id": "hall_door", "cell": [5, 3], "label": "the hall door"},
		{"id": "vault_door", "cell": [5, 4], "label": "the vault door", "flag": "test_vault_opened"}],
	"props": [
		{"id": "hall_table", "cell": [3, 2], "kind": "decor", "label": "the long table", "model": "table", "text": "A table."},
		{"id": "hall_lamp", "cell": [8, 4], "kind": "decor", "label": "the chandelier", "model": "candelabra", "text": "A wheel of candles.",
			"hangs": {"cells": [[8, 4], [9, 4]], "trap": "hall_drop", "lit": true}}],
	"traps": [{"id": "hall_drop", "cells": [[8, 4], [9, 4]], "label": "the chandelier", "detect_dc": 12,
		"save": {"ability": "dex", "dc": 13}, "damage": "3d6", "damage_type": "bludgeoning", "text": "It falls."}],
	"encounters": [
		{"id": "rats", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [10, 1]}]},
		{"id": "rats_again", "trigger": "manual", "monsters": [{"monster": "rat", "cell": [10, 1]}]}],
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_scenery_hall"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_scenery_hall"
	Dice.reseed(11)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _end_fight(v: LocationView) -> void:
	v.combat_view.finished.emit("victory")
	await _frames(4)


func test_doors_props_and_a_chandelier_break_and_stay_broken() -> void:
	var v := _view()
	assert_true(v.grid.has_flag(Vector2i(8, 2), CombatGrid.LOW), "a '=' square is low cover while exploring")
	assert_true(v.start_encounter("rats"), "a fight starts")
	await _frames(3)
	var e := v.combat_view.e
	var door := e.objects.blocking_at(Vector2i(5, 3))
	assert_true(door != null and door.door_id == "hall_door", "the closed door")
	assert_eq(door.name, "the hall door")
	assert_true(e.grid.has_flag(Vector2i(5, 3), CombatGrid.WALL))
	assert_true(e.objects.blocking_at(Vector2i(5, 4)) == null, "the story's door isn't an object")
	assert_true(e.grid.has_flag(Vector2i(5, 4), CombatGrid.WALL), "it stays shut")
	var table := e.objects.blocking_at(Vector2i(3, 2))
	assert_true(table != null and table.prop_id == "hall_table" and table.kind == "table", "the prop standing there")
	assert_true(e.objects.blocking_at(Vector2i(8, 2)) != null, "a bare '=' square: the place's own piece")
	var lamp: BattleObject = null
	for o in e.objects.list:
		if o.hangs:
			lamp = o
	assert_true(lamp != null and lamp.prop_id == "hall_lamp", "the chandelier hangs there")
	assert_eq([str(lamp.fall["save"]), int(lamp.fall["dc"]), str(lamp.fall["damage"])], ["dex", 13, "3d6"], "it falls as hard as its trap")
	e.objects.damage(door, [{"amount": 60, "type": "bludgeoning"}], null, "test")
	e.objects.damage(table, [{"amount": 60, "type": "bludgeoning"}], null, "test")
	e.objects.damage(lamp, [{"amount": 30, "type": "piercing"}], null, "test")
	assert_true(door.destroyed and table.destroyed and lamp.destroyed)
	await _end_fight(v)
	assert_false(v.in_combat, "the fight is over")
	var st := v.st.loc_state("test_scenery_hall")
	assert_eq(str((st["doors"] as Dictionary).get("hall_door", "")), LocationView.DOOR_OPEN, "the broken door stays open")
	assert_false(v.grid.has_flag(Vector2i(5, 3), CombatGrid.WALL), "the way through is open")
	assert_false((v.door_nodes["hall_door"] as Node3D).visible)
	assert_false(v.grid.has_flag(Vector2i(3, 2), CombatGrid.LOW), "the table is gone")
	assert_true(v.grid.has_flag(Vector2i(3, 2), CombatGrid.DIFFICULT), "its wreckage")
	assert_eq(str((st["traps"] as Dictionary).get("hall_drop", "")), "triggered", "the chandelier's trap is sprung")
	assert_true(v.grid.has_flag(Vector2i(9, 4), CombatGrid.DIFFICULT), "it lies on the floor")
	assert_true(v.start_encounter("rats_again"), "the next fight starts")
	await _frames(3)
	var e2 := v.combat_view.e
	assert_true(e2.objects.blocking_at(Vector2i(5, 3)) == null and not e2.grid.has_flag(Vector2i(5, 3), CombatGrid.WALL), "no door")
	assert_true(e2.objects.blocking_at(Vector2i(3, 2)) == null and not e2.grid.has_flag(Vector2i(3, 2), CombatGrid.LOW), "no table")
	assert_true(e2.grid.has_flag(Vector2i(3, 2), CombatGrid.DIFFICULT), "its wreckage")
	assert_false(e2.objects.list.any(func(o: BattleObject) -> bool: return o.hangs), "nothing hangs there now")
	assert_true(e2.objects.blocking_at(Vector2i(8, 2)) != null, "what wasn't broken still stands")
	await _end_fight(v)
