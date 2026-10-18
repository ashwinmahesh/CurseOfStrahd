extends TestCase
## `move <location>[:<spawn>]` in the game (Dungeon Expansion Plan E1, docs/contracts/dialogue.md): the conversation closes
## as it always does, then the party goes as through an exit, behind the same cover, to another map or to another square
## of the same one (a trap's drop from cell to cell). What the place does on arriving (a fight whose area they land in)
## happens as it does for any exit. test_dialogue_move covers the statement itself.

const ROOM_A := {
	"id": "test_move_a", "name": "Test Move A", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"#########",
		"#...#...#",
		"#...#...#",
		"#...#...#",
		"#########"], "light": "dim"},
	"spawns": {"default": [1, 1], "cell": [6, 2]},
}

const ROOM_B := {
	"id": "test_move_b", "name": "Test Move B", "region": "test", "summary": "A fixture.",
	"map": {"rows": [
		"###########",
		"#.........#",
		"#.........#",
		"#.........#",
		"###########"], "light": "dim"},
	"areas": [{"id": "landing_zone", "name": "Landing", "cells": [[6, 1], [9, 3]]}],
	"spawns": {"default": [1, 1], "landing": [7, 2]},
	"encounters": [{"id": "landing_wolves", "trigger": "enter_area:landing_zone",
		"monsters": [{"monster": "wolf", "cell": [9, 1]}], "flag": "test_landing_wolves_dead"}],
}

const DIALOGUE := """
~ to_b
Narrator: The floor gives way.
move test_move_b:landing

~ to_b_late
Narrator: The gas takes you.
time +240
move test_move_b

~ to_cell
move test_move_a:cell

~ to_b_default
move test_move_b
"""

var root: Node


func before_each() -> void:
	Compendium.shared().tables["locations"]["test_move_a"] = ROOM_A.duplicate(true)
	Compendium.shared().tables["locations"]["test_move_b"] = ROOM_B.duplicate(true)
	DialogueFile.register(DialogueFile.parse(DIALOGUE, "test/move_game"))
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "test_move_a"
	Dice.reseed(4)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	await _frames(1)
	UiMotion._checked = true
	UiMotion.reduced = true
	for id: String in ["test_move_a", "test_move_b"]:
		(Compendium.shared().tables["locations"] as Dictionary).erase(id)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _view() -> LocationView:
	return root.get("view") as LocationView


## Reads the conversation to its end and lets the move that follows it come up.
func _finish() -> void:
	for i in 12:
		var d := root.get("dialogue") as DialogueUI
		if d == null:
			break
		d.call("_advance")
		await _frames(2)
	for i in 120:
		if not bool(root.get("moving")):
			break
		await _frames(1)
	await _frames(3)


func test_the_party_arrives_on_another_map() -> void:
	var old := _view()
	assert_eq(old.loc_id, "test_move_a")
	root.call("start_dialogue", "test/move_game:to_b_default", "")
	await _frames(2)
	await _finish()
	var v := _view()
	assert_eq(v.loc_id, "test_move_b", "the party is in the other map")
	assert_true(v != old, "a new place was built")
	assert_eq(GameState.story.location, "test_move_b", "and the story knows it")
	assert_eq(v.leader().cell, Vector2i(1, 1), "no spawn named: the default one")
	assert_true(root.get("dialogue") == null, "the conversation is over")
	assert_eq(ModeController.mode, ModeController.Mode.EXPLORATION)
	assert_false(v.in_combat)
	assert_true((root.get("hud") as Node).get("visible"), "the exploring HUD is back")


func test_it_goes_to_the_named_spawn() -> void:
	root.call("start_dialogue", "test/move_game:to_b", "")
	await _frames(2)
	await _finish()
	var v := _view()
	assert_eq(v.loc_id, "test_move_b")
	assert_eq(v.leader().cell, Vector2i(7, 2), "the landing")
	for m in v.members:
		assert_true(v.grid.in_bounds(m.cell) and not v.grid.is_solid(m.cell), "%s stands on open floor" % m.cell)


func test_time_passes_before_the_party_goes() -> void:
	var before := GameState.story.total_minutes()
	root.call("start_dialogue", "test/move_game:to_b_late", "")
	await _frames(2)
	await _finish()
	assert_eq(_view().loc_id, "test_move_b")
	assert_eq(GameState.story.total_minutes() - before, 240, "four hours later")


func test_a_move_within_the_same_map_puts_the_party_on_another_square() -> void:
	var old := _view()
	assert_eq(old.leader().cell, Vector2i(1, 1))
	root.call("start_dialogue", "test/move_game:to_cell", "")
	await _frames(2)
	await _finish()
	var v := _view()
	assert_eq(v.loc_id, "test_move_a", "the same map")
	assert_true(v != old, "built again, as it is on coming back through an exit")
	assert_eq(v.leader().cell, Vector2i(6, 2), "on the far side of the wall")
	assert_eq(GameState.story.positions[0], Vector2i(6, 2), "and saved there")


func test_arriving_starts_what_the_place_starts() -> void:
	root.call("start_dialogue", "test/move_game:to_b", "")
	await _frames(2)
	await _finish()
	await _frames(6)
	assert_true(_view().in_combat, "they landed in the area whose fight starts on entering it")


func test_it_goes_behind_the_cover() -> void:
	UiMotion._checked = true
	UiMotion.reduced = false
	(root.get_script().get("took_ms") as Dictionary).erase("test_move_b")
	root.call("start_dialogue", "test/move_game:to_b_default", "")
	await _frames(2)
	await _finish()
	for i in 240:
		if _view().loc_id == "test_move_b" and not bool(root.get("moving")):
			break
		await _frames(1)
	assert_eq(_view().loc_id, "test_move_b")
	assert_true((root.get_script().get("took_ms") as Dictionary).has("test_move_b"), "built under the cover, like an exit's")
	assert_false(bool(root.get("moving")), "and the cover lifted")
