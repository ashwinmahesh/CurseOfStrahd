extends TestCase
## The curtain of green fire behind the Tsolenka portcullis (dungeon expansion P1), played on the real map: it is built
## once the gate is up and not before, the first one to walk into it takes the fire (and it is spent), and what puts it
## out (Arcana, Dispel Magic: tests/unit/test_tsolenka_gate_wards.gd) takes its pieces and its trap away together.

const PASS := "tsolenka_pass"

var root: Node


func _start(gate_up: bool, fire_out: bool = false) -> void:
	GameState.reset()
	for id: String in ["hedda_ironvow", "silvain_aster", "ilse_varga", "tamsin_tealeaf"]:
		var ch := Pregens.build(id, 9)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	if gate_up:
		GameState.story.set_flag("tsolenka_gate_open")
	if fire_out:
		GameState.story.set_flag("tsolenka_green_fire_out")
	GameState.story.location = PASS
	GameState.story.visited[PASS] = true
	GameState.story.minute_of_day = 12 * 60
	# The portcullis is up when the winch has been hauled: its doors stand open.
	if gate_up:
		for d: String in ["tsolenka_portcullis_w", "tsolenka_portcullis_e"]:
			(GameState.story.loc_state(PASS)["doors"] as Dictionary)[d] = LocationView.DOOR_OPEN
	Dice.reseed(11)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	for i in 4:
		await get_tree().process_frame


func after_each() -> void:
	if root != null:
		root.queue_free()
		root = null


func _state() -> String:
	return str((GameState.story.loc_state(PASS)["traps"] as Dictionary).get("tsolenka_green_fire", ""))


func test_no_curtain_stands_while_the_portcullis_is_down() -> void:
	await _start(false)
	var view := root.get("view") as LocationView
	assert_false(view.prop_nodes.has("tsolenka_green_fire_w"), "nothing is built behind a closed gate")
	assert_false(view.prop_nodes.has("tsolenka_green_fire_e"))


func test_the_curtain_is_built_once_the_gate_is_up() -> void:
	await _start(true)
	var view := root.get("view") as LocationView
	assert_true(view.prop_nodes.has("tsolenka_green_fire_w"), "its flame in the west square")
	assert_true(view.prop_nodes.has("tsolenka_green_fire_e"), "and in the east one")
	assert_eq(_state(), "", "an unsprung trap")
	assert_true(view.prop_nodes.has("tsolenka_vrock_w") and view.prop_nodes.has("tsolenka_vrock_e"), "the two stone demons flank the gate")
	assert_true(view.prop_nodes.has("tsolenka_arch_w") and view.prop_nodes.has("tsolenka_arch_e"), "and the arches mark the bridge")


func test_the_first_to_walk_in_takes_the_fire_and_it_is_spent() -> void:
	await _start(true)
	var view := root.get("view") as LocationView
	var victim := view.leader()
	victim.cell = Vector2i(30, 8)
	var hp := victim.creature.hp
	view.walk_to(Vector2i(30, 6))
	for i in 300:
		if _state() == "triggered":
			break
		await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_state(), "triggered", "unfound and walked into: it goes off")
	assert_true(victim.creature.hp < hp, "4d10 of fire, halved on a save, still hurts")
	assert_true(bool(GameState.story.get_flag("tsolenka_green_fire_out", false)), "and the curtain is out for good")


func test_a_curtain_already_out_leaves_the_passage_clear() -> void:
	await _start(true, true)
	var view := root.get("view") as LocationView
	assert_false(view.prop_nodes.has("tsolenka_green_fire_w"), "no flame")
	var victim := view.leader()
	victim.cell = Vector2i(30, 8)
	var hp := victim.creature.hp
	view.walk_to(Vector2i(30, 6))
	for i in 120:
		await get_tree().process_frame
	assert_eq(_state(), "", "no trap went off")
	assert_eq(victim.creature.hp, hp, "and nobody was hurt")


func test_putting_it_out_by_conversation_takes_the_flames_with_it() -> void:
	await _start(true)
	var view := root.get("view") as LocationView
	assert_true(view.prop_nodes.has("tsolenka_green_fire_w"))
	GameState.story.set_flag("tsolenka_green_fire_out")
	view.refresh_npcs()   # what the game does after every conversation
	assert_false(view.prop_nodes.has("tsolenka_green_fire_w"), "the west flame goes")
	assert_false(view.prop_nodes.has("tsolenka_green_fire_e"), "and the east one")
