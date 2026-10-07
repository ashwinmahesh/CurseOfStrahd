extends TestCase
## Owner report (2026-10-07): "Strahd doesn't appear in the overworld when he first appears for the funeral." A scene
## puts its speakers on the map (`appear <npc> [at <id>]`, `vanish <npc>`), and they leave when it ends.

var root: Node


func before_each() -> void:
	GameState.reset()
	for id: String in Pregens.roster_ids().slice(0, 4):
		var ch := Pregens.build(id, 3)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	GameState.story.location = "village_of_barovia"
	Dice.reseed(5)
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


func test_strahd_stands_at_the_lych_gate_while_he_speaks_at_the_funeral() -> void:
	var v := _view()
	root.call("start_dialogue", "village_of_barovia/burial:strahd_arrives", "")
	await _frames(3)
	var staged := v.get("_staged") as Dictionary
	assert_true(staged.has("strahd"), "Strahd is on the map")
	if not staged.has("strahd"):
		return
	var tok := staged["strahd"] as Node3D
	var gate := Vector2i(28, 9)
	assert_true(Vector2(v.grid.cell_at(tok.position) - gate).length() <= 4.0, "by the lych-gate")
	var bot := StoryBot.new(self, root)
	bot.prefer.assign(["Say nothing."])
	await bot.converse()
	await _frames(3)
	assert_false((v.get("_staged") as Dictionary).has("strahd"), "and gone when the scene is")


func test_a_visit_brings_him_onto_the_map_too() -> void:
	var v := _view()
	root.call("start_dialogue", "strahd/visits:night", "")
	await _frames(3)
	assert_true((v.get("_staged") as Dictionary).has("strahd"), "his night visit puts him beside the party")
	var bot := StoryBot.new(self, root)
	await bot.converse()
	await _frames(3)
	assert_true((v.get("_staged") as Dictionary).is_empty())
