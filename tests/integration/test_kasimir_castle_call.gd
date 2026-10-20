extends TestCase
## Kasimir at the castle's road end (Story Allies Presence Plan, package K2): the chasm's edge calls his farewell on arrival when he made
## the bargain, travels with the party and has not yet left them (a prop's `call`, `approach` 6, `call_when`).

const GATES := "castle_ravenloft_gates"

var root: Node


func after_each() -> void:
	if is_instance_valid(root):
		root.queue_free()
	root = null
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _boot(at: Vector2i, along: bool, flags: Dictionary = {}) -> LocationView:
	GameState.reset()
	for id: String in ["ilse_varga", "tamsin_tealeaf", "hedda_ironvow", "silvain_aster"]:
		var ch := Pregens.build(id, 10)
		ch.finish_long_rest()
		GameState.story.party.append(ch)
	for f: String in flags:
		GameState.story.set_flag(f, flags[f])
	if along:
		assert_true(GameState.story.add_guest("kasimir_velikov"))
	GameState.story.location = GATES
	GameState.story.positions = [at, at + Vector2i(0, 1), at + Vector2i(-1, 0), at + Vector2i(-1, 1)]
	GameState.story.minute_of_day = 12 * 60
	Dice.reseed(1)
	root = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(root)
	await _frames(3)
	(root.get("hud") as ExploreHud).close_narration()
	return root.get("view") as LocationView


func test_the_chasms_edge_carries_the_call() -> void:
	for p: Variant in Compendium.shared().get_entry("locations", GATES)["props"]:
		if str((p as Dictionary)["id"]) == "crg_chasm_edge":
			assert_eq(str((p as Dictionary)["call"]), "allies/kasimir_castle:gates_road")
			assert_true(int((p as Dictionary)["approach"]) >= 5)
			assert_eq(str((p as Dictionary)["call_when"]), "guest:kasimir_velikov and flag.kasimir_bargain == \"made\" and not flag.kasimir_at_gates")
			return
	assert_true(false, "the prop exists")


func test_he_calls_on_arrival_by_the_road_once() -> void:
	var v: LocationView = await _boot(Vector2i(19, 31), true, {"kasimir_bargain": "made", "patrina_fate": "restored"})
	var calls: Array[String] = []
	v.dialogue_requested.connect(func(ref: String, _npc: String) -> void: calls.append(ref))
	assert_true(LocationNpcs._check_calls(v), "at the road's end, right by the chasm")
	assert_eq(calls, ["allies/kasimir_castle:gates_road"] as Array[String])
	assert_false(LocationNpcs._check_calls(v), "once")


func test_nothing_stirs_without_the_bargain_or_without_him() -> void:
	var no_bargain: LocationView = await _boot(Vector2i(19, 31), true)
	assert_false(LocationNpcs._check_calls(no_bargain), "he did not make the bargain")
	root.queue_free()
	await _frames(2)
	var alone: LocationView = await _boot(Vector2i(19, 31), false, {"kasimir_bargain": "made"})
	assert_false(LocationNpcs._check_calls(alone), "he is not along")
	root.queue_free()
	await _frames(2)
	var left: LocationView = await _boot(Vector2i(19, 31), true, {"kasimir_bargain": "made", "kasimir_at_gates": true})
	assert_false(LocationNpcs._check_calls(left), "he has already gone to wait")
