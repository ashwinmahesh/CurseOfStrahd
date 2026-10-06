extends TestCase
## The final battle in the game (ADR 0014, P6-01): the encounter waits for the Tarokka's room and the reading's quest,
## Strahd's parley plays first, the fight starts on `fight` (not on `yield`), its lair acts, and Misty Escape hands the
## story its flag with no remains left behind.

const LOC := {
	"id": "test_final_hall", "name": "Test Final Hall", "region": "castle_ravenloft", "summary": "A fixture.",
	"map": {"rows": [
		"############",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		"############"], "light": "dim"},
	"areas": [{"id": "study", "name": "Study", "cells": [[6, 1], [10, 4]]}],
	"spawns": {"default": [2, 3]},
	"encounters": [{"id": "final", "trigger": "enter_area:study", "final_battle": "castle_ravenloft_study", "lair": true,
		"monsters": [{"monster": "strahd_von_zarovich", "cell": [9, 2]}]}]
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_final_hall"] = LOC.duplicate(true)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 9)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_final_hall"
	GameState.story.tarokka = {"tome": "", "symbol": "", "sword": "", "ally": "", "enemy": "seer"}
	GameState.story.set_quest_stage("strahds_lair", "foretold")
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null
	await _frames(1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func test_no_final_battle_where_strahd_isnt_waiting() -> void:
	GameState.story.tarokka["enemy"] = "tempter"
	assert_false(_view()._trigger_encounter("enter_area:study"))
	assert_false(_view().in_combat)


func test_the_parley_comes_first_and_fight_starts_the_battle() -> void:
	var v := _view()
	assert_true(v._trigger_encounter("enter_area:study"))
	await _frames(2)
	assert_false(v.in_combat, "not before the parley")
	var d := root.get("dialogue") as Node
	assert_true(d != null, "Strahd names his price")
	GameState.story.set_flag("strahd_parley", "fight")
	d.queue_free()
	root.call("_dialogue_ended", "")
	await _frames(5)
	assert_true(v.in_combat, "the battle starts")
	assert_eq(GameState.story.quest_stage("strahds_lair"), "confronted")
	var cv := v.combat_view
	assert_true(cv.e.lair)
	assert_eq(cv.e.location_id, "test_final_hall")
	var strahd: Combatant = null
	for c in cv.e.combatants:
		if c.side == &"enemy":
			strahd = c
	assert_eq(strahd.creature.ward_hp, 50, "the Heart of Sorrow wards him")
	cv.e.deal_damage(null, strahd, [{"amount": 999, "type": "force"}], false, "test")
	assert_eq(str(cv.e.legendary.departed.get(strahd.id, "")), "mist")
	cv.finished.emit("victory")
	await _frames(3)
	assert_false(v.in_combat)
	assert_true(bool(GameState.story.get_flag("strahd_in_coffin")), "the story learns he fled to his coffin")
	assert_false(bool(GameState.story.get_flag("strahd_destroyed")))
	assert_true(v.find_child("Remains", true, false) == null, "mist leaves no remains")


func test_yield_starts_no_battle() -> void:
	GameState.story.set_flag("strahd_parley", "yield")
	assert_false(_view()._trigger_encounter("enter_area:study"))
	assert_false(_view().in_combat)
