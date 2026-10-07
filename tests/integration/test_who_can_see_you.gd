extends TestCase
## Who can see you (U10, docs/rules/stealth.md) on a fixture hall: while the party sneaks or explores turn-based, or
## while L is held, an eye over each foe waiting in plain view (red when it would notice the party, amber only in
## bright light, gold when the party's Stealth beats it), the squares it can see, and a warning on the square a move
## would be noticed from.

const LOC := {
	"id": "test_sight_hall", "name": "Sight Hall", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"################",
		"#..............#",
		"#..............#",
		"#.......#......#",
		"#.......#......#",
		"#..............#",
		"################"], "light": "bright"},
	"areas": [{"id": "far_end", "name": "Far end", "cells": [[12, 1], [14, 5]]}],
	"spawns": {"default": [2, 1]},
	"encounters": [{"id": "far_wolf", "trigger": "enter_area:far_end", "waiting": true,
		"monsters": [{"monster": "wolf", "cell": [13, 3]}], "flag": "test_far_wolf_dead"}]
}

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_sight_hall"] = LOC.duplicate(true)
	GameSettings.set_turn_based(false)
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 1)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_sight_hall"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	GameSettings.set_turn_based(false)
	Compendium.shared().tables["locations"].erase("test_sight_hall")
	if root != null:
		root.queue_free()
		root = null
	GameState.reset()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


func _overlay() -> SightOverlay:
	return _view().get_node("SightOverlay") as SightOverlay


func _sneak_with(total: int) -> void:
	var v := _view()
	v.set_sneaking(true)
	for m: Combatant in v.members + v.guest_members:
		v.sneak_totals[m.creature] = total


func test_eyes_and_reach_show_only_while_sneaking_or_turn_based() -> void:
	var v := _view()
	assert_true(LocationStealth.is_shown(v.waiting[0]), "the wolf is in plain view down the hall")
	var wolf := v.waiting[0]["foe"] as Combatant
	await _frames(2)
	assert_eq(_overlay().mood_of(wolf.id), "", "walking openly: no eyes")
	Input.action_press(&"show_sight")
	await _frames(2)
	assert_eq(_overlay().mood_of(wolf.id), "notices", "holding L shows them")
	assert_true(_overlay().reach_size("notices") > 0)
	Input.action_release(&"show_sight")
	await _frames(2)
	assert_eq(_overlay().mood_of(wolf.id), "", "and letting go hides them")
	v.toggle_plan()
	await _frames(2)
	assert_eq(_overlay().mood_of(wolf.id), "notices", "turn-based without sneaking: it would notice anyone")
	assert_true(_overlay().reach_size() > 0, "and its reach shows on the ground")
	var reach := _overlay().reach_of(LocationStealth.watch(v), wolf)
	for c in reach:
		assert_true(v.grid.distance_ft(wolf.cell, 1, c, 1) <= LocationStealth.NOTICE_FT, "%s is within the notice reach" % c)
	assert_true(Vector2i(9, 3) in reach, "the open floor before the wall is in its sight")
	assert_false(Vector2i(7, 4) in reach, "behind the wall is out of its sight, though only 30 ft off")


func test_the_eye_follows_the_partys_stealth() -> void:
	var v := _view()
	var wolf := v.waiting[0]["foe"] as Combatant
	var pp := wolf.creature.passive_score(&"perception").total()
	_sneak_with(pp - 5)
	await _frames(2)
	assert_eq(_overlay().mood_of(wolf.id), "notices", "it beats a Stealth 5 below its passive Perception even in dim light")
	_sneak_with(pp)
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = pp
	await _frames(2)
	assert_eq(_overlay().mood_of(wolf.id), "bright", "level with it: only bright light gives the party away")
	for m: Combatant in v.members:
		v.sneak_totals[m.creature] = pp + 1
	await _frames(2)
	assert_eq(_overlay().mood_of(wolf.id), "beaten", "the party's Stealth beats it")
	assert_eq(_overlay().reach_size("notices"), 0, "so none of what it sees is red")
	assert_true(_overlay().reach_size("beaten") > 0, "but it still shows, in gold, while the party sneaks")


func test_a_square_in_its_sight_warns_before_the_move() -> void:
	var v := _view()
	_sneak_with(1)
	v.toggle_plan()
	var near := Vector2i(9, 3)
	assert_true(LocationStealth.hover_warning(v, near).contains("Wolf"), "within 30 ft and in plain sight: the wolf would see")
	assert_eq(LocationStealth.hover_warning(v, Vector2i(3, 1)), "", "far down the hall it wouldn't")
	assert_true(LocationPlan.hover_text(v, near).contains("Wolf"), "the turn-based hint says so")
	assert_eq(v.leader().cell, Vector2i(2, 1), "and nobody moved")
